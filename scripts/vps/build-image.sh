#!/usr/bin/env bash
set -Eeuo pipefail

fail() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
[[ $# -eq 1 ]] || fail "사용법: build-image.sh <정확한-40자리-work-SHA>"
sha="$1"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || fail "전체 소문자 40자리 SHA를 입력하세요."
repo="$(git rev-parse --show-toplevel)"
cd "$repo"
[[ "$(git remote get-url origin)" =~ github\.com[:/]goldeget/putduk-social-auto(\.git)?$ ]] || fail "origin이 goldeget/putduk-social-auto가 아닙니다."
[[ -z "$(git status --porcelain)" ]] || fail "도구 checkout에 변경이 있습니다. 깨끗한 checkout에서 시작하세요."
git fetch --no-tags origin work
git cat-file -e "$sha^{commit}" 2>/dev/null || fail "입력 SHA를 가져올 수 없습니다."
git merge-base --is-ancestor "$sha" FETCH_HEAD || fail "입력 SHA는 원격 work 커밋 기록에 없습니다."

bash "$repo/scripts/vps/preflight.sh"
blocked="$(git ls-tree -r --name-only "$sha" | python3 -c 'import sys; p=[x.strip() for x in sys.stdin if x.strip()]; b=[x for x in p if ((x.rsplit("/",1)[-1].startswith(".env") or x.endswith((".pem",".key"))) and not x.endswith((".example",".sample",".template")))]; print("\n".join(b)); raise SystemExit(bool(b))')" || fail "소스 SHA에 비밀정보로 보이는 파일명이 있습니다."

image="putduk-social-auto:$sha"
if docker image inspect "$image" >/dev/null 2>&1; then
  existing_revision="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$image")"
  [[ "$existing_revision" == "$sha" ]] || fail "같은 SHA 태그가 다른 revision을 가리킵니다. 기존 image는 보존했습니다."
  fail "이 SHA 태그가 이미 존재합니다. 덮어쓰지 않았습니다. 검증 스크립트만 실행하세요."
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/putduk-build-${sha:0:12}.XXXXXXXX")"
cleanup() {
  local rc=$?
  if [[ -n "${monitor_pid:-}" ]]; then kill "$monitor_pid" 2>/dev/null || true; wait "$monitor_pid" 2>/dev/null || true; fi
  if [[ -n "${worktree_added:-}" ]]; then git -C "$repo" worktree remove --force "$worktree_added" >/dev/null 2>&1 || true; fi
  rm -rf -- "$tmp"
  exit "$rc"
}
trap cleanup EXIT INT TERM
source_tree="$tmp/source"
git worktree add --detach "$source_tree" "$sha" >/dev/null
worktree_added="$source_tree"

min_free="${PUTDUK_MIN_BUILD_FREE_GIB:-50}"
min_ram="${PUTDUK_MIN_BUILD_RAM_GIB:-8}"
min_abort="${PUTDUK_ABORT_BUILD_RAM_GIB:-2}"
monitor="${tmp}/memory-monitor.sh"
cat > "$monitor" <<'MONITOR'
#!/usr/bin/env bash
set -u
pid="$1"; threshold_kib="$2"; log="$3"
while kill -0 "$pid" 2>/dev/null; do
  free_kib="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
  if (( free_kib < threshold_kib )); then
    printf 'Available memory fell below safety floor; requesting build cancellation.\n' > "$log"
    kill -TERM "$pid" 2>/dev/null || true
    exit 0
  fi
  sleep 5
done
MONITOR
chmod 700 "$monitor"

for location in "$source_tree" "$(docker info --format '{{.DockerRootDir}}')"; do
  free_kib="$(df -Pk "$location" | awk 'END {print $4}')"
  (( free_kib >= min_free * 1024 * 1024 )) || fail "${location} has less than ${min_free} GiB free. No existing image/data was removed."
done
available_kib="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
(( available_kib >= min_ram * 1024 * 1024 )) || fail "MemAvailable is below ${min_ram} GiB."

log="$tmp/memory-watch.log"
build_log="$tmp/docker-build.log"
docker buildx build --load --platform linux/amd64 \
  --label "org.opencontainers.image.revision=$sha" \
  --label "org.opencontainers.image.source=https://github.com/goldeget/putduk-social-auto" \
  --build-arg "NEXT_PUBLIC_VERSION=$sha" \
  --tag "$image" --file "$source_tree/Dockerfile.dev" "$source_tree" >"$build_log" 2>&1 &
build_pid=$!
bash "$monitor" "$build_pid" "$((min_abort * 1024 * 1024))" "$log" &
monitor_pid=$!
set +e
wait "$build_pid"
build_rc=$?
set -e
kill "$monitor_pid" 2>/dev/null || true
wait "$monitor_pid" 2>/dev/null || true
monitor_pid=""
if [[ -s "$log" ]]; then cat "$log" >&2; fail "메모리 안전선 도달로 빌드를 취소했습니다. Docker daemon이 작업을 완전히 종료했는지 확인 전 재시도하지 마세요."; fi
(( build_rc == 0 )) || fail "Docker 빌드가 실패했습니다. 빌드 원문 로그는 비밀정보 노출 방지를 위해 표시하지 않았으며 임시 디렉터리 정리 시 삭제됩니다. 운영 이미지와 서비스는 변경하지 않았습니다."

bash "$repo/scripts/vps/verify-image.sh" "$sha" "$image"
printf '빌드 및 이미지 검사 완료. production 서비스는 전환하지 않았습니다.\n'
