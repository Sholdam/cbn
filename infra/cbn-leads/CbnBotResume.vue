<script setup>
/* global axios */
import { ref } from 'vue';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  accountId: { type: [Number, String], required: true },
  inboxId: { type: [Number, String], required: true },
});
const busy = ref(false);
const resume = async () => {
  if (busy.value) return;
  busy.value = true;
  try {
    const { data } = await axios.post(`/api/v1/accounts/${props.accountId}/conversations/${props.conversationId}/bot_resume`, { request_id: crypto.randomUUID() });
    useAlert(data.message);
  } catch (error) {
    useAlert(error.response?.data?.error || 'Não foi possível retomar o bot. Confira a conversa antes de tentar novamente.');
  } finally { busy.value = false; }
};
</script>

<template>
  <button v-if="Number(accountId) === 1 && Number(inboxId) === 5" type="button" class="cbn-resume-bot" :disabled="busy" :aria-busy="busy" title="Retoma o atendimento e envia a pergunta da etapa pendente ao cliente" @click="resume">
    <span aria-hidden="true">↻</span> {{ busy ? 'Retomando…' : 'Retomar bot' }}
  </button>
</template>

<style scoped>
.cbn-resume-bot { display:inline-flex; align-items:center; justify-content:center; gap:5px; padding:5px 9px; white-space:nowrap; border:1px solid #8cbfde; border-radius:7px; background:#edf8ff; color:#085582; font-size:12px; font-weight:600; line-height:18px; }
.cbn-resume-bot:hover { background:#dcefff; }
.cbn-resume-bot:disabled { opacity:.6; cursor:wait; }
.cbn-resume-bot:focus-visible { outline:2px solid #008cce; outline-offset:2px; }
:global(.dark) .cbn-resume-bot { background:#183449; color:#d8efff; border-color:#386c8c; }
</style>
