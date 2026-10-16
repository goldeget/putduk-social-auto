#!/usr/bin/env bash
set -Eeuo pipefail
set +x

if ! command -v sudo >/dev/null 2>&1 || ! sudo -n true; then
  echo 'Run-scoped root-owned-file cleanup test requires passwordless sudo.' >&2
  exit 1
fi

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"
: "${GITHUB_RUN_ATTEMPT:?GITHUB_RUN_ATTEMPT is required}"

test_run_id="$((10#$GITHUB_RUN_ID * 10 + 7))"
test_attempt="$GITHUB_RUN_ATTEMPT"
test_project="putdukstep10-${test_run_id}-${test_attempt}"
test_workdir="$RUNNER_TEMP/putduk-step10-${test_run_id}-${test_attempt}"
test_state="$RUNNER_TEMP/putduk-step10-state"
[[ ! -e "$test_workdir" && ! -e "$test_state" ]] || { echo 'Synthetic cleanup test path already exists.' >&2; exit 1; }
mock_bin="$(mktemp -d "$RUNNER_TEMP/putduk-cleanup-mock.XXXXXX")"
test_initialized=false
cleanup_fixture() {
  if [[ "$test_initialized" == true && -L "$test_workdir" && "$(dirname -- "$test_workdir")" == "$RUNNER_TEMP" ]]; then
    python3 - "$test_workdir" "$RUNNER_TEMP" <<'PY'
import pathlib, sys
path, parent = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
if path.parent == parent and path.name.startswith('putduk-step10-') and path.is_symlink():
    path.unlink()
PY
  fi
  if [[ "$test_initialized" == true && -d "$test_workdir" && ! -L "$test_workdir" ]]; then
    sudo chown -hR "$(id -u):$(id -g)" -- "$test_workdir" || true
    python3 - "$test_workdir" "$RUNNER_TEMP" <<'PY'
import pathlib, shutil, sys
path, parent = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
if path.parent == parent and path.name.startswith('putduk-step10-') and path.exists() and not path.is_symlink():
    shutil.rmtree(path)
PY
  fi
  if [[ "$test_initialized" == true && -f "$test_state" && ! -L "$test_state" ]]; then
    sudo chown "$(id -u):$(id -g)" -- "$test_state" || true
    python3 - "$test_state" "$RUNNER_TEMP" <<'PY'
import pathlib, sys
path, parent = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
if path.parent == parent and path.name == 'putduk-step10-state' and path.is_file() and not path.is_symlink():
    path.unlink()
PY
  fi
  python3 - "$mock_bin" "$RUNNER_TEMP" <<'PY'
import pathlib, shutil, sys
path, parent = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
if path.parent == parent and path.name.startswith('putduk-cleanup-mock.') and path.is_dir() and not path.is_symlink():
    shutil.rmtree(path)
PY
}
trap cleanup_fixture EXIT
mkdir -p "$mock_bin" "$test_workdir"
test_initialized=true
cat > "$mock_bin/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  compose|ps|volume|network|rm) exit 0 ;;
  *) echo 'unexpected Docker command in cleanup fixture' >&2; exit 2 ;;
esac
DOCKER
chmod 700 "$mock_bin/docker"

# Simulate files and nested directories created by root-running containers.
sudo mkdir -p "$test_workdir/redis-restore" "$test_workdir/upload-snapshot/nested"
sudo touch "$test_workdir/redis-restore/dump.rdb" "$test_workdir/upload-snapshot/nested/test.png"
[[ "$(stat -c '%u' "$test_workdir/upload-snapshot/nested/test.png")" == 0 ]]
cat > "$test_state" <<EOF
PROJECT=$test_project
WORKDIR=$test_workdir
ENV_FILE=$test_workdir/.env
EOF
chmod 600 "$test_state"
: > "$test_workdir/.env"

RUNNER_TEMP="$RUNNER_TEMP" \
GITHUB_RUN_ID="$test_run_id" \
GITHUB_RUN_ATTEMPT="$test_attempt" \
STEP10_PROJECT="$test_project" \
STEP10_STATE="$test_state" \
STEP10_WORKDIR="$test_workdir" \
PATH="$mock_bin:$PATH" \
bash .github/ci/step10-cleanup.sh

[[ ! -e "$test_workdir" && ! -e "$test_state" ]] || { echo 'Synthetic root-owned files remained after cleanup.' >&2; exit 1; }
echo 'Root-owned nested test files were safely normalized and removed from the synthetic run directory.'

protected_dir="$RUNNER_TEMP/putduk-cleanup-protected-${test_run_id}"
mkdir -m 700 "$protected_dir"
: > "$protected_dir/keep.txt"
ln -s "$protected_dir" "$test_workdir"
if RUNNER_TEMP="$RUNNER_TEMP" GITHUB_RUN_ID="$test_run_id" GITHUB_RUN_ATTEMPT="$test_attempt" \
    STEP10_PROJECT="$test_project" STEP10_STATE="$test_state" STEP10_WORKDIR="$test_workdir" \
    PATH="$mock_bin:$PATH" bash .github/ci/step10-cleanup.sh >/dev/null 2>&1; then
  echo 'Cleanup unexpectedly accepted a symlink target.' >&2
  exit 1
fi
[[ -L "$test_workdir" && -f "$protected_dir/keep.txt" ]] || { echo 'Symlink guard altered its protected target.' >&2; exit 1; }
python3 - "$test_workdir" "$RUNNER_TEMP" <<'PY'
import pathlib, sys
path, parent = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
if path.parent == parent and path.is_symlink(): path.unlink()
PY
python3 - "$protected_dir" "$RUNNER_TEMP" <<'PY'
import pathlib, shutil, sys
path, parent = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
if path.parent == parent and path.name.startswith('putduk-cleanup-protected-') and path.is_dir() and not path.is_symlink():
    shutil.rmtree(path)
PY
echo 'Symlink cleanup target was rejected without changing the protected directory.'

mkdir -m 700 "$test_workdir"
: > "$test_workdir/keep.txt"
cat > "$test_state" <<EOF
PROJECT=putdukstep10-wrong-run
WORKDIR=$test_workdir
ENV_FILE=$test_workdir/.env
EOF
if RUNNER_TEMP="$RUNNER_TEMP" GITHUB_RUN_ID="$test_run_id" GITHUB_RUN_ATTEMPT="$test_attempt" \
    STEP10_PROJECT="$test_project" STEP10_STATE="$test_state" STEP10_WORKDIR="$test_workdir" \
    PATH="$mock_bin:$PATH" bash .github/ci/step10-cleanup.sh >/dev/null 2>&1; then
  echo 'Cleanup unexpectedly accepted mismatched state metadata.' >&2
  exit 1
fi
[[ -f "$test_workdir/keep.txt" && -f "$test_state" ]] || { echo 'State mismatch did not preserve its unverified temp tree.' >&2; exit 1; }
echo 'Mismatched state metadata was rejected and its temp directory was preserved.'
