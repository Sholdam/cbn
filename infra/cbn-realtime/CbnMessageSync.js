import MessageApi from 'dashboard/api/inbox/message';
import types from 'dashboard/store/mutation-types';

const numericId = item => Number.isSafeInteger(Number(item?.id)) ? Number(item.id) : 0;
const timestamp = item => typeof item.created_at === 'number' ? item.created_at * 1000 : Date.parse(item.created_at) || 0;

// Merge against the current store after each response, not the snapshot taken
// before the request: websocket arrivals and unsent drafts must survive.
export default async function syncMessages({ commit, state, dispatch, rootGetters }, { conversationId, refreshRecent = false }) {
  const accountId = rootGetters?.getCurrentAccountId;
  const current = () => state.allConversations.find(item => Number(item.id) === Number(conversationId));
  const sameAccount = () => accountId === rootGetters?.getCurrentAccountId;
  let chat = current();
  if (!chat) return true;
  let newIncoming = false;
  let cursor = Number(state.syncConversationsMessages[conversationId]) || Math.max(0, ...(chat.messages || []).map(numericId));
  const merge = (payload, meta, before) => {
    if (!sameAccount() || !current()) return false;
    chat = current();
    const merged = new Map((chat.messages || []).map(message => [String(message.id), message]));
    for (const message of payload) {
      const key = String(message.id);
      if (!merged.has(key) && (message.message_type === 0 || message.message_type === 'incoming')) newIncoming = true;
      // Preserve a newer websocket replacement received during this HTTP call.
      if (!merged.has(key) || merged.get(key) === before.get(key)) merged.set(key, message);
    }
    commit(`conversationMetadata/${types.SET_CONVERSATION_METADATA}`, { id: conversationId, data: meta });
    commit(types.SET_MISSING_MESSAGES, { id: conversationId, data: [...merged.values()].sort((a, b) => timestamp(a) - timestamp(b)) });
    return true;
  };
  const fetchPage = async after => {
    const before = new Map((current()?.messages || []).map(message => [String(message.id), message]));
    const { data: { payload, meta } } = await MessageApi.getPreviousMessages({ conversationId, after });
    if (!Array.isArray(payload)) throw new Error('Invalid message response');
    if (!merge(payload, meta, before)) return null;
    return payload;
  };
  try {
    if (refreshRecent && await fetchPage(undefined) === null) return true;
    for (let page = 0; page < 20; page += 1) {
      if (!sameAccount() || !current()) return true;
      const payload = await fetchPage(cursor || undefined);
      if (payload === null) return true;
      const next = Math.max(cursor, ...payload.map(numericId));
      if (payload.length < 100 || next <= cursor) {
        commit(types.SET_LAST_MESSAGE_ID_IN_SYNC_CONVERSATION, { conversationId, messageId: null });
        if (newIncoming && Number(state.selectedChatId) === Number(conversationId) && !document.hidden && dispatch) {
          Promise.resolve(dispatch('markMessagesRead', { id: conversationId }, { root: true })).catch(() => {});
        }
        return true;
      }
      cursor = next;
      commit(types.SET_LAST_MESSAGE_ID_IN_SYNC_CONVERSATION, { conversationId, messageId: cursor });
    }
    return false; // Continue the remaining backfill on the next bounded retry.
  } catch (_) {
    return false; // Keep the cursor and retry; never announce a successful sync.
  }
}
