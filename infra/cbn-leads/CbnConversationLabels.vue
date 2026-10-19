<script setup>
import { computed, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

const props = defineProps({ conversationId: { type: Number, required: true } });
const store = useStore();
const open = ref(false);
const search = ref('');
const busy = ref(false);
const labels = computed(() => store.getters['labels/getLabels'] || []);
const selected = computed(() => store.getters['conversationLabels/getConversationLabels'](props.conversationId));
const choices = computed(() => labels.value.filter(label => !selected.value.includes(label.title) && label.title.toLocaleLowerCase().includes(search.value.toLocaleLowerCase())));
const colorFor = title => labels.value.find(label => label.title === title)?.color || '#008cce';

watch(() => props.conversationId, async id => {
  open.value = false;
  search.value = '';
  if (id) await Promise.all([store.dispatch('labels/get'), store.dispatch('conversationLabels/get', id)]);
}, { immediate: true });

const save = async (title, remove = false) => {
  if (busy.value) return;
  busy.value = true;
  const id = props.conversationId;
  const next = remove ? selected.value.filter(item => item !== title) : [...new Set([...selected.value, title])];
  try {
    await store.dispatch('conversationLabels/update', { conversationId: id, labels: next });
    if (store.getters['conversationLabels/getUIFlags'].isError) throw new Error('label_write_failed');
    open.value = false;
    search.value = '';
  } catch {
    useAlert('Não foi possível salvar a etiqueta. Tente novamente.');
  } finally { busy.value = false; }
};
</script>

<template>
  <div v-on-clickaway="() => (open = false)" class="cbn-header-labels" aria-label="Etiquetas da conversa">
    <span v-for="title in selected" :key="title" class="cbn-label-chip">
      <span class="cbn-label-dot" :style="{ backgroundColor: colorFor(title) }" />
      <span>{{ title }}</span>
      <button type="button" :disabled="busy" :aria-label="`Remover etiqueta ${title}`" @click="save(title, true)">×</button>
    </span>
    <div class="cbn-label-picker">
      <button type="button" class="cbn-add-label" :aria-expanded="open" :disabled="busy" @click="open = !open">+ Etiqueta</button>
      <div v-if="open" class="cbn-label-popover">
        <input v-model="search" type="search" placeholder="Buscar etiqueta..." aria-label="Buscar etiqueta" />
        <div class="cbn-label-options">
          <button v-for="label in choices" :key="label.id" type="button" :disabled="busy" @click="save(label.title)">
            <span class="cbn-label-dot" :style="{ backgroundColor: label.color }" />{{ label.title }}
          </button>
          <p v-if="!choices.length">Nenhuma etiqueta disponível.</p>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.cbn-header-labels { display:flex; flex-wrap:wrap; align-items:center; justify-content:flex-end; gap:5px; min-width:0; }
.cbn-label-chip { display:inline-flex; align-items:center; gap:5px; padding:3px 7px; border:1px solid #b6d8e8; border-radius:7px; background:#e8f5fc; color:#12364d; font-size:11px; line-height:18px; overflow-wrap:anywhere; }
.cbn-label-chip button { border:0; background:transparent; padding:0 1px; color:#486378; font-size:15px; line-height:16px; }
.cbn-label-dot { display:inline-block; flex-shrink:0; width:7px; height:7px; border-radius:3px; }
.cbn-label-picker { position:relative; }
.cbn-add-label { display:flex; align-items:center; padding:4px 8px; font-size:11px; line-height:18px; border:1px dashed #319aca; border-radius:7px; background:white; color:#006b9b; white-space:nowrap; }
.cbn-label-popover { position:absolute; right:0; top:calc(100% + 8px); width:230px; max-width:80vw; padding:8px; background:white; border:1px solid #b6d8e8; border-radius:9px; box-shadow:0 8px 24px #132d4626; z-index:1000; color:#12364d; }
.cbn-label-popover input { width:100%; margin:0 0 6px; padding:7px 9px; border:1px solid #b6d8e8; border-radius:6px; background:white; color:#12364d; font-size:12px; }
.cbn-label-options { max-height:220px; overflow-y:auto; }
.cbn-label-options button { display:flex; align-items:center; gap:8px; width:100%; padding:7px 8px; border-radius:5px; background:transparent; text-align:left; font-size:12px; color:#12364d; }
.cbn-label-options button:hover { background:#e8f5fc; }
.cbn-label-options p { padding:8px; font-size:12px; }
:global(.dark) .cbn-label-chip { background:#183449; color:#e9f5ff; border-color:#386078; }
:global(.dark) .cbn-add-label, :global(.dark) .cbn-label-popover, :global(.dark) .cbn-label-popover input { background:#182b3a; color:#e9f5ff; border-color:#386078; }
:global(.dark) .cbn-label-options button { color:#e9f5ff; }
:global(.dark) .cbn-label-options button:hover { background:#264358; }
</style>
