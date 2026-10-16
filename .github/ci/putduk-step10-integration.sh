#!/usr/bin/env bash
set -Eeuo pipefail
set +x

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
PROJECT="putdukstep10-${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}"
WORKDIR="${RUNNER_TEMP:?}/putduk-step10-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
ENV_FILE="$WORKDIR/.env"
BASE_URL='http://127.0.0.1:5500'
IMAGE_TAG="putduk-social-auto:step10-${GITHUB_SHA:?}"
STATS_FILE="$WORKDIR/container-stats.tsv"
DISK_STATS_FILE="$WORKDIR/disk-stats.tsv"
STATS_FLAG="$WORKDIR/collect-stats"
REDACTIONS_FILE="$WORKDIR/redactions.txt"
CURRENT_PHASE='initialization'

mkdir -p "$WORKDIR/es-snapshot" "$WORKDIR/upload-snapshot" "$WORKDIR/redis-restore"
: > "$STATS_FILE"
: > "$DISK_STATS_FILE"
: > "$REDACTIONS_FILE"
chmod 700 "$WORKDIR"
chmod 600 "$REDACTIONS_FILE"
# Elasticsearch runs as UID 1000 inside this isolated runner container.
chmod 777 "$WORKDIR/es-snapshot"
umask 077

POSTIZ_DB_PASSWORD="$(openssl rand -hex 32)"
REDIS_PASSWORD="$(openssl rand -hex 32)"
TEMPORAL_DB_PASSWORD="$(openssl rand -hex 32)"
JWT_SECRET="$(openssl rand -hex 48)"
for secret in "$POSTIZ_DB_PASSWORD" "$REDIS_PASSWORD" "$TEMPORAL_DB_PASSWORD" "$JWT_SECRET"; do
  printf '::add-mask::%s\n' "$secret"
  printf '%s\n' "$secret" >> "$REDACTIONS_FILE"
done

cat > "$ENV_FILE" <<EOF
PUBLIC_DOMAIN=putduk-step10.invalid
POSTIZ_IMAGE=$IMAGE_TAG
POSTIZ_DB_PASSWORD=$POSTIZ_DB_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
TEMPORAL_DB_PASSWORD=$TEMPORAL_DB_PASSWORD
JWT_SECRET=$JWT_SECRET
STEP10_BASE_URL=$BASE_URL
STEP10_ES_SNAPSHOT_DIR=$WORKDIR/es-snapshot
STEP10_EMPTY_DOTENV=$WORKDIR/empty.env
EOF
: > "$WORKDIR/empty.env"
chmod 600 "$ENV_FILE" "$WORKDIR/empty.env"
unset POSTIZ_DB_PASSWORD REDIS_PASSWORD TEMPORAL_DB_PASSWORD JWT_SECRET
cat > "$RUNNER_TEMP/putduk-step10-state" <<EOF
PROJECT=$PROJECT
WORKDIR=$WORKDIR
ENV_FILE=$ENV_FILE
EOF
chmod 600 "$RUNNER_TEMP/putduk-step10-state"

dc() {
  docker compose --project-name "$PROJECT" --env-file "$ENV_FILE" \
    -f "$ROOT/docker-compose.production.yaml" \
    -f "$ROOT/.github/ci/docker-compose.step10-test.yaml" "$@"
}

stop_sampler() {
  rm -f "$STATS_FLAG"
  if [[ -n "${STATS_PID:-}" ]]; then wait "$STATS_PID" 2>/dev/null || true; fi
}

mark_phase() {
  CURRENT_PHASE="$1"
  printf 'Step 10 phase: %s\n' "$CURRENT_PHASE"
}

resource_summary() {
  python3 - "$STATS_FILE" "$DISK_STATS_FILE" <<'PY'
import re, sys
from collections import defaultdict
scales = {'B':1, 'kB':1000, 'MB':1000**2, 'GB':1000**3, 'TB':1000**4, 'KiB':1024, 'MiB':1024**2, 'GiB':1024**3, 'TiB':1024**4}
def size(s):
    m = re.fullmatch(r'([0-9.]+)\s*([A-Za-z]+)', s.strip())
    return int(float(m.group(1))*scales.get(m.group(2), 1)) if m else 0
samples = defaultdict(lambda: [0, 0.0])
containers = defaultdict(lambda: [0, 0.0])
for line in open(sys.argv[1], encoding='utf-8', errors='replace'):
    parts = line.rstrip().split('|', 3)
    if len(parts) != 4: continue
    stamp, name, cpu, memory = parts
    match = re.search(r'[0-9.]+', cpu)
    ram = size(memory.split('/', 1)[0])
    percent = float(match.group()) if match else 0
    samples[stamp][0] += ram
    samples[stamp][1] += percent
    containers[name][0] = max(containers[name][0], ram)
    containers[name][1] = max(containers[name][1], percent)
if not samples:
    print('No container resource sample collected.')
else:
    print(f"Peak sampled aggregate container RAM: {max(x[0] for x in samples.values())/1024**3:.2f} GiB")
    print(f"Peak sampled summed container CPU: {max(x[1] for x in samples.values()):.1f}%")
    print(f"Resource samples: {len(samples)}")
    stamps = sorted(samples)
    print(f"Sampled service uptime window: {stamps[0]} to {stamps[-1]}")
    for name, (ram, cpu) in sorted(containers.items()):
        print(f"Peak {name}: RAM {ram/1024**3:.2f} GiB, CPU {cpu:.1f}%")
disk = []
for line in open(sys.argv[2], encoding='utf-8', errors='replace'):
    parts = line.split('|')
    if len(parts) == 3:
        disk.append((int(parts[1]), int(parts[2])))
if disk:
    print(f"Runner filesystem peak used: {max(x[0] for x in disk)/1024**3:.2f} GiB; minimum free: {min(x[1] for x in disk)/1024**3:.2f} GiB")
    print(f"Disk samples: {len(disk)}")
else:
    print('No runtime disk sample collected.')
PY
}

sanitize_log() {
  python3 - "$1" "$REDACTIONS_FILE" <<'PY'
import re, sys
text = open(sys.argv[1], encoding='utf-8', errors='replace').read()
secrets = [line.rstrip('\n') for line in open(sys.argv[2], encoding='utf-8') if line.strip()]
for secret in sorted(secrets, key=len, reverse=True):
    text = text.replace(secret, '[REDACTED]')
text = re.sub(r'(?i)\b(?:postgres(?:ql)?|redis)://[^\s\"\'<>]+', '[REDACTED_CONNECTION_URL]', text)
text = re.sub(r'(?i)(password|token|authorization|cookie|secret|api[_-]?key)(\s*[:=]\s*)(?:Bearer\s+)?[^\s,;]+', r'\1\2[REDACTED]', text)
text = re.sub(r'(?i)([?&](?:token|key|secret|password)=)[^&\s]+', r'\1[REDACTED]', text)
text = re.sub(r'(?i)(Bearer\s+)[A-Za-z0-9._~+/-]+=*', r'\1[REDACTED]', text)
text = re.sub(r'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+', '[REDACTED_JWT]', text)
lines = text.splitlines()
upstream = [line for line in lines if re.search(r'(?i)(connect\(\) failed|no live upstreams)', line)]
if upstream:
    print('Nginx upstream symptom samples (repetitive retries omitted):')
    for line in upstream[:2]:
        print(line[:500])
print('Postiz and PM2 logs (repetitive Nginx upstream retries omitted):')
for line in [line for line in lines if not re.search(r'(?i)(connect\(\) failed|no live upstreams)', line)][-100:]:
    print(line[:500])
PY
}

