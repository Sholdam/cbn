require 'json'
require 'fileutils'
Rails.logger.level = Logger::FATAL
account = Account.find(1)
raise 'Wrong production inbox' unless account.inboxes.find(5).name == 'CBN WhatsApp (WAHA)'
stamp = Time.current.utc.strftime('%Y%m%dT%H%M%SZ')
backup = "/app/storage/cbn-lead-capture-backups/#{stamp}.json"
FileUtils.mkdir_p(File.dirname(backup), mode: 0700)
File.write(backup, { rules: account.automation_rules.map(&:attributes), definition_ids: account.custom_attribute_definitions.pluck(:id), label_ids: account.labels.pluck(:id) }.to_json)
File.chmod(0600, backup)

definitions = [
 ['cbn_matricula_beneficio', 'Matrícula / benefício', 'contact_attribute', 'Matrícula funcional ou número do benefício, preservando os zeros iniciais.'],
 ['cbn_coleta_etapa', 'Etapa do cadastro automático', 'conversation_attribute', 'Estado técnico da coleta CPF e matrícula. Revisões não sobrescrevem dados existentes.']
]
ActiveRecord::Base.transaction do
 definitions.each do |key, label, model, description|
  d = account.custom_attribute_definitions.find_or_initialize_by(attribute_key: key, attribute_model: model)
  d.update!(attribute_display_name: label, attribute_display_type: 'text', attribute_description: description) unless d.persisted?
 end
 [['servidor-publico', '#087F8C'], ['colatina', '#7C3AED']].each do |title, color|
  label = account.labels.find_or_initialize_by(title: title)
  label.update!(color: color, description: title == 'colatina' ? 'Prefeitura de Colatina' : 'Servidor público', show_on_sidebar: true) unless label.persisted?
 end
 # Native rules are created through the CBN CRM plugin, not the Rails console.
end

puts({ fields_and_labels_ready: true, native_rules: 'created via CBN CRM plugin', historical_replay: false }.to_json)
