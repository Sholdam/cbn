from pathlib import Path
root=Path('/app')
p=root/'app/javascript/dashboard/components/widgets/conversation/ConversationHeader.vue'
s=p.read_text()
if 'CbnConversationLabels' not in s:
 s=s.replace("import MoreActions from './MoreActions.vue';", "import MoreActions from './MoreActions.vue';\nimport CbnConversationLabels from 'dashboard/components-next/cbn-leads/CbnConversationLabels.vue';")
 s=s.replace('      <SLACardLabel', '      <CbnConversationLabels :conversation-id="currentChat.id" />\n      <SLACardLabel',1)
 s=s.replace('pb-2 h-24 xl:h-12','pb-2 min-h-24 xl:min-h-12 h-auto')
 s=s.replace('flex-shrink-0 gap-2 w-full xl:w-auto header-actions-wrap','flex-shrink gap-2 w-full xl:w-auto xl:max-w-[65%] flex-wrap header-actions-wrap')
 p.write_text(s)
p=root/'app/javascript/dashboard/components/ChatListHeader.vue'
s=p.read_text()
if 'cbn-status-switch' not in s:
 anchor="import NextButton from 'dashboard/components-next/button/Button.vue';"
 assert s.count(anchor)==1, 'Quick status import anchor changed'
 s=s.replace(anchor,anchor+"\nimport SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';\nimport { useI18n } from 'vue-i18n';\nimport { useMapGetter, useStore } from 'dashboard/composables/store.js';")
 anchor='const { uiSettings, updateUISettings } = useUISettings();'
 assert s.count(anchor)==1, 'Quick status state anchor changed'
 s=s.replace(anchor,anchor+"""
const { t } = useI18n();
const store = useStore();
const chatSortFilter = useMapGetter('getChatSortFilter');
const quickStatusOptions = computed(() =>
  ['open', 'resolved', 'pending', 'snoozed', 'all'].map(value => ({
    value, label: t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${value}.TEXT`),
  }))
);
const activeQuickStatusLabel = computed(() => quickStatusOptions.value.find(option => option.value === props.activeStatus)?.label || '');
const handleQuickStatusChange = value => {
  store.dispatch('setChatStatusFilter', value);
  updateUISettings({ conversations_filter_by: { status: value, order_by: chatSortFilter.value || wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC } });
  emit('basicFilterChange', value, 'status');
};
""")
 anchor='''      <span
        v-if="!hasAppliedFiltersOrActiveFolders"
        class="px-2 py-1 my-0.5 mx-1 rounded-md capitalize bg-n-slate-3 text-xxs text-n-slate-12 shrink-0"
      >
        {{ $t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${activeStatus}.TEXT`) }}
      </span>'''
 assert s.count(anchor)==1, 'Quick status badge anchor changed'
 s=s.replace(anchor,'''      <SelectMenu
        v-if="!hasAppliedFiltersOrActiveFolders"
        class="cbn-status-switch mx-1"
        :model-value="activeStatus"
        :options="quickStatusOptions"
        :label="activeQuickStatusLabel"
        sub-menu-position="bottom"
        @update:model-value="handleQuickStatusChange"
      />''')
p.write_text(s)
p=root/'app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue'
s=p.read_text().replace("'cbn_data_nascimento', 'cbn_origem_contato'", "'cbn_data_nascimento', 'cbn_matricula_beneficio', 'cbn_origem_contato'")
p.write_text(s)
p=root/'app/javascript/dashboard/routes/dashboard/conversation/customAttributes/CustomAttributes.vue'
s=p.read_text()
anchor='  // If no saved order exists, return in default order'
if 'CBN requested field order' not in s:
 s=s.replace(anchor,"  // CBN requested field order, independent of older saved sidebar order.\n  if (props.attributeFrom === 'cbn_contact_main_data' && props.includeAttributeKeys) {\n    return allElements.sort((a, b) => props.includeAttributeKeys.indexOf(a.key) - props.includeAttributeKeys.indexOf(b.key));\n  }\n\n"+anchor)
p.write_text(s)
p=root/'vite.config.ts'
s=p.read_text().replace('export default defineConfig({','export default defineConfig({\n  build: { sourcemap: false },',1)
p.write_text(s)