postiz_failure_diagnostics() {
  printf 'Failed integration phase: %s\n' "$CURRENT_PHASE"
  echo '### Postiz container state (selected fields only)'
  local container
  container="$(dc ps -q postiz 2>/dev/null || true)"
  if [[ -z "$container" ]]; then
    echo 'Postiz container ID unavailable; it may have failed before creation.'
  else
    docker inspect --format 'status={{.State.Status}} exit={{.State.ExitCode}} oom_killed={{.State.OOMKilled}} restart_count={{.RestartCount}}' "$container" 2>&1 || true
    echo '### Recent Postiz healthcheck attempts (selected fields only)'
    docker inspect --format '{{.State.Health.Status}}{{range .State.Health.Log}}{{printf "\nend=%s exit=%d output=%s" .End .ExitCode .Output}}{{end}}' "$container" 2>&1 | tail -8 || true
    echo '### Postiz process names (no arguments or environment values)'
    timeout 10s docker exec "$container" sh -c 'ps -eo pid,comm 2>/dev/null | head -40 || true' 2>&1 || true
    echo '### PM2 app status (names/status only)'
    timeout 10s docker exec "$container" sh -c 'pm2 jlist 2>/dev/null' > "$WORKDIR/pm2-status.json" || : > "$WORKDIR/pm2-status.json"
    pm2_online="$(python3 - "$WORKDIR/pm2-status.json" <<'PY'
import json, sys
try:
    apps = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception:
    apps = []
for app in apps:
    name = app.get('name', 'unknown')
    status = app.get('pm2_env', {}).get('status', 'unknown')
    restarts = app.get('pm2_env', {}).get('restart_time', 'unknown')
    pid = app.get('pid', 'unknown')
    print(f'{name}: status={status} restarts={restarts} pid={pid}')
print('yes' if any(a.get('pm2_env', {}).get('status') == 'online' for a in apps) else 'no')
PY
    )"
    echo "$pm2_online" | sed '$d'
    echo '### Postiz internal TCP port checks'
    timeout 10s docker exec "$container" node -e 'const net=require("node:net");const ports=[3000,4200,5000];let left=ports.length;for(const port of ports){const s=net.createConnection({host:"127.0.0.1",port,timeout:1500});s.once("connect",()=>{console.log(`${port}: open`);s.destroy()});s.once("timeout",()=>s.destroy(new Error("timeout")));s.once("error",()=>console.log(`${port}: closed`));s.once("close",()=>{if(--left===0)process.exit(0)})}' 2>&1 || true
    echo '### Postiz Prisma startup evidence'
    if timeout 10s docker exec "$container" sh -c 'test -x /app/node_modules/.bin/prisma' >/dev/null 2>&1; then
      echo 'Bundled Prisma CLI exists. Startup runs Prisma db push before the workspace PM2 command (shell && chain).'
    else
      echo 'Bundled Prisma CLI was not found at the expected path.'
    fi
    echo '### Postiz-only startup and error logs (sanitized; up to 100 lines)'
    dc logs --no-color --since=45m --tail=500 postiz > "$WORKDIR/postiz-failure-logs.txt" 2>&1 || true
    sanitize_log "$WORKDIR/postiz-failure-logs.txt"
    if grep -Eiq 'database is now in sync|already in sync' "$WORKDIR/postiz-failure-logs.txt"; then
      echo 'Prisma result: success message is present in Postiz logs.'
    elif [[ "$(echo "$pm2_online" | tail -n 1)" == yes ]]; then
      echo 'Prisma result: app process is online; startup shell executes Prisma db push before PM2 (&& chain), so db push completed.'
    else
      echo 'Prisma result: no successful marker or online PM2 process found; inspect the Postiz-only logs above.'
    fi
  fi

  if [[ -n "${WORKFLOW_ID:-}" ]]; then
    echo '### Temporal workflow and worker evidence (allowlisted fields only)'
    if [[ -s "${workflow_file:-}" ]]; then
      printf 'Workflow ID under test: %s; parsed status: ' "$WORKFLOW_ID"
      node scripts/step10-temporal-status.mjs "$workflow_file" 2>/dev/null || echo UNKNOWN
    else
      printf 'Workflow ID under test: %s; describe JSON unavailable.\n' "$WORKFLOW_ID"
    fi
    if [[ -s "${workflow_list_file:-}" ]]; then
      python3 - "$workflow_list_file" "$WORKFLOW_ID" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception:
    print('Exact workflow list result: invalid JSON.')
else:
    items = data if isinstance(data, list) else data.get('executions', data.get('workflowExecutions', [])) if isinstance(data, dict) else []
    matches = [item for item in items if isinstance(item, dict) and item.get('execution', {}).get('workflowId', item.get('workflowId', item.get('workflow_id'))) == sys.argv[2]] if isinstance(items, list) else []
    print(f'Exact workflow list result: {len(matches)} matching execution(s).')
    for item in matches[:1]:
        status = item.get('status', item.get('executionInfo', {}).get('status', 'UNKNOWN'))
        print(f'Listed workflow status: {status}')
PY
    fi
    if [[ -s "${task_queue_file:-}" ]]; then
      python3 - "$task_queue_file" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception:
    print('Main task queue result: invalid JSON.')
