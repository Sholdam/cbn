# Complement to native Chatwoot automation: capture replies, never replay history.
# Configuration contains rule IDs and activation time only; no credentials or PII.
require 'json'

module CbnLeadCapture
  KEY = 'cbn_lead_capture_v1'.freeze
  STAGE = 'cbn_coleta_etapa'.freeze
  CONFIG = '/app/storage/cbn-lead-capture-config.json'.freeze

  def self.config
    JSON.parse(File.read(CONFIG)) if File.file?(CONFIG)
  end

  def self.eligible?(message, settings)
    settings && settings['active'] && message && message.account_id == 1 &&
      message.inbox_id == 5 && message.incoming? && !message.private? &&
      message.sender_type == 'Contact' && message.created_at >= Time.iso8601(settings.fetch('enabled_at')) &&
      !message.conversation.contact.blocked?
  end

  def self.stage!(conversation, state, stage)
    conversation.update!(additional_attributes: conversation.additional_attributes.merge(KEY => state),
                         custom_attributes: conversation.custom_attributes.merge(STAGE => stage))
  end

  def self.valid_cpf?(number)
    return false unless number&.match?(/\A[0-9]{11}\z/) && number.chars.uniq.length > 1
    digits = number.chars.map(&:to_i)
    [9, 10].all? do |length|
      sum = digits.first(length).each_with_index.sum { |digit, index| digit * (length + 1 - index) }
      check = (sum * 10) % 11
      check = 0 if check == 10
      check == digits[length]
    end
  end

  def self.extract_cpf(text)
    match = text.to_s.strip.match(/\A(?:(?:meu\s+)?cpf\s*(?:é|e)?\s*[:\-]?\s*)?([0-9]{3}[.\s]?[0-9]{3}[.\s]?[0-9]{3}[\-\s]?[0-9]{2})[.!]?\z/i)
    match && match[1].gsub(/\D/, '')
  end

  def self.extract_registration(text, cpf)
    match = text.to_s.strip.match(/\A(?:(?:minha?\s+)?(?:matr[ií]cula|benef[ií]cio|nb)\s*(?:é|e)?\s*[:\-]?\s*)?([0-9][0-9.\-\/ ]{0,23}[0-9])\z/i)
    return unless match
    value = match[1].gsub(/\D/, '')
    return if !value.length.between?(2, 20) || value == cpf || valid_cpf?(value)
    value
  end

  def self.human_replied?(conversation, after_id)
    conversation.messages.outgoing.where(sender_type: 'User', private: false).where('id > ?', after_id).exists?
  end

  def self.mirror_labels!(conversation)
    titles = conversation.label_list & %w[clt servidor-publico colatina]
    return if titles.empty?
    contact = conversation.contact
    contact.with_lock do
      contact.label_list.add(titles)
      contact.save!
    end
  end

  def self.origin!(conversation, message)
    text = message.content.to_s
    return unless text.match?(/AN[ÚU]NCIO DO FACEBOOK|Vim pelo an[úu]ncio/i)
    contact = conversation.contact
    contact.with_lock do
      if contact.custom_attributes['cbn_origem_contato'].blank?
        earlier = Message.incoming.joins(:conversation).where(conversations: { account_id: 1, contact_id: contact.id }).where('messages.id < ?', message.id).exists?
        contact.update!(custom_attributes: contact.custom_attributes.merge('cbn_origem_contato' => 'Anúncio do Facebook')) unless earlier
      end
    end
    ad_id = text.match(/ID do An[úu]ncio:\*{0,2}\s*([0-9]+)/i)&.captures&.first
    if ad_id && conversation.additional_attributes['cbn_anuncio_id'].blank?
      conversation.update!(additional_attributes: conversation.additional_attributes.merge('cbn_anuncio_id' => ad_id))
    end
  end

  def self.capture_reply(message, settings)
    return unless eligible?(message, settings)
    conversation = message.conversation
    conversation.with_lock do
      state = conversation.additional_attributes[KEY]
      # A new CPF reply can answer a still-valid native CLT prompt sent before
      # installation. Only this new reply is processed; never replay old input.
      if state.nil? && valid_cpf?(extract_cpf(message.content))
        prompt = conversation.messages.outgoing.where(private: false).where("content_attributes->>'automation_rule_id' IN (?)", %w[5 6]).where('id < ? AND created_at >= ?', message.id, 7.days.ago).order(:id).last
        if prompt && (prompt.content_attributes['automation_rule_id'].to_i == 6 || conversation.label_list.include?('clt')) && prompt.status != 'failed'
          state = { 'kind' => 'clt', 'started_at' => prompt.created_at.iso8601, 'prompt_id' => prompt.id, 'trigger_id' => message.id }
          stage!(conversation, state, 'aguardando_cpf')
        end
      end
      next unless state && %w[aguardando_cpf aguardando_matricula].include?(conversation.custom_attributes[STAGE])
      next unless message.id > state.fetch('prompt_id', message.id) && message.id > state.fetch('last_processed_id', 0)
      if message.created_at > Time.iso8601(state.fetch('started_at')) + 7.days
        stage!(conversation, state, 'expirado')
        next
      end
      contact = conversation.contact
      stage = conversation.custom_attributes[STAGE]
      if stage == 'aguardando_cpf'
        cpf = extract_cpf(message.content)
        next unless valid_cpf?(cpf)
        contact.with_lock do
          saved = contact.custom_attributes['cbn_cpf'].to_s.gsub(/\D/, '')
          conflict = Contact.where(account_id: 1).where.not(id: contact.id).where("regexp_replace(coalesce(custom_attributes->>'cbn_cpf',''), '[^0-9]', '', 'g') = ?", cpf).exists?
          if conflict || (saved.present? && saved != cpf)
            stage!(conversation, state.merge('last_processed_id' => message.id), 'revisao_cpf')
            next
          end
          contact.update!(custom_attributes: contact.custom_attributes.merge('cbn_cpf' => cpf)) if saved.blank?
          next_stage = state['kind'] == 'colatina' && !human_replied?(conversation, state['prompt_id']) ? 'cpf_recebido' : 'concluido'
          stage!(conversation, state.merge('last_processed_id' => message.id), next_stage)
        end
      else
        registration = extract_registration(message.content, contact.custom_attributes['cbn_cpf'].to_s.gsub(/\D/, ''))
        next unless registration
        contact.with_lock do
          existing = contact.custom_attributes['cbn_matricula_beneficio'].to_s.strip
          next_stage = existing.present? && existing.gsub(/\D/, '') != registration ? 'revisao_matricula' : 'dados_recebidos'
          contact.update!(custom_attributes: contact.custom_attributes.merge('cbn_matricula_beneficio' => registration)) if existing.blank?
          stage!(conversation, state.merge('last_processed_id' => message.id), next_stage)
        end
      end
    end
  rescue StandardError => error
    Rails.logger.error("cbn_lead_capture_failed class=#{error.class.name}")
    raise
  end

  module Listener
    def message_created(event)
      message = event.data[:message]
      settings = CbnLeadCapture.config
      previous = Thread.current[:cbn_lead_message]
      Thread.current[:cbn_lead_message] = message
      if CbnLeadCapture.eligible?(message, settings)
        message.conversation.with_lock { CbnLeadCapture.origin!(message.conversation, message) }
      end
      CbnLeadCapture.capture_reply(message, settings)
      super
    ensure
      Thread.current[:cbn_lead_message] = previous
    end
  end

  module Actions
    private

    def send_message(message)
      settings = CbnLeadCapture.config
      role = settings && settings.fetch('rules', {})[@rule.id.to_s]
      return super unless settings && settings['active'] && role && @conversation.account_id == 1 && @conversation.inbox_id == 5
      incoming = Thread.current[:cbn_lead_message]
      @conversation.with_lock do
        if role == 'conclusao'
          state = @conversation.additional_attributes[CbnLeadCapture::KEY]
          next unless state && state['kind'] == 'colatina' && @conversation.custom_attributes[CbnLeadCapture::STAGE] == 'dados_recebidos'
          if @conversation.assignee_id.nil?
            agent = @conversation.account.users.find_by(id: 1)
            raise 'Fallback attendant unavailable' unless agent
            @conversation.update!(assignee: agent)
          end
          super unless CbnLeadCapture.human_replied?(@conversation, state['prompt_id'])
          CbnLeadCapture.stage!(@conversation, state, 'concluido')
        elsif role == 'matricula'
          state = @conversation.additional_attributes[CbnLeadCapture::KEY]
          next unless state && @conversation.custom_attributes[CbnLeadCapture::STAGE] == 'cpf_recebido'
          if CbnLeadCapture.human_replied?(@conversation, state['prompt_id'])
            CbnLeadCapture.stage!(@conversation, state, 'concluido')
            next
          end
          super
          prompt = @conversation.messages.outgoing.where("content_attributes->>'automation_rule_id' = ?", @rule.id.to_s).order(:id).last
          raise 'Missing native automation message' unless prompt
          CbnLeadCapture.stage!(@conversation, state.merge('prompt_id' => prompt.id), 'aguardando_matricula')
        else
          # Rule 5 also handles INSS: leave that existing flow unchanged.
          if role == 'clt' && !incoming&.content.to_s.match?(/CLT/i) && !@conversation.label_list.include?('clt')
            super
            next
          end
          next unless CbnLeadCapture.eligible?(incoming, settings)
          CbnLeadCapture.mirror_labels!(@conversation)
          CbnLeadCapture.origin!(@conversation, incoming)
          next if @conversation.additional_attributes[CbnLeadCapture::KEY].present?
          next if CbnLeadCapture.human_replied?(@conversation, incoming.id)
          super
          prompt = @conversation.messages.outgoing.where("content_attributes->>'automation_rule_id' = ?", @rule.id.to_s).order(:id).last
          raise 'Missing native automation message' unless prompt
          state = { 'kind' => role, 'started_at' => Time.current.iso8601, 'prompt_id' => prompt.id, 'trigger_id' => incoming.id }
          CbnLeadCapture.stage!(@conversation, state, 'aguardando_cpf')
        end
      end
    end
  end
end

Rails.application.config.after_initialize do
  AutomationRuleListener.prepend(CbnLeadCapture::Listener) unless AutomationRuleListener < CbnLeadCapture::Listener
  AutomationRules::ActionService.prepend(CbnLeadCapture::Actions) unless AutomationRules::ActionService < CbnLeadCapture::Actions
end
