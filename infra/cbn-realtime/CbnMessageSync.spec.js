import { describe, it, expect, vi, beforeEach } from 'vitest';
import sync from '../CbnMessageSync';
import MessageApi from 'dashboard/api/inbox/message';
import types from 'dashboard/store/mutation-types';
vi.mock('dashboard/api/inbox/message', () => ({ default: { getPreviousMessages: vi.fn() } }));
const response = payload => ({ data: { payload, meta: {} } });
function context() {
  const ctx = { state: { allConversations: [{ id: 1, messages: [{ id: 10, created_at: 10 }] }], syncConversationsMessages: {} }, rootGetters: { getCurrentAccountId: 1 } };
  ctx.commit = vi.fn((type, data) => {
    if (type === types.SET_MISSING_MESSAGES) ctx.state.allConversations[0].messages = data.data;
    if (type === types.SET_LAST_MESSAGE_ID_IN_SYNC_CONVERSATION) ctx.state.syncConversationsMessages[data.conversationId] = data.messageId;
  });
  return ctx;
}
const ids = ctx => ctx.state.allConversations[0].messages.map(m => m.id);
describe('CBN missed message recovery', () => {
  beforeEach(() => vi.clearAllMocks());
  it('uses the currently cached message as cursor when disconnect notification was missed', async () => {
    const ctx = context(); MessageApi.getPreviousMessages.mockResolvedValue(response([{ id: 11, created_at: 11 }]));
    expect(await sync(ctx, { conversationId: 1 })).toBe(true);
    expect(MessageApi.getPreviousMessages).toHaveBeenCalledWith({ conversationId: 1, after: 10 });
    expect(ids(ctx)).toEqual([10, 11]);
  });
  it('keeps websocket arrivals received while HTTP catchup is in flight', async () => {
    const ctx = context(); let resolve;
    MessageApi.getPreviousMessages.mockReturnValue(new Promise(r => { resolve = r; }));
    const pending = sync(ctx, { conversationId: 1 });
    ctx.state.allConversations[0].messages.push({ id: 12, created_at: 12 });
    resolve(response([{ id: 11, created_at: 11 }])); await pending;
    expect(ids(ctx)).toEqual([10, 11, 12]);
  });
  it('does not overwrite a newer websocket update with an older HTTP snapshot', async () => {
    const ctx = context(); let resolve;
    MessageApi.getPreviousMessages.mockReturnValue(new Promise(r => { resolve = r; }));
    const pending = sync(ctx, { conversationId: 1 });
    ctx.state.allConversations[0].messages[0] = { id: 10, created_at: 10, status: 'read' };
    resolve(response([{ id: 10, created_at: 10, status: 'sent' }])); await pending;
    expect(ctx.state.allConversations[0].messages[0].status).toBe('read');
  });
  it('deduplicates snapshots and retains local pending messages', async () => {
    const ctx = context(); ctx.state.allConversations[0].messages.push({ id: 'draft-uuid', created_at: 12, content: 'synthetic draft' });
    MessageApi.getPreviousMessages.mockResolvedValue(response([{ id: 10, created_at: 10 }, { id: 11, created_at: 11 }]));
    await sync(ctx, { conversationId: 1 }); expect(ids(ctx)).toEqual([10, 11, 'draft-uuid']);
  });
  it('backfills more than a single server page', async () => {
    const ctx = context();
    MessageApi.getPreviousMessages.mockResolvedValueOnce(response(Array.from({ length: 100 }, (_, i) => ({ id: i + 11, created_at: i + 11 })))).mockResolvedValueOnce(response([{ id: 111, created_at: 111 }]));
    await sync(ctx, { conversationId: 1 });
    expect(MessageApi.getPreviousMessages).toHaveBeenLastCalledWith({ conversationId: 1, after: 110 });
    expect(ids(ctx)).toHaveLength(102);
  });
  it('retains the backfill marker on failure for a later retry', async () => {
    const ctx = context(); ctx.state.syncConversationsMessages[1] = 8;
    MessageApi.getPreviousMessages.mockRejectedValue(new Error('offline'));
    expect(await sync(ctx, { conversationId: 1 })).toBe(false);
    expect(ctx.state.syncConversationsMessages[1]).toBe(8);
  });
  it('discards responses from a previous account', async () => {
    const ctx = context(); let resolve;
    MessageApi.getPreviousMessages.mockReturnValue(new Promise(r => { resolve = r; }));
    const pending = sync(ctx, { conversationId: 1 }); ctx.rootGetters.getCurrentAccountId = 2;
    resolve(response([{ id: 11, created_at: 11 }])); await pending;
    expect(ctx.commit).not.toHaveBeenCalled();
  });
  it('refreshes recent messages even if a later websocket ID already reached the cache', async () => {
    const ctx = context(); ctx.state.allConversations[0].messages.push({ id: 12, created_at: 12 });
    MessageApi.getPreviousMessages.mockResolvedValueOnce(response([{ id: 11, created_at: 11 }, { id: 12, created_at: 12 }])).mockResolvedValueOnce(response([]));
    await sync(ctx, { conversationId: 1, refreshRecent: true }); expect(ids(ctx)).toEqual([10, 11, 12]);
  });
  it('marks recovered incoming messages read only in the active visible conversation', async () => {
    Object.defineProperty(document, 'hidden', { configurable: true, value: false });
    const ctx = context(); ctx.state.selectedChatId = 1; ctx.dispatch = vi.fn();
    MessageApi.getPreviousMessages.mockResolvedValue(response([{ id: 11, created_at: 11, message_type: 0 }]));
    await sync(ctx, { conversationId: 1 });
    expect(ctx.dispatch).toHaveBeenCalledWith('markMessagesRead', { id: 1 }, { root: true });
    ctx.dispatch.mockClear(); await sync(ctx, { conversationId: 1 }); expect(ctx.dispatch).not.toHaveBeenCalled();
    const other = context(); other.state.selectedChatId = 2; other.dispatch = vi.fn();
    await sync(other, { conversationId: 1 }); expect(other.dispatch).not.toHaveBeenCalled();
    const hidden = context(); hidden.state.selectedChatId = 1; hidden.dispatch = vi.fn();
    Object.defineProperty(document, 'hidden', { configurable: true, value: true });
    await sync(hidden, { conversationId: 1 }); expect(hidden.dispatch).not.toHaveBeenCalled();
    Object.defineProperty(document, 'hidden', { configurable: true, value: false });
  });
});
