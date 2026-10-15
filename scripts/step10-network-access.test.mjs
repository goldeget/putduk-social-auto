import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const compose = readFileSync(new URL('../.github/ci/docker-compose.step10-test.yaml', import.meta.url), 'utf8');
const integration = readFileSync(new URL('../.github/ci/putduk-step10-integration.sh', import.meta.url), 'utf8');
const postizService = compose.match(/\n  postiz:\n([\s\S]*?)(?=\n  [a-zA-Z0-9_-]+:\n|\nnetworks:)/)?.[1];

test('internal CI network keeps Postiz unpublished and host tests connect through its private IP', () => {
  assert.ok(postizService, 'CI Compose must define the Postiz service');
  assert.doesNotMatch(postizService, /^\s+ports:/m);
  assert.match(compose, /edge:\s*internal:\s+true/);
  assert.match(integration, /POSTIZ_EDGE_IP=/);
  assert.match(integration, /--connect-to\s+"127\.0\.0\.1:5500:\$\{POSTIZ_EDGE_IP\}:5000"/);
  assert.match(integration, /docker inspect --format .*NetworkSettings\.Ports/);
  assert.match(integration, /Postiz has no host-published ports/);
  assert.match(integration, /Failed integration phase:/);
  assert.match(integration, /exit_code=%s/);
  assert.match(integration, /127\.0\.0\.1:5500/);

  const directHostCurlLines = integration.split('\n').filter((line) =>
    line.includes('$BASE_URL') && /\bcurl\b/.test(line),
  );
  assert.deepEqual(directHostCurlLines, [], 'all host requests using BASE_URL must use the private-IP routing helper');
  assert.match(integration, /postiz_curl\(\)/);
});
