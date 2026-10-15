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
