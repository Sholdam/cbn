# Rails runner; synthetic objects only. Never saves records or sends messages.
require 'minitest/autorun'
require 'minitest/mock'
Rails.logger.level = Logger::FATAL
ARGV.each { |path| load path }

class CbnCpfRetryTest < Minitest::Test
  VALID = '11144477735'.freeze
  INVALID = '11144477734'.freeze
  MessageStub = Struct.new(:id, :content, :created_at, :conversation)
  class Relation
    attr_accessor :duplicate
    def initialize(rows = [], duplicate = false); @rows, @duplicate = rows, duplicate; end
    def incoming; self; end
    def where(*); self; end
    def not(*); self; end
    def reorder(*); self; end
    def limit(*); self; end
    def any?(&block); @rows.any?(&block); end
    def exists?; @duplicate; end
  end
  class ContactStub
    attr_accessor :custom_attributes
    def initialize(cpf); @custom_attributes = cpf ? { 'cbn_cpf' => cpf } : {}; end
    def id; 999_001; end
    def with_lock; yield; end
    def update!(custom_attributes:); @custom_attributes = custom_attributes; end
  end
  class ConversationStub
    attr_accessor :contact, :additional_attributes, :custom_attributes, :messages
    def initialize(saved, prior)
      @contact = ContactStub.new(saved)
      @additional_attributes = { CbnLeadCapture::KEY => { 'kind' => 'inss', 'prompt_id' => 20, 'trigger_id' => 10, 'started_at' => Time.current.iso8601 } }
      @custom_attributes = { CbnLeadCapture::STAGE => 'aguardando_cpf' }
      @messages = Relation.new(prior)
    end
    def id; 999_002; end
    def contact_id; contact.id; end
    def account_id; 1; end
    def inbox_id; 5; end
    def label_list; ['inss']; end
    def open?; true; end
    def with_lock; yield; end
    def update!(additional_attributes:, custom_attributes:)
      @additional_attributes, @custom_attributes = additional_attributes, custom_attributes
    end
  end
  Rule = Struct.new(:id)
  class NativeActionStub
    attr_reader :sent
    def initialize(conversation)
      @conversation, @rule, @sent = conversation, Rule.new(16), 0
    end
    def send_message(_)
      @sent += 1
      prompt = Message.new(id: 24, conversation_id: @conversation.id, message_type: :outgoing, private: false, content_attributes: { 'automation_rule_id' => 16 })
      prompt.define_singleton_method(:persisted?) { true }
      prompt
    end
  end
  class ActionStub < NativeActionStub
    prepend CbnLeadCapture::Actions
  end
  def setup
    @settings = { 'active' => true, 'rules' => { '16' => 'cpf_invalido' } }
    Current.reset
    Thread.current[:cbn_lead_message] = nil
    Thread.current[:cbn_manual_resume_conversation_id] = nil
  end
  def teardown
    Current.reset
    Thread.current[:cbn_lead_message] = nil
    Thread.current[:cbn_manual_resume_conversation_id] = nil
  end
  def input_message(content, id = 23); MessageStub.new(id, content, Time.current, nil); end
  def with_capture(conversation, reply, duplicate: false, human: false)
    reply.conversation = conversation
    CbnLeadCapture.stub(:eligible?, true) do
      CbnLeadCapture.stub(:human_replied?, human) do
        CbnLeadCapture.stub(:mirror_labels!, nil) do
          Contact.stub(:where, Relation.new([], duplicate)) { yield }
        end
      end
    end
  end
  def test_corrected_valid_reply_replaces_only_the_clients_earlier_invalid_value
    c = ConversationStub.new(INVALID, [input_message(INVALID, 21)]); m = input_message(VALID)
    with_capture(c, m) { CbnLeadCapture.capture_reply(m, @settings) }
    assert_equal VALID, c.contact.custom_attributes['cbn_cpf']
    assert_equal 'dados_recebidos', c.custom_attributes[CbnLeadCapture::STAGE]
  end
  def test_existing_valid_cpf_is_never_overwritten
    c = ConversationStub.new('98765432100', [input_message(INVALID, 21)]); m = input_message(VALID)
    with_capture(c, m) { CbnLeadCapture.capture_reply(m, @settings) }
    assert_equal '98765432100', c.contact.custom_attributes['cbn_cpf']
    assert_equal 'revisao_cpf', c.custom_attributes[CbnLeadCapture::STAGE]
  end
  def test_invalid_saved_value_without_customer_proof_still_requires_review
    c = ConversationStub.new(INVALID, []); m = input_message(VALID)
    with_capture(c, m) { CbnLeadCapture.capture_reply(m, @settings) }
    assert_equal INVALID, c.contact.custom_attributes['cbn_cpf']
    assert_equal 'revisao_cpf', c.custom_attributes[CbnLeadCapture::STAGE]
  end
  def test_duplicate_cpf_on_another_contact_stays_protected
    c = ConversationStub.new(INVALID, [input_message(INVALID, 21)]); m = input_message(VALID)
    with_capture(c, m, duplicate: true) { CbnLeadCapture.capture_reply(m, @settings) }
    assert_equal INVALID, c.contact.custom_attributes['cbn_cpf']
    assert_equal 'revisao_cpf', c.custom_attributes[CbnLeadCapture::STAGE]
  end
  def test_human_takeover_prevents_automatic_correction_of_saved_data
    c = ConversationStub.new(INVALID, [input_message(INVALID, 21)]); m = input_message(VALID)
    with_capture(c, m, human: true) { CbnLeadCapture.capture_reply(m, @settings) }
    assert_equal INVALID, c.contact.custom_attributes['cbn_cpf']
  end
  def test_invalid_reply_requests_a_specific_notice_instead_of_being_silently_ignored
    c = ConversationStub.new(nil, []); m = input_message(INVALID); called = false
    with_capture(c, m) do
      CbnLeadCapture.stub(:deliver_invalid_cpf_notice!, ->(*args) { called = args[1].id == m.id }) { CbnLeadCapture.capture_reply(m, @settings) }
    end
    assert called
    assert_nil c.contact.custom_attributes['cbn_cpf']
  end
  def test_invalid_notice_is_idempotent_and_keeps_collection_waiting
    c = ConversationStub.new(nil, []); m = input_message(INVALID); action = ActionStub.new(c)
    Thread.current[:cbn_lead_message] = m
    CbnLeadCapture.stub(:config, @settings) do
      CbnLeadCapture.stub(:eligible?, true) do
        CbnLeadCapture.stub(:human_replied?, false) { 2.times { action.send(:send_message, ['synthetic notice']) } }
      end
    end
    assert_equal 1, action.sent
    assert_equal 'aguardando_cpf', c.custom_attributes[CbnLeadCapture::STAGE]
    assert_equal m.id, c.additional_attributes[CbnLeadCapture::KEY]['invalid_cpf_reply_id']
  end
  def test_short_numeric_attempt_is_invalid_but_ad_ids_and_words_are_not_cpf_attempts
    assert CbnLeadCapture.invalid_cpf_attempt?('1234567890')
    refute CbnLeadCapture.invalid_cpf_attempt?(VALID)
    refute CbnLeadCapture.invalid_cpf_attempt?('Olá, tudo bem?')
    refute CbnLeadCapture.invalid_cpf_attempt?('120000000000000000')
  end
  def test_manual_resume_uses_the_validation_notice_instead_of_repeating_the_greeting
    service = Cbn::LeadBotResumeService.allocate; m = input_message(INVALID)
    service.instance_variable_set(:@settings, @settings)
    service.define_singleton_method(:state) { { 'prompt_id' => 20 } }
    service.define_singleton_method(:eligible_incoming) { [m] }
    service.define_singleton_method(:rule_for) { |role| raise unless role == 'cpf_invalido'; :validation_notice }
    service.define_singleton_method(:initial_rule) { raise 'Must not repeat greeting' }
    assert_equal :validation_notice, service.send(:cpf_retry_rule)
  end
end
