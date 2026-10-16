import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const rootPackage = JSON.parse(
  readFileSync(new URL('../package.json', import.meta.url), 'utf8')
);
const dockerfile = readFileSync(
  new URL('../Dockerfile.production', import.meta.url),
  'utf8'
);
const nginx = readFileSync(
  new URL('../var/docker/nginx.conf', import.meta.url),
  'utf8'
);
const integrationCompose = readFileSync(
  new URL('../.github/ci/docker-compose.step10-test.yaml', import.meta.url),
  'utf8'
);
const integrationScript = readFileSync(
  new URL('../.github/ci/putduk-step10-integration.sh', import.meta.url),
  'utf8'
);

test('application restart does not download Prisma or mutate the database schema', () => {
  assert.doesNotMatch(
    rootPackage.scripts['pm2-run'],
    /prisma|db push|pnpm dlx/
  );
  assert.match(
    rootPackage.scripts['prisma-db-push'],
    /^prisma db push /
  );
  assert.equal(rootPackage.devDependencies.prisma, '6.5.0');
});

test('Step 10 applies schema once before starting Postiz with its default command', () => {
  const dependenciesStart = integrationScript.indexOf(
    'postiz-postgres postiz-redis temporal-postgresql temporal-elasticsearch temporal'
  );
  const schemaApply = integrationScript.indexOf(
    'dc_schema run --rm --no-deps db-schema'
  );
  const postizStart = integrationScript.indexOf(
    'dc up -d --wait --wait-timeout 900 postiz'
  );

  assert.ok(
    dependenciesStart >= 0,
    'database and Temporal dependencies must start'
  );
  assert.ok(
    schemaApply > dependenciesStart,
    'schema application follows healthy dependencies'
  );
  assert.ok(
    postizStart > schemaApply,
    'Postiz starts only after explicit schema application'
  );
  assert.doesNotMatch(integrationCompose, /^\s+command:/m);
});

test('production Docker image installs the exact lockfile and prunes development dependencies', () => {
  for (const packageName of [
    '@nestjs/cli',
    '@tailwindcss/postcss',
    '@types/bcrypt',
    '@types/multer',
    'sass',
    'tailwindcss',
    'tailwindcss-rtl',
  ]) {
    assert.equal(rootPackage.dependencies[packageName], undefined);
    assert.ok(rootPackage.devDependencies[packageName]);
  }
  assert.match(dockerfile, /^RUN pnpm install --frozen-lockfile$/m);
  assert.match(dockerfile, /pnpm install --prod --frozen-lockfile --ignore-scripts/);
  assert.match(dockerfile, /pnpm exec jest --runInBand --runTestsByPath apps\/backend\/src\/services\/auth\/auth\.registration-security\.spec\.ts/);
  assert.match(dockerfile, /find \/app\/node_modules -type f -name '\.env' -delete/);
  assert.match(dockerfile, /-name test -o -name tests -o -name __tests__/);
  assert.doesNotMatch(dockerfile, /-name fixtures| -o -name certificate/);
  assert.match(dockerfile, /happy-dom.*fetch\/certificate/);
  assert.doesNotMatch(dockerfile, /-name docs/);
  assert.match(dockerfile, /-name '\*\.test\.js'.*-name '\*\.md'/s);
  assert.match(dockerfile, /-name '\*\.spec\.ts' -exec rm -f/);
  assert.match(dockerfile, /rm -rf \/app\/scripts \/app\/reports/);
  assert.match(dockerfile, /^FROM node:22\.20-bookworm-slim@sha256:[a-f0-9]{64}(?: AS (?:build|runtime))?$/m);
  assert.match(dockerfile, /pm2@7\.0\.4/);
  assert.match(dockerfile, /prisma@6\.5\.0/);
  assert.match(dockerfile, /^USER www:www$/m);
  assert.match(dockerfile, /^CMD \["sh", "-c", "nginx && pnpm run pm2"\]$/m);
  assert.match(nginx, /^\s*listen 5000;$/m);
  assert.match(nginx, /^\s*pid\s+\/tmp\/nginx\/nginx\.pid;$/m);
  assert.match(nginx, /^\s*access_log\s+\/dev\/stdout;$/m);
  assert.match(nginx, /^\s*error_log\s+\/dev\/stderr warn;$/m);
  assert.match(dockerfile, /\/app\/apps\/frontend\/\.next\/cache/);
  assert.match(dockerfile, /\/app\/node_modules\/\.prisma/);
  assert.match(integrationScript, /docker run --rm --network none --user "\$\(id -u\):\$\(id -g\)" -v "\$upload_volume:\/source:ro"/);
  assert.match(integrationScript, /\$upload_restore_volume:\/uploads/);
  assert.doesNotMatch(integrationScript, /\$upload_restore_volume:\/target/);
  assert.match(
    rootPackage.scripts['prisma-generate'],
    /^pnpm exec prisma generate /
  );
});
