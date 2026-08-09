root = ENV.fetch('CHATWOOT_ROOT', '/app')
path = File.join(root, 'app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue')
source = File.read(path)

replacements = {
  "      senderNameType: 'friendly',\n      businessName: ''," => "      senderNameType: 'friendly',\n      whatsappAgentNameEnabled: false,\n      businessName: '',",
  "      this.senderNameType = this.inbox.sender_name_type;\n      this.businessName = this.inbox.business_name;" => "      this.senderNameType = this.inbox.sender_name_type;\n      this.whatsappAgentNameEnabled =\n        this.inbox.sender_name_type === 'professional';\n      this.businessName = this.inbox.business_name;",
  "          sender_name_type: this.senderNameType,\n          business_name: this.businessName || null," => "          sender_name_type: this.isAWhatsAppChannel\n            ? this.whatsappAgentNameEnabled\n              ? 'professional'\n              : 'friendly'\n            : this.senderNameType,\n          business_name: this.businessName || null,",
  "            <SettingsFieldSection\n              :label=\"$t('INBOX_MGMT.HELP_CENTER.LABEL')\"" => "            <SettingsToggleSection\n              v-if=\"isAWhatsAppChannel\"\n              v-model=\"whatsappAgentNameEnabled\"\n              header=\"Exibir nome do atendente nas mensagens\"\n              description=\"Adiciona automaticamente o nome do agente antes das mensagens enviadas pelo WhatsApp.\"\n              class=\"mb-4\"\n            />\n\n            <SettingsFieldSection\n              :label=\"$t('INBOX_MGMT.HELP_CENTER.LABEL')\""
}

replacements.each do |before, after|
  unless source.include?(before)
    warn "CBN Chatwoot patch failed: expected Settings.vue fragment not found:\n#{before}"
    exit 1
  end

  source = source.sub(before, after)
end

File.write(path, source)
puts 'CBN Chatwoot Settings.vue patch applied successfully.'
