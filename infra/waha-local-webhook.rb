# Only the explicitly provisioned API inbox may POST to the WAHA container.
# Other URLs still use Chatwoot SafeFetch's normal SSRF filtering.
module CbnWahaLocalWebhook
  private

  def perform_request
    allowed = ENV['CBN_WAHA_WEBHOOK_URL']
    return super unless allowed.present? && @webhook_type.to_s == 'api_inbox_webhook' && @url == allowed

    uri = URI(allowed)
    unless uri.scheme == 'http' && uri.hostname == 'waha' && uri.port == 3000 &&
           uri.path.match?(%r{\A/webhooks/chatwoot/default/app_[a-f0-9]{32}\z}) &&
           uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
      raise SafeFetch::UnsafeUrlError, 'Unexpected local WAHA destination'
    end

    body = cbn_waha_payload.to_json
    request = Net::HTTP::Post.new(uri.request_uri, request_headers(body))
    request.body = body
    Net::HTTP.start(uri.hostname, uri.port, nil,
                    open_timeout: webhook_timeout, read_timeout: webhook_timeout) do |http|
      response = http.request(request)
      raise SafeFetch::HttpError, "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)
    end
  end

  def cbn_waha_payload
    payload = @payload.deep_dup
    files = payload[:attachments] || payload['attachments']
    return payload unless files.present?

    message = Message.find_by(id: payload[:id] || payload['id'])
    return payload unless message&.inbox&.channel.is_a?(Channel::Api) &&
                          message.inbox.channel.webhook_url == ENV['CBN_WAHA_WEBHOOK_URL']

    files.each do |file|
      attachment = message.attachments.find_by(id: file[:id] || file['id'])
      next unless attachment&.file&.attached?

      # WAHA downloads media inside Docker. Keep it out of the public gateway
      # and preserve the filename suffix used by the WAHA MIME detector.
      url = Rails.application.routes.url_helpers.rails_storage_proxy_url(
        attachment.file.blob, host: 'chatwoot-web', port: 3000, protocol: 'http'
      )
      key = file.key?(:data_url) ? :data_url : 'data_url'
      file[key] = url
    end
    payload
  end
end

Rails.application.config.to_prepare do
  Webhooks::Trigger.prepend(CbnWahaLocalWebhook) unless Webhooks::Trigger < CbnWahaLocalWebhook
end
