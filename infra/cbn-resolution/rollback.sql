BEGIN;
DROP TRIGGER IF EXISTS cbn_require_resolution_classification ON public.conversations;
DROP FUNCTION IF EXISTS public.cbn_require_resolution_classification();
COMMIT;
