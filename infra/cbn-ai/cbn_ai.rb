module CbnLunaEditor
  private

  def build_chat(context, model:, messages:, schema: nil, tools: [])
    chat = super
    return chat unless account.id == 1 && model == 'gpt-6-luna'

    # Preserve the original non-reasoning editor's latency and output contract.
    chat.with_params(reasoning_effort: 'none')
  end
end

Rails.application.config.after_initialize do
  if defined?(Captain::BaseTaskService)
    Captain::BaseTaskService.prepend(CbnLunaEditor) unless Captain::BaseTaskService < CbnLunaEditor
  end
  require '/app/app/services/cbn/audio_transcription'
  require '/app/app/jobs/cbn/audio_transcription_job'
  require '/app/app/controllers/api/v1/accounts/cbn_audio_transcriptions_controller'
  Rails.application.routes.append do
    get '/api/v1/accounts/:account_id/cbn_audio_transcriptions/:id', to: 'api/v1/accounts/cbn_audio_transcriptions#show'
    post '/api/v1/accounts/:account_id/cbn_audio_transcriptions/:id', to: 'api/v1/accounts/cbn_audio_transcriptions#create'
  end
end
