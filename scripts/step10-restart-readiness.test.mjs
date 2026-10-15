import assert from 'node:assert/strict';
import test from 'node:test';
import { waitForHttpStatus } from './step10-restart-readiness.mjs';

function clock() {
  let now = 0;
  return {
    now: () => now,
    sleep: async (ms) => { now += ms; },
  };
}

test('retries transient 502 and 503 responses until the authenticated request returns 200', async () => {
  const time = clock();
  const statuses = [502, 503, 200];
  const result = await waitForHttpStatus({
    timeoutMs: 180_000,
    pollIntervalMs: 4_000,
    requestTimeoutMs: 5_000,
    now: time.now,
    sleep: time.sleep,
    request: async () => ({ status: statuses.shift() }),
  });

  assert.equal(result.status, 200);
  assert.equal(result.attempts, 3);
  assert.equal(result.elapsedMs, 8_000);
});

test('fails immediately on authentication errors without retrying or exposing response data', async () => {
  const time = clock();
  let attempts = 0;
  await assert.rejects(
    waitForHttpStatus({
      timeoutMs: 180_000,
      now: time.now,
      sleep: time.sleep,
      request: async () => { attempts += 1; return { status: 403, body: 'private token detail' }; },
    }),
    (error) => {
      assert.equal(error.status, 403);
      assert.equal(error.attempts, 1);
      assert.equal(error.elapsedMs, 0);
      assert.match(error.message, /HTTP 403/);
      assert.doesNotMatch(error.message, /private token detail/);
      return true;
    },
  );
  assert.equal(attempts, 1);
});

test('fails immediately on non-transient HTTP errors', async () => {
  const time = clock();
  let attempts = 0;
  await assert.rejects(
    waitForHttpStatus({
      now: time.now,
      sleep: time.sleep,
      request: async () => { attempts += 1; return { status: 500 }; },
    }),
    (error) => error.status === 500 && error.attempts === 1,
  );
  assert.equal(attempts, 1);
});

test('retries request failures only within the hard deadline and reports safe error codes', async () => {
  const time = clock();
  let attempts = 0;
  await assert.rejects(
    waitForHttpStatus({
      timeoutMs: 9_000,
      pollIntervalMs: 4_000,
      requestTimeoutMs: 3_000,
      now: time.now,
      sleep: time.sleep,
      request: async () => {
        attempts += 1;
        const error = new Error('private connection detail');
        error.code = 'ECONNREFUSED';
        throw error;
      },
    }),
    (error) => {
      assert.equal(error.elapsedMs, 9_000);
      assert.equal(error.attempts, 3);
      assert.match(error.message, /ECONNREFUSED/);
      assert.doesNotMatch(error.message, /private connection detail/);
      return true;
    },
  );
  assert.equal(attempts, 3);
});

test('does not accept a response that arrives after the deadline', async () => {
  const time = clock();
  await assert.rejects(
    waitForHttpStatus({
      timeoutMs: 1_000,
      now: time.now,
      sleep: time.sleep,
      request: async () => {
        const error = new Error('request timed out');
        error.code = 'ETIMEDOUT';
        time.now = () => 1_001;
        throw error;
      },
    }),
    (error) => error.elapsedMs === 1_000 && error.attempts === 1,
  );
});
