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
