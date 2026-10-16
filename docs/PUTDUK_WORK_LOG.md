# PUTDUK SOCIAL AUTO 작업 기록

## 현재 상태

- 마지막 작업 일시: 2026-10-15 UTC
- 개발 단계: 운영 배포 설정 초안 작성 및 정적 검증
- 저장소/브랜치: `goldeget/putduk-social-auto` / `work`
- 작업 시작 전 확인한 로컬·원격 SHA: `d3ee3c576471496a1d5da550ce6b9249dc3dd9fa` (일치)
- 이번 작업의 기준 커밋: `d3ee3c576471496a1d5da550ce6b9249dc3dd9fa`
- 작업 시작 때 미커밋 변경: 없음
- 환경: Node.js `v22.20.0`, pnpm `10.6.1`

## 이번 변경

- `docker-compose.production.yaml`을 추가했다. HTTPS 프록시, Postiz 앱, PostgreSQL, Redis, Temporal, Temporal PostgreSQL 및 Elasticsearch를 구성하고 데이터 볼륨, 내부 네트워크, healthcheck, 재시작 정책을 명시했다.
- 기존 `docker-compose.yaml`은 변경하지 않았다.
- `.env.production.example`을 추가했다. 실제 비밀값은 포함하지 않으며 운영값은 저장소 밖에 둘 것을 문서화했다.
- `docs/production-deployment.md`에 서비스 역할, 보안, 백업/복구, 업데이트 및 미검증 항목을 기록했다.
- 이번 기준 전 마지막 검증 커밋은 `d3ee3c576471496a1d5da550ce6b9249dc3dd9fa`다. 이번 변경의 최종 커밋 SHA는 작업 기록에 반복 기입하지 않고 완료 보고에서 확인한다.

## 이전 코드 검증 기록

- 기준 커밋에서 완료된 Jest 테스트: 1 suite, 2 tests 통과.
- 기준 커밋에서 백엔드 빌드, 오케스트레이터 빌드, 프런트엔드 TypeScript 검사가 통과했다고 기존 기록에 남아 있다. 이번 작업 후 재실행 결과는 아래에 추가한다.
- 실제 SNS 계정 연결/게시, 운영용 Compose 실행, 실제 서버 메모리, 복원 훈련은 검증되지 않았다.

## 이번 작업 검증

- `docker compose --env-file .env.production.example -f docker-compose.production.yaml config --quiet`: 통과.
- Compose 정적 구조 검사: 7개 서비스 모두 restart 정책과 healthcheck 존재, 환경 참조 16개 모두 예제에 존재, 공개 포트는 Caddy의 80/443만, DB/Redis/Temporal/Elasticsearch 포트 비공개, 영구 named volume 8개, Spotlight/Temporal UI/Admin Tools 제외를 확인했다.
- `pnpm test --runInBand`: 1 suite, 2 tests 통과.
- `pnpm run build:backend`: 종료 코드 0, 통과.
- `pnpm run build:orchestrator`: 종료 코드 0, 통과.
- `pnpm exec tsc -p apps/frontend/tsconfig.json --noEmit`: 종료 코드 0, 통과.
- `git diff --check`: 통과.
- 실제 secret 값은 추가하지 않았다. `.env.production.example`에는 명시적인 대체용 placeholder만 있다. 테스트 실행으로 `reports/junit.xml`이 생성 변경되어 원래 저장소 상태로 복구했다.
- 컨테이너 실행, HTTPS, 실제 백업 복원 및 게시: 실행하지 않음.

## 복구 및 운영 주의

1. 새 클라우드 환경에서 먼저 GitHub `work` 원격 SHA와 이 기록을 확인한다.
2. `source /workspace/.cloud-onboarding/activate.sh`를 실행하고 저장소 루트에서 Node.js/pnpm 버전을 확인한다.
3. Jest와 빌드/타입 검사 결과를 재확인한다.
4. 실제 운영 비밀값은 절대 저장소에 만들거나 커밋하지 않는다. 향후 서버에서는 `/etc/putduk/.env.production` 같은 저장소 밖 파일을 사용한다.
5. Compose는 이 작업에서 실제 실행하지 않았다. Postiz 이미지 digest, 최초 관리자 설정, 컨테이너 healthcheck, 복구, 메모리/디스크 요구량은 서버 또는 격리 운영 복제본에서 검증해야 한다.
6. `docker compose down -v` 사용 금지: named volume의 DB 및 미디어를 제거할 수 있다.
7. SNS 실제 인증/게시, 유료 서버, DNS/외부 배포, `main` 변경은 이 작업 범위에 포함되지 않는다.

## 다음 작업

이번 설정 초안의 검증 결과를 확인한 뒤 사용자 승인 전까지 다음 개발 단계는 시작하지 않는다.

## 6단계 — 격리 런타임 및 복구 점검 (2026-10-15)

- 작업 시작 시 `work` 로컬/원격 SHA가 `89ac93e5f59338010170afdd69b99105f3b13f6c`으로 같았고, 작업 트리는 깨끗했다. Node.js `v22.20.0`, pnpm `10.6.1`을 확인했다.
- 현재 `work`의 애플리케이션 런타임 소스는 시작 시점 `origin/main` (`0956d49ab79acb314f700779b92677830ac83a9d`)과 동일하다. work 전용 차이는 Jest 설정/테스트 및 문서·운영 Compose다.
- 공식 GHCR `latest`의 manifest digest와 amd64/arm64 manifest를 메타데이터로만 확인했다. 이 digest가 어느 소스 revision에서 빌드됐는지 확인할 OCI revision 증거가 없어 이미지를 pull/run하지 않았다.
- `Dockerfile.dev`로 work 소스 이미지를 빌드해 보았으나 Next.js가 Google Fonts를 Node 22.20 빌드 과정에서 가져오지 못해 완료하지 못했다. TLS 검증을 끄지 않았다. 코드나 Compose는 수정하지 않았다.
- `/tmp` 테스트 env와 고유 Compose 프로젝트 `putduk-step6-isolated`를 사용했다. Postiz 앱/Caddy는 시작하지 않았다. Postiz PostgreSQL, Temporal PostgreSQL, Redis, Elasticsearch는 healthy였고 Elasticsearch 단독 health도 green이었다. 클라우드 Docker의 프록시 변수가 내부 호출에 개입했고, 임시 테스트 override로만 프록시 변수와 Temporal health 주소를 바꿨다.
- 실제 Temporal은 컨테이너 loopback이 아닌 컨테이너 IP에서 listen했다. 운영 Compose의 `127.0.0.1:7233` healthcheck는 실패했고, 테스트 전용 `temporal:7233` 대상 healthcheck는 성공했다. 운영 Compose 수정은 승인 대기이며 적용하지 않았다.
- 임의 문자열만 담은 별도 Postiz test DB 테이블을 `pg_dump`/`pg_restore`로 새 독립 DB에 복원해 조회했다. 실제 Postiz schema/게시물 데이터는 앱이 실행되지 않아 검증하지 못했다.
- Temporal 내부에 외부 worker가 없는 가짜 schedule을 생성했다. Temporal 컨테이너 재시작 뒤 목록을 다시 조회했고, 전체 Temporal PostgreSQL 백업과 Elasticsearch 데이터 볼륨을 새 격리 서비스로 복원한 뒤 새 Temporal이 해당 schedule을 열거하는 것을 확인했다. 이는 Postiz 앱의 예약 생성 경로를 검증한 것이 아니다.
- Redis AOF(`appendonly=1`) key의 컨테이너 재시작 후 유지와 별도 AOF 볼륨 복원을 확인했다. 업로드 볼륨에 넣은 가짜 파일은 별도 볼륨 복원 후 SHA-256이 일치했다. Elasticsearch의 격리 fixture index도 볼륨 백업/복원 후 조회했다.
- 중복 외부 게시 방지는 실행하지 않았다. workflow 소스에는 불확실한 게시 응답에서 자동 재시도를 억제하는 처리가 보이나 SNS 미연결 상태에서 코드 검토만 했다.
- 부분 의존 서비스 자원 표본은 약 1.0 GiB RAM, 유휴 CPU 낮은 한 자릿수 미만이었다. 앱은 실행되지 않았으므로 전체 운영 메모리 측정이 아니다. Docker daemon 수치는 5 CPU/약 33.3 GiB, 실행 cgroup 한도는 4 CPU/32 GiB로 목표 VPS 6 CPU/12 GiB와 다르다.
- 이미지 빌드/시험 중 클라우드 overlay 디스크는 32 GiB 중 약 30 GiB 사용까지 찼고 Elasticsearch flood-stage 차단이 발생했다. 내 테스트 프로젝트의 컨테이너·볼륨·이미지와 BuildKit cache를 정리한 후 32 GiB 중 약 2.4 GiB 사용으로 돌아왔다. 기존 `postiz-cloud-*` 컨테이너와 기존 익명 볼륨은 보존했다. 임시 env, 백업 파일 및 build context도 정리했다.
- 운영 `.gitignore`는 `.env` 파일명만 무시하고 `.env.production`은 무시하지 않는다. `.env.production.example`은 추적 중이며 테스트 중 실제 비밀값은 저장하지 않았다. 최소 보완안은 `.env.production`, `.env.production.local`, `.env.*.local`을 ignore 목록에 추가하는 것이다. `.env.production.example`은 그대로 추적 가능하다. 이번에는 `.gitignore`를 수정하지 않았다.
- 이번 단계 결과: 운영 이미지/source 매칭, Postiz 부팅/로그인/콘텐츠/예약 통합, 12GB 목표 서버 메모리, 외부 HTTPS, 실제 Postiz 데이터 복구 및 중복 외부 게시 방지는 미검증이다. 운영 배포 판정은 NO-GO다.
- 이번 기록 갱신 외 소스 코드 및 운영 Compose는 변경하지 않았다. 최종 기록 커밋 SHA는 보고서에 제시한다.

## 7단계 — 운영 설정 최소 수정 및 이미지 빌드 원인 점검 (2026-10-15)

