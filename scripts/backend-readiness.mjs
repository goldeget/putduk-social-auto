const DEFAULT_URL = 'http://127.0.0.1:3000/auth/can-register';

const safeFailureCode = (error) => {
  const code = error?.cause?.code;
  if (typeof code === 'string' && /^[A-Z0-9_]{1,40}$/.test(code)) return code;
  const name = error?.name;
  if (typeof name === 'string' && /^[A-Za-z0-9_]{1,40}$/.test(name)) return name;
  return 'request failed';
};

export async function waitForBackend({
  url = DEFAULT_URL,
  timeoutMs = 180_000,
  pollIntervalMs = 4_000,
  requestTimeoutMs = 3_000,
  fetchImpl = fetch,
  now = () => performance.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
} = {}) {
  const startedAt = now();
  const deadline = startedAt + timeoutMs;
  let attempts = 0;
  let lastResult = 'no response';

  while (now() < deadline) {
    const remainingMs = deadline - now();
    const requestLimitMs = Math.max(1, Math.min(requestTimeoutMs, remainingMs));
    attempts += 1;

    try {
      const response = await fetchImpl(url, { signal: AbortSignal.timeout(requestLimitMs) });
      if (now() >= deadline) {
        lastResult = 'readiness deadline elapsed during request';
      } else if (response.status !== 200) {
        lastResult = `HTTP ${response.status}`;
      } else {
        try {
          const body = await response.json();
          if (now() >= deadline) {
            lastResult = 'readiness deadline elapsed while reading response';
          } else if (body && typeof body.register === 'boolean') {
            return {
              attempts,
              elapsedMs: Math.max(0, Math.round(now() - startedAt)),
              lastResult: 'HTTP 200 with valid JSON',
            };
          } else {
            lastResult = 'HTTP 200 with invalid JSON shape';
          }
        } catch {
          lastResult = 'HTTP 200 with invalid JSON';
        }
      }
    } catch (error) {
      lastResult = `request ${safeFailureCode(error)}`;
    }

    const remainingAfterRequestMs = deadline - now();
    if (remainingAfterRequestMs <= 0) break;
    await sleep(Math.min(pollIntervalMs, remainingAfterRequestMs));
  }

  const elapsedMs = Math.max(0, Math.round(Math.min(now(), deadline) - startedAt));
  const error = new Error(`Backend readiness timed out after ${elapsedMs} ms; attempts=${attempts}; last=${lastResult}`);
  error.attempts = attempts;
  error.elapsedMs = elapsedMs;
  error.lastResult = lastResult;
  throw error;
}

if (process.argv[1] === '-') {
  waitForBackend()
    .then(({ attempts, elapsedMs }) => {
      console.log(`Backend ready: HTTP 200 with valid JSON; elapsed=${(elapsedMs / 1_000).toFixed(1)}s; attempts=${attempts}.`);
    })
    .catch((error) => {
      console.error(error.message);
      process.exitCode = 1;
    });
}