else:
    def find_pollers(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if key.lower() == 'pollers': return item if isinstance(item, list) else [] if item is None else None
                found = find_pollers(item)
                if found is not None: return found
        elif isinstance(value, list):
            for item in value:
                found = find_pollers(item)
                if found is not None: return found
        return None
    pollers = find_pollers(data)
    stats = data.get('stats', []) if isinstance(data, dict) else []
    backlog = sum(item.get('approximateBacklogCount', 0) for item in stats if isinstance(item, dict) and item.get('taskQueueType') == 'workflow')
    print(f'Main task queue recent pollers: {len(pollers) if pollers is not None else "not reported"}; workflow backlog: {backlog}.')
PY
    fi
    if [[ -s "${workflow_error_file:-}" ]]; then
      echo 'Temporal CLI error (redacted):'
      sanitize_log "$workflow_error_file"
    fi
    if [[ -s "${workflow_list_error_file:-}" ]]; then
      echo 'Temporal list CLI error (redacted):'
      sanitize_log "$workflow_list_error_file"
    fi
    if [[ -s "${task_queue_error_file:-}" ]]; then
      echo 'Temporal task-queue CLI error (redacted):'
      sanitize_log "$task_queue_error_file"
    fi
  fi

  echo '### All isolated service current memory/CPU (container stats only)'
  mapfile -t diagnostic_containers < <(docker ps -q --filter "name=$PROJECT" 2>/dev/null || true)
  if ((${#diagnostic_containers[@]})); then
    docker stats --no-stream --format '{{.Name}} cpu={{.CPUPerc}} memory={{.MemUsage}}' \
      "${diagnostic_containers[@]}" 2>&1 | head -20 || true
  else
    echo 'No running run-scoped containers found.'
  fi
}

on_error() {
  local status=$?
  local line="${BASH_LINENO[0]:-unknown}"
  printf '::error::Step 10 command failed at script line %s (phase: %s; exit: %s).\n' \
    "$line" "$CURRENT_PHASE" "$status" >&2
  return "$status"
}

on_exit() {
  local status=$?
  stop_sampler
  if (( status != 0 )); then
    printf '::error title=Step 10 integration failed::phase=%s; exit_code=%s\n' "$CURRENT_PHASE" "$status"
    echo '### Failure diagnostics collected before the workflow cleanup step'
    postiz_failure_diagnostics > "$WORKDIR/sanitized-failure-diagnostics.txt" 2>&1 || true
    cat "$WORKDIR/sanitized-failure-diagnostics.txt"
    {
      printf '\n### PUTDUK Step 10 sanitized failure diagnostics\n\n- Failed phase: %s\n\n```text\n' "$CURRENT_PHASE"
      cat "$WORKDIR/sanitized-failure-diagnostics.txt"
      printf '\n```\n'
    } >> "$GITHUB_STEP_SUMMARY"
    python3 - "$WORKDIR/sanitized-failure-diagnostics.txt" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding='utf-8', errors='replace').read().splitlines()
selected = []
for line in lines:
    if re.search(r'(?i)(^Failed integration phase:|^Workflow ID under test:|^Exact workflow list result:|^Listed workflow status:|^Main task queue (recent pollers|describe)|^Temporal describe exit code:|^Temporal workflow and worker evidence|status=|oom_killed=|restart_count=|^healthy$|^unhealthy$|^starting$|^end=.*exit=|^(frontend|backend|orchestrator):|^(3000|4200|5000):|Prisma result:|Bundled Prisma CLI|^Peak |^Sampled service|^Resource samples:|^Disk samples:|^Runner filesystem|^postiz[^| ]* cpu=|^Nginx upstream symptom samples:|^Postiz and PM2 logs:)', line):
        selected.append(line)
errors = [line for line in lines if re.search(r'(?i)(error|fatal|exception|uncaught|out of memory|\bERR\b|\bWARN\b)', line)
          and not re.search(r'(?i)(connect\(\) failed|no live upstreams)', line)]
selected.extend(errors[-12:])
if not selected:
    selected = lines[-20:]
message = '\n'.join(line[:300] for line in selected[-30:])[:7000]
message = message.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print(f'::error title=Step 10 sanitized Postiz diagnostics::{message}')
PY
    echo 'Step 10 stopped on a failed assertion or service command.' >&2
    echo 'Only redacted Postiz diagnostics are mirrored to the job summary and annotation.' >&2
  fi
  resource_summary
  exit "$status"
}
trap on_error ERR
trap on_exit EXIT

dc config --quiet
mark_phase 'start and health-check six isolated services'
touch "$STATS_FLAG"
(
  while [[ -f "$STATS_FLAG" ]]; do
    stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    df -B1 / | awk -v stamp="$stamp" 'NR == 2 { print stamp "|" $3 "|" $4 }' >> "$DISK_STATS_FILE" || true
    mapfile -t containers < <(docker ps -q --filter "name=$PROJECT" 2>/dev/null || true)
    if ((${#containers[@]})); then
      docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}' \
        "${containers[@]}" 2>/dev/null |
        while IFS= read -r row; do printf '%s|%s\n' "$stamp" "$row"; done >> "$STATS_FILE" || true
    fi
    sleep 5
  done
) &
STATS_PID=$!

echo 'Starting isolated services. Caddy is disabled and the app is bound to loopback only.'
dc up -d --wait --wait-timeout 900 \
  postiz-postgres postiz-redis temporal-postgresql temporal-elasticsearch temporal postiz
for service in postiz postiz-postgres postiz-redis temporal-postgresql temporal-elasticsearch temporal; do
  container="$(dc ps -q "$service")"
  [[ -n "$container" ]]
  health="$(docker inspect --format '{{.State.Health.Status}}' "$container")"
  [[ "$health" == healthy ]] || { echo "$service health check: $health" >&2; exit 1; }
done
[[ -z "$(dc ps -q caddy)" ]]

dc exec -T postiz pm2 jlist | python3 -c '
import json, sys
apps = json.load(sys.stdin)
expected = {"frontend", "backend", "orchestrator"}
found = {app.get("name"): app for app in apps}
for name in sorted(expected):
    app = found.get(name)
    status = (app or {}).get("pm2_env", {}).get("status", "missing")
    restarts = (app or {}).get("pm2_env", {}).get("restart_time", "unknown")
    print(f"PM2 {name}: {status}, restarts={restarts}")
    if status != "online":
        raise SystemExit(f"Required PM2 app is not online: {name} ({status})")
print("All PM2 applications are online.")
'

mark_phase 'wait up to 180 seconds for backend API readiness'
dc exec -T postiz node --input-type=module - < scripts/backend-readiness.mjs

mark_phase 'verify frontend and Nginx HTTP responses after backend readiness'
dc exec -T postiz node -e '
const assertResponse = async (name, url, expectedStatus) => {
  const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
  console.log(`${name} HTTP ${response.status}`);
  if (response.status !== expectedStatus) throw new Error(`${name} returned an unexpected HTTP status`);
};
(async () => {
  await assertResponse("Frontend :4200", "http://127.0.0.1:4200/auth/login", 200);
  await assertResponse("Nginx :5000", "http://127.0.0.1:5000/auth/login", 200);
})().catch((error) => { console.error(error.message); process.exit(1); });
'
echo 'All three Postiz HTTP endpoints responded with expected statuses.'

resolve_postiz_edge_ip() {
local app_container edge_network app_networks_json
app_container="$(dc ps -q postiz)"
edge_network="${PROJECT}_edge"
app_networks_json="$(docker inspect --format '{{json .NetworkSettings.Networks}}' "$app_container")"
python3 - "$edge_network" "$app_networks_json" <<'PY'
import ipaddress, json, sys
edge_name, raw = sys.argv[1:]
networks = json.loads(raw)
entry = networks.get(edge_name)
if not entry or not entry.get('IPAddress'):
    raise SystemExit('Postiz is not attached to its isolated edge network.')
try:
    address = ipaddress.ip_address(entry['IPAddress'])
except ValueError:
    raise SystemExit('Postiz edge network did not provide a valid private IP.')
if address.version != 4 or not address.is_private:
    raise SystemExit('Postiz edge network address is not a private IPv4 address.')
print(address)
PY
}

verify_postiz_isolation() {
local app_container app_networks_json
app_container="$(dc ps -q postiz)"
app_networks_json="$(docker inspect --format '{{json .NetworkSettings.Networks}}' "$app_container")"
mapfile -t postiz_networks < <(python3 - "$app_networks_json" <<'PY'
import json, sys
for name in json.loads(sys.argv[1]): print(name)
PY
)
for network in "${postiz_networks[@]}"; do
  internal="$(docker network inspect --format '{{.Internal}}' "$network")"
  [[ "$internal" == true ]] || { echo "Postiz network is not egress-isolated: $network" >&2; exit 1; }
done
app_port_state="$(docker inspect --format '{{json .NetworkSettings.Ports}}' "$app_container")"
python3 - "$app_port_state" <<'PY'
import json, sys
ports = json.loads(sys.argv[1]) or {}
published = {name: bindings for name, bindings in ports.items() if bindings}
if published:
    raise SystemExit(f'Unexpected Postiz host-published ports: {published}')
PY
}

POSTIZ_EDGE_IP="$(resolve_postiz_edge_ip)"
verify_postiz_isolation
echo "Postiz has no host-published ports; test traffic will use its private edge IP ${POSTIZ_EDGE_IP}."

postiz_curl() {
  curl --connect-to "127.0.0.1:5500:${POSTIZ_EDGE_IP}:5000" "$@"
}

for service in postiz-postgres postiz-redis temporal-postgresql temporal-elasticsearch temporal; do
  container="$(dc ps -q "$service")"
  port_state="$(docker inspect --format '{{json .NetworkSettings.Ports}}' "$container")"
  python3 - "$service" "$port_state" <<'PY'
import json, sys
service, raw = sys.argv[1:]
ports = json.loads(raw) or {}
published = {name: bindings for name, bindings in ports.items() if bindings}
if published:
    raise SystemExit(f'{service} unexpectedly publishes host ports: {published}')
PY
done
echo 'All six required services healthy; no host ports are published and all Postiz networks are internal.'

mark_phase 'login page, synthetic registration, and authenticated dashboard'
http="$(postiz_curl --silent --show-error --max-time 30 -o "$WORKDIR/login.html" -w '%{http_code}' "$BASE_URL/auth/login")"
[[ "$http" == 200 ]] || { echo "Login page returned HTTP $http." >&2; exit 1; }
echo 'Login page: HTTP 200.'

TEST_EMAIL="putduk-step10-${GITHUB_RUN_ID}@example.invalid"
TEST_PASSWORD="$(openssl rand -hex 24)"
printf '::add-mask::%s\n' "$TEST_PASSWORD"
printf '%s\n' "$TEST_PASSWORD" >> "$REDACTIONS_FILE"
export TEST_EMAIL TEST_PASSWORD
python3 - "$WORKDIR/register.json" <<'PY'
import json, os, sys
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    json.dump({'email': os.environ['TEST_EMAIL'], 'password': os.environ['TEST_PASSWORD'],
               'provider': 'LOCAL', 'company': 'PUTDUK CI Test'}, f)
PY
chmod 600 "$WORKDIR/register.json"
http="$(postiz_curl --silent --show-error --max-time 30 -o "$WORKDIR/register-response.json" \
  -c "$WORKDIR/cookies.txt" -H 'Content-Type: application/json' \
  --data-binary "@$WORKDIR/register.json" -w '%{http_code}' "$BASE_URL/api/auth/register")"
[[ "$http" == 200 ]] || { echo "Test registration returned HTTP $http." >&2; exit 1; }
python3 - "$WORKDIR/register-response.json" <<'PY'
import json, sys
if json.load(open(sys.argv[1], encoding='utf-8')).get('register') is not True:
    raise SystemExit('Test account registration response was not successful.')
PY
http="$(postiz_curl --silent --show-error --max-time 30 -o "$WORKDIR/login-response.json" \
  -b "$WORKDIR/cookies.txt" -c "$WORKDIR/cookies.txt" -H 'Content-Type: application/json' \
  --data-binary "@$WORKDIR/register.json" -w '%{http_code}' "$BASE_URL/api/auth/login")"
[[ "$http" == 200 ]] || { echo "Test login returned HTTP $http." >&2; exit 1; }
python3 - "$WORKDIR/login-response.json" <<'PY'
import json, sys
if json.load(open(sys.argv[1], encoding='utf-8')).get('login') is not True:
    raise SystemExit('Test account login response was not successful.')
PY
http="$(postiz_curl --silent --show-error --max-time 30 -o "$WORKDIR/self.json" \
  -b "$WORKDIR/cookies.txt" -w '%{http_code}' "$BASE_URL/api/user/self")"
[[ "$http" == 200 ]] || { echo "Authenticated dashboard API returned HTTP $http." >&2; exit 1; }
http="$(postiz_curl --silent --show-error --max-time 30 -o "$WORKDIR/dashboard.html" \
  -b "$WORKDIR/cookies.txt" -w '%{http_code}' "$BASE_URL/settings")"
[[ "$http" == 200 && -s "$WORKDIR/dashboard.html" ]] || { echo "Authenticated settings dashboard returned HTTP $http." >&2; exit 1; }
read -r TEST_USER_ID TEST_ORG_ID < <(python3 - "$WORKDIR/self.json" <<'PY'
import json, sys
u = json.load(open(sys.argv[1], encoding='utf-8'))
print(u['id'], u['orgId'])
PY
)
[[ -n "$TEST_USER_ID" && -n "$TEST_ORG_ID" ]]

INTEGRATION_ID="$(dc exec -T -e TEST_ORG_ID="$TEST_ORG_ID" -e TEST_USER_ID="$TEST_USER_ID" postiz node -e '
  const { PrismaClient } = require("@prisma/client");
  const p = new PrismaClient();
  (async () => {
    const membership = await p.userOrganization.findFirst({where:{userId:process.env.TEST_USER_ID,organizationId:process.env.TEST_ORG_ID}});
    if (membership?.role !== "SUPERADMIN") throw new Error("first account is not org admin");
    const row = await p.integration.create({data:{internalId:"putduk-step10-fake-instagram",organizationId:process.env.TEST_ORG_ID,name:"CI Fake Instagram (not connected)",providerIdentifier:"instagram",type:"social",token:"CI_FAKE_TOKEN_NO_CREDENTIAL",profile:"ci-test-only"}});
    process.stdout.write(row.id);
  })().catch(()=>process.exit(1)).finally(()=>p.$disconnect());
')"
[[ -n "$INTEGRATION_ID" ]]
echo 'Test account registered/logged in; authenticated dashboard and organization administrator role verified.'

mark_phase 'create and read a Postiz draft'
write_post_payload() {
  local output="$1" kind="$2" date="$3" image_text="$4" settings_text="$5" content="$6"
  python3 - "$output" "$kind" "$date" "$image_text" "$settings_text" "$content" "$INTEGRATION_ID" <<'PY'
import json, sys
out, kind, date, image_text, settings_text, content, integration = sys.argv[1:]
post = {'integration': {'id': integration}, 'value': [{'content': content, 'image': json.loads(image_text), 'delay': 0}]}
if settings_text != 'null': post['settings'] = json.loads(settings_text)
with open(out, 'w', encoding='utf-8') as f:
    json.dump({'type': kind, 'shortLink': False, 'date': date, 'tags': [], 'posts': [post]}, f)
PY
  chmod 600 "$output"
}

draft_date="$(date -u -d '+1 day' +%Y-%m-%dT%H:%M:%S.000Z)"
write_post_payload "$WORKDIR/draft.json" draft "$draft_date" '[]' null "CI-only draft ${GITHUB_RUN_ID}"
http="$(postiz_curl --silent --show-error --max-time 45 -o "$WORKDIR/draft-response.json" \
  -b "$WORKDIR/cookies.txt" -H 'Content-Type: application/json' \
  --data-binary "@$WORKDIR/draft.json" -w '%{http_code}' "$BASE_URL/api/posts")"
[[ "$http" == 200 || "$http" == 201 ]] || { echo "Draft create returned HTTP $http." >&2; exit 1; }
DRAFT_ID="$(python3 - "$WORKDIR/draft-response.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1], encoding='utf-8'))
if not isinstance(r, list) or not r or not r[0].get('postId'): raise SystemExit('No draft post id returned.')
print(r[0]['postId'])
PY
)"
http="$(postiz_curl --silent --show-error --max-time 30 -o "$WORKDIR/draft-read.json" \
  -b "$WORKDIR/cookies.txt" -w '%{http_code}' "$BASE_URL/api/posts/$DRAFT_ID")"
