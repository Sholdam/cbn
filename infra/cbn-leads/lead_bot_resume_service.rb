class Cbn::LeadBotResumeService
  class Unavailable < StandardError; end
  AUDIT_KEY = 'cbn_bot_resume'.freeze

  def initialize(conversation:, actor:, request_id:)
    @conversation, @actor, @request_id = conversation, actor, request_id
    @settings = CbnLeadCapture.config
  end

  def perform
    previous_message = Thread.current[:cbn_lead_message]
    previous_manual = Thread.current[:cbn_manual_resume_conversation_id]
    previous_actor = Current.executed_by
    validate_scope!
    @conversation.with_lock do
      previous = @conversation.additional_attributes[AUDIT_KEY] || {}
      if previous['request_id'] == @request_id ||
         (previous['at'] && previous['stage'] == stage && Time.iso8601(previous['at']) > 30.seconds.ago)
        return { message: 'O bot já foi retomado há pouco. Aguarde a resposta do cliente.', stage: stage }
      end
      raise Unavailable, 'Abra a conversa antes de retomar o bot.' unless @conversation.open? || @conversation.pending?
      raise Unavailable, 'Este contato está bloqueado.' if @conversation.contact.blocked?

      Thread.current[:cbn_manual_resume_conversation_id] = @conversation.id
      Current.executed_by = @actor
      result = resume!
      @conversation.update!(additional_attributes: @conversation.additional_attributes.merge(
        AUDIT_KEY => { 'request_id' => @request_id, 'actor_id' => @actor.id,
                       'at' => Time.current.iso8601, 'stage' => stage,
                       'message_id' => result[:message_id] }
      ))
      result.merge(stage: stage)
    end
  ensure
    Thread.current[:cbn_lead_message] = previous_message
    Thread.current[:cbn_manual_resume_conversation_id] = previous_manual
    Current.executed_by = previous_actor
  end

  private

  def validate_scope!
    unless @conversation.account_id == 1 && @conversation.inbox_id == 5 && @actor.is_a?(User) && @actor.id != 7 &&
           @conversation.account.users.exists?(id: @actor.id)
      raise Unavailable, 'Este atendimento não possui um fluxo de coleta disponível.'
    end
    generic_active = generic_menu? && CbnGenericMenu.config&.fetch('active', false)
    raise Unavailable, 'A automação de atendimento está desativada.' unless (@settings && @settings['active']) || generic_active
  end

  def stage
    return @conversation.custom_attributes[CbnGenericMenu::STAGE] if generic_menu?
    @conversation.custom_attributes[CbnLeadCapture::STAGE]
  end

  def generic_menu?
    defined?(CbnGenericMenu) && CbnGenericMenu.manual_candidate?(@conversation)
  end

  def state
    @conversation.additional_attributes[CbnLeadCapture::KEY]
  end

  def set_stage(value)
    CbnLeadCapture.stage!(@conversation, state, value)
  end

  def rule_for(role)
    id = @settings.fetch('rules', {}).find { |_id, value| value == role }&.first
    rule = id && @conversation.account.automation_rules.find_by(id: id, active: true)
    raise Unavailable, 'A regra desta etapa está desativada. Confira Configurações → Automação.' unless rule
    rule
  end

  def eligible_incoming
    @conversation.messages.incoming.where(private: false).reorder(id: :desc).limit(100).to_a.select do |message|
      CbnLeadCapture.eligible?(message, @settings)
    end
  end

  def initial_rule
    role = state && state['kind']
    return rule_for('clt') if role == 'inss'
    return rule_for(role) if %w[colatina clt cpf].include?(role)

    %w[colatina clt cpf].each do |candidate|
      begin
        rule = rule_for(candidate)
      rescue Unavailable
        next
      end
      match = eligible_incoming.find do |message|
        next false if candidate == 'clt' && !CbnLeadCapture.cpf_flow_kind(@conversation, message)
        AutomationRules::ConditionsFilterService.new(rule, @conversation, { message: message }).perform
      end
      if match
        @initial_incoming = match
        return rule
      end
    end
    raise Unavailable, 'Não encontrei um fluxo de coleta para esta conversa.'
  end

  def deliver(rule)
    incoming = @initial_incoming || eligible_incoming.first
    raise Unavailable, 'Não há mensagem de cliente elegível para retomar o bot.' unless incoming
    Thread.current[:cbn_lead_message] = incoming
    action = rule.actions.find { |item| item['action_name'] == 'send_message' }
    raise Unavailable, 'Esta regra não possui uma mensagem configurada.' unless action
    previous_message_id = @conversation.messages.maximum(:id).to_i
    AutomationRules::ActionService.new(rule, @conversation.account, @conversation).send(:send_message, action.fetch('action_params'))
    prompt = @conversation.messages.outgoing.where('id > ?', previous_message_id).reorder(id: :desc).find do |message|
      message.content_attributes['automation_rule_id'].to_i == rule.id
    end
    raise Unavailable, 'Não foi possível criar a pergunta. Revise a etapa do atendimento.' unless prompt
    { message: 'Bot retomado. A mensagem desta etapa foi encaminhada para envio.', message_id: prompt.id }
  end

  def resume!
    return CbnGenericMenu.resume!(@conversation) if generic_menu?
    # Repair a missing state from an existing native question before asking
    # again. capture_reply only accepts a valid reply after that question.
    unless state
      eligible_incoming.reverse_each do |reply|
        break if state
        reply.conversation = @conversation
        CbnLeadCapture.capture_reply(reply, @settings)
      end
    end
    unless state
      rule = initial_rule
      labels = rule.actions.select { |item| item['action_name'] == 'add_label' }.flat_map { |item| item['action_params'] }
      unless labels.empty?
        @conversation.label_list.add(labels)
        @conversation.save!
      end
      return deliver(rule)
    end
    if stage.to_s.start_with?('revisao_')
      raise Unavailable, 'Há uma divergência nos dados. Revise o cadastro antes de retomar o bot.'
    end
    unless %w[colatina clt cpf inss].include?(state['kind'])
      raise Unavailable, 'Este fluxo não permite retomada automática.'
    end
    if stage == 'concluido'
      return { message: 'A coleta já foi concluída. O atendimento está com a equipe.' } if complete_data?
      # Human intervention may have ended the automatic steps before all data
      # was collected. An explicit operator action can resume that collection.
      set_stage('aguardando_cpf')
    end

    expired = stage == 'expirado' || Time.iso8601(state.fetch('started_at')) < 7.days.ago
    if expired
      fresh = state.merge('started_at' => Time.current.iso8601,
                          'prompt_id' => @conversation.messages.maximum(:id).to_i)
      CbnLeadCapture.stage!(@conversation, fresh, 'aguardando_cpf')
    else
      capture_pending_reply!
    end
    if stage.to_s.start_with?('revisao_')
      raise Unavailable, 'Os dados enviados divergem do cadastro. Revise-os antes de retomar o bot.'
    end

    advance_saved_data!
    case stage
    when 'concluido'
      { message: 'O CPF já foi cadastrado. O atendimento pode continuar com a equipe.' }
    when 'aguardando_cpf'
      deliver(initial_rule)
    when 'cpf_recebido', 'aguardando_matricula'
      set_stage('cpf_recebido')
      deliver(rule_for('matricula'))
    when 'matricula_recebida', 'aguardando_vinculo'
      set_stage('matricula_recebida')
      deliver(rule_for('vinculo'))
    when 'dados_recebidos'
      deliver(rule_for('conclusao'))
    else
      raise Unavailable, 'Não foi possível identificar a etapa pendente. Revise este atendimento.'
    end
  end

  def capture_pending_reply!
    threshold = [state.fetch('prompt_id', 0), state.fetch('last_processed_id', 0)].max
    contact = @conversation.contact
    reply = eligible_incoming.find do |message|
      next false unless message.id > threshold
      text = CbnLeadCapture.customer_text(message.content)
      case stage
      when 'aguardando_cpf' then CbnLeadCapture.valid_cpf?(CbnLeadCapture.extract_cpf(text))
      when 'aguardando_matricula' then CbnLeadCapture.extract_registration(text, contact.custom_attributes['cbn_cpf'].to_s.gsub(/\D/, ''))
      when 'aguardando_vinculo' then CbnLeadCapture.extract_employment(text)
      end
    end
    return unless reply
    reply.conversation = @conversation
    CbnLeadCapture.capture_reply(reply, @settings)
  end

  def advance_saved_data!
    attributes = @conversation.contact.custom_attributes
    cpf = attributes['cbn_cpf'].to_s.gsub(/\D/, '')
    unless CbnLeadCapture.valid_cpf?(cpf)
      set_stage('aguardando_cpf')
      return
    end
    unless state['kind'] == 'colatina'
      set_stage(state['kind'] == 'inss' && stage != 'concluido' ? 'dados_recebidos' : 'concluido')
      return
    end
    unless CbnLeadCapture.extract_registration(attributes['cbn_matricula_beneficio'], cpf)
      set_stage('cpf_recebido')
      return
    end
    missing_employment = @settings['employment_rule_id'] &&
      !%w[comissionado efetivo temporario].include?(attributes['cbn_vinculo_servidor'])
    set_stage(missing_employment ? 'matricula_recebida' : 'dados_recebidos')
  end

  def complete_data?
    attributes = @conversation.contact.custom_attributes
    cpf = attributes['cbn_cpf'].to_s.gsub(/\D/, '')
    return false unless CbnLeadCapture.valid_cpf?(cpf)
    return true unless state['kind'] == 'colatina'
    return false unless CbnLeadCapture.extract_registration(attributes['cbn_matricula_beneficio'], cpf)
    !@settings['employment_rule_id'] || %w[comissionado efetivo temporario].include?(attributes['cbn_vinculo_servidor'])
  end
end
