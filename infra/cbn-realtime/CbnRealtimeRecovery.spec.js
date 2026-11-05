import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import Recovery from '../CbnRealtimeRecovery';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
const native = vi.hoisted(() => ({ disconnect: vi.fn(), setConversationLastMessageId: vi.fn(), getSecondsSinceDisconnect: vi.fn(() => 20), revalidateCaches: vi.fn(() => Promise.resolve()) }));
vi.mock('../ReconnectService', () => ({ default: class { constructor() { Object.assign(this, native); } } }));
vi.mock('shared/helpers/mitt', () => ({ emitter: { on: vi.fn(), off: vi.fn(), emit: vi.fn() } }));
vi.mock('dashboard/helper/routeHelpers', () => ({ isAConversationRoute: name => name === 'conversation', isAInboxViewRoute: () => false, isNotificationRoute: () => false }));
const settle = async () => { for (let i = 0; i < 15; i += 1) await Promise.resolve(); };
describe('CBN realtime recovery', () => {
  let recovery, store, connector;
  beforeEach(() => {
    vi.useFakeTimers(); vi.clearAllMocks();
    Object.defineProperty(document, 'hidden', { configurable: true, value: false });
    Object.defineProperty(navigator, 'onLine', { configurable: true, value: true });
    store = { getters: { getCurrentAccountId: 1, getAppliedConversationFiltersQuery: [] }, dispatch: vi.fn(() => Promise.resolve(true)) };
    connector = { consumer: { connection: { isOpen: vi.fn(() => true) }, connect: vi.fn() } };
    recovery = new Recovery(store, { currentRoute: { value: { name: 'conversation', params: { conversation_id: 1 } } } }, connector);
  });
  afterEach(() => { recovery.disconnect(); vi.useRealTimers(); });
  it('updates messages independently when the conversation list fails', async () => {
    store.dispatch.mockImplementation(name => Promise.resolve(name === 'fetchAllConversations' ? false : true));
    recovery.onDisconnect(); await recovery.recover(true);
    expect(store.dispatch).toHaveBeenCalledWith('syncActiveConversationMessages', { conversationId: 1, refreshRecent: true });
    expect(emitter.emit).not.toHaveBeenCalledWith(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED);
    store.dispatch.mockImplementation(() => Promise.resolve(true));
    await vi.advanceTimersByTimeAsync(5000);
    expect(emitter.emit).toHaveBeenCalledWith(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED);
  });
  it('always removes the temporary update filter after a rejected HTTP fetch', async () => {
    store.dispatch.mockImplementation(name => name === 'fetchAllConversations' ? Promise.reject(new Error('offline')) : Promise.resolve(true));
    await recovery.recover(true);
    expect(store.dispatch).toHaveBeenLastCalledWith('updateChatListFilters', { updatedWithin: null });
  });
  it('does not let optional cache errors prevent message recovery', async () => {
    recovery.native.revalidateCaches = vi.fn(() => Promise.reject(new Error('cache unavailable')));
    recovery.onDisconnect(); await recovery.recover(true); await settle();
    expect(emitter.emit).toHaveBeenCalledWith(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED);
  });
  it('preserves the first disconnect time through repeated disconnect events', () => {
    recovery.onDisconnect(); const first = recovery.native.disconnectTime;
    vi.advanceTimersByTime(1000); recovery.onDisconnect();
    expect(recovery.native.disconnectTime).toBe(first);
    expect(native.setConversationLastMessageId).toHaveBeenCalledTimes(1);
  });
  it('wakes a closed consumer and catches up without reloading the page', async () => {
    connector.consumer.connection.isOpen.mockReturnValue(false);
    window.dispatchEvent(new Event('focus')); await settle();
    expect(connector.consumer.connect).toHaveBeenCalledTimes(1);
    expect(store.dispatch).toHaveBeenCalledWith('syncActiveConversationMessages', { conversationId: 1, refreshRecent: true });
  });
  it('reconciles messages periodically even when the disconnect event was missed', async () => {
    await vi.advanceTimersByTimeAsync(15000);
    expect(store.dispatch).toHaveBeenCalledWith('syncActiveConversationMessages', { conversationId: 1, refreshRecent: true });
  });
  it('pauses background HTTP checks and refreshes on visibility return', async () => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    await vi.advanceTimersByTimeAsync(15000); expect(store.dispatch).not.toHaveBeenCalled();
    Object.defineProperty(document, 'hidden', { configurable: true, value: false });
    document.dispatchEvent(new Event('visibilitychange')); await settle(); expect(store.dispatch).toHaveBeenCalled();
  });
  it('coalesces concurrent recovery requests', async () => {
    let resolve; const wait = new Promise(r => { resolve = r; });
    store.dispatch.mockReturnValue(wait);
    const a = recovery.recover(true); const b = recovery.recover(true); expect(a).toBe(b);
    resolve(true); await a; await settle();
    expect(store.dispatch.mock.calls.filter(([name]) => name === 'fetchAllConversations')).toHaveLength(1);
  });
  it('stops retries and browser listeners on disposal or account switch', async () => {
    recovery.disconnect(); window.dispatchEvent(new Event('focus')); await vi.advanceTimersByTimeAsync(60000);
    expect(store.dispatch).not.toHaveBeenCalled();
    expect(emitter.off).toHaveBeenCalledWith(BUS_EVENTS.WEBSOCKET_RECONNECT, recovery.onReconnect);
    recovery.stopped = false; store.getters.getCurrentAccountId = 2; await recovery.recover(); expect(store.dispatch).not.toHaveBeenCalled();
  });
});