- 시작 시 `work` 로컬 HEAD와 GitHub 원격 `work`가 `bd5debb437e7ec72b4968e2161038ba7eeff3d59`로 일치했고 작업 트리는 깨끗했다. 원격 `main`은 `0956d49ab79acb314f700779b92677830ac83a9d`였다. 사용자 기준 커밋에서 추가 변경은 없었다.
- `.gitignore`에 `.env.production`, `.env.production.local`, `.env.*.local`을 추가했다. `git check-ignore -v`에서 운영 파일과 `.env.stage.local`이 무시됐고, `.env.production.example`은 무시되지 않으며 계속 추적되는 것을 확인했다. 실제 운영 env 파일은 저장소에 없었다.
- `docker-compose.production.yaml`의 Temporal healthcheck 주소를 `127.0.0.1:7233`에서 `temporal:7233`으로 수정했다. Compose 문법 검사가 통과했고, 독립 Compose 프로젝트에서 Temporal 1.28.1, PostgreSQL 16.9, Elasticsearch 7.17.27만 기동해 모두 healthy가 됐다. Temporal healthcheck 명령 및 CLI probe가 `SERVING`을 확인했다. Temporal host port binding은 비어 있었고 Compose의 내부 DB/Redis/Temporal/Elasticsearch 포트도 외부 publish되지 않았다. 개발용 `docker-compose.yaml`은 수정하지 않았다.
- 해당 격리 테스트의 프로젝트 컨테이너·네트워크·두 named volume 및 테스트에서 새로 받은 이미지 태그만 제거했다. 이전에 있던 `postiz-cloud-*` 컨테이너, 두 기존 볼륨, 사전 이미지 세 개를 보존했다. 정리 후 디스크는 32 GiB 중 약 2.4 GiB 사용 상태로 돌아왔다.
- 환경 활성화로 Node.js `v22.20.0`은 선택됐으나, `pnpm` shim은 Corepack `lastKnownGood.json`의 없는 `12.11.2`를 찾아 실패했다. 환경을 수정하거나 재설치하지 않았다. 설치돼 있던 고정 `pnpm 10.6.1` CJS 실행 파일을 직접 호출해 Jest 1 suite/2 tests, 백엔드 빌드, 오케스트레이터 빌드, 프런트엔드 TypeScript 검사를 실행했고 모두 통과했다. Jest 실행으로 변경된 `reports/junit.xml`은 초기 트리가 깨끗했던 사실에 따라 원본으로 복구했다.
- Docker 이미지 빌드는 다시 시도하지 않았다. 앞 단계에서 실패한 Dockerfile 단계는 `RUN NODE_OPTIONS="--max-old-space-size=4096" pnpm run build`이며, Next.js `16.3.1`의 Google font 처리에서 Plus Jakarta Sans 요청이 실패했다. 저장된 프런트엔드 로그에는 Google Fonts API fetch 재시도 후 실패가 기록돼 있다. 저장소에서 `next/font/google` 호출은 앱/provider/extension layout과 새 layout component 등 4곳에서 확인했다. 현재 환경의 Node `22.20.0`은 proxy 환경변수를 자동 사용하는 `--use-env-proxy` 옵션을 지원하지 않았고, Node fetch는 `EAI_AGAIN`으로 실패했으나 proxy 경유 `curl`은 Google Fonts에서 HTTP 200을 받았다. 따라서 현 증거는 TLS 인증서 문제보다 컨테이너 빌드 Node 프로세스의 proxy/DNS 경로 문제를 가리킨다. TLS 검증은 끄지 않았다.
- UI를 그대로 유지하는 우선 경로는 Google Fonts API에 정상 접근 가능한 격리 빌드 러너에서 기존 `next/font/google` 코드를 그대로 빌드하는 것이다. 오프라인 빌드는 동일한 공식 글꼴 파일/가중치를 `next/font/local`로 자체 호스팅하는 방법이 있으나 프런트엔드 코드와 자산 변경이 필요하며 이번에는 적용하지 않았다. Next.js/GitHub 공식 문서 URL은 이번 클라우드의 HTTPS proxy가 403을 반환해 직접 확인하지 못했다.
- `.github/workflows/build-containers.yml`은 tag 또는 수동 실행에서 현재 checkout의 `Dockerfile.dev`로 amd64/arm64를 빌드하지만, 목적지가 `ghcr.io/gitroomhq/postiz-app`으로 고정돼 있다. 퍼뜩 fork의 현재 work 소스/커밋과 공식 이미지 digest 간 source revision 일치는 검증 증거가 없다. workflow를 실행하거나 수정하지 않았고 새 GHCR 이미지도 만들지 않았다. GitHub runner에서 프로젝트 전용 이미지 빌드를 검증하는 것은 가능성이 있지만 현재 workflow 목적지, package write 권한, 사용량/요금은 별도 확인과 승인 전까지 미검증이다.
- `docker buildx imagetools inspect`로만 현재 공식 `latest` manifest를 확인했다: index `sha256:d2b37802e96757729fdea2d3d71287f841c2b619faa1cb4c21dac07df657fde1`, amd64 `sha256:a844e4d3e5af0e9e1af0fa8adb2eb85e8b16a6d6b6eaac491bfd5c5e12dc0a65`, arm64 `sha256:7fae67875fde51958d76ef2f28f96249027b1c5f098637f31ec4ded9ed469f26`. 이미지를 pull하지 않았고 manifest를 현재 source commit에 연결하는 provenance 증거는 확인되지 않았다. 현재 `work`와 저장소 `main`의 애플리케이션 런타임 파일은 동일하며 차이는 Jest/문서/운영 Compose에 있다.
- 이미지 빌드 전 디스크는 32 GiB 중 28 GiB 가용이었다. 검증용 Temporal 의존 이미지 pull 후 사용량이 약 17 GiB로 증가해 빌드는 안전하지 않다고 판단했다. 격리 자원과 해당 이미지 태그 정리 후 원래 가용량으로 복구했다. 동일한 Google Fonts 실패를 내는 전체 이미지 빌드는 반복하지 않았다.
- 이번 단계 테스트: Compose config 통과, 실제 격리 Temporal health 통과, Git ignore 확인 통과, 변경 patch의 토큰/개인키 패턴 검색에서 일치 없음, Jest 2/2 통과, backend/orchestrator build 통과, frontend typecheck 통과, 최종 `git diff --check` 통과. 전용 gitleaks/trufflehog 도구는 설치돼 있지 않았다. Docker 이미지 생성, Postiz 앱 전체 실행, 관리자 로그인/게시/예약, GitHub Actions, SNS 연결/게시, 공식 문서의 최신 정책은 미검증이다.
- 미완료: Corepack pnpm 버전 포인터 오류, GitHub Actions를 통한 퍼뜩 소스 이미지 빌드/배포 방식 및 비용·권한, 현재 소스와 공식 Postiz 이미지 digest의 revision 매핑. 앱 UI/폰트 코드 변경은 승인 없이 진행하지 않는다. 다음에는 별도 승인과 목적지/권한 확인 후 프로젝트 소유 GHCR로의 격리 빌드 설계를 검토한다.

## 8단계 — GitHub Actions 프런트엔드 빌드 확인

- 시작 시 저장소 `goldeget/putduk-social-auto`, `work`, 로컬·원격 SHA `df887a0c611fe215e476e4143340aa203155a5cf`, 깨끗한 작업 트리와 기존 작업 기록을 확인했다.
- 새 `.github/workflows/putduk-frontend-build-check.yml`은 `work`에서 해당 워크플로 파일 변경 시에만 push 실행된다. `workflow_dispatch`, pull request, tag, schedule 트리거는 없다. job timeout 45분, 동시 실행 시 이전 실행 취소, checkout 자격증명 미보존, `GITHUB_TOKEN` 권한 `contents: read`만 설정했다. secret 참조, Docker, GHCR, package write, release/push 단계는 없다.
- Node `22.20.0`, pnpm `10.6.1`, `pnpm install --frozen-lockfile`, 실제 프런트엔드 명령 `pnpm --filter postiz-frontend run build`을 사용한다. 기존 `postiz-frontend`의 build 스크립트가 `next build`임을 확인했다. 빌드 전후 CPU 코어 수, 메모리, workspace 디스크 용량을 기록하고 Google Fonts CSS와 응답에서 찾은 gstatic 글꼴 파일을 각각 다운로드 확인한다. 각 GitHub step의 실패 출력이 오류 로그로 남으며 자동 재시도는 구성하지 않았다.
- 로컬에서 workflow YAML 및 branch/path/권한/버전/명령/금지 단계 정적 assertion이 통과했다. 동일한 Google Fonts CSS와 gstatic 파일 요청은 현재 클라우드에서 각각 HTTP 200이었다. 이는 GitHub-hosted runner의 실행 결과가 아니다.
- GitHub-hosted 표준 Ubuntu runner만 사용하고 Larger Runner는 사용하지 않는다. 공개 저장소의 표준 runner는 무료 대상이라는 GitHub 정책을 적용한 설계이나, 이번 환경의 프록시가 GitHub 문서/API 요청을 차단해 현재 저장소의 Actions 활성화 설정·계정 결제 상태와 실제 runner quota를 직접 조회하지 못했다. `gh` API 요청은 유효한 로그인 상태를 요구했고, 자격정보 값은 출력하지 않았다. 설정을 변경하지 않았다.
- 기존 `.github/workflows/build.yml`은 모든 push, pull request, merge group에서 기존 전체 빌드 스크립트를 실행한다. 따라서 `work` push는 이 기존 일반 빌드도 트리거한다. `build-containers.yml`은 수동 실행 또는 tag push에서만 실행되므로 이번 branch push는 기존 GHCR 이미지 게시 workflow를 트리거하지 않는다. 새 workflow는 요청대로 자체 파일 경로만 감시한다. 다른 기존 예약·수동 workflow 및 그 비밀값은 변경·사용하지 않았다.
- 현재 단계에 새 workflow 파일의 자동 실행 여부와 run URL/로그를 확인할 GitHub API 접근이 없어 실제 Actions run은 확인 대기 상태다. 따라서 Google Fonts 문제 해결, 실제 GitHub-hosted 프런트엔드 빌드, 실제 runner CPU/RAM/디스크, 공개된 run URL은 미검증이다. Docker 전체 빌드·이미지 생성은 실행하지 않았다.
- 실제 Actions run 결과를 확인한 뒤에만 Google Fonts 오류 해결 여부를 판정한다. Actions 비활성 또는 결제 설정 변경이 필요하면 사용자에게 요청한다. 이후 Docker 빌드 검토는 별도 승인 전 진행하지 않는다.

## 9단계 — GitHub Actions 로컬 Docker 이미지 빌드 검증 (2026-10-15)

- 작업 시작 시 저장소 `goldeget/putduk-social-auto`, 브랜치 `work`, 로컬·원격 SHA `5e5ac0d2431854796f191615792d91510f2527d0` 일치와 깨끗한 작업 트리를 확인했다. 기존 작업 기록도 읽었다.
- 새 `.github/workflows/putduk-docker-build-check.yml`은 `work`에서 이 파일이 변경된 push만 감지한다. `ubuntu-latest`, 60분 제한, `contents: read`, checkout 자격증명 미보존을 설정했다. GHCR/다른 레지스트리 로그인·게시 단계는 없다.
- 워크플로는 작업 공간과 Docker 데이터 저장 경로의 디스크를 각각 측정하며 둘 중 하나라도 35 GiB 미만이면 Docker 빌드 전에 중단한다. 기존 Docker/컨테이너/볼륨을 정리하지 않는다. 충분한 경우 `Dockerfile.dev`로 `linux/amd64` 이미지를 실행기 로컬에만 `--load`하고, OCI revision label과 빌드 인자를 실제 `GITHUB_SHA`로 설정한다.
- 성공 시 이미지 ID/크기/OS·아키텍처/revision, 기본 Entrypoint/Cmd/사용자/노출 포트 및 비밀정보와 유사한 환경 변수명(값은 출력하지 않음)을 검사한다. 격리된 `--network none` 컨테이너에서 앱을 시작하지 않고 이미지 파일의 실제 환경 파일/일부 고신뢰 토큰 패턴을 점검하도록 했다. 이는 포괄적인 비밀정보 감사는 아니다.
- 로컬 정적 검증: YAML 파싱, 트리거·권한·실행기·제한시간·로컬 빌드 및 게시 금지 조건 assertion, 인라인 JavaScript 문법, 셸 문법, 추적된 환경/자격증명 파일 검사 및 `git diff --check` 통과. 추적된 비밀 파일은 발견되지 않았다.
- 이 기록 시점에 GitHub-hosted Actions 실행, runner의 실제 디스크/RAM/CPU, Google Fonts를 포함한 Docker 이미지 생성, 이미지 ID/크기/아키텍처/revision, 이미지 내 비밀정보 검색은 아직 검증되지 않았다. 실제 Actions 실행 결과 확인 전에는 이미지 빌드 성공으로 보고하지 않는다.
- 기존 `.github/workflows/build.yml`은 push마다 별도 실행될 수 있으나 컨테이너 게시 workflow는 수정하거나 수동 실행하지 않았다. 기존 upstream GHCR 게시 workflow를 실행하지 않는다.
- 워크플로와 이 기록을 `work`에 커밋·푸시했다. 첫 푸시의 로컬·원격 SHA는 `f8b2e03605343d2d1bed6fa8af4e92cc7cbf9470`으로 일치했다. 해당 SHA가 Action의 예상 소스 커밋이다.
- 실행 결과 확인을 위해 공개 GitHub Actions API를 조회했으나 현재 실행 환경의 프록시가 HTTP 403을 반환했다. 따라서 실제 run ID/URL, 상태, 디스크 사전검사, Docker 이미지 생성 및 검사 결과는 여전히 확인되지 않았다. Action 실행 성공으로 간주하지 않는다.
- 다음: 사용자가 Actions 화면에서 해당 커밋 `f8b2e03605343d2d1bed6fa8af4e92cc7cbf9470`의 `PUTDUK Docker Build Check` 결과를 확인한다. 디스크 사전검사 실패 또는 빌드 실패는 성공으로 표시하지 않는다.

