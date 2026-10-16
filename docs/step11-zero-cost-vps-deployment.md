# PUTDUK STEP 11-F/G — 추가 GitHub 비용 없는 VPS 배포 설계

작성: 2026-10-16
범위: 배포 설계와 설치 자료 준비. VPS 구매·접속·배포, Docker 전체 빌드, Actions 실행, GHCR 게시를 하지 않는다.

## 기준과 보존

- 저장소: `goldeget/putduk-social-auto`, 배포 소스 브랜치 `work`.
- 시작 시 work SHA: `2ecb65e2cde44ce528871214e66c7e3e1144e978` (원격과 일치).
- 별도 Step 10 성공 기록: [Actions run 38879477823](https://github.com/goldeget/putduk-social-auto/actions/runs/38879477823), 소스 SHA `62ed3585f9b2227a7956950c809b7140478efc90`.
- 기존 사용자 제공 Step 11-F 설계 파일은 읽고 이 문서에 핵심 내용을 보존한다. 본 문서는 Step 11-F/G 설계를 통합 기록한다.
- `main`, `putduk-mining`, 기존 Step 10 테스트 파일과 workflow는 수정하지 않는다.
- GitHub Actions, GitHub Packages, GHCR에 대한 추가 비용·예산 증액·게시 금지. 공개 저장소의 기존 push CI는 별도 GitHub 정책에 따라 자동 실행될 수 있으나, 비공개 Publisher 검증이나 유료 실행의 대체로 쓰지 않는다.

## 권장 공급 방식

VPS에서 공개 `work` 브랜치의 검증된 정확한 SHA를 가져와 해당 커밋만 분리 checkout하고, `linux/amd64` 이미지를 로컬로 빌드한다. 이미지는 `putduk-social-auto:<40자리 SHA>`로 태그하고 OCI revision label과 SHA가 같은지, 플랫폼, 이미지 ID 및 이미지 내 비밀정보 흔적을 확인한다. 실제 registry digest가 없는 로컬 이미지에 가짜 digest를 붙이지 않는다. 기존 운영 태그·이미지·컨테이너는 건드리지 않는다.

`docker-compose.vps-local-image.yaml`은 기존 production Compose를 덮어쓰지 않고 로컬 SHA 태그와 `pull_policy: never`만 덮어쓴다. 로컬 태그가 없으면 Compose가 원격에서 이미지를 가져오는 대신 실패한다. GHCR placeholder가 적힌 `.env.production.example`을 실제 배포값으로 사용하지 말고 정확한 local SHA tag를 지정한다. OpenAI 키는 런타임 전용 `.env.production`에 보관하고 이미지 빌드 인자·레이어·저장소에 넣지 않는다.

## VPS 사전 검사와 자원

`scripts/vps/preflight.sh`는 Linux amd64, 온라인 CPU 4개 이상, Docker/Compose/Buildx, 메모리, workspace 및 Docker root의 남은 디스크를 검사한다. 이미지 빌드 시작 기준은 사용 가능 메모리 8 GiB 이상, 작업공간과 Docker root 각각 50 GiB 이상으로 보수적으로 정한다. 전체 격리 통합검사를 같은 VPS에서 별도로 할 경우에는 시작 전 디스크 20 GiB 이상을 추가 안전 기준으로 삼는다. 이 수치는 충분성을 보증하는 벤치마크가 아니라 기존 CI의 50/20 GiB 차단 기준을 보존한 시작 게이트다.

기존 CI에서 관측한 2.98 GiB RAM은 짧은 통합 실행의 샘플이며 이미지 빌드의 peak RAM이 아니다. 72.93 GiB는 GitHub 실행기 전체 파일시스템 사용량으로 VPS 빌드 공간의 측정값이나 요구량이 아니다. CPU 관측 287.3%는 해당 CI 샘플에서 약 2.87 코어를 합산한 값이며 VPS의 부하·빌드 시간을 예측하지 못한다. 후보 6 vCPU는 사전검사의 4 CPU 최소값을 넘지만, 실제 앱·DB 동시 운영 중 빌드 여유는 검증되지 않았다. 12 GB RAM / 200 GB SSD의 실제 여유 자원과 적합성도 VPS 검사 전까지 **UNKNOWN**이다. 디스크가 기준 미만이거나 메모리 부족 시 빌드 전 차단하고, 빌드 중 여유 메모리가 2 GiB 아래로 내려가면 빌드 CLI를 중단 요청한다. 이 취소 기능은 VPS에서 아직 실증되지 않았으며 Docker daemon 취소 완료를 보증하지 않는다. 운영 중 빌드는 피하고 점검시간에 실행한다.

이미지/캐시 용량은 `docker system df -v`와 파일시스템 여유량으로 관찰하고, 개별 이미지 ID와 참조 여부 확인 후 승인받아 정리한다. 자동 `docker system prune`, `docker image prune -a`, 볼륨 삭제 명령은 제공하지 않는다. 기존 Docker volumes와 DB 데이터는 절대 빌드 정리 대상으로 삼지 않는다.

## 업데이트·검증·롤백 게이트

1. 운영 SHA, 운영 image ID, compose 설정, 활성 컨테이너 상태를 기록한다.
2. 외부 저장 위치로 DB와 uploads/사용자 파일 백업을 수행하고, 결과 파일의 존재·크기·체크섬·복원 가능성을 확인한다. 별도 위치/복원 검사가 끝나기 전 `BACKUP_VERIFIED=NO`로 취급한다.
3. 전체 SHA가 origin `work`의 커밋인지 확인한다. 변경이 없는 detached worktree에서만 빌드한다.
4. OCI revision/SHA, amd64, 이미지 ID, 비밀정보 검사를 통과한 새 SHA 태그가 생겨도 운영 서비스는 아직 그대로 둔다.
5. 격리 Compose project와 별도 테스트 DB/볼륨으로 기능 점검한다. production project/volume을 재사용하지 않는다.
6. 운영자 승인과 백업 확인 후 점검시간에만 새 overlay를 지정해 교체한다. 현재 자료에는 자동 production `up`/배포 기능이 없다.
7. 실패 시 추가 변경을 멈추고 로그·상태를 기록한다. 이전 image ID/SHA로 컨테이너를 복구하고 운영 데이터를 확인한다. 이미지 rollback은 DB schema rollback이 아니다.
8. 예약 게시 worker/Temporal 상태를 교체 전에 확인하고, 이전·새 worker 동시 실행으로 중복 게시가 생기지 않도록 한 쪽만 활성화한다. 게시 동작은 실제 계정으로 시험하지 않는다.

`pm2-run`에는 자동 Prisma schema 변경이 없다. `prisma-db-push`는 별도 명령이며 서버 재시작 시 실행하지 않는다. Schema 변경은 별도 승인, 백업, 격리 검증 뒤 별도 단계로 수행한다. 이전 이미지만 복원해 DB를 되돌릴 수 있다고 가정하지 않는다.

## 보안 및 운영 위험

- 현재 `Dockerfile.dev`는 `USER`를 지정하지 않아 root 기본 사용자로 실행하며, 전역 PM2 버전 및 Node base image digest가 고정되지 않았다. 알려진 Step 10 상태를 보존하기 위해 이번 변경에서는 Dockerfile을 수정하지 않았다. 비 root 실행, PM2/base digest 고정은 별도 변경과 통합 재검증이 필요한 **운영 차단 항목**이다. Docker socket 접근은 root 권한과 동등하게 취급한다.
- Production Compose는 Caddy 80/443만 노출하고 Postiz는 내부 네트워크에서만 노출한다. DB, Redis, Temporal, Elasticsearch 포트를 인터넷에 공개하지 않는다. HTTPS 인증서와 실제 DNS/HTTPS 운영은 서버·도메인 확보 뒤 검증한다.
- 가입 차단(`DISABLE_REGISTRATION=true`)은 유지한다. 최초 관리자 설정은 일시적인 관리 전용 VPN/SSH tunnel 또는 제한된 네트워크에서 진행한다. OAuth callback은 Meta/Google/TikTok 외부에서 HTTPS로 호출되어야 하므로 전체 사이트에 IP 제한이나 기본 인증을 걸면 콜백이 실패할 수 있다. 경로별 예외/보호 규칙을 실제 provider callback 경로를 확인하기 전에는 설정하지 않는다.
- Provider OAuth client secret, access/refresh token, DB 자격증명, `OPENAI_API_KEY` 등은 root 전용 권한(예: 0600)인 서버 외부 `.env.production` 또는 검증된 secret store에만 둔다. 명령행 인수, 이미지 build args/레이어, Git, 로그에 넣지 않는다. 현재 OpenAI 키가 production Compose에서 앱으로 전달되지 않으므로 overlay가 런타임 환경변수로만 선택 전달한다.
- 백업은 VPS와 다른 위치에 암호화 보관하고 접근키를 별도로 보관한다. DB dump, uploads, Temporal/PostgreSQL 및 Elasticsearch의 일관성 있는 백업 절차는 실제 서비스 버전·정지/스냅샷 요구사항을 확인한 뒤 확정해야 한다. 이 작업에서는 백업을 만들거나 복원하지 않았다.

## 설치 자료와 범위

- `scripts/vps/preflight.sh`: 읽기 전용 호스트/자원 선행 검사.
- `scripts/vps/build-image.sh`: exact SHA ancestor 확인, 임시 detached worktree, 비밀 파일 검사, 자원 gate, amd64 local build, image verification. Production Compose를 실행하지 않고 이미지/볼륨을 prune하지 않는다.
- `scripts/vps/verify-image.sh`: local image platform, OCI revision/source, image ID 및 비밀파일 검사.
- `docker-compose.vps-local-image.yaml`: SHA local image를 강제하고 pull을 막는 overlay.
- 실제 DB 백업·복원과 production 전환은 운영 데이터 및 자격증명에 맞춘 별도 승인이 필요하므로 자동화하지 않았다.

## 완료 판정

### A. VPS 구매 전 준비

- 설치 절차, 후보 사양(6 vCPU / 12 GB RAM / 200 GB SSD), 정확한 SHA로 직접 빌드하는 방법, 로컬 이미지 overlay, 자원 사전검사, 이미지 확인, 업데이트/복구 계획 및 보안 설계 초안을 준비했다.
- GitHub 추가 비용 예상: 공개 저장소의 기존 표준 GitHub-hosted runner 외에 Actions/Packages를 추가 사용하지 않는 설계다. GitHub 계정의 실제 청구/사용량 정보는 별도 확인이 필요하다.
- VPS 예상 반복 비용은 사업자·서울/아시아 리전·결제 주기·백업/트래픽 상품을 선택하지 않아 **UNKNOWN**이다. 공급자의 실제 견적을 확인하고 사용자가 승인하기 전에는 구매하지 않는다.
- 준비 판정: **GO — 사용자가 견적을 검토하고 별도 구매 승인을 한 뒤 시험용 VPS를 구매해 post-purchase 검증을 이어갈 수 있다.** 구매 전에 실제 VPS 자원·HTTPS·복원 검증까지 끝내야 한다는 의미는 아니다.

### B. 구매 후 실제 공개 운영 전에 필요한 검증

- 실제 가용 RAM/디스크와 Docker build peak, image 검사, HTTPS 인증서, OAuth callback/관리 접근 제어, 외부 백업과 복원, 장시간 안정성을 실제 대상에서 확인한다.
- 현재 이미지의 root 실행, PM2/base image pin 미완료는 공개 운영 차단 항목으로 별도 변경·검증한다. 구매 전에 임의로 코드를 바꾸지 않았다.
- 서버 구매는 공개 운영 승인을 뜻하지 않는다. 공개 운영 판정은 **NO-GO**이며 위 항목과 계정 연결·provider 설정 등 별도 준비가 완료되어야 한다.
