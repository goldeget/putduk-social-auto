import assert from 'node:assert/strict';
import test from 'node:test';
import { waitForBackend } from './backend-readiness.mjs';

function response(status, body) {
  return {
    status,
    async json() {
      if (body instanceof Error) throw body;
      return body;
    },
  };
}

test('retries unavailable backend and returns only after a valid HTTP 200 response', async () => {
  let now = 0;
  let attempts = 0;
  const result = await waitForBackend({
    timeoutMs: 180_000,
    pollIntervalMs: 4_000,
    requestTimeoutMs: 3_000,
    now: () => now,
    sleep: async (ms) => { now += ms; },
    fetchImpl: async (_url, options) => {
      attempts += 1;
      assert.ok(options.signal);
      assert.equal(options.signal.aborted, false);
      if (attempts < 3) {
        const error = new Error('connection refused');
        error.cause = { code: 'ECONNREFUSED' };
        throw error;
      }
      return response(200, { register: true });
    },
  });

  assert.equal(result.attempts, 3);
  assert.equal(result.elapsedMs, 8_000);
  assert.equal(result.lastResult, 'HTTP 200 with valid JSON');
});

test('does not accept HTTP 200 with malformed registration JSON', async () => {
  let now = 0;
  let attempts = 0;
  const result = await waitForBackend({
    timeoutMs: 10_000,
    pollIntervalMs: 4_000,
    requestTimeoutMs: 3_000,
    now: () => now,
    sleep: async (ms) => { now += ms; },
    fetchImpl: async () => {
      attempts += 1;
      return attempts === 1 ? response(200, new SyntaxError('invalid json')) : response(200, { register: false });
    },
  });

  assert.equal(result.attempts, 2);
  assert.equal(result.elapsedMs, 4_000);
});

test('fails at the bounded deadline with the last safe error and a capped request timeout', async () => {
  let now = 0;
  let attempts = 0;
  await assert.rejects(
    waitForBackend({
      timeoutMs: 9_000,
      pollIntervalMs: 4_000,
      requestTimeoutMs: 3_000,
      now: () => now,
      sleep: async (ms) => { now += ms; },
      fetchImpl: async (_url, { signal }) => {
        attempts += 1;
        assert.equal(signal.aborted, false);
        const error = new Error('private connection detail');
        error.cause = { code: 'ECONNREFUSED' };
        throw error;
      },
    }),
    (error) => {
      assert.equal(error.elapsedMs, 9_000);
      assert.equal(error.attempts, 3);
      assert.equal(error.lastResult, 'request ECONNREFUSED');
      assert.doesNotMatch(error.message, /private connection detail/);
      return true;
    },
  );
  assert.equal(attempts, 3);
});

test('does not accept a successful response arriving after the hard deadline', async () => {
  let now = 0;
  await assert.rejects(
    waitForBackend({
      timeoutMs: 9_000,
      now: () => now,
      sleep: async (ms) => { now += ms; },
      fetchImpl: async () => {
        now = 9_001;
        return response(200, { register: true });
      },
    }),
    (error) => {
      assert.equal(error.elapsedMs, 9_000);
      assert.equal(error.attempts, 1);
      assert.equal(error.lastResult, 'readiness deadline elapsed during request');
      return true;
    },
  );
});

test('does not accept a valid JSON body read after the hard deadline', async () => {
  let now = 0;
  await assert.rejects(
    waitForBackend({
      timeoutMs: 9_000,
      now: () => now,
      sleep: async (ms) => { now += ms; },
      fetchImpl: async () => ({
        status: 200,
        async json() {
          now = 9_001;
          return { register: true };
        },
      }),
    }),
    (error) => {
      assert.equal(error.elapsedMs, 9_000);
      assert.equal(error.lastResult, 'readiness deadline elapsed while reading response');
      return true;
    },
  );
});
