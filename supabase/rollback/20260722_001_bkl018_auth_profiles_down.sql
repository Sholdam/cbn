begin;

-- Fail closed: nao perder semantica de estado ou auditoria humana nova.
do $$
begin
  if exists (
    select 1 from audit.events
    where metadata ->> 'identity_model' = 'BKL018_HUMAN_PROFILE_V1'
  ) then
    raise exception using errcode = '55000',
      message = 'Rollback BKL-018 recusado: existe auditoria indispensavel de perfil humano';
  end if;
  if exists (
    select 1 from public.user_profiles
    where status = 'PENDING_REVIEW'
       or active is distinct from (status = 'ACTIVE')
  ) then
    raise exception using errcode = '55000',
      message = 'Rollback BKL-018 recusado: existe estado humano nao representavel';
  end if;
end
$$;

drop function if exists public.admin_create_human_profile(uuid, public.app_role, text, text, text);
drop function if exists public.admin_change_human_role(uuid, public.app_role, text, text);
drop function if exists public.admin_disable_human_profile(uuid, text, text);
drop function if exists public.admin_reactivate_human_profile(uuid, text, text);
drop function if exists public.get_my_profile();
drop function if exists audit.record_human_profile_event(
  text, uuid, boolean, text, text, text, public.app_role, text
);

alter table public.user_profiles drop constraint if exists user_profiles_active_status_ck;
alter table public.user_profiles drop constraint if exists user_profiles_status_ck;
alter table public.user_profiles
  drop column if exists role_changed_by,
  drop column if exists role_changed_at,
  drop column if exists status_changed_by,
  drop column if exists status_changed_at,
  drop column if exists status;

create or replace function app_private.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select up.role
  from public.user_profiles up
  where up.user_id = auth.uid() and up.active
  limit 1
$$;

drop policy if exists user_profiles_self_read on public.user_profiles;
create policy user_profiles_self_read on public.user_profiles
for select to authenticated using (user_id = auth.uid());

drop policy if exists user_profiles_admin_all on public.user_profiles;
create policy user_profiles_admin_all on public.user_profiles
for all to authenticated
using (app_private.has_app_role(array['admin'::public.app_role]))
with check (app_private.has_app_role(array['admin'::public.app_role]));

revoke all on public.user_profiles from public, anon;
grant select, insert, update, delete on public.user_profiles to authenticated;

commit;
