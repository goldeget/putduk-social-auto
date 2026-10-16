#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-image.sh"
SHA="62ed3585f9b2227a7956950c809b7140478efc90"
PYTHON_BIN="${PYTHON_BIN:-python3}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/putduk-verify-mock.XXXXXXXX")"
trap 'rm -rf -- "$tmp"' EXIT
mock="$tmp/docker"

cat > "$mock" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$1 $2" == "image inspect" ]]; then
  if [[ "${3:-}" == "--format" ]]; then
        cat <<JSON
  [{"Id":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","Os":"linux","Architecture":"${MOCK_ARCH:-amd64}","Config":{"User":"${MOCK_USER:-www:www}","Labels":{"org.opencontainers.image.revision":"${MOCK_REVISION:-62ed3585f9b2227a7956950c809b7140478efc90}","org.opencontainers.image.source":"https://github.com/goldeget/putduk-social-auto"},"Env":${MOCK_ENV:-[]}}}]
JSON
  fi
  exit 0
fi
if [[ "$1 $2" == "image history" ]]; then
  printf '%s\n' "${MOCK_HISTORY:-/bin/sh -c #(nop) ENV PATH=/usr/local/bin:/usr/bin:/bin}"
  exit 0
fi
if [[ "$1" == run ]]; then
  [[ "${MOCK_RUN_FAIL:-0}" == 0 ]] || exit 1
  printf 'Image filesystem secret scan passed (mock).\n'
  exit 0
fi
exit 0
MOCK
chmod +x "$mock"

run_case() {
  local expected="$1"; shift
  local output rc=0
  output="$(env DOCKER_BIN="$mock" PYTHON_BIN="$PYTHON_BIN" "$@" bash "$VERIFY_SCRIPT" "$SHA" 2>&1)" || rc=$?
  if [[ "$expected" == pass && $rc -ne 0 ]]; then printf '%s\n' "$output" >&2; return 1; fi
  if [[ "$expected" == fail && $rc -eq 0 ]]; then printf 'Expected mock failure but verification passed.\n' >&2; return 1; fi
  if [[ "$output" == *'mock-secret-value'* ]]; then printf 'A mock secret leaked to output.\n' >&2; return 1; fi
  printf 'mock case %s: exit=%s\n' "$expected" "$rc"
}

run_case pass
run_case fail MOCK_REVISION=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
run_case fail MOCK_ARCH=arm64
run_case fail MOCK_USER=root
run_case fail MOCK_ENV='["OPENAI_API_KEY=mock-secret-value"]'
run_case fail MOCK_HISTORY='/bin/sh -c #(nop) ENV OPENAI_API_KEY=mock-secret-value'
run_case fail MOCK_RUN_FAIL=1
printf 'All mocked image-verification cases passed.\n'