[[ "$http" == 200 ]]
python3 - "$WORKDIR/draft-read.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1], encoding='utf-8'))
if not r.get('posts') or r['posts'][0].get('state') != 'DRAFT': raise SystemExit('Draft did not persist.')
PY
echo 'Postiz draft creation/read-back passed.'

mark_phase 'upload fake image, schedule post, and verify Temporal timer'
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=' | base64 -d > "$WORKDIR/test.png"
http="$(postiz_curl --silent --show-error --max-time 60 -o "$WORKDIR/upload.json" \
  -b "$WORKDIR/cookies.txt" -F "file=@$WORKDIR/test.png;type=image/png" \
  -w '%{http_code}' "$BASE_URL/api/media/upload-simple")"
if ! media_response="$(node scripts/step10-upload-response.mjs "$http" "$WORKDIR/upload.json" "$BASE_URL")"; then
  echo 'Test image upload response validation failed.' >&2
  exit 1
fi
IFS=$'\t' read -r MEDIA_ID MEDIA_PATH <<< "$media_response"
UPLOAD_RELATIVE_PATH="${MEDIA_PATH#"$BASE_URL"/uploads/}"
[[ "$UPLOAD_RELATIVE_PATH" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}/[A-Za-z0-9._-]+\.png$ ]]
dc exec -T postiz node -e '
const fs = require("node:fs");
const imagePath = `/uploads/${process.argv[1]}`;
const image = fs.statSync(imagePath);
if (!image.isFile() || image.size === 0) throw new Error("Uploaded image file is missing or empty.");
' "$UPLOAD_RELATIVE_PATH"
echo 'Uploaded image response and isolated stored file verified.'

