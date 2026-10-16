import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export function inspectSnapshotResponse(status, body) {
  if (!Number.isInteger(status) || status < 100 || status > 599) {
    return { ok: false, status, errorType: 'invalid_http_status' };
  }

  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch {
    return { ok: false, status, errorType: 'invalid_json' };
  }

  if (status < 200 || status >= 300) {
    const rawType = parsed?.error?.type ?? parsed?.error?.root_cause?.[0]?.type;
    const errorType = typeof rawType === 'string' && /^[a-z0-9_]+$/i.test(rawType)
      ? rawType
      : 'http_error';
    return { ok: false, status, errorType };
  }

  const state = parsed?.snapshot?.state;
  return state === 'SUCCESS'
    ? { ok: true, status, state }
    : { ok: false, status, errorType: 'snapshot_not_successful', state: typeof state === 'string' ? state : undefined };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const status = Number(process.argv[2]);
  const bodyPath = process.argv[3];
  if (!Number.isInteger(status) || !bodyPath) {
    console.error('Usage: step10-es-snapshot-response.mjs HTTP_STATUS RESPONSE_FILE');
    process.exit(2);
  }

  const result = inspectSnapshotResponse(status, readFileSync(bodyPath, 'utf8'));
  if (!result.ok) {
    console.error(`Elasticsearch snapshot failed (HTTP ${result.status}, error_type=${result.errorType}).`);
    process.exit(1);
  }
  console.log(`Elasticsearch snapshot state: ${result.state}.`);
}
