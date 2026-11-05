module Cbn
  class AudioTranscriptionJob < ApplicationJob
    queue_as :active_storage_analysis

    def perform(attachment_id, token)
      attachment = Attachment.find_by(id: attachment_id, account_id: 1)
      return unless attachment
      accepted = false
      attachment.with_lock do
        state = attachment.meta&.[]('cbn_transcription') || {}
        if state['token'] == token && state['state'] == 'queued'
          attachment.update!(meta: (attachment.meta || {}).merge('cbn_transcription' => state.merge('state' => 'processing', 'at' => Time.current.iso8601)))
          accepted = true
        end
      end
      return unless accepted

      begin
        text = Cbn::AudioTranscription.new(attachment).perform
        complete(attachment, token, 'done', text: text)
      rescue StandardError => error
        # No key, audio, transcript or raw provider error enters application logs.
        message = error.is_a?(Cbn::AudioTranscription::Failure) ? error.message : 'Não foi possível transcrever este áudio. Tente novamente mais tarde.'
        complete(attachment, token, 'failed', error: message)
      end
    end

    private

    def complete(attachment, token, state, text: nil, error: nil)
      changed = false
      attachment.with_lock do
        attrs = attachment.meta || {}
        current = attrs['cbn_transcription'] || {}
        if current['token'] == token
          updated = attrs.merge('cbn_transcription' => current.merge('state' => state, 'at' => Time.current.iso8601, 'error' => error))
          updated['transcribed_text'] = text if text
          attachment.update!(meta: updated)
          changed = true
        end
      end
      # Native message update only; never creates/sends a message or reopens it.
      attachment.message.reload.send_update_event if changed
    end
  end
end