## 10단계 — GitHub Actions 격리 전체 실행 및 복구 검사 (2026-10-15)

- 시작 기준은 저장소 `goldeget/putduk-social-auto`, 브랜치 `work`, 로컬 HEAD `1eaaecd8da689d6ab0dc478ffe2212a9e22f6af8`이었다. GitHub `origin/work`도 `git ls-remote`로 같은 SHA임을 확인했다. 별도 origin 추적 ref는 체크아웃에 없었으므로 원격 상태 조회 결과를 직접 확인했다. `main`은 읽기만 했다.
- 기존 9단계 워크플로의 로컬 `linux/amd64` 빌드를 같은 실행에서 한 번만 하고, 그 이미지로 격리 통합검사를 이어가도록 확장했다. 이미지 push, GHCR 권한, Release, 서버 배포 단계는 없다. 일반 `ubuntu-latest`, `contents: read`, checkout 자격증명 미보존, 120분 timeout을 유지한다. 50 GiB 미만이면 빌드 전 중단하고, 이미지 빌드 뒤 20 GiB 미만이면 서비스 다운로드/기동 전에 중단한다. Docker 전역 prune은 없다.
- 새 `.github/ci/docker-compose.step10-test.yaml`은 테스트 전용 override다. `.github`가 기존 `.dockerignore`에서 제외돼 테스트 설정이 운영 이미지 빌드 컨텍스트에 복사되지 않는다. Caddy를 제외하고 Postiz 포트는 `127.0.0.1:5500`만 열며 앱 네트워크의 외부 송신을 막는다. 이 테스트 전용 시작 명령은 이미지에 포함된 Prisma 6.5.0을 사용해 외부 `pnpm dlx` 다운로드 없이 DB schema push를 실행한 다음 기존 PM2 앱들을 시작한다. 서비스 메모리/CPU 상한 합계는 8.75 GiB/5 vCPU로 설정해 제안된 12 GB/6 vCPU 호스트에서 OS 여유를 남긴다. 이는 호스트의 실제 사용량 측정이 아니라 CI 컨테이너 상한이다.
- 새 `.github/ci/putduk-step10-integration.sh`는 Actions 실행별 고유 Compose 프로젝트, 실행 중 생성한 임시 DB/Redis/Temporal/JWT 비밀값, `.invalid` 관리자 계정, 격리 볼륨을 쓴다. 실행 중 비밀값은 Actions mask 처리하고 출력/산출물 업로드를 하지 않는다. Caddy와 DB·Redis·Temporal·Elasticsearch의 호스트 포트는 열지 않는다.
- 검사 절차에는 로그인 화면 HTTP 200, 임시 계정 생성/로그인과 `/api/user/self`, 인증된 `/settings`, 초안 작성/조회, 작은 가짜 PNG 업로드, 30일 후 예약을 포함한다. 게시 예약에는 DB에만 만든 가짜 Instagram integration과 가짜 토큰을 쓴다. workflow의 publish date 대기 단계가 끝나기 전에 Temporal 실행 상태 확인 및 재시작 검사를 하고 workflow를 terminate한다. 실제 SNS OAuth나 게시 요청은 하지 않는다.
- 복구 절차는 실제 테스트 Postiz PostgreSQL dump를 같은 서버 내 별도 DB로 복원해 초안/예약 상태를 확인하고, Temporal PostgreSQL history dump도 별도 DB로 복원해 workflow 실행 행을 확인한다. Redis AOF 재시작 및 RDB 복원, 실제 테스트 업로드 파일 복원 후 SHA-256 대조, Temporal Elasticsearch snapshot 복원을 수행한다. 이는 외부 백업 저장소나 12 GB VPS에서의 복구 검증을 대체하지 않는다. 게시 중복 방지/외부 플랫폼 응답 재시도는 실제 게시 없이 검증할 수 없다.
- 테스트 종료는 이 run id와 일치하는 상태 파일 및 전용 프로젝트 이름을 확인한 뒤 해당 Compose project, `putduk.step10.project` label 자원, run 전용 임시 폴더만 정리한다. 이미지/BuildKit cache 전체 정리 명령은 없다.
- 로컬 사전 검증: 통합 셸 스크립트와 모든 workflow `run` 블록의 `bash -n`, 두 YAML 파일 파싱, Compose `config --quiet`, 포트/네트워크/자원 상한 정적 검사, `git diff --check` 통과. 로컬 Docker daemon은 응답하지만 기존 Docker 자원을 건드리지 않았고 컨테이너는 시작하지 않았다.
- GitHub Actions 실행 `38783312423` (source SHA `97da417d448311ab0d3ea5f10410243b6c6341a7`, 15분 35초)은 실패했다. 세부 job page에서 50 GiB/20 GiB 디스크 체크, `linux/amd64` 이미지 빌드, 이미지 메타데이터 및 비밀정보 검사, run 자원 정리는 성공으로 확인했다. `Run isolated Step 10 integration checks`만 exit 1 (18:19:50–18:24:43 UTC)이었다. 로그 다운로드 경로는 공개 읽기 요청에서 HTTP 404여서 정확한 실패 assertion을 확보하지 못했다. 따라서 Postiz 기동·로그인·게시·예약·복원은 이 실행만으로 성공했다고 판단하지 않는다.
- 정확한 단계를 한 번만 추가 진단하기 위해 테스트 스크립트에 현재 검사 구간, 실패 시 셸 행/구간, 임시 자격정보를 가린 마지막 서비스 로그 일부를 남기는 처리를 추가했다. 앱 소스는 수정하지 않았다.
- 진단 스크립트/기록 커밋 `19311644883ffc079dd7c8fc334ea80a009ad076`은 자동 실행 경로 필터가 워크플로 파일만 감시하므로 새 Action을 시작하지 않았다. 해당 필터를 넓히지 않고 진단 목적을 주석으로 명시한 커밋 `e320c68b3d9aa65caecd3d611e54b30fe5b437ad`에서 한 번 실행했다.
- 진단 run `38789744025` (`e320c68b3d9aa65caecd3d611e54b30fe5b437ad`, 15분 17초)도 실패했다. 이미지 빌드, 이미지 메타데이터/비밀정보 검사, 디스크 사전 점검은 성공했다. 통합 스크립트는 57행의 `docker compose` 호출 중 `start and health-check six isolated services` 단계에서 exit 1을 받았고, run 전용 자원 정리는 성공했다. 실패한 컨테이너의 상세 로그는 로그인된 Actions 체크 화면을 요구해 이 실행 환경에서는 확인할 수 없었다. 관리자 로그인·콘텐츠·예약·Temporal workflow·복구는 여전히 검증되지 않았다.
- 반복 실행은 여기서 중단한다. 다음에는 사용자가 해당 run의 실패한 “Run isolated Step 10 integration checks” 로그에서 비밀값을 가린 서비스 오류를 확인하고 공유해야, 앱 변경 승인 없이 테스트 설정만 고칠 수 있는지 판단할 수 있다. 앱 코드 변경이 필요하다면 별도 승인을 기다린다.

## 10-A단계 — Postiz healthcheck 실패 진단 보완 (2026-10-15)

- 시작 확인: `goldeget/putduk-social-auto`, 브랜치 `work`; 로컬 SHA와 `git ls-remote origin refs/heads/work` 결과가 모두 `d7cb01c3e450d46886e948cb4a056dafaefcc93d`; 시작 시 작업 트리는 깨끗했다.
- 두 앞선 Actions 실행의 결과에서 Postiz 단독 unhealthy와 약 4분 뒤 health 판정을 확인했지만, 현재 저장된 로그에는 앱 컨테이너 오류가 없어 정확한 근본 원인은 미확정이다.
- 소스 경로 확인: Dockerfile은 `nginx && pnpm run pm2`; 루트 `pm2-run`은 Prisma DB push 후 workspace PM2를 실행한다. 테스트 override는 이미지 내 Prisma CLI로 `pnpm exec prisma db push`를 실행해 `pnpm dlx`의 런타임 다운로드를 피한다. PM2 workspace 항목은 frontend(4200), backend(3000), orchestrator이며 Nginx는 5000에서 프록시한다. Compose healthcheck는 컨테이너 내부 `127.0.0.1:5000`의 HTTP 상태가 500 미만인지 검사한다. 테스트 컨테이너에는 4 GiB 메모리 제한이 있다.
- 진단 전용 수정: 실패 시 run 전용 cleanup보다 먼저 Postiz 상태/종료/OOM/재시작 수, 최근 healthcheck 기록, Postiz 전용 시작 로그, 프로세스와 PM2 앱 상태, 포트 3000/4200/5000, Prisma 실행 단서, 컨테이너별 CPU/RAM을 수집하도록 `.github/ci/putduk-step10-integration.sh`를 보완했다. 공개 출력에서는 생성된 비밀값, DB/Redis URL, 토큰·쿠키·JWT 등을 가린다. 앱 코드, 운영 Compose, 개발 Compose는 수정하지 않았다.
- `.github/workflows/putduk-docker-build-check.yml`의 주석만 변경해 경로 필터에 따라 격리 진단 실행 1회를 트리거한다. 무료 `ubuntu-latest`와 `contents: read`, 로컬 이미지 빌드만 유지하며 이미지 push는 없다.
- 정적 검사 통과: 통합 스크립트 `bash -n`, 3개 YAML 파일 파싱, 테스트용 두 Compose 파일의 `config --quiet`, `git diff --check`.
- 진단 실행 `38796024093` (커밋 `ebf09e3c9bf9084a55e6500f9375ab5b3826e869`)에서 이미지 빌드는 성공했다. 통합 단계는 4분 58초 후 실패했고, annotation은 같은 `docker compose` 실행 안에서 `start and health-check six isolated services` phase / 스크립트 line 57 / exit 1을 표시했다. run 전용 cleanup은 성공했다.
- 익명 GitHub 화면에서 summary와 annotations는 읽을 수 있었으나, 상세 step log URL은 GitHub의 404 “Not Found” 페이지로 응답했다. 이 환경의 `gh auth status`도 `GH_TOKEN` 인증 실패를 보고해 상세 로그를 가져오지 못했다. 따라서 개선한 Postiz 상태·health·프로세스·포트·Prisma·메모리 진단 출력의 실제 내용은 미확인이다. Postiz unhealthy가 통합 단계 실패를 일으켰다는 사용자 제공 사실 외에 근본 앱 오류는 확정하지 않는다.
- 다음: 사용자가 run `38796024093`의 “Run isolated Step 10 integration checks” 로그에서 새로 출력된 Postiz diagnostics를 비밀값 제거 후 공유한다. 그 출력으로 원인을 판별하고, 앱 코드 변경이 필요하면 별도 승인을 기다린다. 추가 Action 재실행은 하지 않는다.

## 최종 안정화 — 첫 원인 추적 및 진단 명령 수정 (2026-10-15)

