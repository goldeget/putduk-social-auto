import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(
  new URL(
    '../libraries/nestjs-libraries/src/database/prisma/posts/posts.service.ts',
    import.meta.url
  ),
  'utf8'
);

test('Temporal start failures are recorded with a safe error summary', () => {
  assert.match(source, /Temporal workflow start failed for post/);
  assert.match(source, /safeTemporalError/);
  assert.match(
    source,
    /password\|token\|authorization\|cookie\|secret\|api\[_-\]\?key/
  );
  assert.match(source, /REDACTED_JWT/);
});