scheduled_date="$(date -u -d '+30 days' +%Y-%m-%dT%H:%M:%S.000Z)"
image_json="$(python3 -c 'import json,sys; print(json.dumps([{"id":sys.argv[1],"path":sys.argv[2]}]))' "$MEDIA_ID" "$MEDIA_PATH")"
write_post_payload "$WORKDIR/schedule.json" schedule "$scheduled_date" "$image_json" '{"post_type":"post"}' "CI-only scheduled ${GITHUB_RUN_ID}"
http="$(postiz_curl --silent --show-error --max-time 60 -o "$WORKDIR/schedule-response.json" \
  -b "$WORKDIR/cookies.txt" -H 'Content-Type: application/json' \
  --data-binary "@$WORKDIR/schedule.json" -w '%{http_code}' "$BASE_URL/api/posts")"
[[ "$http" == 200 || "$http" == 201 ]] || { echo "Test scheduling returned HTTP $http." >&2; exit 1; }
SCHEDULED_ID="$(python3 - "$WORKDIR/schedule-response.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1], encoding='utf-8'))
if not isinstance(r, list) or not r or not r[0].get('postId'): raise SystemExit('No scheduled post id returned.')
print(r[0]['postId'])
PY
)"
[[ "$SCHEDULED_ID" =~ ^[A-Za-z0-9]+$ ]]
WORKFLOW_ID="post_${SCHEDULED_ID}"
http="$(postiz_curl --silent --show-error --max-time 30 -o "$WORKDIR/schedule-read.json" \
  -b "$WORKDIR/cookies.txt" -w '%{http_code}' "$BASE_URL/api/posts/$SCHEDULED_ID")"
[[ "$http" == 200 ]]
python3 - "$WORKDIR/schedule-read.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1], encoding='utf-8'))
if not r.get('posts') or r['posts'][0].get('state') != 'QUEUE': raise SystemExit('Scheduled post is not QUEUE.')
PY
workflow_file="$WORKDIR/temporal-describe.json"
workflow_error_file="$WORKDIR/temporal-describe.stderr"
workflow_list_file="$WORKDIR/temporal-list.json"
workflow_list_error_file="$WORKDIR/temporal-list.stderr"
task_queue_file="$WORKDIR/temporal-task-queue.json"
task_queue_error_file="$WORKDIR/temporal-task-queue.stderr"
workflow_status='UNKNOWN'
workflow_describe_exit='not-run'
for attempt in $(seq 1 45); do
  if dc exec -T temporal temporal workflow describe --workflow-id "$WORKFLOW_ID" --address temporal:7233 --output json > "$workflow_file" 2> "$workflow_error_file"; then
    workflow_describe_exit=0
    workflow_status="$(node scripts/step10-temporal-status.mjs "$workflow_file")"
    if [[ "$workflow_status" == RUNNING ]]; then break; fi
  else
    workflow_describe_exit=$?
    workflow_status='UNAVAILABLE'
  fi
  if (( attempt == 45 )); then
    echo 'Temporal workflow did not reach RUNNING within the 90-second check window.' >&2
    printf 'Temporal describe exit code: %s; parsed workflow status: %s\n' "$workflow_describe_exit" "$workflow_status" >&2
    echo 'Querying the exact workflow ID and main task queue for independent evidence.' >&2
    if dc exec -T temporal temporal workflow list --query "WorkflowId = '$WORKFLOW_ID'" --limit 1 --address temporal:7233 --output json > "$workflow_list_file" 2> "$workflow_list_error_file"; then
      python3 - "$workflow_list_file" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception:
    print('Exact workflow list query returned invalid JSON.')