- 시작 시 저장소 `goldeget/putduk-social-auto`, 브랜치 `work`, 로컬·원격 SHA `462b86e286fe14a186bcc8b0ebd7bb533e39898d` 일치, 깨끗한 작업 트리를 확인했다. `main`은 읽기 전용으로 SHA `0956d49ab79acb314f700779b92677830ac83a9d`를 조회했다.
- 전달된 Action 로그에서 Postiz 프로세스는 실행 중, `OOMKilled=false`, Prisma 성공, Nginx 실행, 프런트엔드 포트 4200 연결 거부, Nginx upstream `http://127.0.0.1:4200/`의 `connect() failed (111: Connection refused)`를 확인했다. 이는 Next.js가 해당 시점에 4200 포트에서 수신하지 않았음을 뜻하지만, Next.js가 종료된 직접 원인은 아직 확인 전이다.
- 소스 추적: Next.js 설정은 `output: standalone`을 쓰지 않고, 프런트엔드 실행 스크립트는 `dotenv -e ../../.env -- next start -p 4200`이다. Compose가 빈 `/app/.env`를 테스트에 마운트하고 런타임 환경변수는 별도로 전달한다. pnpm 10.6.1 격리 workspace probe에서 `pnpm run --parallel pm2`가 각 workspace의 `pm2` 스크립트를 실행하는 것을 확인했다. 따라서 이 명령을 원인으로 추정하거나 바꾸지 않는다.
- Docker CLI 도움말 및 명령 재현으로 기존 진단 스크립트의 오류를 확인했다. `docker exec`는 `-T` 옵션을 지원하지 않으며 `docker stats`는 `--filter`를 지원하지 않는다. 이 결함 때문에 이전 run의 PM2/포트/stats 진단은 신뢰할 수 없다.
- 수정 대상은 `.github/ci/putduk-step10-integration.sh`와 관련 workflow path trigger다. `docker exec` 호출에서 잘못된 `-T`를 제거하고, stats 대상은 지원되는 `docker ps --filter name=...`로 run 전용 컨테이너 ID를 찾은 뒤 `docker stats` 인자로 넘기도록 한다. 진단 명령에는 timeout을 두고 PM2 프로세스별 상태/재시작 횟수/PID를 출력하되 환경값은 출력하지 않는다. 앱 시작 코드·UI·운영 Compose는 원인 확인 전 변경하지 않는다.
- RED/GREEN 정적 회귀 확인: 수정 전 Python assertion은 두 잘못된 옵션을 모두 찾아 exit 1; 수정 후 같은 검사 통과. `bash -n`, workflow/Compose YAML 파싱, 두 Compose 파일의 test-variable 기반 `config --quiet`, `git diff --check`도 통과했다. Docker CLI에 없는 리소스를 넣어 option parsing을 확인했으며 컨테이너는 실행·삭제하지 않았다.
- Cloud activation은 Node `22.20.0`을 제공한다. 기본 `pnpm` shim은 없는 Corepack `12.11.2`를 가리켜 실패하지만 `corepack pnpm@10.6.1`은 동작했다. Dockerfile은 컨테이너 안에서 npm으로 pnpm 10.6.1을 직접 설치하므로 이 호스트 shim 문제는 컨테이너의 4200 오류 원인이라는 증거가 없다. Cloud onboarding 설정은 변경하지 않았다.
- 현재 통합 실행 한도: 첫 실행 `38800972657` 사용 (1/3). Docker 이미지 빌드는 성공했고, 통합 단계는 53초 뒤 `start and health-check six isolated services` phase에서 exit 1; run 전용 cleanup은 성공했다. 공개 annotations에는 실패 행이 `dc up --wait`이 호출되는 line 227이라고만 나와 구체 오류는 여전히 미확인이다. 이 짧은 경과 시간은 이전에 관찰된 4분 unhealthy와 다르므로 원인을 단정하지 않는다.
- 상세 Actions step 로그는 익명 요청에서 계속 읽을 수 없었다. 첫 실행 진단 수정에 남아 있는 접근성 공백을 해결하기 위해, 다음 진단은 마스킹된 제한 출력만 job summary와 GitHub error annotation에도 남기도록 추가한다. 수정된 비밀값 필터 fixture, 셸/YAML 파싱, `git diff --check`가 통과했다.
- 두 번째 실행 `38802419300` (2/3)에서 이미지 빌드는 성공했으며 integration phase는 4분 58초 후 실패, test-only cleanup은 성공했다. Redacted annotation에서 Nginx가 `localhost:4200`의 live upstream을 찾지 못하고 `127.0.0.1:4200`에 connection refused를 반복하는 로그를 확인했다. 이는 프런트엔드 서버가 포트를 열지 않은 현상을 재확인하지만, annotation에 마지막 Nginx 재시도들이 우선 노출돼 PM2 상태와 Next의 최초 종료 오류는 여전히 가려져 있다.
- 세 번째/마지막 허용 실행 전 진단 annotation 구성을 수정한다. PM2 이름·상태·재시작 수·PID, 3000/4200/5000 연결 결과, Prisma 상태, OOM/RAM 정보를 선택 우선 포함하고 반복 Nginx 오류는 최대 두 예시만 표시한다. 일반 프런트엔드 오류·예외 로그는 비밀값 필터 뒤 제한해 포함한다.
- 세 번째 실행용 최종 보강: 진단 선택 결과에 컨테이너별 peak RAM/CPU 및 실행기 파일시스템의 peak 사용량/min free, 샘플 기간을 포함한다. `bash -n`, 3개 YAML 파싱, `git diff --check`, 잘못된 `docker exec -T`/`docker stats --filter` 부재 검증은 통과했다.
- 다음 실행이 완료되기 전까지 앱 코드나 실행 경로는 추측으로 바꾸지 않는다. 마지막 실행 후에도 root cause가 드러나지 않으면 미검증 항목과 사용자에게 필요한 상세 로그 접근만 보고한다.
- 세 번째/마지막 실행 `38804864119` (`https://github.com/goldeget/putduk-social-auto/actions/runs/38804864119`)은 이미지 빌드, 이미지 검사, 제한 비밀정보 검사를 통과했으나 통합 기동은 실패했다. 격리 서비스 시작 단계에서 Postiz가 unhealthy였다. sanitized annotation으로 확인: `status=running`, `exit=0`, `oom_killed=false`, `restart_count=0`; Prisma 성공; PM2 목록에는 backend만 `online`/재시작 0으로 나타남; 3000 open, 4200 closed, 5000 open. healthcheck 최근 5회가 exit 1이다. 따라서 확정된 직접 원인은 프런트엔드가 4200에서 서비스하지 않는다는 것이며, Next/PM2가 프런트엔드를 시작하지 못한 구체 오류 메시지는 public annotation에 포함되지 않았다. 백엔드·오케스트레이터 PM2 항목도 보이지 않았지만 그 구동 실패 원인은 미확인이다.
- 이번 작업 승인 한도인 신규 Actions 통합 실행 3회를 모두 사용했다 (`38800972657`, `38802419300`, `38804864119`). 세 번째도 전체 통합 검증 전에 실패했으므로 로그인, 초안, 업로드, 예약/Temporal, 재시작, 각 저장소 복원 단계는 이번 실행에서 실행되지 않았다. 성능 sampler는 통합 시작 전부터 데이터를 수집하도록 추가했지만 최종 실패 annotation이 진단 선택 결과만 노출했고 원시 단계 로그는 공개 익명 접근으로 404/인증 제한을 받았다. 따라서 최대 RAM/CPU/디스크와 안정 실행시간은 이번 증거로 보고하지 않으며 UNKNOWN이다. 이미지 빌드 전 runner 리소스 검사는 통과했으나 구체 수치는 익명 job-step 본문에서 확인할 수 없었다.
- 소스/Compose 수정은 하지 않았다. 세 실행 한도 때문에 추가 Actions 실행을 하지 않는다. 원인을 확정하려면 run `38804864119`의 `Run isolated Step 10 integration checks` 전체 로그에서 `pnpm run --parallel pm2` 시작 구간, frontend PM2 stderr/exit, orchestrator 상태를 검토해야 한다. 필요한 구간에서 비밀값을 제거한 실제 오류 메시지를 확인하기 전에는 앱 코드나 PM2 실행 방식을 바꾸지 않는다.
- 최종 작업 커밋 `d0f65b08d58c9f5117032c702b8faa9545edb320`은 로컬과 GitHub `work` 원격에서 일치 확인됐다. (이 문서의 이번 결과 갱신 자체는 다음 체크포인트에 포함한다.)

## PM2 기동 경쟁 상태 최소 수정 — 2026-10-15

- 시작 시 저장소 `goldeget/putduk-social-auto`, 브랜치 `work`, 로컬·원격 SHA `dea2f50af8fb470866e50bc1c62545fd8349e77d` 일치, 깨끗한 작업 트리를 확인했다. Node `22.20.0`, pnpm `10.6.1`을 cloud activation 뒤 확인했다.
- 근본 원인 근거: 앞선 세 Actions 실행에서 사용자/총괄 분석상 서로 다른 단일 앱만 PM2에 등록됐고, 같은 `PM2_HOME`에 대한 동시 데몬 초기화가 관찰됐다. 코드도 운영 루트 스크립트 `pnpm run --parallel pm2`와 격리 Compose의 동일 병렬 명령이 frontend/backend/orchestrator의 각 `pm2 start`를 동시에 호출했다. 이 두 증거가 공유 PM2 데몬의 초기화 경합을 가장 잘 설명한다. 수정은 순차 등록으로 제한한다.
- TDD 회귀 검증: 신규 `scripts/pm2-start-order.test.mjs`를 먼저 추가해 기존 `package.json`에 `pm2-start-apps`가 없어 RED 실패를 확인했다. 이후 운영 명령과 CI 격리 명령이 같은 순차 스크립트를 쓰고 세 앱 workspace PM2 스크립트가 보존되는지 검사한다. Node 테스트 2개는 최종 GREEN (2 passed, 0 failed).
- `package.json`에 frontend → backend → orchestrator를 `&&` 순서로 실행하는 `pm2-start-apps`를 추가하고, 운영 `pm2-run`에서 이 스크립트를 호출한다. 격리 Compose도 동일한 `pnpm run pm2-start-apps`를 사용한다. 앱 별 시작 명령과 PM2_HOME은 변경하지 않는다.
- 경량 재현: 실제 pnpm 10.6.1과 실제 workspace filter/script를 실행하고 PM2 CLI만 격리 stub으로 대체했다. stub은 첫 PM2_HOME 초기화만 허용하고 초기화 중 동시 호출은 실패시키도록 했다. frontend → backend → orchestrator 순으로 세 앱이 모두 등록됐고 초기화 충돌은 0건이었다. 이는 순차 오케스트레이션 검증이며 실제 PM2 런타임 검증은 다음 단일 Actions 실행에 남아 있다.
- Docker 포트 조사: 이전 공개 annotation에는 첫 실행의 정확한 `docker port` 오류 본문이 없고 익명 상세 job 로그는 인증 제한이었다. 현재 runner Docker에서 loopback 포트 공개 컨테이너와 비공개 컨테이너를 run-scope로 만들고 CLI 결과를 재현했다. 공개된 포트는 `127.0.0.1:<host-port>`로 exit 0, 비공개 서비스는 빈 출력/exit 0으로 기존 검사 기대와 일치했다. 실행 중 두 테스트 컨테이너만 제거했다. 통합 스크립트는 이제 검사 실패 시 앱 binding의 기대/실제값 또는 포트 inspection 실패를 명시한다. Compose의 외부 publish는 앱 loopback `127.0.0.1:5500:5000`만 유지하고 edge network는 internal이다.
- 격리 통합 스크립트에는 PM2의 세 프로세스 `online` 검사와 직접 HTTP 검사(4200 로그인 200, 3000 `/auth/can-register` 200 및 Boolean 응답, 5000 로그인 200)를 추가했다. 최종 성공 annotation에는 기존 전체 로그인·초안·업로드·예약·Temporal·재시작·DB/Redis/Elasticsearch/업로드 복원 검증과 자원 지표를 마스킹 없이 안전한 비밀 없는 요약으로 표시한다. 실패 진단에서 비밀정보를 출력하지 않는 원칙은 유지한다.
- 검증 통과: Node `22.20.0`에서 Node 테스트 2개, pnpm `10.6.1` workspace 경량 실행, shell `bash -n`, workflow/Compose YAML 파싱, 격리 Compose `config --quiet`, Docker 포트 공개/비공개 CLI probe, `git diff --check`. 실제 Postiz 컨테이너는 클라우드 작업공간에서 빌드·기동하지 않았다.
- 다음 검증은 무료 GitHub Actions의 일반 `ubuntu-latest`에서 한 번만 한다. 이미지 빌드가 성공하더라도 단계별 통합 결과를 확인한다. 전체 Postiz healthy, 세 PM2 프로세스, 직접 HTTP, 로그인/초안/업로드/예약/Temporal, 재시작 및 격리 백업·복원 중 어느 하나라도 실패하면 성공 판정을 하지 않는다. 실제 SNS 게시, 외부 배포, 구매는 하지 않는다.
- 단일 통합 실행 결과: `38809241765` (`https://github.com/goldeget/putduk-social-auto/actions/runs/38809241765`, source SHA `9f82a80b1087a308ea50f1523539c854cfaa5d1c`)에서 회귀 테스트, 이미지 빌드/플랫폼/비밀정보 검사, 디스크 사전검사는 통과했다. run 전용 cleanup도 성공했다.
- 실제 PM2 검사에서 frontend/backend/orchestrator가 모두 `online`, 각 restart count 0으로 등록됐다. Postiz container `healthy`, exit 0, `OOMKilled=false`, restart count 0이었다. 이 결과는 순차 PM2 등록이 이전의 앱 누락 현상을 해결했음을 검증한다.
- 다음 직접 HTTP 검사 시점에는 4200과 5000이 열려 있었으나 3000은 닫혀 있어 통합 단계가 실패했다. Postiz 로그 꼬리에는 Nest backend의 route mapping 로그가 있었고 fatal/uncaught/OOM 증거는 annotation에서 확인되지 않았다. 따라서 PM2 초기화 경쟁은 해결됐지만 backend HTTP readiness 시점은 미통과/미확정이다. 즉시 검사 후 서버 준비를 기다리는 polling이 필요할 수 있으나, 추가 Actions 실행 상한 1회를 모두 사용해 이 task에서 다시 실행하지 않았다.
- 로그인, 초안, 이미지 업로드, 예약/Temporal, 재시작 후 보존, DB/Redis/Elasticsearch/업로드 복원 단계는 직접 HTTP 게이트를 통과하지 않아 실행되지 않았다. 최대 RAM/CPU/디스크 결과도 실패 annotation에 제공되지 않아 UNKNOWN이다. Docker published-port check 단계까지 도달하지 않았으나 별도 local Docker probe에서는 loopback mapping `127.0.0.1:<host-port>`와 미공개 컨테이너의 빈 출력/exit 0을 확인했고, 스크립트 오류 메시지는 보강했다.
- 백업은 `work`에 커밋 후 최종 SHA를 다시 조회해 확인한다. 서버 구매 판정은 NO-GO 유지.

