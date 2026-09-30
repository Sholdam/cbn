require 'active_storage/service/s3_service'

# Keep application/storage traffic on the PC while preserving public upload
# signatures for browser direct uploads through the existing Railway gateway.
module CbnLocalS3Transport
  def initialize(bucket:, upload: {}, public: false, **options)
    super
    internal = ENV['CBN_STORAGE_INTERNAL_ENDPOINT']
    return if internal.blank?
    raise 'Unexpected CBN storage destination' unless internal == 'http://garage:3900'

    @cbn_internal_bucket = Aws::S3::Resource.new(**options.merge(endpoint: internal)).bucket(bucket)
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
    return super unless @cbn_internal_bucket

    instrument :url, key: key do |payload|
      generated = bucket.object(key).presigned_url :put, expires_in: expires_in.to_i,
        content_type: content_type, content_length: content_length, content_md5: checksum,
        metadata: custom_metadata, whitelist_headers: ['content-length'], **upload_options
      payload[:url] = generated
      generated
    end
  end

  private

  def object_for(key)
    @cbn_internal_bucket ? @cbn_internal_bucket.object(key) : super
  end

  def private_url(key, expires_in:, filename:, disposition:, content_type:, **client_opts)
    return super unless @cbn_internal_bucket

    bucket.object(key).presigned_url :get, expires_in: expires_in.to_i,
      response_content_disposition: content_disposition_with(type: disposition, filename: filename),
      response_content_type: content_type, **client_opts
  end

  def public_url(key, **client_opts)
    @cbn_internal_bucket ? bucket.object(key).public_url(**client_opts) : super
  end
end

ActiveStorage::Service::S3Service.prepend(CbnLocalS3Transport)

# Relative proxy routes work in both local and public CRM pages. The browser
# uses its current origin and does not encounter another BasicAuth challenge.
module CbnLocalAttachmentMedia
  def file_url
    return super unless ENV['CBN_LOCAL_MEDIA_PROXY'] == 'true'

    file.attached? ? rails_storage_proxy_path(file.blob) : ''
  end

  def thumb_url
    return super unless ENV['CBN_LOCAL_MEDIA_PROXY'] == 'true'
    return '' unless file.attached? && image?

    rails_storage_proxy_path(file.representation(resize_to_fill: [250, nil]))
  rescue ActiveStorage::UnrepresentableError
    ''
  end

  private

  def inline_audio_url
    return super unless ENV['CBN_LOCAL_MEDIA_PROXY'] == 'true'

    file.attached? ? rails_storage_proxy_path(file.blob, disposition: 'inline') : ''
  end
end

Rails.application.config.to_prepare do
  Attachment.prepend(CbnLocalAttachmentMedia) unless Attachment < CbnLocalAttachmentMedia
end
