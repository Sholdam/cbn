\set ON_ERROR_STOP on

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'user_profiles' and column_name = 'status'
  ) then raise exception 'rollback BKL-018 manteve coluna status'; end if;

  if to_regprocedure('public.admin_create_human_profile(uuid,public.app_role,text,text,text)') is not null
     or to_regprocedure('public.admin_change_human_role(uuid,public.app_role,text,text)') is not null
     or to_regprocedure('public.admin_disable_human_profile(uuid,text,text)') is not null
     or to_regprocedure('public.admin_reactivate_human_profile(uuid,text,text)') is not null
     or to_regprocedure('public.get_my_profile()') is not null
     or to_regprocedure('audit.record_human_profile_event(text,uuid,boolean,text,text,text,public.app_role,text)') is not null then
    raise exception 'rollback BKL-018 manteve funcao nova';
  end if;

  if not exists (select 1 from pg_policies
      where schemaname = 'public' and tablename = 'user_profiles'
        and policyname = 'user_profiles_self_read')
     or not exists (select 1 from pg_policies
      where schemaname = 'public' and tablename = 'user_profiles'
        and policyname = 'user_profiles_admin_all') then
    raise exception 'rollback BKL-018 nao restaurou policies anteriores';
  end if;

  if not has_table_privilege('authenticated', 'public.user_profiles', 'SELECT,INSERT,UPDATE,DELETE') then
    raise exception 'rollback BKL-018 nao restaurou grant anterior';
  end if;
end
$$;

select 'BKL-018 clean rollback passed' as result;
