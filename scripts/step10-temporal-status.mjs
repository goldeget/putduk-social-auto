import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

function normalizeStatus(value) {
  if (typeof value !== 'string') return undefined;
  const normalized = value
    .trim()
    .replace(/^WORKFLOW_EXECUTION_STATUS_/, '')
    .toUpperCase();
  return normalized || undefined;
}

export function getWorkflowStatus(jsonText) {
  let document;
  try {
    document = JSON.parse(jsonText);
  } catch {
    return undefined;
  }

  const statuses = [];
  const visit = (value) => {
    if (!value || typeof value !== 'object') return;
    if (Array.isArray(value)) {
      for (const item of value) visit(item);
      return;
    }
    for (const [key, item] of Object.entries(value)) {
      const normalizedKey = key.replaceAll(/[^a-z]/gi, '').toLowerCase();
      if (
        ['status', 'executionstatus', 'workflowexecutionstatus'].includes(
          normalizedKey
        )
      ) {
        const status = normalizeStatus(item);
        if (status) statuses.push(status);
      }
      visit(item);
    }
  };
  visit(document);
  return statuses.find((status) => status === 'RUNNING') ?? statuses[0];
}

export function isWorkflowRunning(jsonText) {
  return getWorkflowStatus(jsonText) === 'RUNNING';
}

function runCli() {
  const [, , jsonPath] = process.argv;
  if (!jsonPath) throw new Error('Usage: step10-temporal-status.mjs JSON_FILE');
  process.stdout.write(
    `${getWorkflowStatus(readFileSync(jsonPath, 'utf8')) ?? 'UNKNOWN'}\n`
  );
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
