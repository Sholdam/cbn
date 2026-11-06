<script setup>
import { computed, useTemplateRef, ref, getCurrentInstance } from 'vue';
import Icon from 'next/icon/Icon.vue';
import CbnAudioTranscription from 'next/cbn-ai/CbnAudioTranscription.vue';
import { useCbnAudioPlayback } from 'next/cbn-audio/useCbnAudioPlayback';
import { downloadFile } from '@chatwoot/utils';
import { useEmitter } from 'dashboard/composables/emitter';
import { emitter } from 'shared/helpers/mitt';

const { attachment } = defineProps({
  attachment: { type: Object, required: true },
  showTranscribedText: { type: Boolean, default: true },
});
defineOptions({ inheritAttrs: false });
const TRANSCRIPT_PREVIEW_LENGTH = 200;
const isTranscriptExpanded = ref(false);
const isTranscriptLong = computed(() => (attachment.transcribedText?.length || 0) > TRANSCRIPT_PREVIEW_LENGTH);
const displayedTranscript = computed(() => {
  const text = attachment.transcribedText || '';
  if (!isTranscriptLong.value || isTranscriptExpanded.value) return text;
  return text.slice(0, TRANSCRIPT_PREVIEW_LENGTH).trimEnd() + '…';
});
const audioPlayer = useTemplateRef('audioPlayer');
const { uid } = getCurrentInstance();
const { mediaURL, isPlaying, isLoading, error, currentTime, duration, playbackSpeed, isMuted,
  stop, toggle: playOrPause, retry, seek, toggleMute, changePlaybackSpeed,
  onMetadata, onCanPlay, onPlaying, onPause, onWaiting, onTimeUpdate, onEnd, onError,
} = useCbnAudioPlayback(audioPlayer, () => attachment.dataUrl,
  () => emitter.emit('pause_playing_audio', uid));
useEmitter('pause_playing_audio', currentPlayingId => { if (currentPlayingId !== uid) stop(); });
const playbackSpeedLabel = computed(() => playbackSpeed.value + 'x');
const formatTime = time => {
  if (!Number.isFinite(time) || time < 0) return '00:00';
  return Math.floor(time / 60).toString().padStart(2, '0') + ':' + Math.floor(time % 60).toString().padStart(2, '0');
};
const downloadAudio = () => {
  const { fileType, dataUrl, extension } = attachment;
  downloadFile({ url: dataUrl, type: fileType, extension });
};
</script>

<template>
  <audio
    ref="audioPlayer"
    :src="mediaURL"
    preload="metadata"
    class="hidden"
    playsinline
    @loadedmetadata="onMetadata"
    @durationchange="onMetadata"
    @canplay="onCanPlay"
    @playing="onPlaying"
    @pause="onPause"
    @waiting="onWaiting"
    @stalled="onWaiting"
    @error="onError"
    @timeupdate="onTimeUpdate"
    @ended="onEnd"
  />
  <div
    v-bind="$attrs"
    class="rounded-xl w-full gap-2 p-1.5 bg-n-alpha-white flex flex-col items-center border border-n-container shadow-[0px_2px_8px_0px_rgba(94,94,94,0.06)]"
  >
    <div class="flex gap-1 w-full flex-1 items-center justify-start">
      <button
        class="p-0 border-0 size-8"
        :aria-label="isPlaying ? 'Pausar áudio' : 'Reproduzir áudio'"
        :aria-busy="isLoading"
        @click="playOrPause"
      >
        <Icon
          v-if="isLoading"
          class="size-4 animate-spin m-auto"
          icon="i-lucide-loader-circle"
        />
        <Icon
          v-else-if="isPlaying"
          class="size-8"
          icon="i-teenyicons-pause-small-solid"
        />
        <Icon v-else class="size-8" icon="i-teenyicons-play-small-solid" />
      </button>
      <div class="tabular-nums text-xs">
        {{ formatTime(currentTime) }} / {{ formatTime(duration) }}
      </div>
      <div class="flex-1 items-center flex px-2">
        <input
          type="range"
          min="0"
          :max="duration"
          :disabled="!duration"
          aria-label="Posição do áudio"
          :value="currentTime"
          class="w-full h-1 bg-n-slate-12/40 rounded-lg appearance-none cursor-pointer accent-current"
          @input="seek"
        />
      </div>
      <button
        class="border-0 w-10 h-6 grid place-content-center bg-n-alpha-2 hover:bg-alpha-3 rounded-2xl"
        @click="changePlaybackSpeed"
      >
        <span class="text-xs text-n-slate-11 font-medium">
          {{ playbackSpeedLabel }}
        </span>
      </button>
      <button
        class="p-0 border-0 size-8 grid place-content-center"
        @click="toggleMute"
      >
        <Icon v-if="isMuted" class="size-4" icon="i-lucide-volume-off" />
        <Icon v-else class="size-4" icon="i-lucide-volume-2" />
      </button>
      <button
        class="p-0 border-0 size-8 grid place-content-center"
        @click="downloadAudio"
      >
        <Icon class="size-4" icon="i-lucide-download" />
      </button>
    </div>

    <div v-if="error" class="text-xs text-n-slate-11 flex items-center gap-2" role="alert">
      <span>{{ error }}</span>
      <button class="underline font-medium" @click="retry">Tentar novamente</button>
    </div>

    <CbnAudioTranscription :attachment="attachment" />

    <div
      v-if="attachment.transcribedText && showTranscribedText"
      class="text-n-slate-12 p-3 text-sm bg-n-alpha-1 rounded-lg w-full break-words"
    >
      {{ displayedTranscript }}
      <button
        v-if="isTranscriptLong"
        class="block mt-1 p-0 border-0 bg-transparent text-n-slate-11 hover:text-n-slate-12 font-medium"
        @click="isTranscriptExpanded = !isTranscriptExpanded"
      >
        {{
          isTranscriptExpanded
            ? $t('CONVERSATION.VOICE_CALL.TRANSCRIPT_SHOW_LESS')
            : $t('CONVERSATION.VOICE_CALL.TRANSCRIPT_SHOW_MORE')
        }}
      </button>
    </div>
  </div>
</template>
