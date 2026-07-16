-- BKL-016 - hardening corretivo para default privileges do Supabase remoto.
-- Nao contem dados, credenciais ou alteracao de RLS.

begin;

-- O projeto remoto concedeu privilegios operacionais a anon por defaults do
-- ambiente. Revogar de PUBLIC e anon cobre grants diretos e herdados, enquanto
-- authenticated recebe novamente somente o conjunto previsto pela BKL-016.
revoke all on
  public.user_profiles, public.clients, public.technical_operations,
  public.consultations, public.offers, public.proposals,
  public.interactions, public.pending_items
from public, anon;

revoke all on public.audit_event_summaries from public, anon;

grant select, insert, update, delete on public.user_profiles to authenticated;
grant select, insert, update, delete on
  public.clients, public.technical_operations, public.consultations,
  public.offers, public.proposals, public.interactions, public.pending_items
to authenticated;

grant select on public.audit_event_summaries to authenticated;

commit;
