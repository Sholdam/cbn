<script setup>
import { ref, computed, watch, onUnmounted } from 'vue';
import { useRoute } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  message: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
});
const emit = defineEmits(['scheduled']);
const route = useRoute();
const content = ref('');
const scheduledLocal = ref('');
const schedules = ref([]);
const loading = ref(false);
const error = ref('');
const notice = ref('');
const editingId = ref(null);
const requestId = ref(null);
const showing = ref(false);
const fileInput = ref(null);
const files = ref([]);
const existingAttachments = ref([]);
const removedAttachmentIds = ref([]);
const retainedAttachments = computed(() => existingAttachments.value.filter(file => !removedAttachmentIds.value.includes(file.id)));
const clearFiles = () => {
  files.value = [];
  existingAttachments.value = [];
  removedAttachmentIds.value = [];
  if (fileInput.value) fileInput.value.value = '';
};
const resetForm = () => {
  editingId.value = null;
  content.value = '';
  scheduledLocal.value = '';
  requestId.value = crypto.randomUUID();
  clearFiles();
};
const sizeLabel = bytes => bytes < 1024 * 1024 ? `${Math.ceil(bytes / 1024)} KB` : `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
const chooseFiles = event => {
  const selected = [...event.target.files];
  event.target.value = '';
  if (!selected.length) return;
  const next = [...files.value, ...selected];
  if (next.length + retainedAttachments.value.length > 10) { error.value = 'Adicione no máximo 10 anexos.'; return; }
  if (next.some(file => !file.size || file.size > 20 * 1024 * 1024)) { error.value = 'Cada anexo deve ter entre 1 byte e 20 MB.'; return; }
  if (next.reduce((sum, file) => sum + file.size, 0) + retainedAttachments.value.reduce((sum, file) => sum + file.byte_size, 0) > 50 * 1024 * 1024) { error.value = 'Os anexos juntos devem ter até 50 MB.'; return; }
  files.value = next;
  error.value = '';
};
let refreshTimer;
const endpoint = computed(() => `/site/cbn-api/accounts/${route.params.accountId}/conversations/${props.conversationId}/scheduled_messages`);
const statusLabel = { pending: 'Agendada', queued: 'Encaminhada para envio', delivered: 'Entregue', read: 'Lida', cancelled: 'Cancelada', failed: 'Falhou — reagende' };
const displayTime = value => new Intl.DateTimeFormat('pt-BR', { timeZone: 'America/Sao_Paulo', dateStyle: 'short', timeStyle: 'short' }).format(new Date(value));
const localTime = value => {
  const parts = new Intl.DateTimeFormat('sv-SE', {timeZone: 'America/Sao_Paulo', year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(new Date(value));
  const values = Object.fromEntries(parts.map(p => [p.type,p.value]));
  return `${values.year}-${values.month}-${values.day}T${values.hour}:${values.minute}`;
};
const load = async () => {
  const target = endpoint.value;
  try {
    const { data } = await window.axios.get(target);
    if (target === endpoint.value) schedules.value = data;
  } catch (e) {
    error.value = e.response?.data?.error || 'Não foi possível consultar os agendamentos.';
  }
};
const open = async () => {
  resetForm();
  showing.value = true;
  content.value = props.message;
  scheduledLocal.value = '';
  editingId.value = null;
  requestId.value = crypto.randomUUID();
  error.value = '';
  notice.value = '';
  await load();
  refreshTimer = setInterval(load, 15000);
};
const close = () => {
  showing.value = false;
  clearInterval(refreshTimer);
};
watch(() => props.conversationId, () => {
  schedules.value = [];
  content.value = '';
  editingId.value = null;
  clearFiles();
  if (showing.value) { close(); }
});
onUnmounted(close);
const save = async () => {
  if (loading.value) return;
  error.value = '';
  notice.value = '';
  if (!scheduledLocal.value || (!content.value.trim() && !files.value.length && !retainedAttachments.value.length)) {
    error.value = 'Escolha data e horário e escreva uma mensagem ou adicione um anexo.';
    return;
  }
  const target = endpoint.value;
  const savedContent = content.value;
  loading.value = true;
  try {
    const body = new FormData();
    body.set('content', savedContent);
    body.set('scheduled_local', scheduledLocal.value);
    body.set('request_id', requestId.value);
    for (const file of files.value) body.append('attachments[]', file, file.name);
    for (const id of removedAttachmentIds.value) body.append('remove_attachment_ids[]', String(id));
    if (editingId.value) await window.axios.patch(`${target}/${editingId.value}`, body);
    else await window.axios.post(target, body);
    if (target !== endpoint.value) return;
    if (!editingId.value) emit('scheduled', savedContent);
    editingId.value = null;
    content.value = '';
    scheduledLocal.value = '';
    clearFiles();
    requestId.value = crypto.randomUUID();
    notice.value = 'Mensagem agendada. Você pode alterar ou cancelar abaixo.';
    await load();
  } catch (e) {
    error.value = e.response?.data?.error || 'Não foi possível agendar. Seu texto foi mantido.';
  } finally { loading.value = false; }
};
const edit = row => {
  editingId.value = row.id;
  content.value = row.content;
  scheduledLocal.value = localTime(row.scheduled_at);
  error.value = '';
  notice.value = '';
  clearFiles();
  existingAttachments.value = row.attachments || [];
};
const cancel = async row => {
  if (loading.value) return;
  loading.value = true;
  error.value = '';
  try {
    await window.axios.delete(`${endpoint.value}/${row.id}`);
    if (editingId.value === row.id) resetForm();
    notice.value = 'Agendamento cancelado.';
    await load();
  } catch(e) {
    error.value = e.response?.data?.error || 'Não foi possível cancelar.';
  } finally { loading.value = false; }
};
</script>

<template>
  <Popover align="end" :close-on-scroll="false" @show="open" @hide="close">
    <template #default>
      <Button label="Agendar" icon="i-lucide-clock" size="sm" variant="faded" color="slate" :disabled="disabled" title="Agendar mensagem ou anexos e consultar agendamentos" />
    </template>
    <template #content>
      <section class="cbn-schedule-panel w-[min(28rem,calc(100vw-2rem))] max-h-[70vh] overflow-auto p-4 bg-n-solid-1 text-n-slate-12 rounded-xl border border-n-strong shadow-lg" @keydown.stop>
        <h3 class="font-semibold text-base mb-1">{{ editingId ? 'Alterar agendamento' : 'Agendar mensagem' }}</h3>
        <label class="block text-sm mb-1" for="cbn-schedule-content">Mensagem <span class="text-n-slate-11">(opcional com anexo)</span></label>
        <textarea id="cbn-schedule-content" v-model="content" :disabled="loading" rows="3" maxlength="10000" class="w-full p-2 rounded-lg border border-n-strong bg-n-background text-n-slate-12" placeholder="Escreva uma mensagem ou legenda, se desejar" />
        <div class="mt-3">
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm font-medium">Anexos</span>
            <Button label="Adicionar anexos" icon="i-lucide-paperclip" variant="faded" size="sm" :disabled="loading" @click="fileInput?.click()" />
          </div>
          <input ref="fileInput" type="file" multiple class="hidden" aria-label="Selecionar anexos para agendar" @change="chooseFiles" />
          <p class="text-xs text-n-slate-11 mt-1">Até 10 arquivos, 20 MB por arquivo e 50 MB no total.</p>
          <ul v-if="retainedAttachments.length || files.length" class="list-none p-0 my-2 space-y-1">
            <li v-for="file in retainedAttachments" :key="`saved-${file.id}`" class="flex items-center gap-2 p-2 rounded border border-n-strong text-sm">
              <span class="min-w-0 flex-1 break-all">📎 {{ file.filename }} <span class="text-xs text-n-slate-11">{{ sizeLabel(file.byte_size) }}</span></span>
              <Button icon="i-lucide-x" variant="ghost" size="xs" :disabled="loading" :title="`Remover ${file.filename}`" :aria-label="`Remover ${file.filename}`" @click="removedAttachmentIds.push(file.id)" />
            </li>
            <li v-for="(file, index) in files" :key="`new-${index}`" class="flex items-center gap-2 p-2 rounded border border-n-strong text-sm">
              <span class="min-w-0 flex-1 break-all">📎 {{ file.name }} <span class="text-xs text-n-slate-11">{{ sizeLabel(file.size) }}</span></span>
              <Button icon="i-lucide-x" variant="ghost" size="xs" :disabled="loading" :title="`Remover ${file.name}`" :aria-label="`Remover ${file.name}`" @click="files.splice(index, 1)" />
            </li>
          </ul>
        </div>
        <label class="block text-sm mt-3 mb-1" for="cbn-schedule-time">Data e horário</label>
        <input id="cbn-schedule-time" v-model="scheduledLocal" :disabled="loading" type="datetime-local" class="w-full p-2 rounded-lg border border-n-strong bg-n-background text-n-slate-12" />
        <p v-if="error" role="alert" class="text-sm text-n-ruby-11 mt-2">{{ error }}</p>
        <p v-if="notice" role="status" class="text-sm text-n-teal-11 mt-2">{{ notice }}</p>
        <div class="flex justify-end gap-2 mt-3">
          <Button v-if="editingId" label="Nova mensagem" variant="ghost" size="sm" :disabled="loading" @click="resetForm" />
          <Button :label="editingId ? 'Salvar alteração' : 'Agendar envio'" icon="i-lucide-clock" size="sm" :disabled="loading" :is-loading="loading" @click="save" />
        </div>
        <h4 class="font-semibold text-sm border-t border-n-strong pt-3 mt-4">Agendamentos desta conversa</h4>
        <p v-if="!schedules.length" class="text-sm text-n-slate-11 py-3">Nenhuma mensagem agendada.</p>
        <article v-for="row in schedules" :key="row.id" class="border border-n-strong rounded-lg p-3 mt-2">
          <div class="text-xs font-semibold">{{ displayTime(row.scheduled_at) }} · {{ statusLabel[row.status] || row.status }}</div>
          <div class="text-xs text-n-slate-11 mt-1">{{ row.agent_name }}</div>
          <p class="text-sm whitespace-pre-wrap break-words mt-2">{{ row.content }}</p>
          <ul v-if="row.attachments?.length" class="list-none p-0 mt-2 space-y-1">
            <li v-for="file in row.attachments" :key="file.id" class="text-xs break-all">📎 {{ file.filename }} · {{ sizeLabel(file.byte_size) }}</li>
          </ul>
          <p v-if="row.error" class="text-xs text-n-ruby-11 mt-2">{{ row.error }}</p>
          <div v-if="row.status === 'pending'" class="flex justify-end gap-2 mt-2">
            <Button label="Alterar" variant="ghost" size="xs" :disabled="loading" @click="edit(row)" />
            <Button label="Cancelar envio" variant="faded" color="ruby" size="xs" :disabled="loading" @click="cancel(row)" />
          </div>
        </article>
      </section>
    </template>
  </Popover>
</template>
