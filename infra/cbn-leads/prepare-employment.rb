# Run only on the authorized CBN account. No contact/customer records accessed.
require 'json'
account = Account.find(1)
raise 'Wrong inbox' unless account.inboxes.find(5).name == 'CBN WhatsApp (WAHA)'
definition = account.custom_attribute_definitions.find_or_initialize_by(attribute_key: 'cbn_vinculo_servidor', attribute_model: 'contact_attribute')
unless definition.persisted?
  definition.update!(attribute_display_name: 'Vínculo com a Prefeitura', attribute_display_type: 'text', attribute_description: 'Vínculo autodeclarado: comissionado, efetivo ou temporário. Não determina elegibilidade de crédito.')
end
raise 'Missing employment parser' unless CbnLeadCapture.respond_to?(:extract_employment)
raise 'Wrong parser' unless CbnLeadCapture.extract_employment('2') == 'efetivo'
raise 'Missing native rule' unless account.automation_rules.find(11).name == 'CBN — Colatina: perguntar vínculo após matrícula'
puts({ field_ready: definition.persisted?, parser_ready: true, no_customer_messages: true }.to_json)
