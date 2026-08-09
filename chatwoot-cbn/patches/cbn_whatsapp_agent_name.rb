# CBN customization: optionally prepend the human agent name to WhatsApp session messages.
#
# We intentionally reuse Inbox#sender_name_type for the per-inbox switch:
#   friendly     => disabled
#   professional => enabled
#
# This is scoped to WhatsApp only, so the original email semantics remain untouched.
module CbnWhatsappAgentName
  def outgoing_content
    rendered_content = super

    return rendered_content unless conversation&.inbox&.whatsapp?
    return rendered_content unless conversation.inbox.professional?
    return rendered_content unless sender.is_a?(User)
    return rendered_content if rendered_content.blank?

    "*#{sender.name}:*\n\n#{rendered_content}"
  end
end

Rails.application.config.to_prepare do
  unless MessageContentPresenter.ancestors.include?(CbnWhatsappAgentName)
    MessageContentPresenter.prepend(CbnWhatsappAgentName)
  end
end
