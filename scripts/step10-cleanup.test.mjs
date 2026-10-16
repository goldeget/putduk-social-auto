import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const cleanup = readFileSync(new URL('../.github/ci/step10-cleanup.sh', import.meta.url), 'utf8');
const workflow = readFileSync(new URL('../.github/workflows/putduk-docker-build-check.yml', import.meta.url), 'utf8');

test('cleanup is restricted to the exact run project and runner temp child', () => {
  assert.match(cleanup, /expected_project="putdukstep10-\$\{GITHUB_RUN_ID\}-\$\{GITHUB_RUN_ATTEMPT\}"/);
  assert.match(cleanup, /expected_workdir="\$RUNNER_TEMP\/putduk-step10-\$\{GITHUB_RUN_ID\}-\$\{GITHUB_RUN_ATTEMPT\}"/);
  assert.match(cleanup, /realpath -m -- "\$RUNNER_TEMP"/);
  assert.match(cleanup, /dirname -- "\$STEP10_WORKDIR"/);
  assert.match(cleanup, /! -L "\$STEP10_WORKDIR" && ! -L "\$STEP10_STATE"/);
  assert.match(cleanup, /find "\$STEP10_WORKDIR" -type l/);
});

test('cleanup verifies Compose-owned and explicit run-labeled containers, networks, and volumes', () => {
  assert.match(cleanup, /label=putduk\.step10\.project=\$STEP10_PROJECT/);
  assert.match(cleanup, /label=com\.docker\.compose\.project=\$STEP10_PROJECT/);
  assert.match(cleanup, /networks:compose\) docker network ls/);
  assert.match(cleanup, /Run-scoped %s remain/);
  assert.doesNotMatch(cleanup, /docker system prune|volume prune/);
});

test('root-created files are normalized only inside the validated run directory', () => {
  assert.match(cleanup, /sudo chown -hR "\$runner_owner" -- "\$STEP10_WORKDIR"/);
  assert.match(cleanup, /find "\$STEP10_WORKDIR" -xdev ! -uid/);
  assert.match(cleanup, /rm -rf -- "\$STEP10_WORKDIR"/);
  assert.match(workflow, /Clean up only this Step 10 run[\s\S]*if: always\(\)/);
  assert.match(workflow, /bash \.github\/ci\/step10-cleanup\.sh/);
});

test('cleanup fixture creates root-owned nested files in a synthetic run temp path', () => {
  const fixture = readFileSync(new URL('../.github/ci/test-step10-cleanup.sh', import.meta.url), 'utf8');
  assert.match(fixture, /test_project="putdukstep10-\$\{test_run_id\}-\$\{test_attempt\}"/);
  assert.match(fixture, /sudo touch .*dump\.rdb.*test\.png/);
  assert.match(fixture, /stat -c '%u'/);
});
