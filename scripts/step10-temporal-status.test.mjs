import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { isWorkflowRunning } from './step10-temporal-status.mjs';

const integration = readFileSync(
  new URL('../.github/ci/putduk-step10-integration.sh', import.meta.url),
  'utf8'
);

test('CI uses Temporal JSON status and checks workflow and worker independently on failure', () => {
  assert.match(integration, /workflow describe .*--output json/);
  assert.match(integration, /workflow list --query/);
  assert.match(integration, /task-queue describe --task-queue main/);
  assert.match(integration, /Temporal describe exit code/);
  assert.match(integration, /recent workflow pollers/);
  assert.match(integration, /Exact workflow list result/);
});

test('accepts Temporal CLI JSON with a running workflow status', () => {
  assert.equal(isWorkflowRunning(JSON.stringify({ status: 'Running' })), true);
});

test('accepts nested protobuf-style Temporal CLI JSON status', () => {
  assert.equal(
    isWorkflowRunning(
      JSON.stringify({
        workflowExecutionInfo: {
          execution: { workflowId: 'post_test' },
          status: 'WORKFLOW_EXECUTION_STATUS_RUNNING',
        },
      })
    ),
    true
  );
});

test('rejects completed, failed, missing, and malformed workflow status', () => {
  for (const value of [
    JSON.stringify({ status: 'Completed' }),
    JSON.stringify({ status: 'Failed' }),
    JSON.stringify({ workflowId: 'post_test' }),
    '{',
  ]) {
    assert.equal(isWorkflowRunning(value), false);
  }
});

test('does not accept a running word unrelated to workflow status', () => {
  assert.equal(
    isWorkflowRunning(JSON.stringify({ message: 'worker running' })),
    false
  );
});
