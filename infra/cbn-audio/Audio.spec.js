import { mount, flushPromises } from '@vue/test-utils';
import { defineComponent, ref, nextTick } from 'vue';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { useCbnAudioPlayback } from './useCbnAudioPlayback';
import AudioChip from '../message/chips/Audio.vue';

vi.mock('dashboard/composables/emitter', () => ({ useEmitter: vi.fn() }));
vi.mock('shared/helpers/mitt', () => ({ emitter: { emit: vi.fn() } }));
vi.mock('@chatwoot/utils', () => ({ downloadFile: vi.fn() }));

let wrappers;
beforeEach(() => { vi.useFakeTimers(); wrappers = []; });
afterEach(() => { wrappers.forEach(w => w.unmount()); vi.restoreAllMocks(); vi.useRealTimers(); });
function fixture() {
  let state;
  const announce = vi.fn();
  const Harness = defineComponent({
    props: ['src'],
    setup(props) {
      const media = ref();
      state = useCbnAudioPlayback(media, () => props.src, announce);
      return { media, ...state };
    },
    template: `<audio ref="media" :src="mediaURL" @loadedmetadata="onMetadata" @durationchange="onMetadata" @canplay="onCanPlay" @playing="onPlaying" @pause="onPause" @waiting="onWaiting" @stalled="onWaiting" @error="onError" @timeupdate="onTimeUpdate" @ended="onEnd" />`,
  });
  vi.spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(() => {});
  vi.spyOn(HTMLMediaElement.prototype, 'load').mockImplementation(() => {});
  vi.spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue();
  const w = mount(Harness, { props: { src: '/synthetic/audio.ogg' } });
  wrappers.push(w);
  const el = w.get('audio').element;
  Object.defineProperties(el, {
    duration: { value: NaN, configurable: true, writable: true },
    currentSrc: { value: '/synthetic/audio.ogg', configurable: true, writable: true },
    paused: { value: true, configurable: true, writable: true },
    error: { value: null, configurable: true, writable: true },
  });
  el.play.mockImplementation(async () => { el.paused = false; });
  el.pause.mockImplementation(() => { el.paused = true; });
  return { w, el, state, announce };
}

