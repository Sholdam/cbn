# Add conversation fields only. No message, status, or automation changes.
fields = [
  ['cbn_ads_primeiro_anuncio_id', 'Ads · Primeiro anúncio', 'text'],
  ['cbn_ads_ultimo_anuncio_id', 'Ads · Último anúncio', 'text'],
  ['cbn_ads_campanha', 'Ads · Campanha', 'text'],
  ['cbn_ads_conjunto', 'Ads · Conjunto', 'text'],
  ['cbn_ads_anuncio', 'Ads · Anúncio', 'text'],
  ['cbn_ads_modalidade', 'Ads · Modalidade', 'text'],
  ['cbn_ads_etapa', 'Ads · Etapa comercial', 'list'],
  ['cbn_ads_valor_contratado', 'Ads · Crédito contratado (R$)', 'currency'],
  ['cbn_ads_comissao', 'Ads · Comissão CBN (R$)', 'currency']
]
stages = ['Novo contato', 'Em atendimento', 'Proposta enviada', 'Contratado', 'Perdido']
created = []
CustomAttributeDefinition.transaction do
  fields.each do |key, label, type|
    row = CustomAttributeDefinition.find_or_initialize_by(account_id: 1, attribute_model: 'conversation_attribute', attribute_key: key)
    next if row.persisted?
    row.attribute_display_name = label
    row.attribute_display_type = type
    row.attribute_description = key == 'cbn_ads_etapa' ? 'Etapa informada pela equipe. Não altera o estado ou as automações da conversa.' : 'Rastreamento de anúncios CBN. Não informar CPF, benefício ou dados bancários.'
    row.attribute_values = stages if type == 'list'
    row.save!
    created << key
  end
end
puts({created: created, count: fields.size, customer_messages_sent: 0}.to_json)
