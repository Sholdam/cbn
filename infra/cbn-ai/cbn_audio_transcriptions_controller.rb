class Api::V1::Accounts::CbnAudioTranscriptionsController < Api::V1::Accounts::BaseController
  before_action :authorized_attachment

  def show
    render json: state
  end

  def create
    Cbn::AudioTranscription.validate!(@attachment)
    Cbn::AudioTranscription.credential(Current.account.id)
    token = nil
    @attachment.with_lock do
      if @attachment.meta&.[]('transcribed_text').present? || in_progress?
        return render json: state
      end
      token = SecureRandom.uuid
      meta = @attachment.meta || {}
      @attachment.update!(meta: meta.merge('cbn_transcription' => { 'state' => 'queued', 'token' => token, 'at' => Time.current.iso8601, 'requested_by' => Current.user.id, 'model' => Cbn::AudioTranscription::MODEL }))
    end
    Cbn::AudioTranscriptionJob.perform_later(@attachment.id, token)
    render json: state, status: :accepted
  rescue Cbn::AudioTranscription::Failure => error
    render json: { error: error.message }, status: :unprocessable_entity
  rescue StandardError
    if token
      @attachment.with_lock do
        current = @attachment.meta&.[]('cbn_transcription') || {}
        if current['token'] == token && current['state'] == 'queued'
          @attachment.update!(meta: @attachment.meta.merge('cbn_transcription' => current.merge('state' => 'failed', 'error' => 'Não foi possível iniciar a transcrição. Tente novamente.')))
        end
      end
    end
    render json: { error: 'Não foi possível iniciar a transcrição. Tente novamente.' }, status: :service_unavailable
  end

  private

  def authorized_attachment
    return head :not_found unless Current.account.id == 1
    @attachment = Attachment.where(account_id: Current.account.id).find(params[:id])
    authorize @attachment.message.conversation, :show?
    Cbn::AudioTranscription.validate!(@attachment)
  rescue Cbn::AudioTranscription::Failure => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def in_progress?
    value = @attachment.meta&.[]('cbn_transcription') || {}
    %w[queued processing].include?(value['state']) && Time.iso8601(value['at'].to_s) > 5.minutes.ago
  rescue ArgumentError
    false
  end

  def state
    value = @attachment.meta&.[]('cbn_transcription') || {}
    text = @attachment.meta&.[]('transcribed_text')
    { state: text.present? ? 'done' : value.fetch('state', 'idle'), text: text, error: value['error'], model: Cbn::AudioTranscription::MODEL }
  end
end