## 백엔드 API 준비 대기 및 통합 검사 재개 — 2026-10-15

- 시작 기준: 저장소 `goldeget/putduk-social-auto`, 브랜치 `work`, 로컬·원격 SHA `54a09b66f177e6d0d8d7dbd3987553de7a793ed0` 일치, 작업 트리 깨끗함. 클라우드 활성화 후 Node.js `22.20.0`, pnpm `10.6.1` 확인.
- 직전 통합 실행 `38809241765`는 앱 컨테이너 healthy, frontend/backend/orchestrator PM2 online, 세 앱 재시작 0, OOM 없음이었다. 검사 순간 backend 3000은 연결되지 않았고 `/auth/can-register` 요청은 실패했다. 이어 5초 뒤 NestJS route 초기화 로그가 나온 사실은 API 준비 지연 가능성을 뒷받침하지만, 이 로그만으로 실제 리스닝 시각이나 유일한 근본 원인을 확정할 수는 없다. PM2 초기화 경쟁은 순차 시작과 세 프로세스 online 결과로 해소된 것으로 확인됐다.
- 신규 `scripts/backend-readiness.mjs`는 실제 `GET /auth/can-register`를 기본 최대 180초 동안 4초 간격으로 확인한다. 개별 요청 제한은 최대 3초이며 남은 총 대기 시간을 넘지 않는다. HTTP 200과 `{register: boolean}` 형태를 모두 확인하고, 오류 시 HTTP 상태 또는 안전한 네트워크 오류 코드/유형, 시도 수, 경과 시간을 출력한다. 비밀값이나 원문 오류 메시지는 출력하지 않는다. 마감 시각 이후 도착한 응답은 성공 처리하지 않는다.
- `.github/ci/putduk-step10-integration.sh`는 이 검사를 `docker compose exec -T`로 실행하고, 성공한 뒤에만 frontend 4200과 Nginx 5000의 HTTP 200 및 공개 포트 바인딩 검사를 계속한다. 기존 loopback-only 포트 제한, 외부 통신 차단, PM2 상태 확인, 실패 진단/로그 마스킹은 유지한다. PM2 순차 시작 코드는 변경하지 않았다.
- 신규 `scripts/backend-readiness.test.mjs`는 ECONNREFUSED 뒤 정상 응답, HTTP 200의 잘못된 JSON, 오류 상태에서의 bounded timeout/짧은 요청 신호, 총 마감 이후의 응답 및 JSON 지연을 확인한다. PM2/격리 포트 정적 회귀 검사도 업데이트했다.
- 로컬 검증: 기존 PM2 검사와 신규 준비 검사 합계 7개 테스트 통과, `node --check`, 통합 셸 `bash -n`, workflow/Compose YAML 파싱, `docker compose ... config --quiet`, `git diff --check` 통과. 실제 격리 Postiz 컨테이너 또는 전체 GitHub Actions 검사는 아직 이번 변경으로 실행되지 않았다.
- 다음: work에 이 체크포인트를 저장하고 무료 `ubuntu-latest` 통합 실행을 한 번만 수행한다. 실제 API 준비 경과 시간과 뒤이은 로그인·초안·업로드·예약/Temporal·재시작·복구 검증 결과가 모두 확인되기 전 운영 구매 판정은 NO-GO다.

### 단일 GitHub Actions 통합 실행 결과

- 실행 `38812246043` (`https://github.com/goldeget/putduk-social-auto/actions/runs/38812246043`), source SHA `51c68f2c41bffd0ca67528ed74acc049028281a3`. Actions 사전 Node 테스트, amd64 Docker 이미지 빌드(8분 44초), 이미지 검사, 비밀 파일 검사 및 격리 통합용 디스크 사전검사는 통과했다. Docker 이미지 게시 단계는 없었다.
- 통합 스크립트에서는 여섯 컨테이너의 healthcheck 대기 및 확인을 통과한 뒤 PM2 검사를 진행했다. 실패 진단 요약은 Postiz `healthy`, `exit=0`, `OOMKilled=false`, 재시작 0; frontend/backend/orchestrator 모두 PM2 `online`, 각 재시작 0; 내부 3000/4200/5000 TCP 포트 열림을 보고했다. Prisma 시작 체인도 완료된 것으로 확인됐다.
- 통합 명령은 총 79초 실행 후 exit 1로 끝났고 run 전용 정리는 성공했다. 진단 시각(21:55:12 UTC) 뒤에 출력된 마지막 Nest route mapping 로그(21:55:23 UTC)는 backend 초기화가 계속 진행됐음을 보인다. 다만 현재 공개된 GitHub annotation은 실패 단계명, 준비 probe 성공 문구/경과 시간, HTTP 응답 코드 및 실패 명령을 포함하지 않는다. 원시 step log의 공개 경로는 HTTP 404를 반환해 이 실행에서 `/auth/can-register`가 언제 200이 됐는지, 이후 어디서 실패했는지 확정할 수 없다.
- 따라서 이번 Actions 실행으로는 PM2 기동과 전체 서비스 health 및 포트 준비는 확인했으나 backend HTTP API readiness의 경과 시간은 **미측정**이다. 테스트 관리자 로그인, 초안·업로드·예약, Temporal 앱 워크플로, 재시작 후 실제 콘텐츠 유지, Postiz/Temporal DB·Redis·Elasticsearch·미디어 복원, CPU/RAM/실행기 디스크 수치는 **미검증**이다. 실패를 성공으로 표시하지 않는다.
- 사용자 지정 최대 1회 통합 실행을 사용했으므로 재실행하지 않는다. 정확한 실패 단계를 확정하려면 저장소에 로그인된 Actions 원시 job log를 열람해야 한다. 다음 서버 판정은 NO-GO다.

## CI 내부 Docker 네트워크에서 HTTP 시험 경로 수정 — 2026-10-15

- 시작 시 `work` 로컬·원격 SHA `b7291767b0ad5ec0fede2c470e9048e7056d6d24` 일치와 깨끗한 트리를 확인했다. 원격 `main` 및 다른 저장소는 변경하지 않았다.
- 직전 Actions에서 사용자가 인증된 로그로 확인한 `Could not inspect Postiz host-port binding for 5000/tcp`를 원인으로 조사했다. 클라우드 Docker에서 고유한 임시 bridge network를 `internal=true`로 만들고 Postgres Alpine 컨테이너에만 HTTP probe를 실행했다. `docker run -p 127.0.0.1:<port>:5000`을 요청했으나 내부 네트워크가 호스트 publish를 만들지 않아 `docker port <container> 5000/tcp`가 `No public port '5000/tcp' published`로 실패했다. 따라서 현재 CI의 `edge: internal: true`와 loopback 포트 publish는 상호 맞지 않는 구성이며, 실패 원인이 재현됐다.
- 같은 probe에서 별도 host port publish 없이 Docker 내부 edge IP `172.18.0.2:5000`을 사용하고 curl의 `--connect-to 127.0.0.1:<port>:<private-ip>:5000`으로 접속했다. HTTP 200 및 원래 `Host: 127.0.0.1:<port>`, 쿠키, POST 본문이 서버 응답에 그대로 돌아오는 것을 확인했다. 이 probe 컨테이너와 네트워크는 실행별 고유 이름으로 만들었고 종료 시 그 자원만 정리했다. 기존 `trusting_nightingale` 컨테이너, 이미지, 볼륨은 건드리지 않았다.
- `.github/ci/docker-compose.step10-test.yaml`에서 Postiz `ports` publish를 제거했다. 통합 스크립트는 Compose가 부여한 edge network 사설 IPv4를 `docker inspect`에서 구해 내부 네트워크 여부를 확인하고, Postiz 및 DB·Redis·Temporal·Elasticsearch의 `.NetworkSettings.Ports`에 host binding이 없는지 확인한다. 모든 호스트 측 Postiz HTTP 호출은 `postiz_curl`을 사용해 `curl --connect-to`로 사설 IP에 연결하지만 URL/Host는 기존 `http://127.0.0.1:5500` 그대로 유지한다. 로그인 쿠키, JSON, 업로드 파일, 예약 요청도 이 helper를 통해 전달된다. 서비스에는 외부 인터넷 통신 경로가 없고 DB 계열 포트도 publish하지 않는다.
- 실패 진단에 통합 단계명과 실제 종료 코드를 GitHub error annotation으로 표시하도록 보강했다. 운영 Compose, 애플리케이션 코드, PM2 순차 기동 및 backend readiness 검사 코드는 바꾸지 않았다.
- 새 `scripts/step10-network-access.test.mjs`를 먼저 추가해 기존 host port 설정이 있음을 확인하는 RED 결과를 얻은 뒤 Compose/스크립트를 수정했다. 최종 Node 테스트 8/8 통과(backend readiness 5, PM2/구성 2, 네트워크 회귀 1). `bash -n`, workflow/Compose YAML 파싱, 실제 격리 Compose `config --format json`에서 여섯 서비스 host port 없음·세 네트워크 internal·Caddy 제외, `git diff --check`도 통과했다.
- 이전 단계에서 확인된 frontend 4200, backend `/auth/can-register`, Nginx 5000 응답 200은 사용자가 제공한 직전 Actions 원시 로그 증거다. 이번 수정 뒤 실제 Postiz로 사설-IP HTTP, 로그인/초안/업로드/예약/복구는 새 Actions 실행으로 확인해야 한다. 전체 이미지 빌드와 전체 통합은 변경 백업 후 최대 한 번만 실행한다.
- 승인된 Actions 실행은 `https://github.com/goldeget/putduk-social-auto/actions/runs/38815929001` (job `116700458936`, 소스 커밋 `93b9ae6554eca171fc7ab026d0d64d7d7a9b1004`)이다. 사용자가 인증된 원시 로그를 확인해 제공한 결과: 여섯 서비스 healthy, frontend/backend/orchestrator PM2 online, 백엔드 API 준비 8.1초, 프런트엔드 HTTP 200, Nginx HTTP 200, Docker 내부 연결, 테스트 관리자 등록·로그인·권한 있는 대시보드, 초안 생성·조회 성공. 업로드 요청은 HTTP 201을 받았으나 기존 CI 검사는 HTTP 200만 허용해 그 지점에서 중단됐다. 스크립트가 즉시 종료했으므로 그 실행에서 응답 JSON의 ID/path, 파일 내용·저장 확인, 예약/Temporal, 재시작 및 백업·복원은 실행되지 않았거나 **미검증**이다. 메모리·CPU·디스크 측정치는 이번에 제공된 로그 요약에 없으며 **미검증**이다. 앞선 비인증 공개 페이지에서 상세 로그를 볼 수 없었던 기록은 유지하되, 이제 위 성공/실패 사실은 사용자 제공 원시 로그로 확인됐다.
- Docker 내부 사설 IP 경로와 기존 Host/cookie/body 보존은 분리된 HTTP probe에서 확인됐고, 사용자가 제공한 Actions 로그는 Postiz에 대한 Docker 내부 연결도 성공했음을 확인한다. Docker 이미지 빌드도 통과했다. 업로드 응답 판정은 애플리케이션 오류가 아니라 CI의 HTTP 200 전용 조건이었다. 작업 당시 업로드 이후 검증이 이루어지지 않아 예약/Temporal/복원 및 서버 준비 판정은 **미검증/NO-GO**다.
- 네트워크 수정 체크포인트는 `work`에 `93b9ae6554eca171fc7ab026d0d64d7d7a9b1004`로 푸시했으며, 당시 로컬/원격 SHA가 일치했다. 이후 이 실행 결과는 다음의 HTTP 201 회귀 수정 단계에서 갱신한다.

