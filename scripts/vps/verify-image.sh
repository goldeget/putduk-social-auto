#!/usr/bin/env bash
set -Eeuo pipefail

fail() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
DOCKER_BIN="${DOCKER_BIN:-docker}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[[ $# -ge 1 && $# -le 2 ]] || fail "사용법: verify-image.sh <40자리-source-SHA> [image-tag]"
sha="$1"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || fail "SHA는 소문자 40자리여야 합니다."
image="${2:-putduk-social-auto:$sha}"
[[ "$image" == "putduk-social-auto:$sha" ]] || fail "이미지 태그는 putduk-social-auto:<동일한 SHA>여야 합니다."
"$DOCKER_BIN" image inspect "$image" >/dev/null 2>&1 || fail "이미지가 로컬에 없습니다: $image"

metadata="$("$DOCKER_BIN" image inspect --format '{{json .}}' "$image" 2>/dev/null | "$PYTHON_BIN" "$SCRIPT_DIR/inspect-image-metadata.py" inspect)" || fail "이미지 metadata 검사 실패(Config.Env secret 검사 포함); 값은 출력하지 않았습니다."
mapfile -t fields < <(printf '%s\n' "$metadata" | tr -d '\r')
image_id="${fields[0]:-}"
os="${fields[1]:-}"
arch="${fields[2]:-}"
revision="${fields[3]:-}"
source="${fields[4]:-}"
image_user="${fields[5]:-}"
[[ "$os/$arch" == linux/amd64 ]] || fail "이미지 플랫폼이 linux/amd64가 아닙니다: $os/$arch"
[[ "$revision" == "$sha" ]] || fail "OCI revision이 입력 SHA와 다릅니다."
[[ "$source" == https://github.com/goldeget/putduk-social-auto ]] || fail "OCI source가 예상 저장소와 다릅니다."
[[ "$image_id" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "Docker image ID를 확인할 수 없습니다."
[[ -n "$image_user" && "$image_user" != 0 && "$image_user" != root && "$image_user" != 0:0 && "$image_user" != root:root ]] || fail "이미지 기본 사용자 설정이 비-root가 아닙니다."

if ! "$DOCKER_BIN" image history --no-trunc --format '{{.CreatedBy}}' "$image" 2>/dev/null | "$PYTHON_BIN" "$SCRIPT_DIR/inspect-image-metadata.py" history >/dev/null; then
  fail "이미지 빌드 이력에 비밀정보가 있을 수 있습니다. 원문은 출력하지 않았습니다."
fi

# Inspect only; do not start the application or attach a network.
"$DOCKER_BIN" run --rm --network none --read-only --cap-drop ALL --security-opt no-new-privileges --pids-limit 64 --memory 256m --user "$image_user" --entrypoint node "$image" -e '
const fs = require("node:fs"), path = require("node:path");
const roots = ["/app", "/opt", "/usr/src/app", "/usr/local/lib/node_modules"].filter(p => fs.existsSync(p));
const blockedNames = /(^|\/)(\.env($|\.)|id_rsa$|id_ed25519$|.*\.(pem|key)$|credentials\.json$)/i;
const privateKeyBlock = /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\r?\n([A-Za-z0-9+/=\r\n]{256,}?)\r?\n-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/m;
const tokenPatterns = [/gh[pousr]_[A-Za-z0-9]{30,}/, /xox[baprs]-[A-Za-z0-9-]+/, /sk_(?:live|test)_[A-Za-z0-9]{16,}/];
let bad = [];
function walk(p, depth) {
  if (depth > 14) return;
  let entries; try { entries = fs.readdirSync(p, {withFileTypes:true}); } catch { return; }
  for (const e of entries) {
    const q = path.join(p, e.name);
    if (blockedNames.test(q)) { bad.push(q); continue; }
    if (e.isSymbolicLink()) continue;
    if (e.isDirectory()) walk(q, depth + 1);
    else if (e.isFile()) {
      let st; try { st = fs.statSync(q); } catch { continue; }
      if (st.size > 2*1024*1024) continue;
      let b; try { b = fs.readFileSync(q); } catch { continue; }
      if (b.includes(0)) continue;
      const s = b.toString("utf8");
      const awsToken = [...s.matchAll(/AKIA[0-9A-Z]{16}/g)].some(m => m[0] !== "AKIAIOSFODNN7EXAMPLE");
      if (privateKeyBlock.test(s) || awsToken || tokenPatterns.some(r => r.test(s))) bad.push(q);
    }
  }
}
roots.forEach(p => walk(p, 0));
if (bad.length) { console.error("Potential secret material found in image paths:", [...new Set(bad)].join(", ")); process.exit(1); }
console.log("Image filesystem secret scan passed (heuristic; not a proof of absence).");
'
printf 'IMAGE_ID=%s\nSOURCE_SHA=%s\nIMAGE=%s\n' "$image_id" "$sha" "$image"
