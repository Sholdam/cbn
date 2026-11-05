<script setup>
/* global axios */
import { computed, ref, onBeforeUnmount } from 'vue';
const props = defineProps({ attachment: { type: Object, required: true } });
const busy = ref(false);
const error = ref('');
const text = ref('');
let timer;
let alive = true;
let checks = 0;
const enabled = computed(() => Number(props.attachment.accountId) === 1 && props.attachment.id && !props.attachment.transcribedText);
const url = computed(() => `/api/v1/accounts/${props.attachment.accountId}/cbn_audio_transcriptions/${props.attachment.id}`);
function accept(data) {
  if (!alive) return;
  if (data.state === 'done') { text.value = data.text || ''; busy.value = false; return; }
  if (data.state === 'failed') { error.value = data.error || 'Não foi possível transcrever o áudio.'; busy.value = false; return; }
  if (++checks > 100) { error.value = 'A transcrição ainda está processando. Consulte novamente em instantes.'; busy.value = false; return; }
  timer = setTimeout(check, 3000);
}
async function check() {
  try { const { data } = await axios.get(url.value); accept(data); }
  catch { if (alive) { busy.value = false; error.value = 'Não foi possível consultar a transcrição. Tente novamente.'; } }
}
async function transcribe() {
  if (busy.value) return;
  busy.value = true; error.value = ''; checks = 0;
  try { const { data } = await axios.post(url.value); accept(data); }
  catch (failure) { if (alive) { busy.value = false; error.value = failure.response?.data?.error || 'Não foi possível iniciar a transcrição. Tente novamente.'; } }
}
onBeforeUnmount(() => { alive = false; clearTimeout(timer); });
</script>

<template>
  <div v-if="enabled" class="cbn-audio-transcription">
    <button v-if="!text" type="button" :disabled="busy" :aria-busy="busy" title="Transcreve este áudio com gpt-transcribe usando a chave OpenAI conectada" @click="transcribe">
      {{ busy ? 'Transcrevendo…' : 'Transcrever áudio' }}
    </button>
    <p v-if="error" role="alert">{{ error }}</p>
    <div v-if="text" class="cbn-audio-transcript" aria-label="Transcrição do áudio">{{ text }}</div>
  </div>
</template>

<style scoped>
.cbn-audio-transcription{width:100%;font-size:12px;text-align:left}
.cbn-audio-transcription button{border:1px solid currentColor;border-radius:6px;background:transparent;color:inherit;padding:5px 9px;font-size:12px;cursor:pointer}
.cbn-audio-transcription button:disabled{opacity:.65;cursor:wait}
.cbn-audio-transcription button:focus-visible{outline:2px solid currentColor;outline-offset:2px}
.cbn-audio-transcription p{margin:8px 0 0;font-size:12px}
.cbn-audio-transcript{padding:10px;border-radius:8px;background:rgba(127,127,127,.12);white-space:pre-wrap;overflow-wrap:anywhere;font-size:14px;line-height:1.5;user-select:text}
</style>