## 이미지 업로드 HTTP 201 성공 판정 보완 — 2026-10-15

- 기준 `work` SHA `1ad6662aa41cb6ea3559c50d0b6426b3553e3b2d`와 원격 SHA가 일치했고 작업 트리는 깨끗했다. 실행 환경은 Node `22.20.0`, pnpm `10.6.1`이었다.
- 사용자가 제공한 인증 로그상 이전 Actions `38815929001`은 여섯 서비스, 세 PM2 앱, backend readiness(8.1초), frontend/Nginx 응답, 격리 내부 네트워크, 테스트 관리자 로그인 및 권한 확인, 초안 생성·조회까지 통과했다. 미디어 업로드 endpoint가 HTTP 201을 반환했을 때 통합 스크립트의 HTTP 200 전용 비교가 실패했다. `apps/backend/src/api/routes/media.controller.ts`의 `@Post('/upload-simple')`는 성공 응답 코드를 200으로 강제하지 않으며, 처리 결과는 media repository에서 선택한 `id`와 `path` 필드를 반환한다. 따라서 정상 POST 생성 응답인 201을 허용해야 한다.
- `scripts/step10-upload-response.mjs`를 추가해 HTTP 200/201 외 코드를 거부하고, 응답 JSON object, `id`, `path`, 테스트 origin의 `/uploads/` 경로를 검증한다. `.github/ci/putduk-step10-integration.sh`는 helper를 호출한 다음 기존 안전 경로 형식 검사와 `/uploads/<relative-path>`의 실제 파일 존재·비어 있지 않음을 Postiz 컨테이너에서 확인한다. 이어지는 기존 업로드 볼륨 백업·복원 검사는 파일 SHA-256 비교를 수행한다.
- 회귀 테스트는 수정 전 현재 스크립트에 validator 호출이 없는 상태에서 실패(1 test, 1 fail)함을 확인했다. 수정 후 HTTP 200/201 성공, HTTP 400/500 거부, 잘못된 JSON, ID/path 누락, 격리 경로 외 URL 거부를 테스트한다.
- 사전 검증 결과: CI와 동일한 Node 테스트 명령 16/16 통과, Bash 스크립트 문법 검사 통과, Actions YAML 파싱 통과, 두 신규 JS 파일 Prettier 검사 통과, HTTP 201 CLI 성공 및 HTTP 400 CLI 실패 동작 확인, `git diff --check` 통과. 운영 Compose와 PM2/backend/network 시작 설정은 변경하지 않았다.
- 이 변경의 유일한 전체 Actions 실행은 `https://github.com/goldeget/putduk-social-auto/actions/runs/38818085590` (job `116707669891`, source SHA `f4239ead8caa36f375b45d6e0383670d66b80481`)이다. 회귀 검증, 비밀정보/디스크 사전 검사, linux/amd64 Docker 이미지 빌드 및 이미지 검사, 사전 통합 디스크 확인은 성공했다. 통합 단계는 22:44:19~22:47:11 UTC 실행 후 **exit 1**로 끝났고 run-scope 정리는 성공했다. GitHub의 failure annotation은 정확한 phase `upload fake image, schedule post, and verify Temporal timer` 및 `exit_code=1`을 제공한다. 진단에는 Postiz `status=running`, `healthy`, `exit=0`, `OOMKilled=false`, 재시작 0, frontend/backend/orchestrator PM2 모두 `online`/재시작 0, 포트 3000·4200·5000 open, Prisma 시작 체인 완료가 포함됐다. 그러나 annotation의 Postiz 로그 일부는 route mapping뿐이며, HTTP status/body, 실패한 명령/줄 번호, 이미지 파일 존재, schedule/Temporal 결과를 포함하지 않는다. 인증된 step 로그 URL은 이 환경에서 HTTP 404를 반환하므로 이 실행의 업로드/예약/Temporal 세부 성공 여부를 확정하지 않는다.
- 현재 run은 `upload fake image, schedule post, and verify Temporal timer` 단계에서 종료됐으므로 다음 restart 단계와 PostgreSQL/Redis/Temporal/Elasticsearch/업로드 백업·복구는 시작하지 않았다. 이 실행의 실제 RAM·CPU·디스크 숫자는 공개 annotation/page에 나오지 않아 **미확인**이다. 이전 Actions `38815929001`에서 성공한 여섯 서비스, PM2 3개, readiness 8.1초, frontend/Nginx HTTP 200, 네트워크 연결, 가입·로그인·대시보드, 초안 생성·조회는 사용자 확인 원시 로그로 계속 **성공**으로 기록한다. 그 실행의 업로드는 HTTP 201이었고 그 다음 JSON·파일 확인 전 HTTP 200 전용 조건 때문에 실패했다. 이 성공들을 뒤의 실행 로그 접근 제한으로 미검증 처리하지 않는다.

## Temporal 예약 워크플로 진단 및 오류 가시성 보완 — 2026-10-15

- 시작 시 저장소 `goldeget/putduk-social-auto`, 브랜치 `work`, 로컬·원격 SHA `43fea2f1702d8e6a942d3ff60f18e712ee3d6170` 일치, 깨끗한 작업 트리를 확인했다. 환경 활성화 후 Node `22.20.0`, pnpm `10.6.1`이었다.
- 사용자가 인증된 Actions 로그에서 확인한 실행 `38818085590`의 정확한 결과: 여섯 Docker 서비스 healthy, PM2 세 앱 online, 백엔드/API·프런트엔드·Nginx HTTP 검사, 관리자 가입·로그인·권한, 초안 생성·조회, 이미지 업로드 응답 및 격리 저장 파일 검사, 예약 API 응답과 Postiz `QUEUE` 상태가 성공했다. 실패는 90초 Temporal 검사 `Temporal did not show the future workflow as running.`이었다. 이 실행은 Temporal 이후의 재시작 및 백업·복원 단계에 진입하지 않았다.
- 소스에서 신뢰성 위험을 확인했다. `PostsService.startWorkflow()`는 기존 실행 목록 조회 예외와 `workflow.start('postWorkflowV112', ...)` 예외를 빈 `catch`로 삼킨다. 게시물 생성 경로도 `startWorkflow(...).catch(() => {})`를 사용하고, 상태/날짜 변경 경로도 오류를 삼킨다. 따라서 `QUEUE` 응답은 Temporal 실행 생성의 증거가 아니다. 이번 최소 변경은 동작/API 응답을 아직 바꾸지 않고, workflow start 실패의 유형·메시지를 URL 자격정보, 흔한 비밀 key-value, bearer/JWT 패턴을 가려 로그에 남긴다. 실제 실패한 Temporal RPC 오류 자체는 새 격리 run 전이라 **미확정**이다.
- 현재 compose의 고정된 Temporal admin-tools 이미지에서 CLI 버전/도움말을 확인했다. `workflow describe`, `workflow list`, `task-queue describe` 및 `--output json`은 지원된다. 이어 `--network none`, 임시 컨테이너·임시 SQLite DB를 쓰는 Temporal `start-dev` probe를 실행했다. 워커 없는 workflow 시작 후 실제 JSON에서 `workflowExecutionInfo.status = WORKFLOW_EXECUTION_STATUS_RUNNING`을 읽었고, 동일 WorkflowId 필터의 list 결과와 task queue describe(`pollers: null`, backlog 통계 포함)를 확인했다. probe 컨테이너는 자동 정리됐으며 기존 `trusting_nightingale`, `postiz-cloud-*` 자원은 변경하지 않았다.
- `.github/ci/putduk-step10-integration.sh`는 기존 90초 제한을 유지하면서 describe JSON의 상태를 판정한다. 실패하면 describe 종료 코드와 안전한 상태 요약, 해당 WorkflowId 전용 list 결과, `main` task queue의 poller/backlog 요약 및 마스킹된 오류를 수집한다. 재시작 후 확인에도 같은 JSON 판정을 적용했다. `.github/workflows/putduk-docker-build-check.yml`에 검사 파일을 경로 감시와 Node 테스트 명령으로 추가했다.
- 새 상태 판정 테스트와 오류 로그 가드 테스트 포함 기존 CI Node 검사 22/22 통과, `bash -n`, workflow YAML 파싱, 신규 JS Prettier 검사, `git diff --check` 통과. `pnpm run build:backend`도 exit 0으로 완료했다. 전체 Postiz Actions 통합 재실행 및 앱 런타임 Temporal workflow 생성은 아직 미실행이다. 이번 변경을 보존한 뒤 허용된 전체 Docker/GitHub Actions 실행은 최대 1회만 수행한다.
- 이전 실행의 재시작 후 예약 보존, Postiz/Temporal DB·Redis·Elasticsearch·업로드 백업/복원, 실제 서버에 준하는 RAM/CPU/디스크 결과는 **미검증**이다. 실제 SNS OAuth/게시도 이 단계에서 하지 않는다. 서버 구매 판정은 **NO-GO** 유지.

### 단일 Temporal 진단 통합 실행 결과 — 2026-10-15

- 진단 변경 커밋 `a1fe1ea01c4a63356c912f4095f2a427473f0bff`는 `work`에 푸시됐고 로컬·원격 SHA 일치를 확인했다. 실행 링크: `https://github.com/goldeget/putduk-social-auto/actions/runs/38821360283` (job `116718434380`). 공개 Actions 페이지에서 source SHA가 해당 커밋임을 확인했다.
- Node 회귀 테스트, 비밀정보 파일 검사, 사전 디스크 검사, Docker Buildx, linux/amd64 이미지 빌드, 이미지 메타데이터/비밀 검사, 통합 전 디스크 여유 검사는 성공했다. Docker 이미지 빌드는 약 9분 25초였다.
- `Run isolated Step 10 integration checks` 단계는 23:14:39–23:16:14 UTC, 약 95초 후 실패했다. 해당 단계 전체 실패는 확인되지만, 공개 job page에는 내부 스크립트 phase나 Temporal CLI 진단 내용이 표시되지 않는다. 인증된 Actions API는 현재 GitHub CLI에서 토큰 거부를 반환했고, 상세 log URL은 HTTP 404였다. 따라서 이 새 실행에서 실제 workflow 존재/상태, `workflow start` 오류, worker poller/backlog, 로그인 이후 어느 검사까지 통과했는지는 **미확정**이며 성공으로 보고하지 않는다.
- run 전용 정리 단계와 사후 자원 기록 단계는 성공했다. 다만 요약의 RAM·CPU·디스크 숫자를 읽을 수 없어 수치는 **미확인**이다. 이 실행은 실패했으므로 후속 재시작과 데이터 백업·복원은 완료 증거가 없고 **미검증**이다.
- 사용자가 전달한 이전 실행 `38818085590`의 업로드·예약 API 및 Postiz `QUEUE` 통과 사실은 유효한 기존 증거다. 새 단일 실행 후에도 Temporal 예약 성공, 재시작, DB/Temporal/Redis/Elasticsearch/미디어 복원은 검증되지 않았다. 통합 재실행 한도는 사용 완료했고, 서버 구매 판정은 **NO-GO** 유지한다. 상세 실패 원인을 확정하려면 Actions의 인증된 “Run isolated Step 10 integration checks” 원시 로그가 필요하다.

