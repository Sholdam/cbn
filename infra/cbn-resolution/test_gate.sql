CREATE TEMP TABLE contacts(id integer PRIMARY KEY,account_id integer,custom_attributes jsonb);
CREATE TEMP TABLE custom_attribute_definitions(account_id integer,attribute_model integer,attribute_key text,attribute_values jsonb);
CREATE TEMP TABLE conversations(id integer PRIMARY KEY,account_id integer,status integer,contact_id integer,custom_attributes jsonb DEFAULT '{}',additional_attributes jsonb DEFAULT '{}');
INSERT INTO custom_attribute_definitions VALUES(1,1,'cbn_situacao_atendimento','["Novo contato","Em negociação","Aguardando cliente","Follow-up","Venda fechada","Sem interesse","Sem oferta"]');
INSERT INTO contacts VALUES(1,1,'{}'),(2,1,'{"cbn_situacao_atendimento":"Follow-up"}'),(3,2,'{"cbn_situacao_atendimento":"Follow-up"}');

-- The generator inserts the candidate trigger here, on pg_temp only.
-- __CANDIDATE_TRIGGER__

DO $test$
DECLARE
  v jsonb;
  choice text;
  expected text;
  tests integer := 0;
BEGIN
  INSERT INTO conversations(id,account_id,status,contact_id) VALUES(1,1,0,1),(2,1,0,2);
  FOREACH v IN ARRAY ARRAY['null'::jsonb,'""'::jsonb,'"   "'::jsonb,'"Abóbora"'::jsonb,'false'::jsonb,'["Follow-up"]'::jsonb,'"Não informado"'::jsonb] LOOP
    UPDATE contacts SET custom_attributes=jsonb_build_object('cbn_situacao_atendimento',v) WHERE id=1;
    BEGIN
      UPDATE conversations SET status=1 WHERE id=1;
      RAISE EXCEPTION 'Unclassified resolution was allowed';
    EXCEPTION WHEN check_violation THEN tests := tests+1;
    END;
    IF (SELECT status FROM conversations WHERE id=1)<>0 THEN RAISE EXCEPTION 'Resolution persisted after rejection'; END IF;
  END LOOP;
  BEGIN
    UPDATE conversations SET status=1;
    RAISE EXCEPTION 'Mixed bulk resolution was allowed';
  EXCEPTION WHEN check_violation THEN tests := tests+1;
  END;
  IF (SELECT count(*) FROM conversations WHERE status=1)<>0 THEN RAISE EXCEPTION 'Bulk resolution partially persisted'; END IF;
  FOREACH choice IN ARRAY ARRAY['Novo contato','Em negociação','Aguardando cliente','Follow-up','Venda fechada','Sem interesse','Sem oferta'] LOOP
    UPDATE contacts SET custom_attributes=jsonb_build_object('cbn_situacao_atendimento',choice) WHERE id=1;
    UPDATE conversations SET status=1 WHERE id=1;
    expected := CASE choice WHEN 'Novo contato' THEN 'Novo contato' WHEN 'Venda fechada' THEN 'Contratado' WHEN 'Sem interesse' THEN 'Perdido' WHEN 'Sem oferta' THEN 'Perdido' ELSE 'Em atendimento' END;
    IF (SELECT custom_attributes->>'cbn_ads_etapa' FROM conversations WHERE id=1)<>expected THEN RAISE EXCEPTION 'Wrong ad stage'; END IF;
    IF (SELECT additional_attributes->'cbn_resolution'->>'classification' FROM conversations WHERE id=1)<>choice THEN RAISE EXCEPTION 'Wrong resolution snapshot'; END IF;
    UPDATE conversations SET status=0 WHERE id=1;
    tests := tests+1;
  END LOOP;
  UPDATE contacts SET custom_attributes='{"cbn_situacao_atendimento":"Em negociação"}' WHERE id=1;
  UPDATE conversations SET custom_attributes='{"cbn_ads_etapa":"Proposta enviada"}',status=1 WHERE id=1;
  IF (SELECT custom_attributes->>'cbn_ads_etapa' FROM conversations WHERE id=1)<>'Proposta enviada' THEN RAISE EXCEPTION 'Proposal stage downgraded'; END IF;
  tests := tests+1;
  UPDATE contacts SET custom_attributes='{}' WHERE id=1;
  UPDATE conversations SET additional_attributes='{"unrelated":true}' WHERE id=1;
  UPDATE conversations SET status=0 WHERE id=1;
  tests := tests+1;
  BEGIN
    UPDATE conversations SET contact_id=3,status=1 WHERE id=1;
    RAISE EXCEPTION 'Cross-account classification accepted';
  EXCEPTION WHEN check_violation THEN tests := tests+1;
  END;
  BEGIN
    INSERT INTO conversations(id,account_id,status,contact_id) VALUES(3,1,1,1);
    RAISE EXCEPTION 'Resolved insert without classification accepted';
  EXCEPTION WHEN check_violation THEN tests := tests+1;
  END;
  INSERT INTO conversations(id,account_id,status,contact_id) VALUES(4,2,1,3);
  tests := tests+1;
  RAISE NOTICE 'CBN classification gate: % checks passed, synthetic temporary tables only.',tests;
END;
$test$;
