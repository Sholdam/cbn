const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export async function deliverCallback(config, payload, fetchImpl = fetch) {
  let lastError;
  for (let attempt = 1; attempt <= config.callbackMaxAttempts; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.callbackTimeoutMs);
    try {
      const response = await fetchImpl(config.callbackUrl, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${config.callbackToken}`,
          'content-type': 'application/json',
          'idempotency-key': payload.operation_id,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      if (response.ok) return;
      lastError = new Error(`CALLBACK_HTTP_${response.status}`);
    } catch (error) {
      lastError = error;
    } finally {
      clearTimeout(timeout);
    }
    if (attempt < config.callbackMaxAttempts) {
      await sleep(Math.min(1000 * 2 ** (attempt - 1), 10000));
    }
  }
  throw lastError || new Error('CALLBACK_FAILED');
}
