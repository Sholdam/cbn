# Run with rails runner inside the local CBN Chatwoot container.
# This updates future matching events; it never replays messages or queues.
Rails.logger.level = Logger::FATAL

account = Account.find(1)
inbox = account.inboxes.find(5)
raise 'Expected WAHA API inbox' unless inbox.channel.is_a?(Channel::Api)
raise 'Unexpected webhook host' unless URI(inbox.channel.webhook_url).hostname == 'waha'

rules = account.automation_rules.where(id: [1, 3, 4, 5, 6]).order(:id).to_a
raise 'Expected five existing rules' unless rules.length == 5

plans = rules.map do |rule|
  content_conditions = rule.conditions.select { |condition| condition['attribute_key'] == 'content' }
  raise 'Missing content condition' if content_conditions.empty?
  operators = content_conditions.map { |condition| condition['filter_operator'] }.uniq
  raise 'Mixed content operators require review' unless operators.length == 1

  conditions = [
    { 'attribute_key' => 'inbox_id', 'values' => [inbox.id], 'filter_operator' => 'equal_to' },
    { 'attribute_key' => 'message_type', 'values' => ['incoming'], 'filter_operator' => 'equal_to' },
    { 'attribute_key' => 'private_note', 'values' => [false], 'filter_operator' => 'equal_to' },
    { 'attribute_key' => 'content', 'values' => content_conditions.flat_map { |condition| condition['values'] }.uniq,
      'filter_operator' => operators.first }
  ]
  conditions.each_with_index do |condition, index|
    condition['custom_attribute_type'] = ''
    condition['query_operator'] = 'and' if index < conditions.length - 1
  end
  candidate = rule.dup
  candidate.conditions = conditions
  raise 'Invalid revised automation' unless candidate.valid? && AutomationRules::ConditionValidationService.new(candidate).perform

  [rule, conditions]
end

ActiveRecord::Base.transaction do
  plans.each { |rule, conditions| rule.update!(conditions: conditions, active: true) }
end
puts({ activated_rule_ids: rules.map(&:id), inbox_id: inbox.id, historical_replay: false }.to_json)
