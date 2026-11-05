const fs=require('node:fs');const path=require('node:path');
const root=process.argv[2];
function patch(file,edits){let text=fs.readFileSync(path.join(root,file),'utf8');for(const [from,to]of edits){if(text.split(from).length!==2)throw new Error('Source anchor changed: '+file+' '+from.slice(0,55));text=text.replace(from,to);}fs.writeFileSync(path.join(root,file),text);}
patch('app/javascript/dashboard/App.vue',[
 ["import ReconnectService from 'dashboard/helper/ReconnectService';","import ReconnectService from 'dashboard/helper/CbnRealtimeRecovery';"],
 ['reconnectService: null,','reconnectService: null,\n      actionCableConnector: null,'],
 ['  unmounted() {','  unmounted() {\n    this.actionCableConnector?.disconnect();'],
 ["      await this.$store.dispatch('accounts/get');","      const requestedAccount = this.currentAccountId;\n      await this.$store.dispatch('accounts/get');\n      if (requestedAccount !== this.currentAccountId) return;"],
 ['      vueActionCable.init(this.store, pubsubToken);\n      this.reconnectService = new ReconnectService(this.store, this.router);','      this.reconnectService?.disconnect();\n      this.actionCableConnector?.disconnect();\n      this.actionCableConnector = vueActionCable.init(this.store, pubsubToken);\n      this.reconnectService = new ReconnectService(this.store, this.router, this.actionCableConnector);'],
]);
patch('app/javascript/shared/helpers/BaseActionCableConnector.js',[
 ['    this.consumer = createConsumer(websocketURL);','    this.stopped = false;\n    this.consumer = createConsumer(websocketURL);'],
 ['        disconnected: () => {','        disconnected: () => {\n          if (this.stopped) return;'],
 ['      setTimeout(() => {\n        this.subscription.updatePresence();','      this.presenceTimer = setTimeout(() => {\n        if (this.stopped) return;\n        this.subscription.updatePresence();'],
 ['  checkConnection() {','  checkConnection() {\n    if (this.stopped) return;'],
 ['  disconnect() {\n    this.consumer.disconnect();','  disconnect() {\n    this.stopped = true;\n    this.clearReconnectTimer();\n    clearTimeout(this.presenceTimer);\n    this.consumer.disconnect();'],
]);
const file=path.join(root,'app/javascript/dashboard/store/modules/conversations/actions.js');let text=fs.readFileSync(file,'utf8');
const start=text.indexOf('  syncActiveConversationMessages: async (');const end=text.indexOf('  setConversationLastMessageId:',start);if(start<0||end<start)throw new Error('Message sync anchor changed');
text=text.slice(0,start)+'  syncActiveConversationMessages: cbnSyncMessages,\n\n'+text.slice(end);
text="import cbnSyncMessages from 'dashboard/helper/CbnMessageSync';\n"+text;
for(const name of ['fetchAllConversations','fetchFilteredConversations']){
 const start=text.indexOf('  '+name+':');const end=text.indexOf('\n  },',start);let block=text.slice(start,end);
 if(!block.includes('// Handle error'))throw new Error('List catch anchor changed');
 block=block.replace('    } catch (error) {','      return true;\n    } catch (error) {').replace('// Handle error','return false;');text=text.slice(0,start)+block+text.slice(end);
}
fs.writeFileSync(file,text);
