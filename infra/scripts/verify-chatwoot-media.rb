# Read-only parity check; run with `bundle exec rails runner` in the local Web container.
total = ActiveStorage::Blob.count
present = 0
by_service = Hash.new { |hash, key| hash[key] = { total: 0, present: 0 } }
ActiveStorage::Blob.find_each do |blob|
  name = blob.service_name || '(default)'
  by_service[name][:total] += 1
  if blob.service.exist?(blob.key)
    present += 1
    by_service[name][:present] += 1
  end
end
puts "blobs=#{total}"
puts "blobs_present_in_configured_service=#{present}"
by_service.sort.each do |name, counts|
  puts "service_#{name}_total=#{counts[:total]}"
  puts "service_#{name}_present=#{counts[:present]}"
end
puts "accounts=#{Account.count}"
puts "conversations=#{Conversation.count}"
puts "messages=#{Message.count}"