else:
    items = data if isinstance(data, list) else data.get('executions', data.get('workflowExecutions', [])) if isinstance(data, dict) else []
    print(f'Exact workflow list query succeeded; matching execution count: {len(items) if isinstance(items, list) else "unknown"}.')
PY
    else
      list_exit=$?
      printf 'Exact workflow list query exit code: %s\n' "$list_exit" >&2
      sanitize_log "$workflow_list_error_file" >&2
    fi
    if dc exec -T temporal temporal task-queue describe --task-queue main --address temporal:7233 --output json > "$task_queue_file" 2> "$task_queue_error_file"; then
      python3 - "$task_queue_file" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception:
    print('Main task queue describe returned invalid JSON.')
else:
    def find_pollers(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if key.lower() == 'pollers':
                    return item if isinstance(item, list) else [] if item is None else None
                found = find_pollers(item)
                if found is not None:
                    return found
        elif isinstance(value, list):
            for item in value:
                found = find_pollers(item)
                if found is not None:
                    return found
        return None
    pollers = find_pollers(data)
    stats = data.get('stats', []) if isinstance(data, dict) else []
    backlog = sum(item.get('approximateBacklogCount', 0) for item in stats if isinstance(item, dict) and item.get('taskQueueType') == 'workflow')
    print(f'Main task queue describe succeeded; recent workflow pollers: {len(pollers) if pollers is not None else "not reported"}; workflow backlog: {backlog}.')
PY
    else
      queue_exit=$?
      printf 'Main task queue describe exit code: %s\n' "$queue_exit" >&2
      sanitize_log "$task_queue_error_file" >&2
    fi
    if [[ -s "$workflow_error_file" ]]; then
      echo 'Sanitized Temporal workflow describe error:' >&2
      sanitize_log "$workflow_error_file" >&2
    fi
    exit 1
  fi
  sleep 2
done
echo "Image-backed schedule and Temporal timer passed; workflow status=$workflow_status; publish date is 30 days away."

mark_phase 'restart Postiz and Temporal and verify scheduled state'
echo 'Restarting Postiz and Temporal; checking that the post and timer survive.'
dc restart postiz temporal >/dev/null
dc up -d --wait --wait-timeout 900 postiz temporal >/dev/null
mark_phase 'wait up to 180 seconds for backend API readiness after restart'
dc exec -T -e BACKEND_READINESS_TIMEOUT_MS=180000 -e BACKEND_READINESS_INTERVAL_MS=4000 \
  -e BACKEND_READINESS_REQUEST_TIMEOUT_MS=3000 postiz node --input-type=module - < scripts/backend-readiness.mjs

mark_phase 'refresh isolated Postiz address and verify frontend and Nginx after restart'
POSTIZ_EDGE_IP="$(resolve_postiz_edge_ip)"
verify_postiz_isolation
echo "Refreshed isolated Postiz edge IP after restart: ${POSTIZ_EDGE_IP}."
dc exec -T postiz node -e '
const assertResponse = async (name, url, expectedStatus) => {
  const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
  console.log(`${name} HTTP ${response.status}`);
  if (response.status !== expectedStatus) throw new Error(`${name} returned an unexpected HTTP status`);
};
(async () => {
  await assertResponse("Frontend :4200", "http://127.0.0.1:4200/auth/login", 200);
  await assertResponse("Nginx :5000", "http://127.0.0.1:5000/auth/login", 200);
})().catch((error) => { console.error(error.message); process.exit(1); });
'

mark_phase 'retry authenticated scheduled post read after restart'
if ! node scripts/step10-restart-readiness.mjs \
  --url "$BASE_URL/api/posts/$SCHEDULED_ID" \
  --cookie-jar "$WORKDIR/cookies.txt" \
  --output "$WORKDIR/schedule-after-restart.json" \
  --connect-to "127.0.0.1:5500:${POSTIZ_EDGE_IP}:5000"; then
  echo 'Authenticated scheduled-post read did not become ready after restart; see HTTP status, attempt count, and elapsed time above.' >&2
  exit 1
fi
python3 - "$WORKDIR/schedule-after-restart.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1], encoding='utf-8'))
if not r.get('posts') or r['posts'][0].get('state') != 'QUEUE': raise SystemExit('Scheduled post lost after restart.')
PY
workflow_after_restart_file="$WORKDIR/temporal-after-restart.json"
workflow_after_restart_error_file="$WORKDIR/temporal-after-restart.stderr"
if ! dc exec -T temporal temporal workflow describe --workflow-id "$WORKFLOW_ID" --address temporal:7233 --output json \
  > "$workflow_after_restart_file" 2> "$workflow_after_restart_error_file"; then
  workflow_status='UNAVAILABLE'
else
  workflow_status="$(node scripts/step10-temporal-status.mjs "$workflow_after_restart_file" 2>/dev/null || echo UNKNOWN)"
fi
if [[ "$workflow_status" != RUNNING ]]; then
  printf 'Temporal timer did not survive restart; parsed status=%s.\n' "$workflow_status" >&2
  if [[ -s "$workflow_after_restart_error_file" ]]; then sanitize_log "$workflow_after_restart_error_file" >&2; fi
  exit 1
fi
echo "Fresh Temporal describe after restart confirmed Workflow ID ${WORKFLOW_ID} is RUNNING."
echo 'Postiz scheduled record and Temporal timer survived restart.'

mark_phase 'backup and restore Postiz PostgreSQL data'
echo 'Backing up and restoring the live Postiz test database into a separate database.'
dc exec -T postiz-postgres sh -ec 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$WORKDIR/postiz.dump"
[[ -s "$WORKDIR/postiz.dump" ]]
dc exec -T postiz-postgres sh -ec 'export PGPASSWORD="$POSTGRES_PASSWORD"; createdb -U "$POSTGRES_USER" putduk_step10_restore'
docker cp "$WORKDIR/postiz.dump" "$(dc ps -q postiz-postgres):/tmp/putduk-step10-postiz.dump" >/dev/null
dc exec -T postiz-postgres sh -ec 'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_restore --no-owner --no-privileges -U "$POSTGRES_USER" -d putduk_step10_restore /tmp/putduk-step10-postiz.dump'
restored_post="$(dc exec -T -e TEST_POST_ID="$SCHEDULED_ID" postiz-postgres sh -ec \
  'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -v post_id="$TEST_POST_ID" -U "$POSTGRES_USER" -d putduk_step10_restore -At' <<'SQL'
SELECT state FROM "Post" WHERE id = :'post_id';
SQL
)"
[[ "$restored_post" == 'QUEUE' ]] || { echo 'Restored Postiz DB is missing the scheduled post.' >&2; exit 1; }
restored_draft="$(dc exec -T -e TEST_POST_ID="$DRAFT_ID" postiz-postgres sh -ec \
  'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -v post_id="$TEST_POST_ID" -U "$POSTGRES_USER" -d putduk_step10_restore -At' <<'SQL'
