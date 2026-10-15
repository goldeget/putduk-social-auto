import { execFile as execFileCallback } from 'node:child_process';
import { promisify } from 'node:util';

const execFile = promisify(execFileCallback);

function safeErrorCode(error) {
  const code = error?.code;
  if (typeof code === 'string' && /^[A-Z0-9_]{1,40}$/.test(code)) return code;
  if (Number.isInteger(code) && code >= 0 && code <= 255) return `curl exit ${code}`;
  return 'request failed';
}

export async function waitForHttpStatus({
  request,
  expectedStatus = 200,
  retryStatuses = [502, 503],
  authenticationStatuses = [401, 403],
  timeoutMs = 180_000,
  pollIntervalMs = 4_000,
  requestTimeoutMs = 5_000,
  now = () => performance.now(),
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
} = {}) {
  if (typeof request !== 'function') throw new TypeError('An HTTP request function is required.');
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) throw new RangeError('timeoutMs must be positive.');

  const startedAt = now();
  const deadline = startedAt + timeoutMs;
  let attempts = 0;
  let lastResult = 'no response';
  let lastStatus;

  while (now() < deadline) {
    const remainingMs = deadline - now();
    const boundedRequestTimeoutMs = Math.max(1, Math.min(requestTimeoutMs, remainingMs));
    attempts += 1;

    try {
      const response = await request({ attempt: attempts, timeoutMs: boundedRequestTimeoutMs });
      lastStatus = response?.status;
      if (now() >= deadline) {
        lastResult = 'readiness deadline elapsed during request';
      } else if (lastStatus === expectedStatus) {
        return {
          status: lastStatus,
          attempts,
          elapsedMs: Math.max(0, Math.round(now() - startedAt)),
        };
      } else if (authenticationStatuses.includes(lastStatus)) {
        lastResult = `authentication failure HTTP ${lastStatus}`;
        throw readinessError(lastResult, { attempts, elapsedMs: now() - startedAt, status: lastStatus });
      } else if (retryStatuses.includes(lastStatus)) {
        lastResult = `transient HTTP ${lastStatus}`;
      } else {
        lastResult = `unexpected HTTP ${lastStatus ?? 'unknown'}`;
        throw readinessError(lastResult, { attempts, elapsedMs: now() - startedAt, status: lastStatus });
      }
    } catch (error) {
      if (error?.readinessFailure) throw error;
      lastResult = `request ${safeErrorCode(error)}`;
    }

    const remainingAfterRequestMs = deadline - now();
    if (remainingAfterRequestMs <= 0) break;
    await sleep(Math.min(pollIntervalMs, remainingAfterRequestMs));
  }

  const elapsedMs = Math.max(0, Math.round(Math.min(now(), deadline) - startedAt));
  throw readinessError(`HTTP readiness timed out after ${elapsedMs} ms; attempts=${attempts}; last=${lastResult}`, {
    attempts,
    elapsedMs,
    status: lastStatus,
  });
}

function readinessError(message, { attempts, elapsedMs, status }) {
  const error = new Error(`${message}; attempts=${attempts}; elapsed=${Math.max(0, Math.round(elapsedMs))}ms`);
  error.name = 'HttpReadinessError';
  error.attempts = attempts;
  error.elapsedMs = Math.max(0, Math.round(elapsedMs));
  error.status = status;
  error.readinessFailure = true;
  return error;
}

function parseArgs(args) {
  const values = new Map();
  for (let index = 0; index < args.length; index += 2) {
    const key = args[index];
    const value = args[index + 1];
    if (!key?.startsWith('--') || !value || values.has(key)) throw new Error('Invalid readiness command arguments.');
    values.set(key, value);
  }
  for (const key of ['--url', '--cookie-jar', '--output', '--connect-to']) {
    if (!values.has(key)) throw new Error(`Missing required readiness argument: ${key}.`);
  }
  const url = new URL(values.get('--url'));
  if (url.origin !== 'http://127.0.0.1:5500' || !/^\/api\/posts\/[A-Za-z0-9]+$/.test(url.pathname)) {
    throw new Error('Readiness URL must target the isolated Postiz schedule API.');
  }
  if (!/^[0-9.]+:[0-9]+:[0-9.]+:[0-9]+$/.test(values.get('--connect-to'))) {
    throw new Error('Invalid isolated Postiz connection target.');
  }
  return values;
}

async function main() {
  const values = parseArgs(process.argv.slice(2));
  const result = await waitForHttpStatus({
    request: async ({ timeoutMs }) => {
      const maxTime = (timeoutMs / 1_000).toFixed(3);
      const { stdout } = await execFile('curl', [
        '--silent', '--show-error', '--noproxy', '*', '--max-time', maxTime,
        '--connect-to', values.get('--connect-to'),
        '-o', values.get('--output'),
        '-b', values.get('--cookie-jar'),
        '-w', '%{http_code}',
        values.get('--url'),
      ], { encoding: 'utf8', maxBuffer: 1_024 });
      const status = Number(stdout);
      if (!Number.isInteger(status) || status < 100 || status > 599) {
        const error = new Error('curl returned an invalid HTTP status.');
        error.code = 'INVALID_HTTP_STATUS';
        throw error;
      }
      return { status };
    },
  });
  console.log(`Authenticated schedule API ready: HTTP ${result.status}; attempts=${result.attempts}; elapsed=${(result.elapsedMs / 1_000).toFixed(1)}s.`);
}

if (process.argv[1] && new URL(import.meta.url).pathname === process.argv[1]) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
