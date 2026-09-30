# Authorized cleanup of local account 1. Keep its owner and the WAHA service.
# Run with rails runner; call only after confirming this deletion with the owner.
Rails.logger.level = Logger::FATAL
account = Account.find(1)
owner = account.users.find(1)
raise 'Owner must remain administrator' unless account.account_users.find_by!(user: owner).administrator?
service = account.users.find_by!(email: 'waha-integration@cbn.invalid')
inbox = account.inboxes.find(5)
raise 'WAHA agent must retain inbox membership' unless inbox.members.exists?(service.id)

targets = account.users.where.not(id: [owner.id, service.id]).to_a
raise 'Unexpected team member; obtain a new deletion authorization' if targets.any? { |user| ![2, 3, 4].include?(user.id) }
raise 'Cannot delete users of another account' if targets.any? { |user| user.accounts.where.not(id: account.id).exists? }
before = [account.contacts.count, account.conversations.count, account.messages.count]

# Execute only the cleanup callbacks created by this operation. Do not start
# the low queue containing inherited work from the migration.
Agents::DestroyJob.queue_adapter = :inline
ActiveRecord::DestroyAssociationAsyncJob.queue_adapter = :inline

targets.each do |user|
  account.account_users.find_by!(user: user).destroy!
  DeleteObjectJob.perform_now(user.reload) if user.account_users.empty?
end

# The imported clone contains an account membership with no User record.
orphan_count = account.account_users.where.not(user_id: User.select(:id)).delete_all
after = [account.contacts.count, account.conversations.count, account.messages.count]
raise 'Unexpected loss of CRM history' unless after == before
puts({ removed_user_ids: targets.map(&:id), removed_orphan_memberships: orphan_count,
       remaining_user_ids: account.users.order(:id).pluck(:id), history_counts_preserved: true }.to_json)