## 재시작 안정화 및 전체 복구 검증 — 2026-10-15

- 시작 시 저장소 `goldeget/putduk-social-auto`, 브랜치 `work`, 로컬·원격 SHA `52a8750f8c2c8c191868fa1d27a9d93b7ea19760` 일치와 깨끗한 작업 트리를 확인했다. 환경 활성화 후 Node.js `22.20.0`, pnpm `10.6.1`을 확인했다.
- 사용자가 인증된 원시 로그로 확인한 `38821360283`의 정확한 범위: 여섯 Docker 서비스 healthy, PM2 세 앱 online, 관리자 등록·로그인·대시보드, 초안, 이미지 업로드, 30일 예약 및 Temporal `RUNNING`까지 성공했다. 재시작 이후 예약 API 조회 시점에는 Postiz/Temporal 컨테이너가 healthy였으나 backend 3000이 닫혀 HTTP 검사가 실패했다. 이 실행은 재시작 뒤 Temporal 재조회 전에 중단됐으므로 재시작 후 예약/워크플로 보존 및 그 이후 백업·복원은 미검증이었다. 이는 통합 스크립트가 재시작 후 backend readiness를 기다리지 않은 것이 직접 확인된 검사 결함이다. 서버 기동이 늦어진 내부 원인은 이 로그만으로 확정하지 않는다.
- 기존 `scripts/backend-readiness.mjs`의 최대 180초·4초 간격·개별 3초 요청 제한, HTTP 200과 `{register: boolean}` 검증을 재사용하도록 재시작 순서를 수정했다. 재시작 후 검사는 현재 Compose 컨테이너의 edge 사설 IP를 다시 읽고, 연결 네트워크가 계속 internal이고 앱 포트가 게시되지 않았는지 재검증한다. 그 뒤 frontend 4200과 Nginx 5000 HTTP 200, 인증 쿠키가 든 실제 예약 API 조회를 확인한다.
- 새 `scripts/step10-restart-readiness.mjs`는 인증 예약 GET이 502/503이면 최대 180초 동안 4초 간격으로 다시 확인한다. 개별 curl 요청은 남은 기한에 맞춘 timeout을 쓰고 프록시를 우회해 지정된 loopback URL을 격리 edge 사설 IP로 연결한다. 401/403은 인증 오류로 즉시 분리하고, 나머지 HTTP 오류도 재시도하지 않는다. 로그에는 응답 본문·쿠키를 출력하지 않고 상태, 안전한 요청 오류 코드, 시도 수와 경과 시간만 남긴다.
- 재시작 후 예약 레코드는 재요청 결과의 `QUEUE` 상태를 확인한다. Temporal은 이전 describe JSON을 재사용하지 않고 새 `temporal-after-restart.json` 파일을 만들어 같은 Workflow ID의 실제 `RUNNING` 상태를 다시 확인한다. 통합 뒤의 기존 실제 테스트 DB·Temporal history·Redis·Elasticsearch·업로드 파일 백업/복원 검사는 그대로 이어진다.
- 신규 회귀 테스트는 502/503에서 200 회복, 401/403 즉시 인증 실패, 비일시 500 실패, transport 오류의 제한시간, hard deadline을 검사한다. 통합 순서 검사도 재시작→backend readiness→사설 IP 재조회/격리 검증→frontend/Nginx→인증된 예약 조회 순서와 새로운 Temporal 조회 파일을 확인한다.
- 사전 로컬 검증: CI Node 테스트 29/29 통과, `bash -n` 및 JavaScript 구문검사 통과, Actions/Compose YAML 파싱 통과, 프로덕션+격리 테스트 Compose config 검사 통과, `git diff --check` 통과. 로컬 loopback HTTP 서버를 통한 curl CLI 시험에서 쿠키가 유지되고 첫 502 뒤 두 번째 요청의 HTTP 200 및 QUEUE JSON이 확인됐다. 이는 Postiz의 재시작이나 통합 기능 실행은 아니다.
- 기존 `.github/workflows/build.yml`은 모든 push에서 별도로 전체 `pnpm run build`를 수행한다. 사용자가 제공한 현재 일반 Build의 `next/font/google` 실패는 이 재시작 통합 검사와 별도 현상이며 폰트/UI 구성은 변경하지 않는다. 이 환경은 GitHub API 요청에 HTTP 403을 반환해 최신 일반 Build run 로그는 독립 조회하지 못했다. Docker 통합 실행은 수정 근거가 확인된 후 1회만 수행한다.
- 미검증: 이번 수정 후 Actions 전체 통합, 실제 재시작 후 인증 예약 조회 및 Temporal 상태, Postiz/Temporal PostgreSQL·Redis·Elasticsearch·업로드 복원, RAM/CPU/디스크 수치. 실제 SNS 연결/게시도 하지 않았다. 백업/복원과 운영 자원 측정은 통합 run이 해당 단계까지 성공하면 보고하고, 실행 전에는 성공으로 표시하지 않는다. 운영 서버 구매 판정은 **NO-GO** 유지한다.

### 단일 재시작·복구 통합 실행 결과 — 2026-10-15

- 수정 커밋 `2a71e263d3ddbeda83d23d14d958b8f8bcff14ca`를 `work`에 push했다. 해당 커밋에서 무료 일반 `ubuntu-latest`로 통합 run `38824053103` (`https://github.com/goldeget/putduk-social-auto/actions/runs/38824053103`) 한 번만 실행했다. Node 회귀 검사, secret 파일 차단, 디스크 사전 확인, amd64 이미지 빌드 및 이미지 검사 모두 통과했다. 이미지 빌드 시간은 9분 8초, 전체 job 시간은 약 11분 56초였다. 이미지 push는 하지 않았다.
- 재시작 후 backend readiness, 4200/5000 검사 및 사설 IP 재조회 후 인증 쿠키를 통한 예약 GET이 다음 단계로 진행될 때까지 성공했다. 통합 run은 그 뒤 동일 예약이 `QUEUE`인지 확인하고 새 파일에 쓴 Temporal describe 결과가 `RUNNING`인지 판정했다. 이전 pre-restart JSON은 재사용하지 않았다. 따라서 요청된 재시작 검사 결함은 이번 실행에서 통과했다. 공개 페이지에는 재시작 뒤 readiness 경과 시간·시도 수와 예약/Temporal 개별 응답 본문이 노출되지 않아 그 수치는 미확인이다.
- 실제 테스트 데이터에 대해 Postiz PostgreSQL backup/restore 후 draft·scheduled state, Temporal PostgreSQL execution history restore, Redis AOF restart 및 독립 RDB restore, 업로드 파일 volume restore와 SHA-256 대조를 수행하고 다음 Elasticsearch 단계에 도달했다. 이들은 해당 run에서 통과한 것으로 판단할 수 있다. 외부 저장소에서의 백업이나 12GB 실제 VPS 복구는 포함하지 않았다.
- run은 Temporal Elasticsearch snapshot repository 등록의 `acknowledged` 검사를 통과한 뒤 `.github/ci/putduk-step10-integration.sh` 809행의 snapshot 생성 curl 요청에서 종료 코드 `22`로 실패했다. 이는 curl이 HTTP 오류 응답을 받았다는 사실을 뜻하지만, 공개 GitHub run 페이지에는 정확한 HTTP 상태·응답 본문이 없어 Elasticsearch snapshot 오류의 상세 원인은 **미확정**이다. Elasticsearch snapshot/restore 및 뒤따르는 fatal-log scan은 미검증이다. 근거 없이 스냅샷 정책이나 서비스 구성을 변경하지 않았다.
- 실패 진단에서 Postiz는 healthy, `OOMKilled=false`, 재시작 0이었고 PM2 frontend/backend/orchestrator 세 앱은 모두 online/재시작 0, 포트 3000·4200·5000은 열려 있었다. Temporal Workflow ID는 진단 당시 `RUNNING`이었다. Redis 재시작 순간의 `ECONNREFUSED`/`EAI_AGAIN` 로그는 있었으나 이후 예약·백업·복원 단계는 진행됐다. 이는 관측된 일시 오류이며 그 자체가 최종 실패 원인이라고 단정하지 않는다.
- 실패 뒤 Actions의 `Clean up only this Step 10 run`도 종료 코드 1로 끝났다. 정확한 cleanup 오류는 공개 로그에서 확인할 수 없어 해당 실행기의 임시 컨테이너/볼륨 정리를 완전히 입증하지 못한다. runner는 GitHub-hosted 임시 실행기이며 run 이후 다른 실행에 자원이 전달되지 않지만 cleanup 결과는 **미확인**으로 기록한다. 가능한 잔여 리소스의 정확한 종류는 알 수 없다.
- 최대 container RAM/CPU와 디스크 수치는 공개 check annotation에 포함되지 않아 **미확인**이다. 사전 디스크 안전 게이트는 통과했다. 이 실행은 목표 VPS 자원 적합성을 증명하지 않는다.
- 같은 커밋에서 별도 일반 Build run `38824053077` (`https://github.com/goldeget/putduk-social-auto/actions/runs/38824053077`)의 `pnpm run build`가 성공했다. 따라서 사용자가 앞서 언급한 일반 Build의 `next/font/google` 실패는 이 커밋의 실행에서는 재현되지 않았다. 글꼴 코드나 UI를 변경하지 않았다.
- 통합 실행 허용 횟수 1회를 모두 사용했으므로 추가 전체 Docker/GitHub Actions 통합 실행은 하지 않는다. 다음 필요한 최소 작업은 Elasticsearch snapshot API의 비밀 없는 HTTP 상태/오류 본문과 cleanup 단계의 상세 종료 원인을 기록하도록 진단만 보강한 뒤, 별도 승인된 테스트 횟수 안에서 격리 검증하는 것이다. Elasticsearch 복원, fatal-log scan, 자원 사용량은 아직 검증되지 않았으며 운영 구매 판정은 **NO-GO**다.

## Elasticsearch 스냅샷 API 및 CI 임시 자원 정리 안정화 — 2026-10-16

