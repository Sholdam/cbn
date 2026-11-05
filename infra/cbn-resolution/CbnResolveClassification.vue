<script setup>
/* global axios */
import { ref, onBeforeUnmount } from 'vue';
import { useStore } from 'dashboard/composables/store';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const store = useStore();
const dialogRef = ref(null);
const options = ref([]);
const previous = ref('');
const loading = ref(false);
const busy = ref(false);
const errorMessage = ref('');
let context = null;
let settle = null;
let generation = 0;

const finish = result => {
  const done = settle;
  settle = null;
  done?.(result);
};
const cancel = () => {
  // A request already submitted may still finish; never suggest it was undone.
  if (busy.value) return;
  generation += 1;
  context = null;
  finish(false);
};
const load = async token => {
  loading.value = true;
  options.value = [];
  try {
    const { data } = await axios.get(context.url);
    if (generation !== token) return;
    if (!Array.isArray(data.options) || !data.options.length) {
      throw new Error('Não há situações disponíveis. Confira o cadastro do campo.');
    }
    options.value = data.options;
    previous.value = data.classification || '';
    context.lastMessageId = data.last_message_id;
  } catch (error) {
    if (generation === token) errorMessage.value = error.response?.data?.error || error.message || 'Não foi possível carregar as situações.';
  } finally {
    if (generation === token) loading.value = false;
  }
};
const open = async ({ accountId, conversationId }) => {
  if (busy.value || settle) return false;
  const token = ++generation;
  context = {
    conversationId,
    url: `/api/v1/accounts/${accountId}/conversations/${conversationId}/resolution_classification`,
  };
  errorMessage.value = '';
  previous.value = '';
  const result = new Promise(resolve => { settle = resolve; });
  dialogRef.value.open();
  await load(token);
  return result;
};
const choose = async choice => {
  if (busy.value || loading.value || !context || !options.value.includes(choice)) return;
  busy.value = true;
  errorMessage.value = '';
  const selected = context;
  const token = generation;
  try {
    await axios.post(selected.url, { classification: choice, last_message_id: selected.lastMessageId });
    // Fetch the native payload to update contact, status and conversation lists.
    await store.dispatch('getConversation', selected.conversationId);
    if (generation !== token) return;
    finish(true);
    busy.value = false;
    dialogRef.value?.close();
  } catch (error) {
    errorMessage.value = error.response?.data?.error || error.response?.data?.message || 'Não foi possível confirmar a resolução. Confira a conversa antes de tentar novamente.';
    if (error.response?.status === 409) await load(token);
    busy.value = false;
  }
};
onBeforeUnmount(() => { generation += 1; finish(false); });
defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="sm"
    title="Resolver atendimento"
    description="Escolha a situação do atendimento para resolver."
    :show-confirm-button="false"
    :show-cancel-button="!busy"
    cancel-button-label="Cancelar"
    @close="cancel"
  >
    <p v-if="loading" class="m-0 text-sm text-n-slate-11" role="status">Carregando situações…</p>
    <div v-else class="cbn-resolution-options" :aria-busy="busy">
      <button
        v-for="option in options"
        :key="option"
        type="button"
        class="cbn-resolution-option"
        :class="{ 'is-current': option === previous }"
        :disabled="busy"
        @click="choose(option)"
      >
        {{ option }}
        <span v-if="option === previous" class="cbn-resolution-current">Atual</span>
      </button>
    </div>
    <p v-if="busy" class="m-0 text-sm text-n-slate-11" role="status">Salvando e resolvendo…</p>
    <p v-if="errorMessage" class="m-0 text-sm text-n-ruby-11" role="alert">{{ errorMessage }}</p>
  </Dialog>
</template>

<style scoped>
.cbn-resolution-options{display:grid;gap:8px}
.cbn-resolution-option{display:flex;align-items:center;justify-content:space-between;gap:12px;width:100%;padding:12px 14px;border:1px solid #b9cbd6;border-radius:8px;background:#fff;color:#11344a;text-align:left;font-size:14px;line-height:20px;font-weight:500;cursor:pointer}
.cbn-resolution-option:hover,.cbn-resolution-option.is-current{background:#eaf7ff;border-color:#1689c3}
.cbn-resolution-option:focus-visible{outline:2px solid #008cce;outline-offset:2px}
.cbn-resolution-option:disabled{opacity:.65;cursor:wait}
.cbn-resolution-current{font-size:11px;color:#48677a}
:global(.dark) .cbn-resolution-option{background:#142b3f;color:#e5f2fb;border-color:#47647a}
:global(.dark) .cbn-resolution-option:hover,:global(.dark) .cbn-resolution-option.is-current{background:#204962;border-color:#64bbeb}
:global(.dark) .cbn-resolution-current{color:#aacade}
</style>
