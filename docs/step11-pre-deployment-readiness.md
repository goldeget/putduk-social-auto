# PUTDUK Step 11 — 운영 배포 사전 점검

점검 기준 저장소는 `goldeget/putduk-social-auto`, 브랜치는 `work`, 시작 커밋은 `c3a55c321d8e8ee5180df4a62fc99755f304d073`다. 사용자가 제시한 GitHub Actions 실행 [38871945385](https://github.com/goldeget/putduk-social-auto/actions/runs/38871945385)은 Step 10 격리 통합 검증 전체 성공으로 기록한다. 이번 점검에서는 그 실행을 반복하지 않았고 실제 VPS, 공개 HTTPS, OAuth 또는 외부 SNS 게시를 시험하지 않았다.

## 현재 판정

**운영 배포 준비: NO-GO.** 격리 환경의 내부 앱 흐름은 검증됐지만, 운영 Compose의 HTTPS·공개 접근·비밀값·외부 백업·실제 이미지 공급 경로는 아직 서버에서 검증되지 않았다. 특히 현재 Compose 예제는 Step 10에서 검증한 퍼뜩 소스 이미지가 아니라 공식 Postiz GHCR 이미지 이름과 가짜 digest를 가리킨다. 테스트 성공을 현재 배포 이미지의 실행 증거로 볼 수 없다.

### 사실과 한계

| 확인 항목 | 현재 확인된 내용 | 미확인 또는 위험 |
| --- | --- | --- |
| Step 10 기능 | 사용자가 확인한 Actions 실행에서 6개 서비스, PM2 앱, 관리자 로그인, 초안·이미지·예약, Temporal, 재시작, 격리 DB·미디어 백업 복원 및 자원 정리 성공 | 실제 VPS에서의 장시간 운영, 실 SNS API 게시, 공개 TLS는 테스트하지 않음 |
| 운영 Compose 문법 | `.env.production.example`의 예시 값으로 `docker compose config --quiet` 및 구성 렌더링 성공 | 예시의 가짜 비밀값과 가짜 이미지 digest로 실제 기동한 것이 아님 |
| 네트워크 | Caddy만 80/443 TCP와 443 UDP 게시. Postiz는 컨테이너 내부 5000만 노출. DB, Redis, Temporal, Elasticsearch 호스트 포트는 미게시. `app-data`와 `temporal` 네트워크는 internal | VPS 방화벽, 제공업체 방화벽, 실제 DNS와 Caddy 인증서 발급은 미검증 |
| 저장 | Postiz/Temporal PostgreSQL, Redis, Elasticsearch, Postiz 업로드, Caddy 데이터·설정에 named volume이 정의됨 | 서버 외부 자동 백업·보존·복구 주기는 아직 실행 가능한 설정으로 구현되지 않음 |
| 재시작 | Compose 서비스는 `unless-stopped`, 시작 의존성과 healthcheck가 정의됨 | 호스트 재부팅, 전원 장애, 실제 Docker daemon 자동 시작 및 데이터 손상 복구는 VPS에서 검증 전 |

## 서버 구매 전 차단 항목

1. **배포 이미지 경로와 소스 일치:** Step 10은 `Dockerfile.dev`에서 `GITHUB_SHA`를 OCI revision으로 표시한 amd64 이미지를 GitHub Actions 실행기 로컬에서만 만들었다. 레지스트리에 올리지 않았으므로 영구 pull 가능한 digest가 없다. 반면 `.env.production.example`은 `ghcr.io/gitroomhq/postiz-app@sha256:REPLACE_WITH_TESTED_64_HEX_DIGEST`를 적고 있어 upstream Postiz 이미지와 잘못된 예시 digest를 가리킨다. `POSTIZ_IMAGE`에는 `work`의 정확한 검증 커밋에서 만든 퍼뜩 이미지의 실제 immutable digest가 필요하다. 공개 GHCR 게시나 계정·레지스트리 생성은 승인 없이 하지 않는다.
2. **실행 명령과 DB 스키마 변경:** `Dockerfile.dev`의 기본 CMD는 `pnpm run pm2`이고, 루트 `pm2-run`은 시작 때 `pnpm run prisma-db-push`를 실행한다. 이 스크립트는 `pnpm dlx prisma@6.5.0 db push`로 패키지를 네트워크에서 가져오며 DB 스키마를 자동 변경할 수 있다. Step 10 overlay는 인터넷 차단을 유지하려고 `pnpm exec prisma db push`로 명령을 덮어썼다. 따라서 성공한 CI 검증은 production의 정확한 시작 경로와 외부 패키지 다운로드 동작을 검증하지 않았다. 재시작마다 자동 스키마 변경을 할지, 버전 고정된 로컬 CLI와 별도 승인 마이그레이션 절차를 쓸지 결정하고 격리 복구를 시험해야 한다.
3. **12GB 자원 상한:** Step 10 overlay의 컨테이너 제한은 합계 약 8.75 GiB / 5 vCPU다(앱 4 GiB/2 CPU, Temporal 2 GiB/1 CPU, Elasticsearch 1.5 GiB/0.75 CPU, 나머지 DB와 Redis). 이는 CI의 제한값이지 사용량 측정치가 아니다. 운영 Compose에는 Elasticsearch 2 GiB 제한만 있고 나머지 서비스의 CPU/RAM 제한은 없다. 서비스가 상한까지 사용하면 Ubuntu, Docker, 파일 캐시와 장애 대응 여유가 보장되지 않는다. 6 vCPU / 12GB는 최초 후보로만 보며, 같은 상한과 실제 운영 workload로 VPS에서 검증 전에는 적합 확정 불가다.
4. **운영 인증 모드:** 운영 Compose는 `DISABLE_REGISTRATION=true`, `NOT_SECURED=false`지만 Step 10은 테스트 가입 허용과 `NOT_SECURED=true`를 사용했다. 공개 HTTPS에서 secure cookie, 최초 관리자 생성·권한, 가입 차단 및 관리자 외부 접근 통제를 확인해야 한다. 현재 Caddy는 관리자 전체 화면을 공개 도메인에 프록시하며 IP 제한/VPN/별도 접근 게이트가 정의되지 않았다.
5. **외부 백업과 복원:** Step 10의 덤프 및 볼륨 복원은 같은 일회용 GitHub runner 내부의 격리 자원에서 성공한 테스트다. 운영 서버 외부 저장소, 백업 암호화 키, 일정·보존·삭제 방지, 알림, 장애 시 새 서버 복원은 미구현·미검증이다. Postiz DB에는 OAuth 자격 증명이 포함될 수 있으므로 암호화와 최소 접근 권한이 필요하다.
6. **런타임 최소 권한과 재현 가능 빌드:** Dockerfile에 `USER` 지정이 없어 기본 컨테이너 사용자(root)로 PM2 앱을 실행한다. 또한 `pnpm install`이 lockfile 고정 모드가 아니고, 전역 PM2와 일부 베이스 이미지는 digest로 고정되지 않았다. `apps/frontend/next.config.js`에서 production browser sourcemap 생성도 켜져 있어 배포 산출물의 소스 노출 필요성을 검토해야 한다. 운영 이미지를 만들기 전 권한, 업로드/설정 볼륨 쓰기, 신뢰할 수 있는 고정 이미지 빌드 및 sourcemap 정책을 별도 검증해야 한다.

위 항목들은 검토에서 드러난 원인과 운영 영향이다. `.dockerignore`의 비밀파일 제외만 이번 단계에서 최소 보완했다. 다른 앱·Compose·Dockerfile 동작은 수정하지 않았다.

## 운영 아키텍처와 공개 포트

```text
인터넷 ── 80/tcp, 443/tcp, 443/udp ── Caddy ── Postiz :5000
                                           ├── app-data (internal): Postgres, Redis
                                           └── temporal (internal): Temporal :7233, Temporal Postgres, Elasticsearch
```

- VPS 방화벽은 80/443을 공개하고 SSH는 키 기반·관리자 IP/VPN 제한으로 열어야 한다. Docker 관리 포트와 Postgres 5432, Redis 6379, Temporal 7233, Elasticsearch 9200은 공개하지 않는다.
- Caddy의 자동 HTTPS 발급 전 실제 보유 도메인의 DNS가 서버로 연결되고 외부에서 80/443 연결이 되는지 확인해야 한다. 이 단계에서는 도메인이나 DNS를 만들거나 바꾸지 않았다.
- `PUBLIC_DOMAIN` 하나가 `MAIN_URL`, `FRONTEND_URL`, `NEXT_PUBLIC_BACKEND_URL`의 기준이다. OAuth 공급자 콘솔에 등록할 콜백은 이 실제 HTTPS 도메인에 아래 경로를 붙여야 한다. `postiz.example.com`은 예시 문자열일 뿐 등록할 주소가 아니다.
- 현재 로그인은 애플리케이션 계정 인증이다. 관리자 MFA, IP allowlist, VPN 또는 외부 접근 게이트가 구성됐다고 볼 증거는 없다. 인터넷 공개 전 별도 관리자 보호 정책을 선택해야 한다.

## 백업·복구 운영안

| 데이터 | 중요도 | 운영 절차 초안 |
| --- | --- | --- |
| Postiz PostgreSQL | 계정·채널 OAuth 정보·초안·예약 | 매일 암호화 덤프와 복구 점검. DB 접근·암호화 키 분리 |
| Temporal PostgreSQL | workflow 실행 기록·타이머 | Postiz DB와 같은 복구 시점으로 백업하고 일정 workflow ID를 복원 후 대조 |
| Elasticsearch | Temporal visibility/search | 등록된 snapshot repository의 별도 snapshot과 복원 시험. 재생성 가능하다고 가정하지 않음 |
| Redis AOF/RDB | 대기 큐·캐시·런타임 상태 | AOF 지속성을 켠 상태로 유지하고 별도 RDB 복구 검증. DB 백업을 대체하지 않음 |
| `/uploads`, `/config` | 게시 미디어·애플리케이션 설정 | 데이터베이스 백업과 함께 보존하고 파일 checksum 확인 |
| Caddy `/data`, `/config` | 인증서·프록시 상태 | 재발급 가능성에 대비해 권한을 제한해 보존 |

- 설계 목표 예시: 매일 암호화 전체 백업, 보존 7일/4주/6개월. 복구 시점(RPO)과 복구 시간(RTO)은 사용자가 정해야 하며 이 일정은 현재 자동화되어 있지 않다.
- 서버와 계정/장애 영역이 다른 저장소에 저장한다. 공급자, 지역, 비용, 암호화 키 보관을 선택하기 전에는 “외부 백업 준비 완료”라고 볼 수 없다.
- 백업 성공 알림은 복원 성공이 아니다. 최소 분기별로 격리된 새 DB/볼륨에 실제 복원하고 사용자·미디어·예약 상태를 대조한다. 이미 SNS에 게시됐을 수 있는 작업은 재개 전 수동 확인해 중복 위험을 줄인다.
- 앱과 Temporal을 한꺼번에 복구할 때 DB, workflow, 미디어의 시점 일치와 중복 예약 방지 절차가 필요하다. Step 10 테스트는 runner 임시 데이터 복원만 검증했다.

## 환경변수 준비 목록

비밀값은 `/etc/putduk/.env.production` 같은 저장소 외부 파일 또는 비밀 관리 도구에 두고 권한을 제한한다. GitHub, Docker 이미지, 일반 로그, 이 작업 기록에 넣지 않는다.

| 변수 | 사용처 | 상태 |
| --- | --- | --- |
| `PUBLIC_DOMAIN` | Caddy 및 공개 URL | 실제 도메인 결정 필요 |
| `POSTIZ_IMAGE` | 테스트된 퍼뜩 이미지 | 현재 예제는 잘못된 upstream placeholder; 검증 digest 미확보 |
| `POSTIZ_DB_PASSWORD`, `REDIS_PASSWORD`, `TEMPORAL_DB_PASSWORD`, `JWT_SECRET` | Postiz/Temporal 보호 | 별도 고유 난수 생성 필요. DB URL 안의 비밀번호는 URL-safe 문자 사용 |
| `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | Facebook 및 Instagram Meta OAuth | 앱 등록·승인 뒤에만 저장 |
| `THREADS_APP_ID`, `THREADS_APP_SECRET` | Threads OAuth | 앱 등록·승인 뒤에만 저장 |
| `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET` | Google/YouTube OAuth | OAuth consent 구성·API 승인 뒤에만 저장 |
| `TIKTOK_CLIENT_ID`, `TIKTOK_CLIENT_SECRET` | TikTok OAuth | 향후 연결, 앱 승인 후 설정 |
| `TIKTOK_BUSINESS_CLIENT_ID`, `TIKTOK_BUSINESS_CLIENT_SECRET` | TikTok Business 연동 | 해당 연동을 선택할 때 승인 후 설정 |
| `OPENAI_API_KEY` | Postiz의 AI 콘텐츠 기능 일부 | production 예제와 Compose 서비스 환경 모두에 없음. env 파일에만 추가해도 앱에 전달되지 않으므로 Compose 전달 설정이 필요함. 서버에서 ChatGPT Work/Codex 계정을 대신하지 않으며 API 사용료·한도 별도 결정 필요 |
| `RUNPOD_API_KEY`, `RUNPOD_ENDPOINT_ID` 등 | 예제의 선택적 영상 처리 흐름 | 현재 production Compose에 연결되지 않았고 별도 비용·구성 필요 |

변수의 값이나 실제 API key는 아직 만들거나 입력하지 않았다. 운영 예제는 실제 계정·도메인 승인을 의미하지 않는다.

## SNS OAuth 준비 현황

아래 콜백 경로는 현재 소스 코드가 `FRONTEND_URL`/`NEXT_PUBLIC_BACKEND_URL`에서 조립하는 경로다. OAuth 공급자 콘솔에 등록하지 않았고 실제 토큰 발급·게시도 하지 않았다. 권한 범위·검수·업무 계정 조건은 플랫폼 개발자 콘솔에서 최신 공식 규칙으로 확인해야 한다.

| 플랫폼 | 코드가 요구하는 변수 | 콜백 경로(실제 도메인 미지정) | 준비 상태 |
| --- | --- | --- | --- |
| Facebook | `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | `/integrations/social/facebook` | 개발자 앱, Page 권한, 앱 검수/라이브 전환 미확인 |
| Instagram | Meta의 `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | `/integrations/social/instagram`, `/integrations/social/instagram-standalone` | 지원 계정 유형, 연결된 자산, API 권한·검수 미확인 |
| Threads | `THREADS_APP_ID`, `THREADS_APP_SECRET` | `/integrations/social/threads` | Threads 앱 설정·권한·앱 검수 미확인 |
| YouTube (Shorts 포함 게시 경로) | `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET` | `/integrations/social/youtube` | Google Cloud OAuth 동의/테스트 사용자, YouTube API 활성화·게시 승인 미확인. Shorts 전용 동작은 별도 실계정 검증 필요 |
| TikTok (향후) | `TIKTOK_CLIENT_ID`, `TIKTOK_CLIENT_SECRET` 또는 Business 변수 | `/integrations/social/tiktok`, `/integrations/social/tiktok-business/` | 이번 필수 범위 밖. 개발자 앱·게시 권한·앱 감사/공개 제한 미확인 |

실제 연결은 HTTPS 공개 주소, 공급자 콘솔의 정확한 redirect URI, 앱 승인, 검증된 비밀 저장, 별도 사용자 승인이 모두 준비된 후에만 수행한다.

## AI 마케팅 기능 및 예상 비용

- 코드에는 `OPENAI_API_KEY`가 없거나 비어 있으면 사용할 수 없는 AI 관련 backend 경로가 있다. 해당 값을 production example은 현재 선언하지 않는다. AI 글/캡션 생성은 API 사용량 기반 별도 과금이 가능하므로 월 상한과 승인 절차를 먼저 정한다.
- ChatGPT Work와 Codex Cloud는 개발·사람의 콘텐츠 작업을 돕는 도구다. 서버의 상시 백그라운드 API 키나 자동 게시 실행기를 제공한다고 간주하면 안 된다. 사용자 승인 워크플로를 실제 운영하기 전에 검토/승인/발행 권한을 분리해야 한다.
- 영상 생성·변환은 현재 Compose에서 지원되는 것으로 확인되지 않았다. 저장소 예제는 RunPod 등 외부 endpoint와 키, 일부 흐름에서는 추가 음성/미디어 서비스를 언급한다. 공급자와 비용은 미정이며 이번 단계에서 연결하지 않았다.
- 서버 기본료는 사용자가 제공한 후보 가격 **약 $9/월**(6 vCPU, RAM 12GB, SSD 200GB)이다. 이는 최신 공급자 가격을 이번에 재조회한 값이 아니다. 도메인, 암호화 외부 백업, 모니터링/알림, AI API, 영상 서비스, 세금/환율 비용은 미확인이다. 무료 Caddy/Let's Encrypt가 기본 TLS 비용을 줄여도 도메인과 백업 비용은 별도일 수 있다.

## 구매 전 / 구매 후 검증 순서

### 구매 전

- [ ] 6 vCPU/12GB/200GB 후보와 정확한 월 비용·세금·대역폭·백업 옵션 확인
- [ ] 실제 퍼뜩 소스 커밋에 대응하는 immutable 이미지 digest 확보 방식 결정; upstream Postiz image placeholder 제거
- [ ] production 시작 명령에서 `pnpm dlx`의 네트워크 의존과 자동 `db push` 정책 해결·격리 검증
- [ ] 컨테이너의 CPU/RAM 상한과 호스트 여유 설정을 정하고 재시작·OOM·영상 처리 동시 부하 검증
- [ ] 관리자 외부 접근 방식(VPN/IP 제한 등), 도메인, DNS, OAuth 사용 계정·공식 승인 계획 결정
- [ ] 암호화 외부 백업 대상/키/보존, RPO/RTO, 실제 복원 runbook 및 알림 결정
- [ ] OpenAI/영상 API 사용료 한도와 사용자 승인 후 발행 흐름 정의
- [ ] root 실행 여부와 frontend source map 노출 정책 검토

### 서버 구매 후, 공개 운영 전

- [ ] 안전한 Ubuntu 초기화, SSH 키 전용/제한, 방화벽, 보안 업데이트와 재부팅 절차
- [ ] `/etc/putduk/.env.production`에 실 비밀값을 안전하게 저장하고 권한 확인
- [ ] 검증 digest로 Compose 설정만 렌더링한 후 격리 단계에서 먼저 기동
- [ ] DNS와 Caddy의 실제 TLS 인증서 발급/갱신·재부팅 후 복구 확인
- [ ] 외부 스캔으로 80/443 이외 포트가 닫혔는지 확인
- [ ] 초기 관리자 생성, 가입 비활성화, 쿠키 secure mode, 관리 접근 제한 확인
- [ ] 외부 백업 생성 알림과 새 격리 데이터베이스/볼륨 복원 테스트
- [ ] 실제 SNS 연결은 각 플랫폼 심사 후 별도 승인·테스트 계정·비공개 게시 조건으로 검증
- [ ] 예약 발행 알림, 지연/실패 대시보드, 디스크/RAM/서비스/Temporal 상태 알림 확인

## 이번 단계 변경·검증

- `.dockerignore`에 `.env*` 제외를 추가했다. Git ignore와 달리 Docker build context에서도 운영 환경 파일이 `COPY . /app`로 이미지에 들어가지 않게 하기 위한 최소 보완이다.
- 임시 Docker build context에 가짜 `.env.production`, `.env.production.example`, 일반 소스 파일을 넣어 실제 BuildKit export로 확인했다. 두 env 파일은 제외되고 정상 소스 파일은 포함됐다. 임시 테스트 자원만 제거했다.
- `docker compose --env-file .env.production.example -f docker-compose.production.yaml config --quiet` 통과. 구성 렌더링 결과에서 공개 포트·내부 네트워크·named volume 및 운영 서비스 자원을 정적으로 확인했다.
- Step 10 전체 통합 검사는 반복하지 않았다. HTTPS/TLS, 실제 이미지 pull, 운영 모드 VPS 부하, 실제 SNS OAuth/게시, 외부 저장소 백업·복원은 미검증이다.
