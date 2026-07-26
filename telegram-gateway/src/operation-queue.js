export class OperationQueue {
  constructor({ execute, onComplete, onFailure }) {
    this.execute = execute;
    this.onComplete = onComplete;
    this.onFailure = onFailure;
    this.items = [];
    this.operations = new Map();
    this.running = false;
  }

  enqueue(operation) {
    const existing = this.operations.get(operation.operationId);
    if (existing) {
      return { accepted: false, status: existing.status };
    }

    this.operations.set(operation.operationId, {
      status: 'RECEIVED',
      conversationId: operation.conversationId,
      createdAt: new Date().toISOString(),
    });
    this.items.push(operation);
    void this.drain();
    return { accepted: true, status: 'RECEIVED' };
  }

  get(operationId) {
    const operation = this.operations.get(operationId);
    return operation ? { ...operation } : null;
  }

  get health() {
    return {
      busy: this.running,
      queueDepth: this.items.length,
    };
  }

  async drain() {
    if (this.running) return;
    this.running = true;
    try {
      while (this.items.length > 0) {
        const operation = this.items.shift();
        const state = this.operations.get(operation.operationId);
        state.status = 'LOCK_ACQUIRED';
        state.startedAt = new Date().toISOString();
        try {
          state.status = 'WAITING_RESPONSE';
          const result = await this.execute(operation);
          await this.onComplete(operation, result);
          state.status = 'COMPLETED';
        } catch (error) {
          state.status = error?.name === 'HumanReviewError' ? 'HUMAN_REVIEW' : 'FAILED_FINAL';
          state.errorCode = error?.code || error?.message || 'UNKNOWN_ERROR';
          try {
            await this.onFailure(operation, error);
          } catch {
            state.callbackFailed = true;
          }
        } finally {
          state.finishedAt = new Date().toISOString();
        }
      }
    } finally {
      this.running = false;
    }
  }
}
