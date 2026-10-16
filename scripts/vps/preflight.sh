#!/usr/bin/env bash
set -Eeuo pipefail

MIN_BUILD_RAM_GIB="${PUTDUK_MIN_BUILD_RAM_GIB:-8}"
MIN_BUILD_DISK_GIB="${PUTDUK_MIN_BUILD_DISK_GIB:-50}"
MIN_TEST_DISK_GIB="${PUTDUK_MIN_TEST_DISK_GIB:-20}"

fail() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Linux ]] || fail "이 절차는 Linux VPS에서만 지원합니다."
[[ "$(uname -m)" == x86_64 ]] || fail "amd64/x86_64 호스트가 아닙니다."
cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc)"
(( cpu_count >= 4 )) || fail "온라인 CPU가 ${cpu_count}개입니다. 최소 4개가 필요합니다."
command -v docker >/dev/null || fail "Docker Engine CLI가 없습니다."
docker info >/dev/null 2>&1 || fail "Docker daemon에 연결할 수 없습니다."
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2가 필요합니다."
docker buildx version >/dev/null 2>&1 || fail "Docker Buildx가 필요합니다."
command -v git >/dev/null || fail "Git이 없습니다."
command -v python3 >/dev/null || fail "Python 3이 없습니다."

ram_kib="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
ram_gib=$((ram_kib / 1024 / 1024))
(( ram_gib >= MIN_BUILD_RAM_GIB )) || fail "사용 가능 RAM ${ram_gib} GiB; 빌드 시작 기준 ${MIN_BUILD_RAM_GIB} GiB 미만입니다."

repo_root="$(git rev-parse --show-toplevel)"
docker_root="$(docker info --format '{{.DockerRootDir}}')"
for path in "$repo_root" "$docker_root"; do
  [[ -d "$path" ]] || fail "경로를 확인할 수 없습니다: $path"
  avail_kib="$(df -Pk "$path" | awk 'END {print $4}')"
  avail_gib=$((avail_kib / 1024 / 1024))
  (( avail_gib >= MIN_BUILD_DISK_GIB )) || fail "$path 여유 공간 ${avail_gib} GiB; 빌드 시작 기준 ${MIN_BUILD_DISK_GIB} GiB 미만입니다. 아무것도 삭제하지 않았습니다."
  printf '디스크 여유: %s = %s GiB\n' "$path" "$avail_gib"
done
printf '사용 가능 메모리: %s GiB\n' "$ram_gib"
printf '온라인 CPU: %s\n' "$cpu_count"
printf '별도 격리 통합검사 시작 디스크 기준: %s GiB (이 스크립트는 통합검사를 실행하지 않음)\n' "$MIN_TEST_DISK_GIB"
docker --version
docker compose version
docker buildx version
printf '사전검사 통과. 실제 자원 적합성은 VPS에서 다시 확인해야 합니다.\n'
