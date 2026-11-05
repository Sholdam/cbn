require 'minitest/autorun'
require 'minitest/mock'

class CbnAiTest < Minitest::Test
  def test_routes_keep_native_account_authentication
    %i[get post].each do |method|
      route = Rails.application.routes.recognize_path('/api/v1/accounts/1/cbn_audio_transcriptions/123', method: method)
      assert_equal 'api/v1/accounts/cbn_audio_transcriptions', route[:controller]
    end
    klass = Api::V1::Accounts::CbnAudioTranscriptionsController
    assert klass < Api::V1::Accounts::BaseController
    assert klass._process_action_callbacks.any? { |callback| callback.filter == :current_account }
    assert klass._process_action_callbacks.any? { |callback| callback.filter == :authorized_attachment }
  end

  def test_luna_is_registered_for_editor_and_other_workloads_keep_defaults
    assert Llm::Models.valid_model_for?('editor', 'gpt-6-luna')
    assert Llm::Models.valid_model_for?('audio_transcription', 'gpt-transcribe')
    assert_equal 'gpt-4.1-mini', Llm::Models.default_model_for('editor')
    assert_equal 'gpt-4.1', Llm::Models.default_model_for('copilot')
    assert_equal 'openai', Llm::Models.provider_for('gpt-6-luna')
    account = Account.find(1)
    account.captain_models = (account.captain_models || {}).merge('editor' => 'gpt-6-luna')
    assert_equal 'gpt-6-luna', Llm::FeatureRouter.resolve(feature: 'editor', account: account)[:model]
    assert Captain::BaseTaskService < CbnLunaEditor if defined?(Captain::BaseTaskService)
  end

  Blob = Struct.new(:byte_size)
  FileData = Struct.new(:blob) { def attached?; true; end }
  MessageData = Struct.new(:content_attributes)
  AudioData = Struct.new(:account_id, :file, :message) { def audio?; true; end }
  def audio(size = 100)
    AudioData.new(1, FileData.new(Blob.new(size)), MessageData.new({}))
  end
  def test_validation_rejects_other_accounts_deleted_and_large_audio
    assert_nil Cbn::AudioTranscription.validate!(audio)
    assert_raises(Cbn::AudioTranscription::Failure) { Cbn::AudioTranscription.validate!(audio(25_000_001)) }
    item = audio; item.account_id = 2
    assert_raises(Cbn::AudioTranscription::Failure) { Cbn::AudioTranscription.validate!(item) }
    item = audio; item.message.content_attributes = { 'deleted' => true }
    assert_raises(Cbn::AudioTranscription::Failure) { Cbn::AudioTranscription.validate!(item) }
  end

  class FakeHttp
    attr_reader :request_value
    attr_accessor :use_ssl, :open_timeout, :read_timeout, :write_timeout
    def initialize(code, body); @code = code; @body = body; end
    def request(value); @request_value = value; Struct.new(:code, :body).new(@code, @body); end
  end
  def with_audio_file
    Tempfile.create(['cbn-test-', '.webm']) { |file| file.write('synthetic'); file.flush; yield file.path }
  end
  def test_transcribe_request_uses_exact_model_and_no_legacy_language_parameter
    http = FakeHttp.new('200', '{"text":"Transcrição sintética."}')
    service = Cbn::AudioTranscription.new(audio)
    with_audio_file do |path|
      Net::HTTP.stub(:new, http) do
        assert_equal 'Transcrição sintética.', service.send(:request, path, 'synthetic-key')
      end
    end
    assert_equal 'Bearer synthetic-key', http.request_value['Authorization']
    params = http.request_value.instance_variable_get(:@body_data)
    assert_includes params, ['model', 'gpt-transcribe']
    assert_includes params, ['languages[]', 'pt']
    refute params.any? { |row| row.first == 'language' }
    assert_equal '/v1/audio/transcriptions', http.request_value.path
  end
  def test_provider_error_body_is_not_exposed_or_stored
    service = Cbn::AudioTranscription.new(audio)
    with_audio_file do |path|
      http = FakeHttp.new('401', '{"error":"private-secret-must-not-escape"}')
      Net::HTTP.stub(:new, http) do
        failure = assert_raises(Cbn::AudioTranscription::Failure) { service.send(:request, path, 'synthetic-key') }
        refute_includes failure.message, 'private-secret'
        assert_includes failure.message, 'chave'
      end
    end
  end

  def test_empty_transcript_is_not_success
    with_audio_file do |path|
      Net::HTTP.stub(:new, FakeHttp.new('200', '{"text":""}')) do
        assert_raises(Cbn::AudioTranscription::Failure) { Cbn::AudioTranscription.new(audio).send(:request, path, 'synthetic-key') }
      end
    end
  end

  class FakeAttachment
    attr_accessor :meta
    def initialize; @meta = { 'other' => 'preserve', 'cbn_transcription' => { 'token' => 'current', 'state' => 'queued' } }; end
    def with_lock; yield; end
    def update!(meta:); @meta = meta; end
    def message; @message ||= Struct.new(:updates) { def reload; self; end; def send_update_event; self.updates += 1; end }.new(0); end
  end
  def test_completion_preserves_metadata_and_does_not_overwrite_a_newer_request
    item = FakeAttachment.new; job = Cbn::AudioTranscriptionJob.new
    job.send(:complete, item, 'older', 'done', text: 'old')
    refute item.meta.key?('transcribed_text')
    job.send(:complete, item, 'current', 'done', text: 'transcrição')
    assert_equal 'preserve', item.meta['other']
    assert_equal 'transcrição', item.meta['transcribed_text']
    assert_equal 1, item.message.updates
    assert_equal 'active_storage_analysis', Cbn::AudioTranscriptionJob.queue_name
  end
end
