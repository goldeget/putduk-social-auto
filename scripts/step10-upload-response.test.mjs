import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { validateUploadResponse } from './step10-upload-response.mjs';

const integration = readFileSync(
  new URL('../.github/ci/putduk-step10-integration.sh', import.meta.url),
  'utf8'
);

test('CI integration accepts HTTP 200 and 201 for a successful image upload', () => {
  assert.equal(
    /step10-upload-response\.mjs.*upload\.json.*BASE_URL/s.test(integration),
    true,
    'image upload must use the tested response validator'
  );
});

test('CI integration verifies the uploaded file exists in the isolated /uploads volume', () => {
  assert.match(integration, /dc exec -T postiz node -e/);
  assert.match(integration, /fs\.statSync\(imagePath\)/);
  assert.match(integration, /Uploaded image file is missing or empty/);
});

for (const status of [200, 201]) {
  test(`valid image upload response with HTTP ${status} returns media id and path`, () => {
    assert.deepEqual(
      validateUploadResponse(
        status,
        JSON.stringify({
          id: 'media-123',
          path: 'http://127.0.0.1:5500/uploads/2026/10/15/image.png',
        }),
        'http://127.0.0.1:5500'
      ),
      {
        id: 'media-123',
        path: 'http://127.0.0.1:5500/uploads/2026/10/15/image.png',
      }
    );
  });
}

for (const status of [400, 500]) {
  test(`image upload response with HTTP ${status} is rejected`, () => {
    assert.throws(
      () => validateUploadResponse(status, '{}', 'http://127.0.0.1:5500'),
      new RegExp(`HTTP ${status}`)
    );
  });
}

test('malformed JSON and missing media id or path are rejected', () => {
  assert.throws(
    () => validateUploadResponse(201, '{', 'http://127.0.0.1:5500'),
    /not valid JSON/
  );
  assert.throws(
    () =>
      validateUploadResponse(
        201,
        JSON.stringify({ path: 'http://127.0.0.1:5500/uploads/image.png' }),
        'http://127.0.0.1:5500'
      ),
    /id is missing/
  );
  assert.throws(
    () =>
      validateUploadResponse(
        200,
        JSON.stringify({ id: 'media-123' }),
        'http://127.0.0.1:5500'
      ),
    /path is missing/
  );
});

test('media path must point into the isolated upload directory on the test origin', () => {
  assert.throws(
    () =>
      validateUploadResponse(
        201,
        JSON.stringify({
          id: 'media-123',
          path: 'https://example.invalid/uploads/image.png',
        }),
        'http://127.0.0.1:5500'
      ),
    /isolated local upload storage/
  );
  assert.throws(
    () =>
      validateUploadResponse(
        201,
        JSON.stringify({
          id: 'media-123',
          path: 'http://127.0.0.1:5500/private/image.png',
        }),
        'http://127.0.0.1:5500'
      ),
    /isolated local upload storage/
  );
});
