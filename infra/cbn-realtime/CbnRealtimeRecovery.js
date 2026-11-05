import NativeReconnectService from './ReconnectService';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { isAConversationRoute, isAInboxViewRoute, isNotificationRoute } from './routeHelpers';

export default class CbnRealtimeRecovery {
  constructor(store, router, connector) {
    this.store = store;
    this.router = router;
    this.connector = connector;
    this.accountId = store.getters.getCurrentAccountId;
    this.native = new NativeReconnectService(store, router);
    this.native.disconnect();
    this.stopped = false;
    this.pendingNotice = false;
    this.inFlight = null;
    this.fullRequested = false;
    this.retryTimer = null;
    this.lastListSyncAt = Date.now();
    this.onReconnect = () => { this.pendingNotice = true; this.recover(true); };
    this.onDisconnect = () => {
      if (!this.native.disconnectTime) {
        this.native.disconnectTime = new Date();
        Promise.resolve(this.native.setConversationLastMessageId()).catch(() => {});
      }
      this.pendingNotice = true;
    };
    this.onResume = () => { if (this.visible()) this.recover(true); };
    emitter.on(BUS_EVENTS.WEBSOCKET_RECONNECT, this.onReconnect);
    emitter.on(BUS_EVENTS.WEBSOCKET_DISCONNECT, this.onDisconnect);
    ['online', 'focus', 'pageshow'].forEach(event => window.addEventListener(event, this.onResume));
    document.addEventListener('visibilitychange', this.onResume);
    this.watchdog = setInterval(() => {
      if (this.visible()) this.recover(Date.now() - this.lastListSyncAt >= 60000 || this.pendingNotice);
    }, 15000);
  }

  active() {
    return !this.stopped && this.accountId === this.store.getters.getCurrentAccountId;
  }

  visible() {
    return this.active() && !document.hidden && navigator.onLine !== false;
  }

  async fetchList() {
    const getters = this.store.getters;
    const query = getters.getAppliedConversationFiltersQuery?.payload?.length
      ? getters.getAppliedConversationFiltersQuery
      : getters['customViews/getActiveConversationFolder']?.query;
    if (query) return this.store.dispatch('fetchFilteredConversations', { queryData: query, page: 1 });
    try {
      await this.store.dispatch('updateChatListFilters', {
        page: null,
        updatedWithin: Math.max(15 + this.native.getSecondsSinceDisconnect(), 15 + Math.ceil((Date.now() - this.lastListSyncAt) / 1000)),
      });
      return await this.store.dispatch('fetchAllConversations');
    } finally {
      if (this.active()) await this.store.dispatch('updateChatListFilters', { updatedWithin: null });
    }
  }

  recover(full = true) {
    if (!this.visible()) return Promise.resolve();
    if (this.inFlight) {
      this.fullRequested ||= full && !this.syncIsFull;
      return this.inFlight;
    }
    this.fullRequested ||= full;
    // The native consumer reconnects with its own backoff. connect() only wakes
    // a stopped/closed consumer; never tear down a healthy socket to refresh UI.
    if (!this.connector?.consumer?.connection?.isOpen?.()) this.connector?.consumer?.connect?.();
    this.inFlight = this.sync().finally(() => {
      this.inFlight = null;
      this.syncIsFull = false;
      if (this.fullRequested && this.visible()) this.recover(true);
    });
    return this.inFlight;
  }

  async sync() {
    const full = this.fullRequested;
    this.syncIsFull = full;
    this.fullRequested = false;
    const route = this.router.currentRoute.value;
    const tasks = [];
    if (isAConversationRoute(route.name, true)) {
      if (full) tasks.push(Promise.resolve().then(() => this.fetchList()));
      if (route.params.conversation_id) tasks.push(this.store.dispatch('syncActiveConversationMessages', {
        conversationId: Number(route.params.conversation_id), refreshRecent: true,
      }));
    } else if (full && (isAInboxViewRoute(route.name, true) || isNotificationRoute(route.name))) {
      tasks.push(this.store.dispatch('notifications/index', { ...this.store.getters['notifications/getNotificationFilters'], page: 1 }));
    }
    const results = await Promise.allSettled(tasks);
    if (!this.active()) return;
    const failed = results.some(result => result.status === 'rejected' || result.value === false);
    if (failed) {
      clearTimeout(this.retryTimer);
      this.retryTimer = setTimeout(() => this.recover(true), 5000);
      return;
    }
    clearTimeout(this.retryTimer);
    this.retryTimer = null;
    if (full) this.lastListSyncAt = Date.now();
    const socketOpen = this.connector?.consumer?.connection?.isOpen?.();
    if (this.pendingNotice && socketOpen) {
      this.pendingNotice = false;
      this.native.disconnectTime = null;
      emitter.emit(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED);
    }
    // Label/team cache failures must not prevent the active messages syncing.
    if (full) Promise.resolve(this.native.revalidateCaches()).catch(() => {});
  }

  disconnect() {
    this.stopped = true;
    clearInterval(this.watchdog);
    clearTimeout(this.retryTimer);
    this.native.disconnect();
    emitter.off(BUS_EVENTS.WEBSOCKET_RECONNECT, this.onReconnect);
    emitter.off(BUS_EVENTS.WEBSOCKET_DISCONNECT, this.onDisconnect);
    ['online', 'focus', 'pageshow'].forEach(event => window.removeEventListener(event, this.onResume));
    document.removeEventListener('visibilitychange', this.onResume);
  }
}
