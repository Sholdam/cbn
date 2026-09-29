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

    body = @payload.to_json
    request = Net::HTTP::Post.new(uri.request_uri, request_headers(body))
    request.body = body
    Net::HTTP.start(uri.hostname, uri.port, nil,
                    open_timeout: webhook_timeout, read_timeout: webhook_timeout) do |http|
      response = http.request(request)
      raise SafeFetch::HttpError, "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)
    end
  end
end

Rails.application.config.to_prepare do
  Webhooks::Trigger.prepend(CbnWahaLocalWebhook) unless Webhooks::Trigger < CbnWahaLocalWebhook
end
