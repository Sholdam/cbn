begin;

-- BKL-018: perfis humanos controlados. Nao cria usuario Auth, e-mail ou senha.
alter table public.user_profiles
  add column status text not null default 'ACTIVE',
  add column status_changed_at timestamptz,
  add column status_changed_by uuid references auth.users(id) on delete set null,
  add column role_changed_at timestamptz,
  add column role_changed_by uuid references auth.users(id) on delete set null;

update public.user_profiles
set status = case when active then 'ACTIVE' else 'DISABLED' end,
    status_changed_at = coalesce(updated_at, created_at);

alter table public.user_profiles
  add constraint user_profiles_status_ck
    check (status in ('ACTIVE', 'DISABLED', 'PENDING_REVIEW')),
  add constraint user_profiles_active_status_ck
    check (active = (status = 'ACTIVE'));

comment on column public.user_profiles.status is
  'Estado humano controlado: ACTIVE, DISABLED ou PENDING_REVIEW.';

-- Todos os helpers de RLS passam a negar perfil pendente ou desativado.
create or replace function app_private.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select up.role
  from public.user_profiles up
  where up.user_id = auth.uid()
    and up.active
    and up.status = 'ACTIVE'
  limit 1
$$;

-- Auditoria minima desta fase. O helper nao e executavel por identidades web.
create or replace function audit.record_human_profile_event(
  p_event_type text,
  p_target_user_id uuid,
  p_allowed boolean,
  p_reason_code text,
  p_purpose_code text,
  p_process_version text,
  p_target_role public.app_role default null,
  p_target_status text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_event_type not in (
      'HUMAN_PROFILE_CREATED', 'HUMAN_ROLE_CHANGED',
      'HUMAN_PROFILE_DISABLED', 'HUMAN_PROFILE_REACTIVATED',
      'HUMAN_ROLE_ELEVATION_DENIED'
    )
    or p_target_user_id is null
    or p_reason_code !~ '^[A-Z0-9_:-]{2,80}$'
    or p_purpose_code !~ '^[A-Z0-9_:-]{2,80}$'
    or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$'
    or (p_target_status is not null and p_target_status not in (
      'ACTIVE', 'DISABLED', 'PENDING_REVIEW'
    )) then
    raise exception using errcode = '22023', message = 'human_profile_audit_metadata_rejected';
  end if;

  insert into audit.events (
    actor_id, actor_role, origin, event_type, entity_type, entity_id,
    allowed, purpose_code, metadata
  ) values (
    auth.uid(), app_private.current_user_role(), 'human', p_event_type,
    'HUMAN_PROFILE', p_target_user_id::text, p_allowed, p_purpose_code,
    jsonb_strip_nulls(jsonb_build_object(
      'reason_code', p_reason_code,
      'process_version', p_process_version,
      'identity_model', 'BKL018_HUMAN_PROFILE_V1',
      'target_role', p_target_role::text,
      'target_status', p_target_status
    ))
  );
end;
$$;

revoke all on function audit.record_human_profile_event(
  text, uuid, boolean, text, text, text, public.app_role, text
) from public, anon, authenticated, service_role;

create or replace function public.admin_create_human_profile(
  p_target_user_id uuid,
  p_role public.app_role,
  p_status text,
  p_purpose_code text,
  p_process_version text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  caller_role public.app_role := app_private.current_user_role();
begin
  if p_target_user_id is null
    or p_status not in ('ACTIVE', 'DISABLED', 'PENDING_REVIEW')
    or p_purpose_code !~ '^[A-Z0-9_:-]{2,80}$'
    or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'human_profile_request_rejected';
  end if;

  if caller_id is null then
    raise exception using errcode = '42501', message = 'human_identity_required';
  end if;

  if caller_role is distinct from 'admin'::public.app_role then
    perform audit.record_human_profile_event(
      'HUMAN_ROLE_ELEVATION_DENIED', p_target_user_id, false,
      'CALLER_NOT_ACTIVE_ADMIN', p_purpose_code, p_process_version, p_role, p_status
    );
    return false;
  end if;

  if caller_id = p_target_user_id then
    perform audit.record_human_profile_event(
      'HUMAN_ROLE_ELEVATION_DENIED', p_target_user_id, false,
      'SELF_ASSIGNMENT_DENIED', p_purpose_code, p_process_version, p_role, p_status
    );
    return false;
  end if;

  if not exists (select 1 from auth.users where id = p_target_user_id)
     or exists (select 1 from public.user_profiles where user_id = p_target_user_id) then
    raise exception using errcode = '23514', message = 'human_profile_target_rejected';
  end if;

  insert into public.user_profiles (
    user_id, role, display_name, active, status,
    status_changed_at, status_changed_by, role_changed_at, role_changed_by
  ) values (
    p_target_user_id, p_role, null, p_status = 'ACTIVE', p_status,
    now(), caller_id, now(), caller_id
  );

  perform audit.record_human_profile_event(
    'HUMAN_PROFILE_CREATED', p_target_user_id, true,
    'PROFILE_CREATED', p_purpose_code, p_process_version, p_role, p_status
  );
  return true;
end;
$$;

create or replace function public.admin_change_human_role(
  p_target_user_id uuid,
  p_role public.app_role,
  p_purpose_code text,
  p_process_version text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  caller_role public.app_role := app_private.current_user_role();
  affected integer;
  target_status text;
begin
  if p_target_user_id is null
    or p_purpose_code !~ '^[A-Z0-9_:-]{2,80}$'
    or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'human_profile_request_rejected';
  end if;
  if caller_id is null then
    raise exception using errcode = '42501', message = 'human_identity_required';
  end if;
  if caller_role is distinct from 'admin'::public.app_role then
    perform audit.record_human_profile_event(
      'HUMAN_ROLE_ELEVATION_DENIED', p_target_user_id, false,
      'CALLER_NOT_ACTIVE_ADMIN', p_purpose_code, p_process_version, p_role, null
    );
    return false;
  end if;
  if caller_id = p_target_user_id then
    perform audit.record_human_profile_event(
      'HUMAN_ROLE_ELEVATION_DENIED', p_target_user_id, false,
      'SELF_ROLE_CHANGE_DENIED', p_purpose_code, p_process_version, p_role, null
    );
    return false;
  end if;

  select status into target_status
  from public.user_profiles where user_id = p_target_user_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'human_profile_not_found';
  end if;

  update public.user_profiles
  set role = p_role, role_changed_at = now(), role_changed_by = caller_id
  where user_id = p_target_user_id and role is distinct from p_role;
  get diagnostics affected = row_count;
  if affected = 0 then return false; end if;

  perform audit.record_human_profile_event(
    'HUMAN_ROLE_CHANGED', p_target_user_id, true,
    'ROLE_CHANGED', p_purpose_code, p_process_version, p_role, target_status
  );
  return true;
end;
$$;

create or replace function public.admin_disable_human_profile(
  p_target_user_id uuid,
  p_purpose_code text,
  p_process_version text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  caller_role public.app_role := app_private.current_user_role();
  target_role public.app_role;
  affected integer;
begin
  if p_target_user_id is null
    or p_purpose_code !~ '^[A-Z0-9_:-]{2,80}$'
    or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'human_profile_request_rejected';
  end if;
  if caller_id is null then
    raise exception using errcode = '42501', message = 'human_identity_required';
  end if;
  if caller_role is distinct from 'admin'::public.app_role or caller_id = p_target_user_id then
    perform audit.record_human_profile_event(
      'HUMAN_ROLE_ELEVATION_DENIED', p_target_user_id, false,
      case when caller_id = p_target_user_id then 'SELF_DISABLE_DENIED'
           else 'CALLER_NOT_ACTIVE_ADMIN' end,
      p_purpose_code, p_process_version, null, 'DISABLED'
    );
    return false;
  end if;

  select role into target_role from public.user_profiles
  where user_id = p_target_user_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'human_profile_not_found'; end if;

  update public.user_profiles
  set active = false, status = 'DISABLED', status_changed_at = now(),
      status_changed_by = caller_id
  where user_id = p_target_user_id and status <> 'DISABLED';
  get diagnostics affected = row_count;
  if affected = 0 then return false; end if;

  perform audit.record_human_profile_event(
    'HUMAN_PROFILE_DISABLED', p_target_user_id, true,
    'PROFILE_DISABLED', p_purpose_code, p_process_version, target_role, 'DISABLED'
  );
  return true;
end;
$$;

create or replace function public.admin_reactivate_human_profile(
  p_target_user_id uuid,
  p_purpose_code text,
  p_process_version text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  caller_role public.app_role := app_private.current_user_role();
  target_role public.app_role;
  affected integer;
begin
  if p_target_user_id is null
    or p_purpose_code !~ '^[A-Z0-9_:-]{2,80}$'
    or p_process_version !~ '^[A-Za-z0-9._:-]{1,40}$' then
    raise exception using errcode = '22023', message = 'human_profile_request_rejected';
  end if;
  if caller_id is null then
    raise exception using errcode = '42501', message = 'human_identity_required';
  end if;
  if caller_role is distinct from 'admin'::public.app_role or caller_id = p_target_user_id then
    perform audit.record_human_profile_event(
      'HUMAN_ROLE_ELEVATION_DENIED', p_target_user_id, false,
      case when caller_id = p_target_user_id then 'SELF_REACTIVATION_DENIED'
           else 'CALLER_NOT_ACTIVE_ADMIN' end,
      p_purpose_code, p_process_version, null, 'ACTIVE'
    );
    return false;
  end if;

  select role into target_role from public.user_profiles
  where user_id = p_target_user_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'human_profile_not_found'; end if;

  update public.user_profiles
  set active = true, status = 'ACTIVE', status_changed_at = now(),
      status_changed_by = caller_id
  where user_id = p_target_user_id and status <> 'ACTIVE';
  get diagnostics affected = row_count;
  if affected = 0 then return false; end if;

  perform audit.record_human_profile_event(
    'HUMAN_PROFILE_REACTIVATED', p_target_user_id, true,
    'PROFILE_REACTIVATED', p_purpose_code, p_process_version, target_role, 'ACTIVE'
  );
  return true;
end;
$$;

create or replace function public.get_my_profile()
returns table (user_id uuid, role public.app_role, status text)
language sql
stable
security definer
set search_path = ''
as $$
  select up.user_id, up.role, up.status
  from public.user_profiles up
  where up.user_id = auth.uid()
$$;

-- Gestao humana somente por RPC controlada. Nem admin altera a tabela diretamente.
drop policy if exists user_profiles_self_read on public.user_profiles;
drop policy if exists user_profiles_admin_all on public.user_profiles;
revoke all on public.user_profiles from public, anon, authenticated, service_role;

do $$
declare
  fn regprocedure;
begin
  foreach fn in array array[
    'public.admin_create_human_profile(uuid,public.app_role,text,text,text)'::regprocedure,
    'public.admin_change_human_role(uuid,public.app_role,text,text)'::regprocedure,
    'public.admin_disable_human_profile(uuid,text,text)'::regprocedure,
    'public.admin_reactivate_human_profile(uuid,text,text)'::regprocedure,
    'public.get_my_profile()'::regprocedure
  ] loop
    execute format('revoke all on function %s from public, anon, service_role', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;

comment on function public.get_my_profile() is
  'Retorna somente UUID tecnico, papel humano e estado do proprio usuario.';

commit;
