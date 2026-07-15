-- Rollback manual da BKL-016, somente para ambiente de desenvolvimento limpo.
-- Revise antes de executar: este arquivo remove toda a estrutura e seus dados.
-- pgcrypto nao e removido porque pode ser compartilhado por outros componentes.

begin;

drop view if exists public.audit_event_summaries;

drop table if exists public.pending_items;
drop table if exists public.interactions;
drop table if exists public.proposals;
drop table if exists public.offers;
drop table if exists public.consultations;

alter table if exists public.technical_operations
  drop constraint if exists technical_operations_protected_log_ref_fk;

drop schema if exists app_private cascade;
drop schema if exists audit cascade;

drop table if exists public.technical_operations;
drop table if exists public.clients;
drop table if exists public.user_profiles;

drop function if exists public.enforce_offer_consultation_consistency();
drop function if exists public.protect_offer_snapshot();
drop function if exists public.enforce_support_pending_update();
drop function if exists public.set_updated_at();

drop type if exists public.app_role;
drop type if exists public.credit_product;

-- Remove somente buckets vazios criados pela BKL-016. Objetos precisam passar
-- pela rotina de descarte aprovada; o rollback nunca os apaga silenciosamente.
do $$
begin
  if to_regclass('storage.buckets') is not null
     and to_regclass('storage.objects') is not null then
    delete from storage.buckets b
    where b.id in (
      'cbn-documents-private', 'cbn-raw-payloads-private',
      'cbn-evidence-private', 'cbn-temporary-private'
    )
    and not exists (
      select 1 from storage.objects o where o.bucket_id = b.id
    );
  end if;
end $$;

commit;
