import { mount, flushPromises } from '@vue/test-utils';
import { ref, defineComponent } from 'vue';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import CbnResolveClassification from './CbnResolveClassification.vue';

const dispatch = vi.hoisted(() => vi.fn());
vi.mock('dashboard/composables/store', () => ({ useStore: () => ({ dispatch }) }));
const DialogStub = defineComponent({
  emits: ['close'],
  setup(_, { expose, slots, emit }) {
    const visible = ref(false);
    expose({ open: () => { visible.value = true; }, close: () => { visible.value = false; emit('close'); } });
    return () => visible.value ? slots.default?.() : null;
  },
});
const context = { options: ['Em negociação', 'Venda fechada', 'Sem interesse'], classification: '', last_message_id: 100 };
const create = () => mount(CbnResolveClassification, { global: { stubs: { Dialog: DialogStub } } });
beforeEach(() => {
  dispatch.mockReset();dispatch.mockResolvedValue();
  global.axios = { get: vi.fn().mockResolvedValue({ data: context }), post: vi.fn().mockResolvedValue({ data: { current_status: 'resolved' } }) };
});
describe('classify and resolve', () => {
  it('opens without saving; choosing an option posts once and refreshes native state', async () => {
    const w = create();const result = w.vm.open({ accountId: 1, conversationId: 123 });
    await flushPromises();expect(axios.post).not.toHaveBeenCalled();
    await w.findAll('button')[1].trigger('click');await flushPromises();
    expect(axios.post).toHaveBeenCalledExactlyOnceWith('/api/v1/accounts/1/conversations/123/resolution_classification', { classification: 'Venda fechada', last_message_id: 100 });
    expect(dispatch).toHaveBeenCalledWith('getConversation',123);expect(await result).toBe(true);w.unmount();
  });
  it('rejects duplicate clicks while a choice is being saved', async () => {
    let complete;axios.post.mockImplementation(() => new Promise(resolve => { complete = resolve; }));
    const w=create();const result=w.vm.open({accountId:1,conversationId:123});await flushPromises();
    await w.findAll('button')[0].trigger('click');await w.findAll('button')[1].trigger('click');expect(axios.post).toHaveBeenCalledTimes(1);
    complete({data:{current_status:'resolved'}});await flushPromises();expect(await result).toBe(true);w.unmount();
  });
  it('does not save a classification when the dialog is closed', async () => {
    const w=create();const result=w.vm.open({accountId:1,conversationId:123});await flushPromises();
    w.findComponent(DialogStub).vm.$emit('close');expect(await result).toBe(false);expect(axios.post).not.toHaveBeenCalled();w.unmount();
  });
  it('keeps a failed resolution open and fetches fresh context after a new message', async () => {
    axios.post.mockRejectedValue({response:{status:409,data:{error:'Chegou uma nova mensagem.'}}});
    const w=create();const result=w.vm.open({accountId:1,conversationId:123});await flushPromises();
    await w.findAll('button')[0].trigger('click');await flushPromises();
    expect(w.get('[role="alert"]').text()).toContain('nova mensagem');expect(axios.get).toHaveBeenCalledTimes(2);expect(dispatch).not.toHaveBeenCalled();
    w.unmount();expect(await result).toBe(false);
  });
  it('shows no choices on a configuration error and never resolves', async () => {
    axios.get.mockResolvedValue({data:{options:[]}});
    const w=create();const result=w.vm.open({accountId:1,conversationId:123});await flushPromises();
    expect(w.findAll('button')).toHaveLength(0);expect(w.get('[role="alert"]').text()).toContain('Não há situações');expect(axios.post).not.toHaveBeenCalled();
    w.unmount();expect(await result).toBe(false);
  });
});
