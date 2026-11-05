# Rails runner: synthetic stubs only, no writes, jobs or customer sends.
require 'minitest/autorun'
require 'minitest/mock'
Rails.logger.level = Logger::FATAL
load ARGV.first if ARGV.first.present?

class CbnMenuContextTest < Minitest::Test
  Rule = Struct.new(:id, :description, :active) { def active?; active; end }
  ConversationStub = Struct.new(:account_id, :inbox_id, :additional_attributes, :label_list) do
    def with_lock; yield; end
    def id; 999_999; end
  end
  MessageStub = Struct.new(:content)
  class NativeActionStub
    attr_reader :native_calls, :native_executor
    def initialize(rule, _account, conversation)
      @rule, @conversation = rule, conversation
      @native_calls = 0
      Current.executed_by = rule
    end
    def perform
      @native_calls += 1
      @native_executor = Current.executed_by
    ensure
      Current.reset
    end
  end
  class ActionStub < NativeActionStub
    prepend CbnGenericMenu::Actions
  end
  def setup
    Current.reset
    @settings = { 'active' => true, 'rules' => { 'menu' => 12, 'confirmation' => 13, 'reminder' => 14 } }
    @conversation = ConversationStub.new(1, 5, {}, [])
  end
  def teardown; Current.reset; end
  def execute(rule, settings = @settings)
    CbnGenericMenu.stub(:config, settings) do
      CbnGenericMenu.stub(:can_start?, false) do
        action = ActionStub.new(rule, nil, @conversation)
        action.perform
        action
      end
    end
  end
  def test_skipped_menu_does_not_mark_the_next_event_as_automation
    execute(AutomationRule.new(id: 12, description: '', active: true))
    assert_nil Current.executed_by
    # This is the exact native guard that discarded the CPF transition.
    event = Struct.new(:data).new({ performed_by: Current.executed_by })
    refute AutomationRuleListener.instance.send(:performed_by_automation?, event)
  end
  def test_nested_menu_restores_the_callers_identity
    actor = Object.new
    Current.executed_by = actor
    execute(Rule.new(12, '', true))
    assert_same actor, Current.executed_by
  end
  def test_inactive_menu_does_not_leak_its_rule
    execute(Rule.new(12, '', true), @settings.merge('active' => false))
    assert_nil Current.executed_by
  end
  def test_unavailable_confirmation_does_not_leak_its_rule
    execute(Rule.new(13, '', true))
    assert_nil Current.executed_by
  end
  def test_unrelated_native_rules_keep_their_behavior
    rule = Rule.new(5, '', true)
    action = execute(rule)
    assert_equal 1, action.native_calls
    assert_same rule, action.native_executor
    assert_nil Current.executed_by
  end
  def test_unmatched_ad_can_reach_fallback_menu
    message = MessageStub.new("📢 ANÚNCIO DO FACEBOOK\nMENSAGEM DO CLIENTE:\nOlá")
    CbnGenericMenu.stub(:campaign_rule_matches?, false) do
      refute CbnGenericMenu.existing_flow?(@conversation, message)
    end
  end
  def test_recognized_or_paused_campaign_is_not_taken_over_by_menu
    CbnGenericMenu.stub(:campaign_rule_matches?, true) do
      assert CbnGenericMenu.existing_flow?(@conversation, MessageStub.new('ANÚNCIO DO FACEBOOK'))
    end
  end
  def test_existing_collection_remains_protected
    @conversation.additional_attributes[CbnLeadCapture::KEY] = { 'kind' => 'inss' }
    assert CbnGenericMenu.existing_flow?(@conversation, MessageStub.new('ANÚNCIO DO FACEBOOK'))
  end
  def test_manual_resume_accepts_unmatched_ad_but_respects_campaign_pause
    relation = Object.new
    %i[incoming where reorder limit].each { |method| relation.define_singleton_method(method) { |*| relation } }
    relation.define_singleton_method(:select) { |&block| [MessageStub.new('ANÚNCIO DO FACEBOOK')].select(&block) }
    @conversation.define_singleton_method(:messages) { relation }
    CbnGenericMenu.stub(:campaign_rule_matches?, false) { assert CbnGenericMenu.manual_candidate?(@conversation) }
    CbnGenericMenu.stub(:campaign_rule_matches?, true) { refute CbnGenericMenu.manual_candidate?(@conversation) }
  end
end
