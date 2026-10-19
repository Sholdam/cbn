require 'minitest/autorun'
require 'ostruct'
require 'active_support/all'

module Rails
  def self.application = self
  def self.config = self
  def self.after_initialize; end
  def self.logger = Logger.new(File::NULL)
end
require_relative 'cbn_lead_capture'

class EmploymentCaptureTest < Minitest::Test
  class ContactFixture
    attr_reader :custom_attributes, :writes
    def initialize(attrs = {})
      @custom_attributes, @writes = attrs, 0
    end
    def with_lock = yield
    def update!(custom_attributes:)
      @custom_attributes = custom_attributes
      @writes += 1
    end
  end
  class ConversationFixture
    attr_reader :custom_attributes, :additional_attributes, :contact
    def initialize(stage, attrs = {})
      @contact = ContactFixture.new(attrs)
      @custom_attributes = { CbnLeadCapture::STAGE => stage }
      @additional_attributes = { CbnLeadCapture::KEY => {
        'kind' => 'colatina', 'started_at' => Time.current.iso8601, 'prompt_id' => 20
      } }
    end
    def with_lock = yield
    def update!(additional_attributes:, custom_attributes:)
      @additional_attributes, @custom_attributes = additional_attributes, custom_attributes
    end
  end
  def capture(stage, text, attrs: {}, settings: { 'employment_rule_id' => 11 })
    conversation = ConversationFixture.new(stage, attrs)
    message = OpenStruct.new(conversation: conversation, content: text, id: 21, created_at: Time.current)
    CbnLeadCapture.stub(:eligible?, true) { CbnLeadCapture.capture_reply(message, settings) }
    conversation
  end
  def test_all_numbered_options_and_text
    { '1' => 'comissionado', '2' => 'efetivo', '3' => 'temporario',
      'Sou comissionada.' => 'comissionado', 'efetiva' => 'efetivo',
      'Temporário' => 'temporario' }.each do |reply, expected|
      c = capture('aguardando_vinculo', reply)
      assert_equal expected, c.contact.custom_attributes['cbn_vinculo_servidor']
      assert_equal 'dados_recebidos', c.custom_attributes[CbnLeadCapture::STAGE]
    end
  end
  def test_unrecognized_answer_does_not_advance_or_write
    c = capture('aguardando_vinculo', 'nao sei')
    assert_equal 'aguardando_vinculo', c.custom_attributes[CbnLeadCapture::STAGE]
    assert_equal 0, c.contact.writes
  end
  def test_existing_conflicting_declaration_is_preserved_for_review
    c = capture('aguardando_vinculo', '3', attrs: { 'cbn_vinculo_servidor' => 'efetivo' })
    assert_equal 'efetivo', c.contact.custom_attributes['cbn_vinculo_servidor']
    assert_equal 'revisao_vinculo', c.custom_attributes[CbnLeadCapture::STAGE]
  end
  def test_registration_advances_to_new_question
    c = capture('aguardando_matricula', '001234')
    assert_equal '001234', c.contact.custom_attributes['cbn_matricula_beneficio']
    assert_equal 'matricula_recebida', c.custom_attributes[CbnLeadCapture::STAGE]
  end
  def test_legacy_configuration_keeps_previous_flow
    c = capture('aguardando_matricula', '001234', settings: {})
    assert_equal 'dados_recebidos', c.custom_attributes[CbnLeadCapture::STAGE]
  end
  def test_option_number_never_becomes_registration
    c = capture('aguardando_vinculo', '2')
    assert_nil c.contact.custom_attributes['cbn_matricula_beneficio']
  end
  def test_completed_conversation_is_not_reprocessed
    c = capture('concluido', '2')
    assert_equal 0, c.contact.writes
    assert_equal 'concluido', c.custom_attributes[CbnLeadCapture::STAGE]
  end
  def test_repeat_message_and_expired_stage_are_ignored
    c = ConversationFixture.new('aguardando_vinculo')
    state = c.additional_attributes[CbnLeadCapture::KEY]
    state['last_processed_id'] = 21
    msg = OpenStruct.new(conversation: c, content: '2', id: 21, created_at: Time.current)
    CbnLeadCapture.stub(:eligible?, true) { CbnLeadCapture.capture_reply(msg, {}) }
    assert_equal 0, c.contact.writes
    msg.id = 22
    msg.created_at = Time.current + 8.days
    CbnLeadCapture.stub(:eligible?, true) { CbnLeadCapture.capture_reply(msg, {}) }
    assert_equal 'expirado', c.custom_attributes[CbnLeadCapture::STAGE]
    assert_equal 0, c.contact.writes
  end

  class PromptList
    def outgoing = self
    def where(*) = self
    def order(*) = self
    def last = OpenStruct.new(id: 30)
  end
  class ActionConversation < ConversationFixture
    def account_id = 1
    def inbox_id = 5
    def messages = PromptList.new
  end
  class NativeAction
    attr_reader :sends
    def initialize(conversation)
      @conversation, @rule, @sends = conversation, OpenStruct.new(id: 11), 0
    end
    def send_message(*) = @sends += 1
    prepend CbnLeadCapture::Actions
  end
  def test_new_prompt_is_sent_once_and_awaits_employment
    c = ActionConversation.new('matricula_recebida')
    service = NativeAction.new(c)
    settings = { 'active' => true, 'rules' => { '11' => 'vinculo' } }
    CbnLeadCapture.stub(:config, settings) do
      CbnLeadCapture.stub(:human_replied?, false) do
        2.times { service.send(:send_message, 'synthetic prompt') }
      end
    end
    assert_equal 1, service.sends
    assert_equal 'aguardando_vinculo', c.custom_attributes[CbnLeadCapture::STAGE]
    assert_equal 30, c.additional_attributes[CbnLeadCapture::KEY]['prompt_id']
  end
  def test_human_intervention_prevents_new_question
    c = ActionConversation.new('matricula_recebida')
    service = NativeAction.new(c)
    settings = { 'active' => true, 'rules' => { '11' => 'vinculo' } }
    CbnLeadCapture.stub(:config, settings) do
      CbnLeadCapture.stub(:human_replied?, true) { service.send(:send_message, 'synthetic prompt') }
    end
    assert_equal 0, service.sends
    assert_equal 'concluido', c.custom_attributes[CbnLeadCapture::STAGE]
  end
end