SELECT state FROM "Post" WHERE id = :'post_id';
SQL
)"
[[ "$restored_draft" == 'DRAFT' ]]
echo 'Postiz DB dump restored; both draft and scheduled post states verified.'

mark_phase 'backup and restore Temporal PostgreSQL history'
echo 'Backing up and restoring Temporal execution history into a separate database.'
temporal_count="$(dc exec -T -e TEST_WORKFLOW_ID="$WORKFLOW_ID" temporal-postgresql sh -ec \
  'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -v workflow_id="$TEST_WORKFLOW_ID" -U "$POSTGRES_USER" -d temporal -At' <<'SQL'
SELECT count(*) FROM executions WHERE workflow_id = :'workflow_id';
SQL
)"
[[ "$temporal_count" =~ ^[1-9][0-9]*$ ]] || { echo 'Temporal DB is missing the scheduled workflow execution.' >&2; exit 1; }
dc exec -T temporal-postgresql sh -ec 'export PGPASSWORD="$POSTGRES_PASSWORD"; exec pg_dump -U "$POSTGRES_USER" -d temporal -Fc' > "$WORKDIR/temporal.dump"
[[ -s "$WORKDIR/temporal.dump" ]]
dc exec -T temporal-postgresql sh -ec 'export PGPASSWORD="$POSTGRES_PASSWORD"; createdb -U "$POSTGRES_USER" temporal_step10_restore'
docker cp "$WORKDIR/temporal.dump" "$(dc ps -q temporal-postgresql):/tmp/putduk-step10-temporal.dump" >/dev/null
dc exec -T temporal-postgresql sh -ec 'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_restore --no-owner --no-privileges -U "$POSTGRES_USER" -d temporal_step10_restore /tmp/putduk-step10-temporal.dump'
restored_temporal_count="$(dc exec -T -e TEST_WORKFLOW_ID="$WORKFLOW_ID" temporal-postgresql sh -ec \
  'export PGPASSWORD="$POSTGRES_PASSWORD"; exec psql -v workflow_id="$TEST_WORKFLOW_ID" -U "$POSTGRES_USER" -d temporal_step10_restore -At' <<'SQL'
SELECT count(*) FROM executions WHERE workflow_id = :'workflow_id';
SQL
)"
[[ "$restored_temporal_count" =~ ^[1-9][0-9]*$ ]]
echo 'Temporal PostgreSQL dump restored; scheduled workflow execution row is present.'

mark_phase 'verify Redis AOF restart and RDB restore'
echo 'Checking Redis AOF restart persistence and independent RDB backup restore.'
REDIS_TEST_KEY="putduk:step10:${GITHUB_RUN_ID}"
REDIS_TEST_VALUE="ci-only-${GITHUB_RUN_ATTEMPT}"
[[ "$(dc exec -T postiz-redis redis-cli --raw SET "$REDIS_TEST_KEY" "$REDIS_TEST_VALUE")" == 'OK' ]]
[[ "$(dc exec -T postiz-redis redis-cli --raw CONFIG GET appendonly | tail -n 1)" == 'yes' ]]
dc restart postiz-redis >/dev/null
redis_ready=false
for attempt in $(seq 1 30); do
  if [[ "$(dc exec -T postiz-redis redis-cli ping 2>/dev/null || true)" == 'PONG' ]]; then redis_ready=true; break; fi
  sleep 2
done
[[ "$redis_ready" == true ]]
[[ "$(dc exec -T postiz-redis redis-cli --raw GET "$REDIS_TEST_KEY")" == "$REDIS_TEST_VALUE" ]]
dc exec -T postiz-redis redis-cli --rdb /tmp/putduk-step10-redis.rdb >/dev/null
docker cp "$(dc ps -q postiz-redis):/tmp/putduk-step10-redis.rdb" "$WORKDIR/redis-restore/dump.rdb" >/dev/null
redis_restore="${PROJECT}-redis-restore"
docker run -d --name "$redis_restore" --label "putduk.step10.project=$PROJECT" --network none \
  -v "$WORKDIR/redis-restore:/data" redis:7.4.2-alpine \
  redis-server --appendonly no --dir /data --dbfilename dump.rdb --port 6379 --bind 0.0.0.0 >/dev/null
[[ "$(docker exec "$redis_restore" redis-cli ping)" == 'PONG' ]]
[[ "$(docker exec "$redis_restore" redis-cli --raw GET "$REDIS_TEST_KEY")" == "$REDIS_TEST_VALUE" ]]
echo 'Redis AOF survived restart and RDB backup restored in an isolated Redis container.'

mark_phase 'backup and restore uploaded file'
echo 'Backing up and restoring the uploaded test image volume.'
postiz_container="$(dc ps -q postiz)"
upload_volume="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/uploads"}}{{.Name}}{{end}}{{end}}' "$postiz_container")"
[[ "$upload_volume" == "${PROJECT}_postiz-uploads" ]] || { echo 'Upload volume is outside this test project.' >&2; exit 1; }
docker run --rm --network none -v "$upload_volume:/source:ro" -v "$WORKDIR/upload-snapshot:/backup" \
  "$IMAGE_TAG" node -e 'require("node:fs").cpSync("/source/.", "/backup", {recursive:true})'
source_hash="$(sha256sum "$WORKDIR/upload-snapshot/$UPLOAD_RELATIVE_PATH" | awk '{print $1}')"
upload_restore_volume="${PROJECT}-upload-restore"
docker volume create --label "putduk.step10.project=$PROJECT" "$upload_restore_volume" >/dev/null
docker run --rm --network none -v "$WORKDIR/upload-snapshot:/backup:ro" -v "$upload_restore_volume:/target" \
  "$IMAGE_TAG" node -e 'require("node:fs").cpSync("/backup/.", "/target", {recursive:true})'
restored_hash="$(docker run --rm --network none -v "$upload_restore_volume:/uploads:ro" \
  "$IMAGE_TAG" node -e 'const f=require("node:fs"),c=require("node:crypto");process.stdout.write(c.createHash("sha256").update(f.readFileSync("/uploads/"+process.argv[1])).digest("hex"))' "$UPLOAD_RELATIVE_PATH")"
