# Initial menu for unhandled direct arrivals. Messages remain editable native rules.
require 'json'

module CbnGenericMenu
  CONFIG = '/app/storage/cbn-generic-menu-config.json'.freeze
  KEY = 'cbn_generic_credit_menu_v1'.freeze
  RULE_MARKER = '[CBN_GENERIC_MENU_V1]'.freeze
  STAGE = 'cbn_menu_credito_etapa'.freeze
  PRODUCT_LABELS = %w[clt inss fgts servidor-publico colatina siape garantia-veiculo outros-assuntos].freeze

  def self.config
    JSON.parse(File.read(CONFIG)) if File.file?(CONFIG)
  rescue JSON::ParserError, SystemCallError => error
    Rails.logger.error("cbn_generic_menu_config_failure class=#{error.class.name}")
    nil
  end

  def self.eligible?(message, settings)
    return false unless settings && settings['active'] && message && message.account_id == 1 && message.inbox_id == 5
    return false unless message.incoming? && !message.private? && message.sender_type == 'Contact'
    return false unless message.created_at >= Time.iso8601(settings.fetch('enabled_at'))
    conversation = message.conversation
    chat_id = conversation.contact.custom_attributes['waha_whatsapp_chat_id'].to_s
    return false if chat_id == 'whatsapp.integration' || chat_id.end_with?('@g.us', '@broadcast', '@newsletter')
    return false if conversation.contact.blocked? || !conversation.account.active?
    # WAHA adds a calendar wrapper to recovered historical messages.
    !message.content.to_s.match?(/📅|Imported from WhatsApp|Importad[ao] do WhatsApp/i)
  end

  def self.existing_flow?(conversation, message)
    conversation.additional_attributes[CbnLeadCapture::KEY].present? ||
      (conversation.label_list & PRODUCT_LABELS).any? ||
      message.content.to_s.match?(/AN[ÚU]NCIO DO FACEBOOK|Vim pelo an[úu]ncio|Receber oferta!/i)
  end

  def self.can_start?(conversation, message, settings)
    eligible?(message, settings) && conversation.status == 'open' && conversation.assignee_id.nil? &&
      conversation.additional_attributes[KEY].blank? && !existing_flow?(conversation, message) &&
      !conversation.messages.outgoing.where(private: false).exists?
  end

  def self.state!(conversation, state, stage)
    conversation.update!(additional_attributes: conversation.additional_attributes.merge(KEY => state),
                         custom_attributes: conversation.custom_attributes.merge(STAGE => stage))
  end

  def self.human_replied?(conversation, prompt_id)
    conversation.messages.outgoing.where(private: false, sender_type: %w[User AgentBot]).where('id > ?', prompt_id).exists?
  end

  def self.option(text, settings)
    value = text.to_s.strip.downcase.unicode_normalize(:nfd).gsub(/\p{Mn}|[\uFE0F\u20E3]/, '').gsub(/\s+/, ' ')
    number = value.match(/\A(?:opcao\s*)?([1-6])[.!)]?\z/)&.captures&.first
    settings.fetch('choices').find do |choice|
      choice['number'].to_s == number || choice.fetch('aliases', []).include?(value)
    end
  end

  def self.send_rule!(conversation, role, message, settings)
    previous = Thread.current[:cbn_generic_menu_command]
    rule = conversation.account.automation_rules.find_by(id: settings.fetch('rules').fetch(role), active: true)
    return nil unless rule
    scope = { conversation_id: conversation.id, role: role, message_id: message.id, sent: [] }
    Thread.current[:cbn_generic_menu_command] = scope
    AutomationRules::ActionService.new(rule, conversation.account, conversation).perform
    raise 'Menu native response missing' unless scope[:sent].length == 1
    scope[:sent].first
  ensure
    Thread.current[:cbn_generic_menu_command] = previous
  end

  def self.capture_choice(message)
    settings = config
    return unless eligible?(message, settings)
    conversation = message.conversation
    conversation.with_lock do
      state = conversation.additional_attributes[KEY]
      next unless state && conversation.custom_attributes[STAGE] == 'aguardando_opcao'
      next unless message.id > state.fetch('prompt_id') && message.id > state.fetch('last_processed_id', 0)
      if human_replied?(conversation, state['prompt_id']) || conversation.additional_attributes[CbnLeadCapture::KEY].present?
        state!(conversation, state.merge('last_processed_id' => message.id), 'atendimento_em_andamento')
        next
      end
      if message.created_at > Time.iso8601(state.fetch('started_at')) + 7.days
        state!(conversation, state.merge('last_processed_id' => message.id), 'expirado')
        next
      end
      choice = option(message.content, settings)
      if choice
        # A paused confirmation rule pauses this transition too.
        next unless conversation.account.automation_rules.exists?(id: settings.fetch('rules').fetch('confirmation'), active: true)
        contact = conversation.contact
        contact.with_lock do
          label = conversation.account.labels.find_by!(title: choice.fetch('label'))
          conversation.label_list.add(label.title)
          conversation.save!
          contact.label_list.add(label.title)
          contact.save!
        end
        if conversation.assignee_id.nil?
          agent = conversation.account.users.find(settings.fetch('fallback_agent_id'))
          conversation.update!(assignee: agent)
        end
        response = send_rule!(conversation, 'confirmation', message, settings)
        raise 'Menu confirmation unavailable' unless response
        state!(conversation, state.merge('last_processed_id' => message.id, 'choice' => choice['key'],
          'choice_number' => choice['number'], 'confirmation_id' => response.id, 'selected_at' => Time.current.iso8601), 'concluido')
      elsif state['reminder_id'].blank? && message.content.present? && !message.attachments.exists?
        response = send_rule!(conversation, 'reminder', message, settings)
        if response
          state!(conversation, state.merge('last_processed_id' => message.id, 'reminder_id' => response.id), 'aguardando_opcao')
        end
      end
    end
  rescue StandardError => error
    Rails.logger.error("cbn_generic_menu_failure class=#{error.class.name}")
    raise
  end

  module Listener
    def message_created(event)
      previous = Thread.current[:cbn_generic_menu_message]
      Thread.current[:cbn_generic_menu_message] = event.data[:message]
      super
      CbnGenericMenu.capture_choice(event.data[:message])
    ensure
      Thread.current[:cbn_generic_menu_message] = previous
    end
  end

  module Actions
    def perform
      settings = CbnGenericMenu.config
      role = settings && settings.fetch('rules', {}).find { |_name, id| id.to_i == @rule.id }&.first
      owned_rule = role || @rule.description.to_s.include?(CbnGenericMenu::RULE_MARKER)
      return super unless owned_rule
      return unless role && settings['active'] && @rule.active? && @conversation.account_id == 1 && @conversation.inbox_id == 5
      @conversation.with_lock do
        if role == 'menu'
          message = Thread.current[:cbn_generic_menu_message]
          next unless CbnGenericMenu.can_start?(@conversation, message, settings)
          @cbn_menu_sent = []
          super
          raise 'Menu native messages missing' unless @cbn_menu_sent.length == 2
          state = { 'started_at' => Time.current.iso8601, 'trigger_id' => message.id,
                    'greeting_id' => @cbn_menu_sent.first.id, 'prompt_id' => @cbn_menu_sent.last.id }
          CbnGenericMenu.state!(@conversation, state, 'aguardando_opcao')
        else
          scope = Thread.current[:cbn_generic_menu_command]
          next unless scope && scope[:conversation_id] == @conversation.id && scope[:role] == role
          @cbn_menu_sent = scope[:sent]
          super
        end
      ensure
        @cbn_menu_sent = nil
      end
    end

    private

    def send_message(message)
      prompt = super
      if @cbn_menu_sent
        unless prompt.is_a?(Message) && prompt.persisted? && prompt.conversation_id == @conversation.id &&
               prompt.outgoing? && !prompt.private? && prompt.sender_type.nil? && prompt.content_attributes['automation_rule_id'].to_i == @rule.id
          raise 'Invalid menu native message'
        end
        @cbn_menu_sent << prompt
      end
      prompt
    end
  end
end

Rails.application.config.after_initialize do
  AutomationRuleListener.prepend(CbnGenericMenu::Listener) unless AutomationRuleListener < CbnGenericMenu::Listener
  AutomationRules::ActionService.prepend(CbnGenericMenu::Actions) unless AutomationRules::ActionService < CbnGenericMenu::Actions
end
