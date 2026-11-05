require 'minitest/autorun'
require 'minitest/mock'

class CbnResolutionPolicyTest < Minitest::Test
  OPTIONS = CbnResolutionClassification::STAGES.keys.freeze
  def setup
    @conversation = Conversation.new(account_id: 1, contact_id: -123, status: :resolved)
    Current.reset
  end

  def validate_choice(value)
    scope = Struct.new(:data) { def pick(_); data; end }.new({ CbnResolutionClassification::KEY => value })
    Contact.stub(:where, scope) do
      CbnResolutionClassification.stub(:options, OPTIONS) { @conversation.cbn_validate_resolution_classification }
    end
  end

  def test_native_callback_and_routes_loaded
    assert Conversation._validate_callbacks.any? { |callback| callback.filter == :cbn_validate_resolution_classification }
    %i[get post].each do |method|
      path = Rails.application.routes.recognize_path('/api/v1/accounts/1/conversations/123/resolution_classification', method: method)
      assert_equal 'api/v1/accounts/conversations/resolution_classifications', path[:controller]
    end
    klass = Api::V1::Accounts::Conversations::ResolutionClassificationsController
    assert klass < Api::V1::Accounts::Conversations::BaseController
    assert klass._process_action_callbacks.any? { |callback| callback.filter == :conversation }
    assert klass._process_action_callbacks.any? { |callback| callback.filter == :current_account }
  end

  def test_missing_invalid_and_wrong_json_types_rejected
    [nil, '', ' ', false, ['Follow-up'], 'Inexistente'].each do |value|
      @conversation.errors.clear
      validate_choice(value)
      assert_includes @conversation.errors[:base], CbnResolutionClassification::ERROR
    end
  end

  def test_valid_classification_maps_to_ads_and_keeps_existing_attributes
    @conversation.custom_attributes = { 'unrelated' => 123 }
    validate_choice('Sem interesse')
    assert_empty @conversation.errors[:base]
    assert_equal 'Perdido', @conversation.custom_attributes['cbn_ads_etapa']
    assert_equal 123, @conversation.custom_attributes['unrelated']
    assert_equal 'Sem interesse', @conversation.additional_attributes.dig('cbn_resolution', 'classification')
  end

  def test_proposal_stage_is_not_downgraded_by_generic_negotiation
    @conversation.custom_attributes = { 'cbn_ads_etapa' => 'Proposta enviada' }
    validate_choice('Em negociação')
    assert_equal 'Proposta enviada', @conversation.custom_attributes['cbn_ads_etapa']
  end

  def test_no_offer_has_its_own_classification_and_an_unconverted_ad_stage
    validate_choice('Sem oferta')
    assert_empty @conversation.errors[:base]
    assert_equal 'Perdido', @conversation.custom_attributes['cbn_ads_etapa']
    assert_equal 'Sem oferta', @conversation.additional_attributes.dig('cbn_resolution', 'classification')
  end

  def test_open_and_other_accounts_are_not_blocked
    @conversation.status = :open
    validate_choice(nil)
    assert_empty @conversation.errors[:base]
    @conversation.status = :resolved
    @conversation.account_id = 2
    validate_choice(nil)
    assert_empty @conversation.errors[:base]
  end
end

class CbnResolutionControllerTest < Minitest::Test
  class FakeContact
    attr_accessor :custom_attributes, :writes
    def initialize; @custom_attributes = { 'unrelated' => 123 }; @writes = 0; end
    def with_lock; yield; end
    def update!(custom_attributes:); @custom_attributes = custom_attributes; @writes += 1; end
  end
  class FakeConversation
    attr_accessor :status, :writes, :additional_attributes
    attr_reader :contact
    def initialize
      @contact = FakeContact.new; @status = 'open'; @writes = 0; @additional_attributes = {}
    end
    def with_lock; yield; end
    def resolved?; status == 'resolved'; end
    def update!(status:); @status = status.to_s; @writes += 1; end
    def display_id; 123; end
  end

  def setup
    @conversation = FakeConversation.new
    @controller = Api::V1::Accounts::Conversations::ResolutionClassificationsController.new
    @controller.instance_variable_set(:@conversation, @conversation)
    @controller.define_singleton_method(:render) { |json:, status: :ok| @result = { json: json, status: status } }
    @controller.define_singleton_method(:last_message_id) { 100 }
    Current.account = Struct.new(:id).new(1)
  end
  def teardown; Current.reset; end
  def submit(choice, message = 100)
    values = ActionController::Parameters.new(classification: choice, last_message_id: message)
    @controller.define_singleton_method(:params) { values }
    CbnResolutionClassification.stub(:options, ['Follow-up', 'Sem interesse']) { @controller.create }
    @controller.instance_variable_get(:@result)
  end
  def test_choice_is_saved_with_resolution_and_preserves_other_contact_fields
    result = submit('Follow-up')
    assert_equal :ok, result[:status]
    assert_equal 'resolved', @conversation.status
    assert_equal 'Follow-up', @conversation.contact.custom_attributes[CbnResolutionClassification::KEY]
    assert_equal 123, @conversation.contact.custom_attributes['unrelated']
    assert_equal 1, @conversation.writes
  end
  def test_invalid_choice_does_not_save_or_resolve
    assert_equal :unprocessable_entity, submit('Banana')[:status]
    assert_equal 0, @conversation.contact.writes
    assert_equal 0, @conversation.writes
  end
  def test_new_message_and_missing_revision_are_not_closed
    assert_equal :conflict, submit('Follow-up', 99)[:status]
    assert_equal :unprocessable_entity, submit('Follow-up', nil)[:status]
    assert_equal 0, @conversation.contact.writes
    assert_equal 0, @conversation.writes
  end
  def test_idempotent_retry_does_not_rewrite_closed_classification
    @conversation.status = 'resolved'
    @conversation.additional_attributes = { 'cbn_resolution' => { 'classification' => 'Follow-up' } }
    assert_equal :ok, submit('Follow-up')[:status]
    assert_equal :conflict, submit('Sem interesse')[:status]
    assert_equal 0, @conversation.contact.writes
    assert_equal 0, @conversation.writes
  end
end