[[ "$source_hash" == "$restored_hash" ]]
echo 'Uploaded-image volume backup restored; SHA-256 matched.'

mark_phase 'snapshot and restore Temporal Elasticsearch'
echo 'Creating a Temporal Elasticsearch snapshot and restoring it into an isolated cluster.'
repo_response="$(dc exec -T temporal-elasticsearch curl -fsS -X PUT -H 'Content-Type: application/json' \
  -d '{"type":"fs","settings":{"location":"/usr/share/elasticsearch/step10-snapshots/repository","compress":true}}' \
  http://127.0.0.1:9200/_snapshot/putduk_step10)"
python3 - "$repo_response" <<'PY'
import json, sys
if json.loads(sys.argv[1]).get('acknowledged') is not True: raise SystemExit('ES repository registration failed.')
PY
snapshot_exchange="$(dc exec -T temporal-elasticsearch curl -sS -w $'\nPUTDUK_HTTP_STATUS=%{http_code}' \
  -X PUT -H 'Content-Type: application/json' -d '{"include_global_state":true}' \
  'http://127.0.0.1:9200/_snapshot/putduk_step10/step10_snapshot?wait_for_completion=true')" || {
  echo 'Elasticsearch snapshot request failed before receiving an HTTP response.' >&2
  exit 1
}
snapshot_http_status="${snapshot_exchange##*$'\nPUTDUK_HTTP_STATUS='}"
snapshot_response="${snapshot_exchange%$'\nPUTDUK_HTTP_STATUS='*}"
[[ "$snapshot_http_status" =~ ^[0-9]{3}$ ]] || { echo 'Elasticsearch snapshot response did not include a valid HTTP status.' >&2; exit 1; }
snapshot_response_file="$WORKDIR/elasticsearch-snapshot-response.json"
printf '%s' "$snapshot_response" > "$snapshot_response_file"
node scripts/step10-es-snapshot-response.mjs "$snapshot_http_status" "$snapshot_response_file"

echo 'Terminating the far-future test workflow before stopping its worker services.'
dc exec -T temporal temporal workflow terminate --address temporal:7233 --workflow-id "$WORKFLOW_ID" --reason 'PUTDUK Step 10 CI cleanup' >/dev/null
dc stop postiz temporal temporal-elasticsearch >/dev/null

es_restore="${PROJECT}-es-restore"
docker run -d --name "$es_restore" --label "putduk.step10.project=$PROJECT" --network none --memory 2g --cpus 0.75 \
  -e discovery.type=single-node -e 'ES_JAVA_OPTS=-Xms512m -Xmx512m' \
  -e xpack.security.enabled=false -e path.repo=/usr/share/elasticsearch/step10-snapshots \
  -v "$WORKDIR/es-snapshot:/usr/share/elasticsearch/step10-snapshots:ro" \
  elasticsearch:7.17.27 >/dev/null
es_ready=false
for attempt in $(seq 1 90); do
  if docker exec "$es_restore" curl -fsS http://127.0.0.1:9200/ >/dev/null 2>&1; then es_ready=true; break; fi
  sleep 2
done
[[ "$es_ready" == true ]] || { echo 'Restored Elasticsearch service did not become ready.' >&2; exit 1; }
restore_repo="$(docker exec "$es_restore" curl -fsS -X PUT -H 'Content-Type: application/json' \
  -d '{"type":"fs","settings":{"location":"/usr/share/elasticsearch/step10-snapshots/repository","readonly":true}}' \
  http://127.0.0.1:9200/_snapshot/putduk_step10)"
python3 - "$restore_repo" <<'PY'
import json, sys
if json.loads(sys.argv[1]).get('acknowledged') is not True: raise SystemExit('Restored ES repository was not acknowledged.')
PY
restore_result="$(docker exec "$es_restore" curl -fsS -X POST -H 'Content-Type: application/json' \
  -d '{"include_global_state":true}' \
  'http://127.0.0.1:9200/_snapshot/putduk_step10/step10_snapshot/_restore?wait_for_completion=true')"
restore_failures="$(python3 -c 'import json,sys; print(len(json.loads(sys.argv[1]).get("snapshot",{}).get("failures",[])))' "$restore_result")"
[[ "$restore_failures" == 0 ]]
restored_indices="$(docker exec "$es_restore" curl -fsS 'http://127.0.0.1:9200/_cat/indices?format=json' | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
[[ "$restored_indices" =~ ^[1-9][0-9]*$ ]]
echo "Elasticsearch snapshot restored; index count: $restored_indices."

mark_phase 'scan service logs and report resource samples'
dc logs --no-color --since=45m --tail=10000 > "$WORKDIR/service-logs.txt" 2>&1 || true
serious_errors="$(python3 - "$WORKDIR/service-logs.txt" <<'PY'
import re, sys
pattern = re.compile(r'(?i)(fatal error|unhandled promise rejection|uncaught exception|out of memory|heap out of memory|PrismaClientInitializationError|PANIC:)')
print(sum(bool(pattern.search(line)) for line in open(sys.argv[1], encoding='utf-8', errors='replace')))
PY
)"
[[ "$serious_errors" == 0 ]] || { echo "Found $serious_errors serious error markers; raw logs withheld." >&2; exit 1; }
echo 'No fatal, unhandled, OOM, or Prisma-initialization markers found in service logs.'

stop_sampler
stats_summary="$(resource_summary)"
printf '%s\n' "$stats_summary"
{
  cat <<EOF

### PUTDUK Step 10 integration results

- Source revision: $GITHUB_SHA
- Six services healthy; Caddy excluded; no host ports published; Postiz is reached from the runner through its private IP on an internal network
- Test registration/login and dashboard API: passed (synthetic .invalid account)
- Draft create/read-back: passed
- Future schedule and Temporal workflow: passed; terminated before publish activity
- Postiz DB backup/restore: passed to separate DB
- Temporal PostgreSQL backup/restore: passed to separate DB
- Redis AOF restart + RDB backup/restore: passed
- Upload backup/restore SHA-256: passed
- Elasticsearch snapshot/restore: passed ($restored_indices indices)
- Serious service log markers: $serious_errors
- $stats_summary
- No real SNS credentials, OAuth, post, registry push, or public endpoint used.
EOF
} >> "$GITHUB_STEP_SUMMARY"
notice_metrics="$(printf '%s' "$stats_summary" | tr '\r\n' '  ')"
notice_metrics="${notice_metrics//'%'/'%25'}"
notice_metrics="${notice_metrics//$'\r'/'%0D'}"
notice_metrics="${notice_metrics//$'\n'/'%0A'}"
printf '::notice title=Step 10 integration passed::Six services healthy; no host ports published; frontend/backend/orchestrator PM2 online; HTTP checks on 3000, 4200, 5000 passed; login, draft, image upload, schedule, Temporal timer, restart, and isolated backup/restore checks passed. %s\n' "$notice_metrics"
