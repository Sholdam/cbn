const fs=require('node:fs');
const file=process.argv[2];let s=fs.readFileSync(file,'utf8');
const replace=(old,next)=>{if(!s.includes(old))throw Error('ResolveAction source changed: '+old.slice(0,60));s=s.replace(old,()=>next);};
replace("import { ref, computed } from 'vue';","import { ref, computed } from 'vue';\nimport CbnResolveClassification from 'dashboard/components-next/cbn-resolution/CbnResolveClassification.vue';");
replace('const resolveAttributesModalRef = ref(null);','const resolveAttributesModalRef = ref(null);\nconst cbnResolutionRef = ref(null);');
replace('const onCmdResolveConversation = () => {',`const onCmdResolveConversation = async () => {
  if (Number(getters.getCurrentAccountId.value) === 1) {
    const resolved = await cbnResolutionRef.value.open({
      accountId: getters.getCurrentAccountId.value,
      conversationId: currentChat.value.id,
    });
    if (resolved) useAlert(t('CONVERSATION.CHANGE_STATUS'));
    return resolved;
  }`);
replace('      onCmdResolveConversation();\n\n      if (activeIndex', '      const resolved = await onCmdResolveConversation();\n      if (resolved === false) { event.preventDefault(); return; }\n\n      if (activeIndex');
replace('    <ConversationResolveAttributesModal','    <CbnResolveClassification ref="cbnResolutionRef" />\n    <ConversationResolveAttributesModal');
fs.writeFileSync(file,s);
