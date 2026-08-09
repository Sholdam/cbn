# CBN customization: optionally prepend the human agent display name to
# WhatsApp Cloud messages at the exact Message#outgoing_content boundary used
# by the provider.
#
# We intentionally reuse Inbox#sender_name_type for the per-inbox switch:
#   friendly     => disabled
#   professional => enabled
#
# The prefix is delivery-only: the original message content stored in Chatwoot
# remains unchanged.
module CbnWhatsappAgentName
  def outgoing_content
    rendered_content = super

    return rendered_content unless inbox&.whatsapp?
    return rendered_content unless inbox.professional?
    return rendered_content unless outgoing?
    return rendered_content unless sender_type == 'User'
    return rendered_content if sender.blank?
    return rendered_content if rendered_content.blank?

    # Do not alter automated/campaign/template deliveries.
    return rendered_content if content_attributes&.dig('automation_rule_id').present?
    return rendered_content if additional_attributes&.dig('campaign_id').present?
    return rendered_content if additional_attributes&.dig('template_params').present?

    display_name = sender.try(:available_name).presence || sender.name
    return rendered_content if display_name.blank?

    plain_prefix = "#{display_name}:"
    bold_prefix = "*#{display_name}:*"
    return rendered_content if rendered_content.start_with?(plain_prefix, bold_prefix)

    Rails.logger.info("[CBN_AGENT_NAME] applied message_id=#{id} inbox_id=#{inbox_id} sender_id=#{sender_id} display_name=#{display_name.inspect}")
    "#{bold_prefix}\n\n#{rendered_content}"
  end
end

Rails.application.config.to_prepare do
  Message.prepend(CbnWhatsappAgentName) unless Message.ancestors.include?(CbnWhatsappAgentName)
end
