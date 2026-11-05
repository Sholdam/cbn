BEGIN;
CREATE OR REPLACE FUNCTION public.cbn_require_resolution_classification()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  classification text;
  options jsonb;
  stage text;
BEGIN
  IF NEW.account_id <> 1 OR NEW.status <> 1 THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' THEN
    IF OLD.status = 1 AND OLD.contact_id = NEW.contact_id AND OLD.account_id = NEW.account_id THEN RETURN NEW; END IF;
  END IF;
  SELECT c.custom_attributes->>'cbn_situacao_atendimento' INTO classification
    FROM contacts c WHERE c.id = NEW.contact_id AND c.account_id = NEW.account_id
      AND jsonb_typeof(c.custom_attributes->'cbn_situacao_atendimento') = 'string';
  SELECT d.attribute_values INTO options FROM custom_attribute_definitions d
    WHERE d.account_id = NEW.account_id AND d.attribute_model = 1 AND d.attribute_key = 'cbn_situacao_atendimento';
  stage := CASE classification
    WHEN 'Novo contato' THEN 'Novo contato'
    WHEN 'Em negociação' THEN 'Em atendimento'
    WHEN 'Aguardando cliente' THEN 'Em atendimento'
    WHEN 'Follow-up' THEN 'Em atendimento'
    WHEN 'Venda fechada' THEN 'Contratado'
    WHEN 'Sem interesse' THEN 'Perdido'
    WHEN 'Sem oferta' THEN 'Perdido'
    ELSE NULL END;
  IF classification IS NULL OR NOT coalesce(options @> jsonb_build_array(classification), false) OR stage IS NULL THEN
    RAISE EXCEPTION 'Escolha uma Situação do atendimento válida antes de resolver a conversa.'
      USING ERRCODE = '23514', CONSTRAINT = 'cbn_resolution_requires_classification';
  END IF;
  IF stage = 'Em atendimento' AND NEW.custom_attributes->>'cbn_ads_etapa' = 'Proposta enviada' THEN
    stage := 'Proposta enviada';
  END IF;
  NEW.custom_attributes := coalesce(NEW.custom_attributes, '{}'::jsonb) || jsonb_build_object('cbn_ads_etapa', stage);
  NEW.additional_attributes := coalesce(NEW.additional_attributes, '{}'::jsonb) || jsonb_build_object('cbn_resolution',
    coalesce(NEW.additional_attributes->'cbn_resolution', '{}'::jsonb) || jsonb_build_object('classification', classification, 'at', CURRENT_TIMESTAMP));
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS cbn_require_resolution_classification ON public.conversations;
CREATE TRIGGER cbn_require_resolution_classification
  BEFORE INSERT OR UPDATE OF status, contact_id, account_id ON public.conversations
  FOR EACH ROW EXECUTE FUNCTION public.cbn_require_resolution_classification();
COMMIT;
