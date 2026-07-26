import { Api, TelegramClient } from 'telegram';
import { StringSession } from 'telegram/sessions/index.js';
import { deterministicRandomId } from './random-id.js';

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export class TelegramAdapter {
  constructor(config) {
    this.config = config;
    this.client = new TelegramClient(
      new StringSession(config.session),
      config.apiId,
      config.apiHash,
      { connectionRetries: 5 }
    );
    this.entity = null;
  }

  async connect() {
    await this.client.connect();
    if (!(await this.client.checkAuthorization())) {
      throw new Error('TELEGRAM_SESSION_NOT_AUTHORIZED');
    }
    this.entity = await this.client.getInputEntity(this.config.target);
  }

  async disconnect() {
    await this.client.disconnect();
  }

  async peekLatest() {
    const messages = await this.client.getMessages(this.entity, { limit: 20 });
    const latest = messages.find((message) => !message.out);
    return latest
      ? { id: Number(latest.id), text: latest.message || '' }
      : { id: 0, text: '' };
  }

  async send(operationId, step, text) {
    const result = await this.client.invoke(
      new Api.messages.SendMessage({
        peer: this.entity,
        message: text,
        randomId: deterministicRandomId(operationId, step),
        noWebpage: true,
      })
    );

    const message = result?.updates?.find((update) => update?.message)?.message;
    if (!message?.id) {
      const latest = await this.client.getMessages(this.entity, { limit: 10 });
      const sent = latest.find(
        (candidate) => candidate.out && (candidate.message || '').trim() === text.trim()
      );
      if (!sent) throw new Error('TELEGRAM_SENT_MESSAGE_NOT_FOUND');
      return { id: Number(sent.id) };
    }
    return { id: Number(message.id) };
  }

  async waitAfter(messageId) {
    const deadline = Date.now() + this.config.responseTimeoutMs;
    let cursor = Number(messageId);

    while (Date.now() < deadline) {
      const messages = await this.client.getMessages(this.entity, { limit: 50 });
      const incoming = messages
        .filter((message) => !message.out && Number(message.id) > cursor)
        .sort((left, right) => Number(left.id) - Number(right.id));

      if (incoming.length > 0) {
        const message = incoming[0];
        return { id: Number(message.id), text: message.message || '' };
      }
      await sleep(this.config.pollIntervalMs);
    }

    throw new Error('TELEGRAM_RESPONSE_TIMEOUT');
  }
}
