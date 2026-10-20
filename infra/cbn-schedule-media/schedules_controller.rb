  class SchedulesController < Api::V1::Accounts::Conversations::BaseController
    before_action :human_agent!
    rescue_from ArgumentError, with: :bad_request
    rescue_from ActiveRecord::RecordInvalid do |error|
      render json: { error: error.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    def index
      render json: schedule_scope.with_attached_files.order(created_at: :desc).limit(30).map { |row| serialize(row) }
    end

    def create
      ensure_channel!
      content = params[:content].to_s.strip
      descriptors = upload_descriptors
      validate_payload!(content, descriptors)
      run_at = scheduled_time!
      request_id = params[:request_id].to_s
      raise ArgumentError, 'Identificador de agendamento inválido.' unless request_id.match?(/\A[0-9a-f-]{36}\z/i)
      row = nil
      staged = []
      ScheduledMessage.transaction do
        advisory_lock("schedule:#{Current.account.id}:#{request_id}")
        row = ScheduledMessage.find_by(account_id: Current.account.id, request_id: request_id)
        if row
          same = row.user_id == current_user.id && row.conversation_id == @conversation.id &&
            row.content == content && row.run_at == run_at && fingerprints(row.files.blobs) == descriptor_fingerprints(descriptors)
          raise ArgumentError, 'Identificador já usado para outro agendamento.' unless same
        else
          staged = upload_blobs(descriptors)
          row = ScheduledMessage.new(account: Current.account, conversation: @conversation, user: current_user,
                                     content: content, run_at: run_at, request_id: request_id, status: 'pending')
          row.files = staged
          row.save!
        end
      end
      render json: serialize(row), status: :created
    ensure
      purge_unattached(staged)
    end

    def update
      ensure_channel!
      descriptors = upload_descriptors
      staged = []
      row = schedule_scope.find(params[:id])
      row.with_lock do
        raise ArgumentError, 'Somente agendamentos pendentes podem ser alterados.' unless row.status == 'pending'
        attachments = row.files.attachments.includes(:blob).to_a
        removal_ids = Array.wrap(params[:remove_attachment_ids]).reject(&:blank?).map do |id|
          raise ArgumentError, 'Anexo inválido.' unless id.to_s.match?(/\A[1-9][0-9]*\z/)
          id.to_i
        end.uniq
        raise ArgumentError, 'Anexo não pertence a este agendamento.' unless (removal_ids - attachments.map(&:id)).empty?
        retained = attachments.reject { |attachment| removal_ids.include?(attachment.id) }.map(&:blob)
        # A retry of an append must not attach identical files a second time.
        existing_fingerprints = fingerprints(retained)
        descriptors = descriptors.reject { |item| existing_fingerprints.include?(descriptor_fingerprints([item]).first) }
        content = params[:content].to_s.strip
        validate_payload!(content, descriptors, retained)
        run_at = scheduled_time!
        staged = upload_blobs(descriptors)
        row.files = retained + staged
        row.update!(content: content, run_at: run_at)
      end
      render json: serialize(row)
    ensure
      purge_unattached(staged)
    end

    def destroy
      row = schedule_scope.find(params[:id])
      row.with_lock do
        raise ArgumentError, 'O agendamento já foi processado.' unless row.status == 'pending'
        row.update!(status: 'cancelled')
      end
      render json: serialize(row)
    end

    private

    def ensure_channel!
      raise ArgumentError, 'Agendamento disponível somente no WhatsApp da CBN.' unless @conversation.inbox_id == 5
      raise ArgumentError, 'Contato bloqueado.' if @conversation.contact.blocked?
    end

    def human_agent!
      head :forbidden unless current_user.is_a?(User) && Current.account_user && current_user.id != 7
    end

    def schedule_scope
      scope = ScheduledMessage.where(account_id: Current.account.id, conversation_id: @conversation.id)
      Current.account_user.administrator? ? scope : scope.where(user_id: current_user.id)
    end

    def scheduled_time!
      local = params[:scheduled_local].to_s
      raise ArgumentError, 'Informe data e horário válidos.' unless local.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}\z/)
      value = ActiveSupport::TimeZone['America/Sao_Paulo'].strptime(local, '%Y-%m-%dT%H:%M')
      raise ArgumentError, 'Escolha um horário futuro, em até 180 dias.' unless value > 1.minute.from_now && value <= 180.days.from_now
      value
    end

    def upload_descriptors
      raw = params[:attachments]
      raise ArgumentError, 'Envie os anexos como arquivos.' unless raw.nil? || raw.is_a?(Array)
      files = Array.wrap(raw).reject(&:blank?)
      raise ArgumentError, 'Adicione no máximo 10 anexos.' if files.length > ScheduledMessage::MAX_FILES
      files.map do |upload|
        raise ArgumentError, 'Envie os anexos como arquivos.' unless upload.is_a?(ActionDispatch::Http::UploadedFile)
        raise ArgumentError, 'Anexo vazio ou maior que 20 MB.' unless upload.size.between?(1, ScheduledMessage::MAX_FILE_BYTES)
        upload.tempfile.rewind
        type = Marcel::MimeType.for(upload.tempfile, name: upload.original_filename, declared_type: upload.content_type)
        upload.tempfile.rewind
        { upload: upload, filename: File.basename(upload.original_filename.to_s.tr('\\', '/')).presence || 'anexo',
          content_type: type, byte_size: upload.size, sha256: Digest::SHA256.file(upload.tempfile.path).hexdigest }
      end
    end

    def validate_payload!(content, descriptors, retained = [])
      raise ArgumentError, 'A mensagem deve ter até 10.000 caracteres.' if content.length > 10_000
      raise ArgumentError, 'Escreva uma mensagem ou adicione um anexo.' if content.empty? && descriptors.empty? && retained.empty?
      raise ArgumentError, 'Adicione no máximo 10 anexos.' if descriptors.length + retained.length > ScheduledMessage::MAX_FILES
      size = descriptors.sum { |item| item[:byte_size] } + retained.sum(&:byte_size)
      raise ArgumentError, 'Os anexos juntos devem ter até 50 MB.' if size > ScheduledMessage::MAX_TOTAL_BYTES
    end

    def upload_blobs(descriptors)
      blobs = []
      descriptors.each do |item|
        item[:upload].tempfile.rewind
        blobs << ActiveStorage::Blob.create_and_upload!(io: item[:upload].tempfile, filename: item[:filename],
          content_type: item[:content_type], identify: false, metadata: { cbn_schedule_sha256: item[:sha256] })
      end
      blobs
    rescue StandardError
      purge_unattached(blobs)
      raise
    end

    def fingerprints(blobs)
      blobs.map { |blob| [blob.filename.to_s, blob.content_type, blob.byte_size, blob.metadata['cbn_schedule_sha256']] }.sort_by(&:to_json)
    end

    def descriptor_fingerprints(descriptors)
      descriptors.map { |item| [item[:filename], item[:content_type], item[:byte_size], item[:sha256]] }.sort_by(&:to_json)
    end

    def purge_unattached(blobs)
      Array(blobs).each do |blob|
        blob.purge unless blob.attachments.exists?
      rescue StandardError => error
        Rails.logger.error("cbn_schedule_upload_cleanup_failure class=#{error.class.name}")
      end
    end

    def serialize(row)
      delivery = row.message&.status
      state = row.status == 'queued' && %w[delivered read failed].include?(delivery) ? delivery : row.status
      { id: row.id, content: row.content, scheduled_at: row.run_at.iso8601, status: state,
        message_id: row.message_id, error: row.last_error, agent_name: row.user.name,
        attachments: row.files.attachments.includes(:blob).order(:id).map { |file|
          { id: file.id, filename: file.blob.filename.to_s, content_type: file.blob.content_type, byte_size: file.blob.byte_size }
        } }
    end

    def bad_request(error)
      render json: { error: error.message }, status: :unprocessable_entity
    end

    def advisory_lock(key)
      number = Digest::SHA256.digest(key).unpack1('q>')
      ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(#{number})")
    end
  end
