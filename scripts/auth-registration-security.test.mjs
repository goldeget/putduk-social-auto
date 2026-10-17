import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

const authService = readFileSync(
  new URL('../apps/backend/src/services/auth/auth.service.ts', import.meta.url),
  'utf8'
);
const initialAdmin = readFileSync(
  new URL('../apps/backend/src/services/auth/create-initial-admin.ts', import.meta.url),
  'utf8'
);
const integrationCompose = readFileSync(
  new URL('../.github/ci/docker-compose.step10-test.yaml', import.meta.url),
  'utf8'
);
const productionCompose = readFileSync(
  new URL('../docker-compose.production.yaml', import.meta.url),
  'utf8'
);
const integrationScript = readFileSync(
  new URL('../.github/ci/putduk-step10-integration.sh', import.meta.url),
  'utf8'
);
const productionDockerfilePath = new URL(
  '../Dockerfile.production',
  import.meta.url
);
const productionDockerfile = existsSync(productionDockerfilePath)
  ? readFileSync(productionDockerfilePath, 'utf8')
  : '';
const imageVerifier = readFileSync(
  new URL('../scripts/vps/verify-image.sh', import.meta.url),
  'utf8'
);

test('disabled registrations do not exempt the generic OAuth provider', () => {
  assert.doesNotMatch(
    authService,
    /process\.env\.DISABLE_REGISTRATION\s*!==\s*'true'\s*\|\|\s*provider\s*===\s*Provider\.GENERIC/
  );
  assert.match(
    authService,
    /if \(process\.env\.DISABLE_REGISTRATION !== 'true'\) \{\s*return true;\s*\}\s*\n\s*return false;/
  );
});

test('first account creation is private, serialized, and rechecked transactionally', () => {
  assert.match(initialAdmin, /\$executeRaw`LOCK TABLE "Organization" IN EXCLUSIVE MODE`/);
  assert.match(initialAdmin, /prisma\.\$transaction\(async \(tx\) =>/);
  assert.match(initialAdmin, /tx\.organization\.count\(/);
  assert.match(initialAdmin, /tx\.organization\.create\(/);
  assert.match(initialAdmin, /isSuperAdmin:\s*true/);
  assert.match(initialAdmin, /DISABLE_REGISTRATION !== 'true'/);
  assert.match(initialAdmin, /input\.setRawMode\(true\)/);
});

test('Step 10 verifies concurrent first registration and the production registration lockout', () => {
  assert.match(integrationCompose, /DISABLE_REGISTRATION:\s*'true'/);
  assert.match(integrationScript, /const clients = \[new PrismaClient\(\), new PrismaClient\(\)\]/);
  assert.match(integrationScript, /Promise\.allSettled\(attempts\)/);
  assert.match(integrationScript, /winners\.length !== 1/);
  assert.match(integrationScript, /sanitize_log "\$WORKDIR\/bootstrap-result\.log"/);
  assert.match(integrationScript, /exactly one successful request/i);
  assert.match(integrationScript, /\/api\/auth\/can-register/);
  assert.match(integrationScript, /GENERAL_EMAIL/);
  assert.match(integrationScript, /user\.isSuperAdmin/);
  assert.match(integrationScript, /Existing general-user Local login/);
  assert.match(productionCompose, /profiles: \[admin-bootstrap\]/);
  assert.match(productionCompose, /working_dir: \/app\/apps\/backend/);
  assert.match(productionCompose, /\/app\/apps\/backend\/dist\/apps\/backend\/src\/services\/auth\/create-initial-admin\.js/);
  assert.match(productionCompose, /create-initial-admin\.js/);
  assert.match(productionCompose, /- --skip-generate/);
  assert.match(productionCompose, /networks:\s+- app-data/);
});

test('production Docker image prunes development dependencies and test key fixtures', () => {
  assert.match(productionDockerfile, /pnpm install --prod --frozen-lockfile/);
  assert.match(productionDockerfile, /node_modules.*\.env/);
  assert.match(productionDockerfile, /node_modules.*(?:test|tests|__tests__)/);
});

test('image scanning still checks QuickJS wrapper text while ignoring embedded WASM base64 runs', () => {
  assert.match(imageVerifier, /quickjs-emscripten\/dist\/generated\/emscripten-module\.WASM_/);
  assert.ok(imageVerifier.includes('s.replace(/[A-Za-z0-9+/=]{256,}/g, "")'));
  assert.match(imageVerifier, /privateKeyBlock\.test\(scanText\)/);
});
