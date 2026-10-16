#!/usr/bin/env bash
set -Eeuo pipefail
set +x

fail() {
  printf 'Step 10 cleanup error: %s\n' "$1" >&2
  exit 1
}

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"
: "${GITHUB_RUN_ATTEMPT:?GITHUB_RUN_ATTEMPT is required}"
: "${STEP10_PROJECT:?STEP10_PROJECT is required}"
: "${STEP10_STATE:?STEP10_STATE is required}"
: "${STEP10_WORKDIR:?STEP10_WORKDIR is required}"

expected_project="putdukstep10-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
expected_state="$RUNNER_TEMP/putduk-step10-state"
expected_workdir="$RUNNER_TEMP/putduk-step10-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
[[ "$STEP10_PROJECT" == "$expected_project" && "$STEP10_PROJECT" =~ ^putdukstep10-[0-9]+-[0-9]+$ ]] || fail 'project name does not match this Actions run.'
[[ "$STEP10_STATE" == "$expected_state" ]] || fail 'state file is outside the expected runner temp path.'
[[ "$STEP10_WORKDIR" == "$expected_workdir" ]] || fail 'work directory does not match this Actions run.'
[[ "$(realpath -m -- "$RUNNER_TEMP")" == "$RUNNER_TEMP" ]] || fail 'runner temp path is not canonical.'
[[ "$(dirname -- "$STEP10_WORKDIR")" == "$RUNNER_TEMP" ]] || fail 'work directory is not a direct child of runner temp.'
[[ ! -L "$STEP10_WORKDIR" && ! -L "$STEP10_STATE" ]] || fail 'refusing symlink cleanup target.'

state_matches=false
state_present=false
if [[ -e "$STEP10_STATE" ]]; then
  state_present=true
  [[ -f "$STEP10_STATE" ]] || fail 'state path is not a regular file.'
  state_project="$(sed -n 's/^PROJECT=//p' "$STEP10_STATE")"
  state_workdir="$(sed -n 's/^WORKDIR=//p' "$STEP10_STATE")"
  state_env_file="$(sed -n 's/^ENV_FILE=//p' "$STEP10_STATE")"
  if [[ "$state_project" == "$STEP10_PROJECT" && "$state_workdir" == "$STEP10_WORKDIR" && "$state_env_file" == "$STEP10_WORKDIR/.env" ]]; then
    state_matches=true
  else
    printf 'State metadata does not match run %s; skipping Compose down and temp-tree removal.\n' "$STEP10_PROJECT" >&2
  fi
fi

cleanup_failed=false
if [[ "$state_matches" == true && -f "$STEP10_WORKDIR/.env" && ! -L "$STEP10_WORKDIR/.env" ]]; then
  if ! docker compose --project-name "$STEP10_PROJECT" --env-file "$STEP10_WORKDIR/.env" \
      -f docker-compose.production.yaml -f .github/ci/docker-compose.step10-test.yaml \
      down --volumes --remove-orphans; then
    echo 'Compose down reported an error; continuing with run-label-scoped cleanup and verification.' >&2
  fi
fi

collect_ids() {
  local resource="$1" filter="$2"
  case "$resource:$filter" in
    containers:putduk) docker ps -aq --filter "label=putduk.step10.project=$STEP10_PROJECT" ;;
    containers:compose) docker ps -aq --filter "label=com.docker.compose.project=$STEP10_PROJECT" ;;
    volumes:putduk) docker volume ls -q --filter "label=putduk.step10.project=$STEP10_PROJECT" ;;
    volumes:compose) docker volume ls -q --filter "label=com.docker.compose.project=$STEP10_PROJECT" ;;
    networks:compose) docker network ls -q --filter "label=com.docker.compose.project=$STEP10_PROJECT" ;;
    *) fail 'internal cleanup resource selector is invalid.' ;;
  esac
}

remove_labeled() {
  local resource="$1" filter="$2" id listed
  local -a ids=()
  listed="$(collect_ids "$resource" "$filter")" || fail "could not list run-scoped $resource."
  if [[ -n "$listed" ]]; then mapfile -t ids <<< "$listed"; fi
  for id in "${ids[@]}"; do
    [[ -n "$id" ]] || continue
    case "$resource:$filter" in
      containers:*) [[ "$id" =~ ^[0-9a-f]{12,64}$ ]] || fail 'Docker returned an invalid container ID.'; docker rm --force "$id" || cleanup_failed=true ;;
      volumes:*) [[ "$id" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]] || fail 'Docker returned an invalid volume name.'; docker volume rm "$id" || cleanup_failed=true ;;
      networks:*) [[ "$id" =~ ^[0-9a-f]{12,64}$ ]] || fail 'Docker returned an invalid network ID.'; docker network rm "$id" || cleanup_failed=true ;;
    esac
  done
}

# Compose-owned and explicitly run-labeled resources are removed separately.
# No image/cache pruning or unscoped Docker deletion is performed.
remove_labeled containers putduk
remove_labeled containers compose
remove_labeled volumes putduk
remove_labeled volumes compose
remove_labeled networks compose

for spec in 'containers putduk' 'containers compose' 'volumes putduk' 'volumes compose' 'networks compose'; do
  read -r resource filter <<< "$spec"
  leftovers="$(collect_ids "$resource" "$filter")" || fail "could not verify run-scoped $resource cleanup."
  if [[ -n "$leftovers" ]]; then
    printf 'Run-scoped %s remain (%s label): %s\n' "$resource" "$filter" "${leftovers//$'\n'/, }" >&2
    cleanup_failed=true
  fi
done

if [[ "$state_present" == true && "$state_matches" != true ]]; then
  cleanup_failed=true
fi

if [[ -e "$STEP10_WORKDIR" ]]; then
  [[ -d "$STEP10_WORKDIR" && ! -L "$STEP10_WORKDIR" ]] || fail 'work directory is not a real directory.'
  symlink="$(find "$STEP10_WORKDIR" -type l -print -quit)"
  [[ -z "$symlink" ]] || fail 'work directory contains a symlink; refusing recursive ownership or deletion.'
  if [[ "$cleanup_failed" == false ]]; then
    runner_owner="$(id -u):$(id -g)"
    sudo chown -hR "$runner_owner" -- "$STEP10_WORKDIR"
    wrong_owner="$(find "$STEP10_WORKDIR" -xdev ! -uid "$(id -u)" -print -quit)"
    [[ -z "$wrong_owner" ]] || fail 'run temp tree still contains files not owned by the Actions runner.'
    rm -rf -- "$STEP10_WORKDIR"
    [[ ! -e "$STEP10_WORKDIR" ]] || fail 'run temp directory remains after deletion.'
  else
    echo 'Run temp tree retained because Docker resources did not all pass cleanup verification.' >&2
  fi
fi

if [[ -e "$STEP10_STATE" && "$cleanup_failed" == false ]]; then
  [[ "$state_matches" == true ]] || fail 'refusing to remove mismatched state file.'
  runner_owner="$(id -u):$(id -g)"
  sudo chown "$runner_owner" -- "$STEP10_STATE"
  rm -f -- "$STEP10_STATE"
  [[ ! -e "$STEP10_STATE" ]] || fail 'run state file remains after deletion.'
elif [[ -e "$STEP10_STATE" ]]; then
  echo 'Run state file retained because cleanup verification did not finish.' >&2
fi

[[ "$cleanup_failed" == false ]] || fail 'one or more run-scoped Docker resources remain.'
echo 'Verified: this run’s containers, networks, volumes, and temporary files were removed.'