describe('audio media recovery', () => {
  it('preloads metadata without playing or announcing on mount', async () => {
    const { el, state, announce } = fixture();
    await flushPromises();
    expect(el.play).not.toHaveBeenCalled();
    expect(announce).not.toHaveBeenCalled();
    expect(state.isPlaying.value).toBe(false);
  });
  it('does not show playing until play succeeds', async () => {
    const { el, state } = fixture();
    let resolve;
    el.play.mockImplementation(() => new Promise(r => { resolve = r; }));
    const pending = state.toggle();
    expect(state.isPlaying.value).toBe(false);
    expect(state.isLoading.value).toBe(true);
    el.paused = false; resolve(); await pending;
    expect(state.isPlaying.value).toBe(true);
  });
  it('recovers a rejected play with a new media request, without page reload', async () => {
    const { el, state } = fixture();
    el.play.mockRejectedValueOnce(new DOMException('Temporary media failure', 'NotSupportedError'));
    await state.toggle();
    expect(state.isPlaying.value).toBe(false);
    await vi.advanceTimersByTimeAsync(1000); await flushPromises();
    expect(el.load).toHaveBeenCalledTimes(1);
    expect(el.getAttribute('src')).toContain('t=');
    expect(el.play).toHaveBeenCalledTimes(2);
    expect(state.isPlaying.value).toBe(true);
  });
  it('reloads when the attachment arrives or changes, but never auto plays it', async () => {
    const { w, el, state } = fixture();
    await w.setProps({ src: '' });
    await w.setProps({ src: '/synthetic/ready.ogg' }); await flushPromises();
    expect(el.getAttribute('src')).toContain('/synthetic/ready.ogg');
    expect(el.load).toHaveBeenCalledTimes(1);
    expect(el.play).not.toHaveBeenCalled();
    expect(state.duration.value).toBe(0);
    await w.setProps({ src: '/synthetic/ready.ogg' });
    expect(el.load).toHaveBeenCalledTimes(1);
  });
  it('cancels old playback when a different source replaces it', async () => {
    const { w, el, state } = fixture();
    await state.toggle();
    await w.setProps({ src: '/synthetic/different.ogg' }); await flushPromises();
    expect(state.isPlaying.value).toBe(false);
    expect(el.play).toHaveBeenCalledTimes(1);
  });
  it('retries source errors at most three times and allows an explicit retry', async () => {
    const { w, el, state } = fixture();
    for (const delay of [1000, 3000, 8000]) {
      await w.get('audio').trigger('error');
      await w.get('audio').trigger('error');
      await vi.advanceTimersByTimeAsync(delay); await flushPromises();
    }
    expect(el.load).toHaveBeenCalledTimes(3);
    await w.get('audio').trigger('error');
    await vi.advanceTimersByTimeAsync(60000);
    expect(el.load).toHaveBeenCalledTimes(3);
    expect(state.error.value).toContain('Não foi possível');
    expect(el.play).not.toHaveBeenCalled();
    await state.retry(); await flushPromises();
    expect(el.load).toHaveBeenCalledTimes(4);
    expect(el.play).toHaveBeenCalledTimes(1);
  });
  it('recovers a silent metadata timeout', async () => {
    const { el } = fixture();
    await vi.advanceTimersByTimeAsync(11000); await flushPromises();
    expect(el.load).toHaveBeenCalledTimes(1);
    expect(el.play).not.toHaveBeenCalled();
  });
  it('does not retry healthy paused media when preload stops after metadata', async () => {
    const { w, el, state } = fixture();
    el.duration = 120;
    await w.get('audio').trigger('loadedmetadata');
    await vi.advanceTimersByTimeAsync(60000);
    expect(state.duration.value).toBe(120);
    expect(state.isLoading.value).toBe(false);
    expect(el.load).not.toHaveBeenCalled();
    expect(el.play).not.toHaveBeenCalled();
  });
  it('handles browser playback restrictions without repeated requests', async () => {
    const { el, state } = fixture();
    el.play.mockRejectedValue(new DOMException('Gesture required', 'NotAllowedError'));
    await state.toggle(); await vi.advanceTimersByTimeAsync(60000);
    expect(el.play).toHaveBeenCalledTimes(1);
    expect(el.load).not.toHaveBeenCalled();
    expect(state.error.value).toContain('Clique em reproduzir');
    expect(state.isLoading.value).toBe(false);
  });
  it('stops pending playback and retry when another audio is selected or user pauses', async () => {
    const { el, state } = fixture();
    el.play.mockRejectedValueOnce(new Error('Unavailable'));
    await state.toggle(); state.stop();
    await vi.advanceTimersByTimeAsync(60000);
    expect(el.load).not.toHaveBeenCalled();
    expect(state.isPlaying.value).toBe(false);
  });
  it('updates late duration, seeking, speed and mute', async () => {
    const { w, el, state } = fixture();
    el.duration = 38;
    await w.get('audio').trigger('durationchange');
    expect(state.duration.value).toBe(38);
    state.seek({ target: { value: '15' } });
    expect(el.currentTime).toBe(15);
    state.changePlaybackSpeed(); expect(el.playbackRate).toBe(1.5);
    state.toggleMute(); expect(el.muted).toBe(true);
  });
  it('recovers stalled playback at its previous position and chosen speed', async () => {
    const { w, el, state } = fixture();
    el.duration = 38; await w.get('audio').trigger('loadedmetadata');
    await state.toggle(); el.currentTime = 7; state.changePlaybackSpeed();
    await w.get('audio').trigger('waiting');
    await vi.advanceTimersByTimeAsync(11000); await flushPromises();
    expect(el.load).toHaveBeenCalledTimes(1);
    el.currentTime = 0; await w.get('audio').trigger('loadedmetadata');
    expect(el.currentTime).toBe(7);
    expect(el.playbackRate).toBe(1.5);
  });
  it('resolves WebM duration once and removes listeners on unmount', async () => {
    const { w, el, state } = fixture();
    const remove = vi.spyOn(el, 'removeEventListener');
    el.duration = Infinity; await w.get('audio').trigger('loadedmetadata');
    expect(state.duration.value).toBe(0);
    el.duration = 4; await w.get('audio').trigger('timeupdate');
    expect(state.duration.value).toBe(4);
    expect(el.currentTime).toBe(0);
    w.unmount(); wrappers = [];
    expect(remove).toHaveBeenCalledWith('timeupdate', expect.any(Function));
    await vi.advanceTimersByTimeAsync(60000);
    expect(el.load).not.toHaveBeenCalled();
  });
  it('discards stale play promises after switching to another recording', async () => {
    const { el, state } = fixture();
    let resolve;
    el.play.mockImplementation(() => new Promise(r => { resolve = r; }));
    const pending = state.toggle(); state.stop(); resolve(); await pending;
    expect(state.isPlaying.value).toBe(false);
    expect(state.isLoading.value).toBe(false);
  });
  it('cleans pending retry and pauses on unmount', async () => {
    const { w, el } = fixture();
    await w.get('audio').trigger('error');
    w.unmount(); wrappers = [];
    await vi.advanceTimersByTimeAsync(60000);
    expect(el.load).not.toHaveBeenCalled();
    expect(el.pause).toHaveBeenCalled();
  });
  it('wires recovery events and preserves manual transcription in the real chip', async () => {
    vi.spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(() => {});
    vi.spyOn(HTMLMediaElement.prototype, 'load').mockImplementation(() => {});
    vi.spyOn(HTMLMediaElement.prototype, 'play').mockRejectedValue(new Error('Temporary'));
    const w = mount(AudioChip, {
      props: { attachment: { id: 1, accountId: 1, dataUrl: '/synthetic/chip.ogg' } },
      global: { stubs: { Icon: true, CbnAudioTranscription: { template: '<button>Transcrever áudio</button>' } } },
    });
    wrappers.push(w);
    expect(w.find('source').exists()).toBe(false);
    expect(w.get('audio').attributes('preload')).toBe('metadata');
    expect(w.text()).toContain('Transcrever áudio');
    await w.get('audio').trigger('error');
    await vi.advanceTimersByTimeAsync(1000); await nextTick();
    expect(HTMLMediaElement.prototype.load).toHaveBeenCalledTimes(1);
    Object.defineProperty(w.get('audio').element, 'duration', { value: 14, configurable: true });
    await w.get('audio').trigger('durationchange');
    await w.get('audio').trigger('canplay');
    expect(w.text()).toContain('00:00 / 00:14');
    expect(w.get('input').attributes('disabled')).toBeUndefined();
  });
});
