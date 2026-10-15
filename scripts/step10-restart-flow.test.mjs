import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const script = readFileSync(new URL('../.github/ci/putduk-step10-integration.sh', import.meta.url), 'utf8');
const restartStart = script.indexOf("mark_phase 'restart Postiz and Temporal and verify scheduled state'");
const restoreStart = script.indexOf("mark_phase 'backup and restore Postiz PostgreSQL data'", restartStart);
assert.notEqual(restartStart, -1, 'restart verification phase exists');
assert.notEqual(restoreStart, -1, 'restore phase exists after restart verification');
const restartFlow = script.slice(restartStart, restoreStart);

test('post-restart backend readiness precedes refreshed HTTP and authenticated schedule checks', () => {
  const restart = restartFlow.indexOf('dc restart postiz temporal');
  const backendReady = restartFlow.indexOf('node --input-type=module - < scripts/backend-readiness.mjs');
  const refreshIp = restartFlow.indexOf('POSTIZ_EDGE_IP="$(resolve_postiz_edge_ip)"');
  const frontendNginx = restartFlow.indexOf('Frontend :4200');
  const authenticatedSchedule = restartFlow.indexOf('scripts/step10-restart-readiness.mjs');

  assert.ok(restart >= 0 && backendReady > restart);
  assert.ok(refreshIp > backendReady);
  assert.ok(frontendNginx > refreshIp);
  assert.ok(authenticatedSchedule > frontendNginx);
  assert.match(restartFlow, /BACKEND_READINESS_TIMEOUT_MS=180000/);
});

test('post-restart Temporal status comes from a fresh describe response', () => {
  assert.match(restartFlow, /temporal-after-restart\.json/);
  assert.match(restartFlow, /temporal workflow describe --workflow-id "\$WORKFLOW_ID"/);
  assert.match(restartFlow, /step10-temporal-status\.mjs "\$workflow_after_restart_file"/);
  assert.doesNotMatch(restartFlow, /step10-temporal-status\.mjs "\$workflow_file"/);
});
