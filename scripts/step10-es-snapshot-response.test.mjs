import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { inspectSnapshotResponse } from './step10-es-snapshot-response.mjs';

const integration = readFileSync(new URL('../.github/ci/putduk-step10-integration.sh', import.meta.url), 'utf8');

test('snapshot request sends include_global_state in JSON body and not as a query parameter', () => {
  assert.match(integration, /-d '\{"include_global_state":true\}'[\s\S]*_snapshot\/putduk_step10\/step10_snapshot\?wait_for_completion=true/);
  assert.doesNotMatch(integration, /step10_snapshot\?[^'\n]*include_global_state/);
});

test('snapshot validation accepts only a successful HTTP response with SUCCESS state', () => {
  assert.deepEqual(inspectSnapshotResponse(200, '{"snapshot":{"state":"SUCCESS"}}'), {
    ok: true,
    status: 200,
    state: 'SUCCESS',
  });
  assert.deepEqual(inspectSnapshotResponse(200, '{"snapshot":{"state":"PARTIAL"}}'), {
    ok: false,
    status: 200,
    errorType: 'snapshot_not_successful',
    state: 'PARTIAL',
  });
});

test('snapshot failure reports status and safe error type without Elasticsearch reason text', () => {
  const body = JSON.stringify({
    error: { type: 'illegal_argument_exception', reason: 'do not expose secret-value-123' },
  });
  const result = inspectSnapshotResponse(400, body);
  assert.deepEqual(result, { ok: false, status: 400, errorType: 'illegal_argument_exception' });
  assert.doesNotMatch(JSON.stringify(result), /secret-value-123/);
});

test('snapshot response with malformed JSON fails safely', () => {
  assert.deepEqual(inspectSnapshotResponse(200, 'not-json'), {
    ok: false,
    status: 200,
    errorType: 'invalid_json',
  });
});

test('snapshot response with an invalid HTTP status fails closed', () => {
  assert.deepEqual(inspectSnapshotResponse(Number.NaN, '{"snapshot":{"state":"SUCCESS"}}'), {
    ok: false,
    status: Number.NaN,
    errorType: 'invalid_http_status',
  });
});

test('CLI prints a safe error summary and never prints the response reason', () => {
  const dir = mkdtempSync(join(tmpdir(), 'putduk-es-response-test-'));
  const file = join(dir, 'response.json');
  const script = fileURLToPath(new URL('./step10-es-snapshot-response.mjs', import.meta.url));
  try {
    writeFileSync(file, JSON.stringify({
      error: { type: 'illegal_argument_exception', reason: 'secret-value-must-not-be-logged' },
    }));
    const result = spawnSync(process.execPath, [script, '400', file], { encoding: 'utf8' });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /HTTP 400, error_type=illegal_argument_exception/);
    assert.doesNotMatch(result.stderr, /secret-value-must-not-be-logged/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
