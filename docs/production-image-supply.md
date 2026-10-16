# PUTDUK 운영 이미지 공급 절차

상태: **설계 문서이며 게시 승인/패키지 생성/이미지 push를 수행하지 않음**

대상 후보: `ghcr.io/goldeget/putduk-social-auto`

## 현재 확인 상태

- 사용자가 기준으로 지정한 Step 10 전체 통합 run [38871945385](https://github.com/goldeget/putduk-social-auto/actions/runs/38871945385)은 성공 증거로 유지한다.
- 그 검증 이미지는 Actions runner 안에서만 생성됐다. 재사용 가능한 GHCR digest, 실제 운영 pull 또는 VPS 배포는 없다.
- 익명 GHCR registry 확인은 `401 UNAUTHORIZED`를 반환했다. 이는 패키지의 존재, 올바른 소유자, private visibility, `packages: write` 권한 중 어느 것도 입증하지 않는다. 현재 패키지 상태는 **UNKNOWN**이다.
- 소스 저장소가 public이라고 해서 패키지의 visibility가 안전하다고 가정하지 않는다. 실제 첫 publish는 패키지를 만들고 기본 visibility를 결정할 수 있으므로, 사전 승인 및 패키지 설정 확인 없이는 실행하지 않는다.
- `.env.production.example`은 퍼뜩 GHCR 후보 경로와 의도적으로 치환 문자열인 digest를 사용한다. 이 값으로는 pull 또는 운영 기동이 불가능하다.

## 게시 전 승인 게이트

1. 별도 사용자 승인 후 GitHub Packages 화면에서 소유자가 `goldeget`인지, 이름이 `putduk-social-auto`인지, 패키지가 **Private**인지 확인한다. 상태가 모호하거나 public이면 게시를 중단한다.
2. 최초 게시로 패키지가 자동 생성되는 방식에 의존하지 않는다. 사전에 private 패키지를 만들고 저장소 연결·접근 권한을 확인한다. 이를 확인할 수 없다면 다른 private registry를 별도 승인 없이 도입하지 않는다.
3. 보호된 GitHub Environment(예: `putduk-image-publish`)에 required reviewer를 설정한다. YAML의 `environment:` 이름만으로 승인자가 생기지는 않으므로 GitHub 설정 화면에서도 승인 규칙을 확인한다.
4. 게시 workflow는 `workflow_dispatch`만 받고 `work` 외 ref라면 즉시 실패해야 한다. 입력에는 정확한 대상 SHA와 명시적 확인값을 요구하고, 입력 SHA가 checkout SHA와 같지 않으면 실패한다.
5. 사전 검사 job은 `contents: read`만 갖는다. 게시 job만 보호된 Environment 승인 뒤 `packages: write`를 갖고, 가능한 경우 GitHub `GITHUB_TOKEN`을 사용한다. PAT를 상시 저장하지 않는다. Release 생성, 다른 저장소 권한, registry 외부 게시 권한은 부여하지 않는다.
6. 이 전용 publish workflow는 Step 10 통합 검사 workflow와 분리한다. 일반 push, tag, pull request가 운영 이미지를 게시하면 안 된다. 현재 upstream `build-containers.yml`은 실행하지 않는다. 그 workflow는 `gitroomhq/postiz-app`에 push하며 `latest` manifest까지 갱신하기 때문에 퍼뜩 공급 절차가 아니다.
7. 같은 SHA에서 회귀 테스트, frozen lockfile 검사, 비밀정보·환경 파일 검사, amd64 빌드 및 이미지 구성 검사를 통과한 뒤에만 push한다. BuildKit secret은 빌드에 필요한 경우에도 이미지 layer/args/log에 노출하지 않는다.

## 태그, OCI revision, digest

- Source of truth는 승인된 `work` 커밋 SHA다. 빌드 job은 그 SHA를 checkout하고, build context가 같은 commit인지 확인한다.
- tag는 `ghcr.io/goldeget/putduk-social-auto:<full-git-sha>` 형식으로 고정한다. `latest`는 만들거나 운영 설정에 사용하지 않는다.
- 이미지 label `org.opencontainers.image.revision`과 `org.opencontainers.image.source`를 설정하고, push 후 실제 registry manifest의 digest를 기록한다. tag 이름만으로 이미지 불변성을 가정하지 않는다.
- 이미지에 포함된 revision이 checkout SHA와 다르거나, registry에서 읽은 manifest digest와 build 결과의 digest가 다르면 게시를 실패 처리한다.
- Compose에는 검증된 `ghcr.io/goldeget/putduk-social-auto@sha256:<실제 digest>`만 주입한다. placeholder, tag, `latest`를 운영에 넣지 않는다.
- package metadata, 승인 기록, source SHA, OCI revision, digest, amd64 플랫폼, 빌드 Actions URL을 작업 기록에 남긴다. 토큰이나 비밀 환경 파일은 기록하지 않는다.

## VPS에서 읽기 전용 pull 및 검증

운영 서버가 준비되고 별도 승인을 받은 뒤에만 수행한다.

1. 패키지 하나만 읽을 수 있는 별도 인증수단을 준비한다. 필요한 최소 범위는 `read:packages`이며, write 권한이나 전체 계정 저장 토큰을 서버에 두지 않는다. 가능한 경우 root 소유 Docker credential helper를 이용하고 토큰을 명령 인자, 셸 기록, 로그에 넣지 않는다.
2. digest로 pull한다: `docker pull ghcr.io/goldeget/putduk-social-auto@sha256:<검증한 digest>`.
3. `docker image inspect` 및 `docker buildx imagetools inspect`로 플랫폼 `linux/amd64`, repository digest, `org.opencontainers.image.revision`을 확인한다.
4. pull 결과 digest가 승인된 값과 다르거나 OCI revision이 기록한 소스 SHA와 다르면 실행하지 않는다.
5. `.env.production`은 이미지 밖의 권한 제한 경로에서 제공한다. 이미지 안의 환경 변수·비밀값 검사는 배포 전 다시 실시한다.

## DB schema와 서비스 시작 순서

이제 일반 애플리케이션 재시작(`pnpm run pm2`)은 schema를 자동 변경하지 않는다. Prisma CLI 6.5.0은 이미지 의존성에 들어 있고 작업 명령은 `pnpm exec prisma`를 사용하므로 실행 중 외부 패키지를 `pnpm dlx`로 다운로드하지 않는다.

첫 기동 또는 명시적으로 승인된 schema 변경 때는 다음 흐름을 사용한다.

1. Postiz DB, Redis, Temporal DB, Elasticsearch, Temporal 같은 의존 서비스를 기동하고 health를 확인한다.
2. 승인된 이미지에서 일회성 `pnpm run prisma-db-push`를 실행한다. 이 명령은 DB schema를 바꿀 수 있으므로 운영 데이터 백업과 변경 검토 이후에만 수행한다.
3. 명령 종료코드와 Prisma 결과를 확인한다. 실패하면 Postiz/Caddy를 시작하지 않고 로그를 보존하되 비밀값은 제거한다.
4. 성공한 뒤 같은 image digest로 Postiz를 기본 CMD로 시작한다.
5. 재시작 시에는 PM2 앱만 순차 시작한다. 자동 `db push`는 하지 않는다.

`db push`는 versioned migration history나 자동 롤백을 제공하는 것으로 간주하지 않는다. schema 변경 실패 시 이전 schema로 안전하게 되돌릴 수 있다고 가정하면 안 된다. 운영 적용 전 DB 외부 백업을 확인하고, 실패 시 서비스 시작을 멈춘 다음 승인된 복원 절차를 사용한다. Step 10의 격리 복구 성공은 실제 운영 백업/복구 성공을 뜻하지 않는다.

## 이미지 위험 및 남은 조건

- `.dockerignore`의 `.env*` 규칙은 이전 단계에서 확인했고 `.env.production.example`도 이미지 context에서 제외된다. 변경 후 전체 이미지 비밀 검사 및 재빌드는 아직 하지 않았다.
- `Dockerfile.dev`는 `pnpm install --frozen-lockfile`을 사용하도록 바꿨다. 실제 Docker 재빌드와 Actions 결과는 미확인이다.
- Dockerfile은 현재 명시적 non-root `USER`가 없어 root 실행 위험이 남아 있다. Postiz config/upload 권한과 PM2/NGINX 쓰기 경로를 확인하지 않은 채 무단으로 사용자 변경하지 않는다.
- pnpm 버전은 10.6.1로 고정돼 있으나 PM2 전역 버전과 base image digest는 아직 고정되지 않았다. 이번에는 게시 전에 해결해야 할 공급망 잔여 항목으로 기록하고 무관한 리팩터링은 하지 않았다.
- GHCR 저장/전송 비용 및 현재 계정의 포함 한도는 확인하지 않았다. 운영 전에 GitHub Packages의 현재 과금·저장 정책과 계정 한도를 확인한다.
- 실제 private package 확인, GitHub Environment reviewer 설정, publish workflow 작성/실행, GHCR push, VPS pull, HTTPS, OAuth, SNS 게시는 **미수행**이다.

## 현재 결론

운영 이미지 공급 방식은 private GHCR 후보와 immutable digest로 설계할 수 있지만 실제 package visibility와 권한이 검증되지 않았다. 따라서 실제 게시는 반드시 **NO**이며 서버 구매 및 운영 배포도 **NO-GO**다. 다음 허용 작업은 GitHub UI에서 package 소유권/비공개 상태를 사용자가 승인된 방식으로 확인하는 것이다. 해당 상태가 보장된 뒤, 별도 승인으로 수동 publish workflow를 구현한다.
