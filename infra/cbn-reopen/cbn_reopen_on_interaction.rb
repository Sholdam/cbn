# Account-wide customer-message policy. Runs synchronously in the native
# after-create-commit path, before message events and delivery are dispatched.
# Does not depend on automation chaining, message text, or human sender type.
module CbnReopenOnInteraction
  private

  def reopen_conversation
    return super unless account_id == 1 && !private? && (incoming? || outgoing?)

    conversation.with_lock do
      if conversation.resolved?
        # Preserve native contact attribution on API inboxes. Outgoing bot and
        # automation messages retain their existing actor, without impersonation.
        Current.executed_by = sender if conversation.inbox.api? && reopened_by_contact?
        conversation.open!
      else
        super
      end
    end
  end
end

Rails.application.config.after_initialize do
  Message.prepend(CbnReopenOnInteraction) unless Message < CbnReopenOnInteraction
end
