  class ScheduledMessage < ApplicationRecord
    self.table_name = 'cbn_scheduled_messages'
    MAX_FILES = 10
    MAX_FILE_BYTES = 20.megabytes
    MAX_TOTAL_BYTES = 50.megabytes

    belongs_to :account
    belongs_to :conversation
    belongs_to :user
    belongs_to :message, optional: true
    has_many_attached :files

    validates :content, length: { maximum: 10_000 }
    validates :request_id, presence: true, uniqueness: { scope: :account_id }
    validate :payload_present_and_bounded

    private

    def payload_present_and_bounded
      blobs = files.blobs.to_a
      errors.add(:base, 'Escreva uma mensagem ou adicione um anexo.') if content.to_s.strip.empty? && blobs.empty?
      errors.add(:base, 'Adicione no máximo 10 anexos.') if blobs.length > MAX_FILES
      errors.add(:base, 'Cada anexo deve ter até 20 MB.') if blobs.any? { |blob| blob.byte_size > MAX_FILE_BYTES }
      errors.add(:base, 'Os anexos juntos devem ter até 50 MB.') if blobs.sum(&:byte_size) > MAX_TOTAL_BYTES
    end
  end
