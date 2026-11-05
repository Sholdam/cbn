# Mandatory resolution classification for the CBN account. The database trigger
# is the final guard, including writers that deliberately skip Rails validation.
module CbnResolutionClassification
  KEY = 'cbn_situacao_atendimento'.freeze
  STAGES = {
    'Novo contato' => 'Novo contato', 'Em negociação' => 'Em atendimento',
    'Aguardando cliente' => 'Em atendimento', 'Follow-up' => 'Em atendimento',
    'Venda fechada' => 'Contratado', 'Sem interesse' => 'Perdido', 'Sem oferta' => 'Perdido'
  }.freeze
  ERROR = 'Escolha uma Situação do atendimento válida antes de resolver a conversa.'.freeze

  def self.options(account_id)
    definition = CustomAttributeDefinition.find_by(account_id: account_id, attribute_model: :contact_attribute, attribute_key: KEY)
    Array(definition&.attribute_values).select { |value| value.is_a?(String) && STAGES.key?(value) }
  end

  def cbn_resolution_requires_classification?
    account_id == 1 && resolved? && (new_record? || will_save_change_to_status? || will_save_change_to_contact_id? || will_save_change_to_account_id?)
  end

  def cbn_validate_resolution_classification
    return unless cbn_resolution_requires_classification?

    attributes = Contact.where(id: contact_id, account_id: account_id).pick(:custom_attributes) || {}
    value = attributes[KEY]
    unless value.is_a?(String) && CbnResolutionClassification.options(account_id).include?(value)
      errors.add(:base, ERROR)
      return
    end
    stage = STAGES.fetch(value)
    # A known proposal stage is more precise than the generic "in service".
    stage = 'Proposta enviada' if stage == 'Em atendimento' && custom_attributes&.dig('cbn_ads_etapa') == 'Proposta enviada'
    self.custom_attributes = (custom_attributes || {}).merge('cbn_ads_etapa' => stage)
    self.additional_attributes = (additional_attributes || {}).merge('cbn_resolution' => {
      'classification' => value, 'at' => Time.current.iso8601,
      'actor_type' => Current.user&.class&.name, 'actor_id' => Current.user&.id
    })
  end
end

Rails.application.config.after_initialize do
  Conversation.include(CbnResolutionClassification) unless Conversation < CbnResolutionClassification
  unless Conversation._validate_callbacks.any? { |callback| callback.filter == :cbn_validate_resolution_classification }
    Conversation.validate :cbn_validate_resolution_classification
  end

  require '/app/app/controllers/api/v1/accounts/conversations/resolution_classifications_controller'
  Rails.application.routes.append do
    get '/api/v1/accounts/:account_id/conversations/:conversation_id/resolution_classification',
        to: 'api/v1/accounts/conversations/resolution_classifications#show'
    post '/api/v1/accounts/:account_id/conversations/:conversation_id/resolution_classification',
         to: 'api/v1/accounts/conversations/resolution_classifications#create'
  end
end
