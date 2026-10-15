import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export function validateUploadResponse(status, body, baseUrl) {
  const statusCode = Number(status);
  if (!Number.isInteger(statusCode) || ![200, 201].includes(statusCode)) {
    throw new Error(`Test image upload returned HTTP ${status}.`);
  }

  let media;
  try {
    media = JSON.parse(body);
  } catch {
    throw new Error('Image upload response is not valid JSON.');
  }

  if (!media || typeof media !== 'object' || Array.isArray(media)) {
    throw new Error('Image upload response must be a JSON object.');
  }
  if (
    typeof media.id !== 'string' ||
    media.id.length === 0 ||
    /[\t\r\n]/.test(media.id)
  ) {
    throw new Error('Uploaded media id is missing or invalid.');
  }
  if (typeof media.path !== 'string' || media.path.length === 0) {
    throw new Error('Uploaded media path is missing or invalid.');
  }

  let expectedOrigin;
  let mediaUrl;
  try {
    expectedOrigin = new URL(baseUrl).origin;
    mediaUrl = new URL(media.path);
  } catch {
    throw new Error('Uploaded media path is not a valid absolute URL.');
  }

  if (
    mediaUrl.origin !== expectedOrigin ||
    !mediaUrl.pathname.startsWith('/uploads/') ||
    mediaUrl.search !== '' ||
    mediaUrl.hash !== '' ||
    /[\t\r\n]/.test(media.path)
  ) {
    throw new Error('Image is not using isolated local upload storage.');
  }

  return { id: media.id, path: media.path };
}

function runCli() {
  const [, , status, responsePath, baseUrl] = process.argv;
  if (!status || !responsePath || !baseUrl) {
    throw new Error(
      'Usage: step10-upload-response.mjs STATUS RESPONSE_FILE BASE_URL'
    );
  }

  const response = validateUploadResponse(
    status,
    readFileSync(responsePath, 'utf8'),
    baseUrl
  );
  process.stdout.write(`${response.id}\t${response.path}\n`);
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  try {
    runCli();
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
