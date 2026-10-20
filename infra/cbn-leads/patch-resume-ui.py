from pathlib import Path
p=Path('/app/app/javascript/dashboard/components/widgets/conversation/ConversationHeader.vue')
text=p.read_text()
anchor="import CbnConversationLabels from 'dashboard/components-next/cbn-leads/CbnConversationLabels.vue';"
assert text.count(anchor)==1
text=text.replace(anchor,anchor+"\nimport CbnBotResume from 'dashboard/components-next/cbn-leads/CbnBotResume.vue';")
anchor='      <CbnConversationLabels :conversation-id="currentChat.id" />'
assert text.count(anchor)==1
text=text.replace(anchor,anchor+'\n      <CbnBotResume :conversation-id="currentChat.id" :account-id="accountId" :inbox-id="currentChat.inbox_id" />')
p.write_text(text)
p=Path('/app/config/routes.rb')
text=p.read_text()
anchor='Rails.application.routes.draw do\n'
assert text.count(anchor)==1
text=text.replace(anchor,anchor+"  post '/api/v1/accounts/:account_id/conversations/:conversation_id/bot_resume', to: 'api/v1/accounts/conversations/bot_resumes#create'\n",1)
p.write_text(text)

p=Path('/app/vite.config.ts')
text=p.read_text()
if 'build: { sourcemap: false }' not in text:
    text=text.replace('export default defineConfig({','export default defineConfig({\n  build: { sourcemap: false },',1)
p.write_text(text)
