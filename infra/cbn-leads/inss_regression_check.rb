# Run with bundle exec rails runner; uses synthetic stubs, no database writes or sends.
Rails.logger.level=Logger::FATAL
Cbn::LeadBotResumeService
conv=Struct.new(:label_list).new([])
msg=Struct.new(:content)
raise 'Unlabelled INSS' unless CbnLeadCapture.cpf_flow_kind(conv,msg.new('Olá! Recebo INSS e quero uma simulação.'))=='inss'
raise 'Ad title' unless CbnLeadCapture.cpf_flow_kind(conv,msg.new("📢 **ANÚNCIO DO FACEBOOK**\n**Título:** Simule seu consignado INSS\n💬 MENSAGEM DO CLIENTE:\nOlá"))=='inss'
raise 'Unrelated' unless CbnLeadCapture.cpf_flow_kind(conv,msg.new('Olá')).nil?
conv.label_list=['clt'];raise 'CLT precedence' unless CbnLeadCapture.cpf_flow_kind(conv,msg.new('INSS'))=='clt'
[['inss','aguardando_cpf','dados_recebidos'],['inss','concluido','concluido'],['clt','aguardando_cpf','concluido']].each do |kind,initial,expected|
 service=Cbn::LeadBotResumeService.allocate
 contact=Struct.new(:custom_attributes).new({'cbn_cpf'=>'11144477735'})
 service.instance_variable_set(:@conversation,Struct.new(:contact).new(contact))
 service.instance_variable_set(:@test_stage,initial)
 service.define_singleton_method(:state){{'kind'=>kind}}
 service.define_singleton_method(:stage){@test_stage}
 service.define_singleton_method(:set_stage){|value|@test_stage=value}
 service.send(:advance_saved_data!)
 raise 'Saved data stage' unless service.send(:stage)==expected
end
puts 'INSS_REGRESSIONS_OK cases=7 no_writes=true no_sends=true'
