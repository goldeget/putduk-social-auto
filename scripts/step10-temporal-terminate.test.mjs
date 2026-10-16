import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL('../.github/ci/putduk-step10-integration.sh', import.meta.url),
  'utf8'
);

test('Temporal workflow cleanup targets the Temporal service endpoint', () => {
  const terminate = source.match(/dc exec -T temporal temporal workflow terminate[^\n]*/)?.[0];

  assert.ok(terminate, 'workflow termination command must exist');
  assert.match(terminate, /--address temporal:7233/);
  assert.match(terminate, /--workflow-id "\$WORKFLOW_ID"/);
});
