import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const rootPackage = JSON.parse(readFileSync(new URL('../package.json', import.meta.url)));
const frontend = JSON.parse(readFileSync(new URL('../apps/frontend/package.json', import.meta.url)));
const backend = JSON.parse(readFileSync(new URL('../apps/backend/package.json', import.meta.url)));
const orchestrator = JSON.parse(readFileSync(new URL('../apps/orchestrator/package.json', import.meta.url)));
const integrationCompose = readFileSync(new URL('../.github/ci/docker-compose.step10-test.yaml', import.meta.url), 'utf8');
const integrationScript = readFileSync(new URL('../.github/ci/putduk-step10-integration.sh', import.meta.url), 'utf8');

test('operational and isolated startup register all PM2 apps sequentially through one command', () => {
  const expected = [
    'pnpm --filter ./apps/frontend run pm2',
    'pnpm --filter ./apps/backend run pm2',
    'pnpm --filter ./apps/orchestrator run pm2',
  ].join(' && ');

  assert.equal(rootPackage.scripts['pm2-start-apps'], expected);
  assert.match(rootPackage.scripts['pm2-run'], /pnpm run pm2-start-apps/);
  assert.doesNotMatch(rootPackage.scripts['pm2-run'], /--parallel/);
  assert.match(integrationCompose, /pnpm run pm2-start-apps/);
  assert.doesNotMatch(integrationCompose, /--parallel\s+pm2/);
  assert.ok(frontend.scripts.pm2);
  assert.ok(backend.scripts.pm2);
  assert.ok(orchestrator.scripts.pm2);
  assert.match(integrationScript, /pm2 jlist/);
  assert.match(integrationScript, /All PM2 applications are online/);
  assert.match(integrationScript, /http:\/\/127\.0\.0\.1:4200\/auth\/login/);
  assert.match(integrationScript, /http:\/\/127\.0\.0\.1:3000\/auth\/can-register/);
  assert.match(integrationScript, /http:\/\/127\.0\.0\.1:5000\/auth\/login/);
  assert.match(integrationScript, /Step 10 integration passed/);
});

test('isolated Postiz HTTP access remains loopback-only and service network remains internal', () => {
  assert.match(integrationCompose, /127\.0\.0\.1:5500:5000/);
  assert.match(integrationCompose, /networks:\s+edge:\s+internal:\s+true/);
  assert.match(integrationScript, /Could not inspect Postiz host-port binding/);
  assert.match(integrationScript, /Could not inspect published ports for/);
});
