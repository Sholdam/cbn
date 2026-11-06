import { computed, nextTick, onMounted, onBeforeUnmount, ref, watch } from 'vue';

// Recover the media element, never reload the conversation or resend a message.
export function useCbnAudioPlayback(audio, source, announcePlay) {
  const isPlaying = ref(false);
  const isLoading = ref(false);
  const error = ref('');
  const currentTime = ref(0);
  const duration = ref(0);
  const playbackSpeed = ref(1);
  const isMuted = ref(false);
  const revision = ref(0);
  let retries = 0;
  let timer;
  let generation = 0;
  let wanted = false;
  let disposed = false;
  let resumeAt = 0;
  let durationProbe;
  let durationProbeTimer;
  let durationProbeAttempted = false;
  let retryPending = false;
  const retryDelays = [1000, 3000, 8000];
  const mediaURL = computed(() => {
    const value = source();
    if (!value) return '';
    const url = new URL(value, window.location.origin);
    if (revision.value) url.searchParams.set('t', String(revision.value));
    return url.toString();
  });
  const clearTimer = () => { clearTimeout(timer); timer = undefined; retryPending = false; };
  const clearProbe = () => {
    clearTimeout(durationProbeTimer);
    if (durationProbe) audio.value?.removeEventListener('timeupdate', durationProbe);
    durationProbe = undefined;
  };
  const waitForMedia = () => {
    clearTimer();
    timer = setTimeout(() => recover(), 10000);
  };
  const stop = () => {
    wanted = false;
    generation += 1;
    isPlaying.value = false;
    isLoading.value = false;
    clearTimer();
    audio.value?.pause();
  };
  const start = async () => {
    const el = audio.value;
    if (!el || !wanted || disposed) return;
    const token = ++generation;
    isLoading.value = true;
    waitForMedia();
    try {
      await el.play();
      if (disposed || token !== generation || !wanted) return;
      isPlaying.value = !el.paused;
      isLoading.value = false;
      error.value = '';
      clearTimer();
    } catch (failure) {
      if (disposed || token !== generation || !wanted) return;
      isPlaying.value = false;
      if (failure?.name === 'NotAllowedError') {
        stop();
        error.value = 'Clique em reproduzir para ouvir o áudio.';
      } else {
        recover();
      }
    }
  };
  const reloadMedia = async () => {
    if (disposed || !source()) return;
    generation += 1;
    clearTimer();
    clearProbe();
    durationProbeAttempted = false;
    isPlaying.value = false;
    isLoading.value = true;
    revision.value = Math.max(Date.now(), revision.value + 1);
    await nextTick();
    if (disposed) return;
    audio.value?.load();
    if (audio.value) {
      audio.value.playbackRate = playbackSpeed.value;
      audio.value.muted = isMuted.value;
    }
    waitForMedia();
    if (wanted) void start();
  };
  function recover() {
    if (disposed || retryPending || !source()) return;
    clearTimer();
    generation += 1;
    clearProbe();
    const position = audio.value?.currentTime;
    resumeAt = Number.isFinite(position) && position > 0 ? position : resumeAt || currentTime.value;
    isPlaying.value = false;
    audio.value?.pause();
    if (retries >= retryDelays.length) {
      wanted = false;
      isLoading.value = false;
      error.value = 'Não foi possível carregar o áudio.';
      return;
    }
    isLoading.value = true;
    const delay = retryDelays[retries++];
    timer = setTimeout(() => { timer = undefined; retryPending = false; void reloadMedia(); }, delay);
    retryPending = true;
  }
  const onError = () => {
    if (retryPending) return;
    recover();
  };
  const onMetadata = () => {
    const el = audio.value;
    if (!el) return;
    if (Number.isFinite(el.duration) && el.duration > 0) {
      duration.value = el.duration;
      clearProbe();
      // preload=metadata may deliberately stop before canplay for a paused file.
      if (!wanted) { clearTimer(); isLoading.value = false; }
      if (resumeAt > 0 && resumeAt < el.duration) {
        el.currentTime = resumeAt;
        currentTime.value = resumeAt;
      }
      resumeAt = 0;
    } else if (el.duration === Infinity && !durationProbeAttempted) {
      durationProbeAttempted = true;
      // Recorder WebM may omit duration. Probe once, and always remove the listener.
      const position = Number.isFinite(el.currentTime) ? el.currentTime : 0;
      durationProbe = () => {
        if (!Number.isFinite(el.duration)) return;
        duration.value = el.duration;
        clearProbe();
        el.currentTime = position;
      };
      el.addEventListener('timeupdate', durationProbe);
      durationProbeTimer = setTimeout(clearProbe, 3000);
      try { el.currentTime = Number.MAX_SAFE_INTEGER; } catch { clearProbe(); }
    }
  };
  const onCanPlay = () => {
    clearTimer();
    retryPending = false;
    isLoading.value = false;
    error.value = '';
    onMetadata();
  };
  const onPlaying = () => {
    if (!wanted) { audio.value?.pause(); return; }
    isPlaying.value = true;
    isLoading.value = false;
    error.value = '';
    clearTimer();
  };
  const onPause = () => { isPlaying.value = false; };
  const onWaiting = () => {
    if (!wanted || retryPending) return;
    isLoading.value = true;
    waitForMedia();
  };
  const onTimeUpdate = () => {
    if (durationProbe) return;
    const t = audio.value?.currentTime;
    if (Number.isFinite(t)) currentTime.value = t;
    if (wanted && !audio.value?.paused && t > 0) onPlaying();
    onMetadata();
  };
  const onEnd = () => {
    stop();
    currentTime.value = 0;
    playbackSpeed.value = 1;
    if (audio.value) audio.value.playbackRate = 1;
  };
  const toggle = async () => {
    if (wanted) { stop(); return; }
    announcePlay();
    wanted = true;
    error.value = '';
    retries = 0;
    if (audio.value?.error || !audio.value?.currentSrc || retryPending) {
      retryPending = false;
      await reloadMedia();
    } else await start();
  };
  const retry = async () => {
    stop();
    retryPending = false;
    retries = 0;
    wanted = true;
    announcePlay();
    error.value = '';
    await reloadMedia();
  };
  const seek = event => {
    if (!duration.value || !audio.value) return;
    const value = Math.max(0, Math.min(duration.value, Number(event.target.value)));
    if (!Number.isFinite(value)) return;
    audio.value.currentTime = value;
    currentTime.value = value;
  };
  const toggleMute = () => {
    isMuted.value = !isMuted.value;
    if (audio.value) audio.value.muted = isMuted.value;
  };
  const changePlaybackSpeed = () => {
    const speeds = [1, 1.5, 2];
    playbackSpeed.value = speeds[(speeds.indexOf(playbackSpeed.value) + 1) % speeds.length];
    if (audio.value) audio.value.playbackRate = playbackSpeed.value;
  };
  const resetSource = async () => {
    stop();
    retryPending = false;
    clearProbe();
    retries = 0;
    resumeAt = 0;
    currentTime.value = 0;
    duration.value = 0;
    error.value = '';
    revision.value = 0;
    if (source()) await reloadMedia();
  };
  watch(source, resetSource, { flush: 'post' });
  onMounted(() => {
    if (!audio.value) return;
    audio.value.playbackRate = playbackSpeed.value;
    onMetadata();
    if (audio.value.readyState >= 3) onCanPlay();
    else if (!duration.value && source()) { isLoading.value = true; waitForMedia(); }
  });
  onBeforeUnmount(() => { disposed = true; stop(); clearProbe(); });
  return { mediaURL, isPlaying, isLoading, error, currentTime, duration, playbackSpeed, isMuted,
    stop, toggle, retry, seek, toggleMute, changePlaybackSpeed,
    onMetadata, onCanPlay, onPlaying, onPause, onWaiting, onTimeUpdate, onEnd, onError };
}