- 시작 기준 저장소 `goldeget/putduk-social-auto`, 브랜치 `work`; 로컬·GitHub 원격 SHA `e53ff50ffd2ebf1de6819140fcfbfb8db4a97f5e` 일치, 시작 작업 트리 깨끗함을 확인했다. 활성화 스크립트 후 Node.js `22.20.0`, pnpm `10.6.1`이었다. main 및 다른 저장소는 열거나 변경하지 않았다.
- 최소 Elasticsearch 7.17.27 probe는 `--network none`, 스냅샷 저장 위치만 고유한 `/tmp` 테스트 폴더에 연결해 실행했다. 이전 URI 형식은 실제 HTTP 400과 `illegal_argument_exception` / `request ... contains unrecognized parameter: [include_global_state]`를 반환했다. 따라서 `include_global_state`를 URL 쿼리에 넣은 것이 원인이었다. JSON 본문 `{"include_global_state":true}`와 `wait_for_completion=true`만 쿼리에 둔 요청은 스냅샷 `SUCCESS`를 반환했고, 별도 Elasticsearch 클러스터에서 복원하여 실패 0건과 테스트 문서 내용을 확인했다. Elasticsearch 버전/운영 Compose는 변경하지 않았다. probe 컨테이너와 호스트 임시 데이터는 정리했고, 확인 후 내려받았던 ES 이미지 태그도 제거했다.
- 통합 스크립트는 본문에 `include_global_state`를 보내고 HTTP 상태 및 스냅샷 `SUCCESS`를 별도 검증한다. 실패 시 HTTP 상태와 allowlist된 오류 유형만 기록하며 Elasticsearch 오류 본문이나 원문 reason은 출력하지 않는다.
- 직전 Actions의 cleanup 단계는 임시 폴더 소유권을 확인하지 않았고 `rm -rf` 권한 오류의 정확한 파일 UID/GID를 남기지 않았다. 따라서 그 실행의 실제 UID/GID 원인을 사후에 확정할 수는 없다. 다만 격리 재현에서 root 소유 중첩 디렉터리/파일은 일반 실행 사용자 삭제를 거부했고, 해당 고유 폴더만 실행 사용자에게 소유권을 넘긴 뒤 삭제가 성공했다. Actions cleanup은 정확한 run ID, state metadata, runner-temp 직속 경로, 심볼릭 링크 부재를 검증한 뒤에만 제한된 `chown`/삭제를 수행한다. Compose 프로젝트 레이블 및 명시적 run 레이블로 컨테이너·볼륨·네트워크를 각각 제거·재조회하며, 전역 prune이나 이미지/cache 삭제는 하지 않는다. cleanup은 기존처럼 `if: always()`에서 실행된다.
- 추가한 회귀 검사에는 스냅샷 상태/HTTP 오류 및 비밀 문구 마스킹, cleanup 경로·레이블 규칙이 포함된다. root 소유 파일 cleanup fixture는 고유 합성 run ID 아래 root 소유 중첩 파일을 만들고 정리하며, 심볼릭 링크 및 불일치 상태 정보일 때 대상 보존을 검사한다.
- 사전 로컬 검증: Node 회귀 테스트 `39/39` 통과; Bash 구문 검사, JavaScript 구문 검사, 세 YAML 파일 파싱, `git diff --check` 통과. 격리 Compose 정적 렌더링에는 6개 서비스, 게시된 호스트 포트 0개, internal 네트워크 3개 및 각 서비스의 영구 볼륨 설정이 확인됐다. root 소유 정리 fixture는 현재 실행기에 passwordless sudo가 없어 컨테이너 기반 root 소유 파일과 임시 sudo shim으로 실제 경로를 재현했다. GitHub-hosted `ubuntu-latest`에서는 workflow의 별도 fixture가 passwordless sudo를 직접 확인한 뒤 수행한다.
- 이번 수정 전후의 전체 GitHub Actions 통합 실행은 아직 하지 않았다. 단일 실행은 커밋·푸시 후 이 워크플로가 자동 시작되면 한 번만 확인한다. 이전 기능 성공 기록은 직전 실행 `38824053103`의 해당 통과 단계에만 적용하며, 새 통합 run 결과로 간주하지 않는다. 실제 SNS 연결/게시, 서버 배포, 운영 데이터 변경은 하지 않았다. 이번 결과의 운영 서버 구매 판정도 **NO-GO**다.
- 다음: 사전 검사 후 `work`에 이 변경과 기록을 체크포인트 커밋·푸시하고, 원격 SHA 일치를 확인한 뒤 자동 통합 실행 하나의 실제 결과를 기록한다.

### 원격 체크포인트 및 통합 실행 조회 상태

- 코드·워크플로 변경은 `761d42c8c83bcf673cb0bbe767db7b9999b18b42`로 `work`에 push했다. 이후 이 기록만 별도 커밋으로 추가한다.
- push가 workflow의 `work` 브랜치 및 변경 경로 조건을 만족하므로 자동 통합 실행이 예상되지만, 이 실행 환경에서 GitHub Actions run ID/상태/로그는 확인하지 못했다. `gh auth status`는 현재 인증 토큰이 유효하지 않다고 보고했고, GitHub API 조회는 네트워크 프록시에서 HTTP CONNECT 403으로 차단됐다. 따라서 Actions 통합 결과는 **UNVERIFIED**이며, 성공으로 판정하지 않는다. 최대 1회 제한을 지키기 위해 수동 재실행하지 않는다.
- 확인 위치: https://github.com/goldeget/putduk-social-auto/actions/workflows/putduk-docker-build-check.yml?query=branch%3Awork . 실행이 실제로 완료됐는지는 해당 Actions 기록에서 확인해야 한다.
- GitHub 원격 `work` SHA는 코드 체크포인트 push 직후 `761d42c8c83bcf673cb0bbe767db7b9999b18b42`와 일치했다. 이 기록 추가 후 최종 원격 SHA는 완료 보고서와 재조회 결과에 기재한다. 새 전체 통합 실행 결과가 확인되기 전 운영 구매 판정은 **NO-GO**다.

## Temporal 종료 명령 주소 보완 — 2026-10-16

- 시작 시 저장소 `goldeget/putduk-social-auto`, 브랜치 `work`, 로컬·원격 SHA `2d85ca373d2f6b9449d83f5959308f20039eb4c9`가 일치하고 작업 트리가 깨끗한 것을 확인했다. 기준 이후 원격 변경은 없었다.
- 사용자가 전달한 Actions `38869461144` 로그 판정은 Elasticsearch 스냅샷 `SUCCESS`, 실행별 임시 자원 정리 성공, 마지막 Temporal workflow terminate 단계에서 `[::1]:7233` 연결 거부다. 기존 종료 명령만 `--address temporal:7233`이 빠져 있었다. 같은 스크립트의 workflow describe/list/task-queue describe 명령은 모두 이 주소를 명시한다.
- `scripts/step10-temporal-terminate.test.mjs`를 먼저 추가해 기존 명령에서 실패하는 RED 결과를 재현했다. 종료 명령에 `--address temporal:7233`을 추가한 뒤 테스트가 통과한다. `.github/workflows/putduk-docker-build-check.yml`에 새 테스트 파일의 경로 및 테스트 실행을 연결했다. 운영 Compose, 앱 코드, 로그인·예약·백업 경로는 변경하지 않았다.
- 별도 internal Docker 네트워크에서 기존 캐시된 Temporal CLI 이미지로 개발용 Temporal 서버를 격리 실행했다. CLI가 시작/종료/조회 서버에 도달하는지 확인했고, 테스트 Workflow를 생성한 뒤 `temporal workflow terminate --address temporal:7233 ...`로 종료, 새 describe 결과에서 `WORKFLOW_EXECUTION_STATUS_TERMINATED`를 확인했다. 테스트 컨테이너와 네트워크만 정리했으며 기존 `postiz-cloud-*`와 `trusting_nightingale` 자원은 보존했다. 테스트 CLI 컨테이너에서 실행기 프록시 환경변수를 비워야 Docker 내부 DNS 주소로 연결됨도 확인했다.
- 기존 Step 10 회귀 테스트 전체와 신규 테스트는 40/40 통과했다. `bash -n .github/ci/putduk-step10-integration.sh`, workflow YAML 파싱, `git diff --check`도 통과했다. 전체 통합 실행은 아직 수행하지 않았다.
- 변경 후 자동 실행될 무료 GitHub Actions 통합 테스트가 이번 단계의 유일한 전체 실행이다. 실행 결과는 실제로 조회·확인될 때까지 미검증으로 처리한다. Actions가 확인되지 않으면 수동 재실행하지 않는다. 운영 서버 구매 판정은 **NO-GO**다.
- 코드·테스트 체크포인트 커밋 `3932db505d036291f225c0141dd123d60c1fb130`을 `work`에 push했고, 직후 `git ls-remote`에서 원격 SHA가 로컬과 일치함을 확인했다. 이 변경으로 workflow가 자동 시작되는 조건이다.
- Actions 실행 조회는 이 환경의 GitHub API 프록시 `CONNECT 403` 차단과 유효하지 않은 `GH_TOKEN` 때문에 확인하지 못했다. 따라서 통합 실행 ID·결과는 **미검증**이며, 수동 재실행하지 않는다. 확인 위치는 https://github.com/goldeget/putduk-social-auto/actions/workflows/putduk-docker-build-check.yml?query=branch%3Awork 이다.

## STEP 11 운영 배포 사전 점검 — 2026-10-16

- 시작 시 `goldeget/putduk-social-auto`, `work`, 로컬·원격 SHA `c3a55c321d8e8ee5180df4a62fc99755f304d073`가 일치했고 작업 트리는 깨끗했다. Node `22.20.0` 및 pnpm `10.6.1` 활성화 확인. 기존 `main`과 다른 저장소는 변경하지 않았다.
- 사용자가 확인한 Step 10 Actions `38871945385` 전체 성공(6개 서비스, PM2 세 앱, 로그인, 초안, 이미지, 예약/Temporal, 재시작, PostgreSQL/Redis/Elasticsearch/업로드 복원, 임시 자원 정리)을 기준선으로 기록했다. 이번에는 전체 Docker 통합을 재실행하지 않았다.
- 운영 Compose와 Step 10 overlay를 비교했다. 실제 운영 HTTPS/Caddy는 Step 10에서 비활성, 테스트 가입 및 `NOT_SECURED=true`는 운영의 `DISABLE_REGISTRATION=true`/`NOT_SECURED=false`와 다르다. Step 10 앱 명령은 이미지 내 Prisma CLI를 사용하지만 Dockerfile 기본 시작은 `pnpm dlx prisma@6.5.0 db push`를 실행해 네트워크 다운로드와 자동 DB schema 변경 위험이 남는다. DB/Redis/Temporal/ES 호스트 포트는 운영 Compose에서 공개되지 않고 internal network를 사용한다.
- Step 10 이미지는 Actions 실행기 로컬에서만 만들어졌고 운영 Compose의 `POSTIZ_IMAGE` 예제는 공식 `gitroomhq/postiz-app` 이름과 치환용 가짜 digest를 가리킨다. 따라서 퍼뜩 소스와 일치하는 운영 이미지 digest/공급 경로는 미확보. 운영 Compose의 메모리 상한은 Elasticsearch만 2GiB이며 Step 10의 합산 8.75GiB/5 vCPU는 테스트 상한이지 실제 사용량이 아니다.
- `OPENAI_API_KEY`는 코드의 일부 AI 경로에 쓰이지만 production example 및 Compose 환경에 선언되지 않아 현재 운영 구성에는 전달되지 않는다. Facebook/Instagram, Threads, YouTube와 TikTok의 코드상 환경변수 및 콜백 경로를 기록했으나 앱 심사·권한·HTTPS 콜백 등록·실제 계정 연결은 전부 미검증이다.
- 확인한 명확한 비밀정보 위험: `.gitignore`에는 실제 `.env.production` ignore가 있으나 `.dockerignore`에는 없었다. `Dockerfile.dev`의 `COPY . /app`에 따라 로컬 루트의 실 env가 이미지 컨텍스트에 포함될 수 있어 `.dockerignore`에 `.env*`를 추가했다. 임시 BuildKit context로 실제 `.env.production`과 `.env.production.example` 둘 다 제외되고 일반 소스는 포함되는 것을 검증했다.
- `docs/step11-pre-deployment-readiness.md`에 운영 점검표, 배포 전 차단 항목, 자원 및 비용 한계, HTTPS/방화벽, 백업·복원, AI 변수, SNS 콜백, 구매 전/후 절차를 작성했다. 예시 compose 정적 config 검사는 통과했다. VPS, DNS, HTTPS, 외부 백업, 운영 모드 부하, 실제 OAuth/게시, 이미지 pull은 실행하지 않았으며 서버 구매 판정은 **NO-GO**다.
- 변경 파일: `.dockerignore`, `docs/step11-pre-deployment-readiness.md`, `docs/PUTDUK_WORK_LOG.md`. Step 10 app/Compose/workflow 및 `main`은 변경하지 않았다. 변경은 안전한 work 체크포인트로 보존 후 원격 SHA를 재조회한다.
