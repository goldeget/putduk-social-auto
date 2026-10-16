# PUTDUK 운영 이미지 공급 절차

상태: **설계 문서이며 게시 승인/패키지 생성/이미지 push를 수행하지 않음**

대상 후보: `ghcr.io/goldeget/putduk-social-auto`

## 현재 확인 상태

- Git 원격 `HEAD`가 `main`을 가리키고, 확인 당시 main SHA는 `0956d49ab79acb314f700779b92677830ac83a9d`, work SHA는 `73669e8221b00b1f106edbf848d11a107aebd94f`였다. work에는 Step 10 검사 workflow가 있지만 push 전용이며 `workflow_dispatch`는 없다. 그 workflow는 main에 존재하지 않는다.
- 사용자가 제공한 Step 10 run [38879477823](https://github.com/goldeget/putduk-social-auto/actions/runs/38879477823)은 source SHA `62ed3585f9b2227a7956950c809b7140478efc90`에서 성공했다. `62ed...`와 현재 `work` 사이 변경 파일은 `docs/PUTDUK_WORK_LOG.md`뿐이다. 따라서 같은 코드 revision이지만 Actions runner에서 생성된 테스트 image 자체는 보존되지 않았고 재사용할 수 있는 digest도 없다.
- GHCR 익명 manifest 조회는 HTTP `401 UNAUTHORIZED`/`authentication required`였다. 인증된 읽기 확인도 시도했지만 `gh auth status`는 로컬 `GH_TOKEN`이 유효하지 않다고 했고, GitHub Packages API 요청은 프록시에서 `403 Forbidden`을 반환했다. 저장소 `git ls-remote` 성공은 private package API 권한을 증명하지 않는다. 패키지 존재, 소유권, visibility, publisher 권한은 모두 **UNKNOWN**이다.
- GitHub 문서의 `workflow_dispatch` 설명상 workflow 파일이 default branch에 있어야 수동 실행 가능하다. 이번 환경에서는 공식 문서 사이트 접근이 프록시 `CONNECT 403`으로 차단되어 문서 본문을 새로 검증하지 못했지만, 원격 main에 workflow가 없고 work의 workflow도 push 전용이라는 저장소 사실은 확인했다. 참고: [workflow_dispatch 공식 문서](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#workflow_dispatch).
- 소스 저장소가 public이라고 해서 패키지 visibility를 추정하지 않는다. 첫 push의 package 생성·repository 연결·권한 상속·기본 visibility가 현재 계정에서 어떻게 적용되는지 검증하지 못했다. Private 상태를 push 전에 보장할 수 없으면 push를 중단해야 한다.
- `.env.production.example`의 GHCR 주소와 digest는 교체용 문자열이다. 실제 package나 image가 존재한다는 뜻이 아니다.

## 게시 경로 비교 및 권장안

| 방식 | main 무변경 | 수동 승인 | 권한/위험 | 판정 |
| --- | --- | --- | --- | --- |
| source 저장소 `work`에 `workflow_dispatch` 추가 | 예 | 실행 불가 상태 | GitHub 수동 실행에서 workflow가 default branch에 있어야 한다. 현재 main에는 이 파일이 없으므로 work에만 둔 새 workflow는 수동 게시 경로를 만들지 못한다. | 현재는 사용할 수 없음 |
| source `main`에 게시 workflow 추가 | 아니오 | 가능 | 사용자 금지사항을 위반한다. | 제외 |
| 현재 main의 `build-containers.yml` 재사용 | 파일 실행은 가능 | workflow_dispatch 존재 | 실제 스크립트는 `ghcr.io/gitroomhq/postiz-app`에 이미지 push와 manifest/`latest` 업데이트를 한다. 대상과 동작이 다르다. | 실행 금지 |
| 로컬 PC에서 수동 build/push | 예 | 직접 조작 | 초보자가 장기 자격증명을 로컬에 보관해야 하고 빌드 환경·산출물·감사 기록이 분산된다. 현재 PC 자원 제약에도 맞지 않는다. | 비추천 대안 |
| 별도 비공개 publisher 저장소의 `main` workflow | 예 | 수동 dispatch 및 protected Environment로 구성 가능 | 새 private repo와 GHCR package Actions 접근을 설정해야 한다. 정확한 source SHA를 public source repo에서 읽고, publisher repo의 workflow만 package 권한을 갖는다. | **권장** |

현재 제약(소스 `main` 불변, GH Actions 사용, 감사 가능한 수동 게시)을 모두 지키려면 별도 private publisher 저장소가 필요하다. 예시 이름은 `goldeget/putduk-image-publisher`지만 생성하지 않았다. 개인 계정에서 private repo의 required reviewers/환경 승인 기능이 현재 요금제에서 가능한지도 확인하지 않았다. 기능을 사용할 수 없다면 별도 승인된 publisher 저장소에서만 수동 dispatch를 허용하고, dispatch 권한을 소유자/지정 운영자에게 제한하는 대체 gate를 먼저 승인받는다.

### 권장 수동 workflow 흐름

publisher 저장소의 `main`에만 workflow를 두고 `workflow_dispatch`로 실행한다. 입력에는 `work`에서 도달 가능한 전체 source SHA와 private publish 확인값을 요구한다. workflow는 ref가 publisher `main`인지 확인하고, target SHA가 `goldeget/putduk-social-auto`의 현재 `work` ancestry 안에 있는지도 확인한다. source checkout은 `persist-credentials: false`로 읽기 전용 수행한다.

표준 runner 한 job에서 이미지를 한 번 빌드해 local image로 로드하고, revision/source label을 확인한 다음 격리 Step 10 전체 통합 검사를 그 **같은 이미지**로 실행한다. 통합 검사 성공 뒤에만 마지막 trusted workflow 단계에서 GHCR login/push를 수행해 재빌드와 test/publish image 불일치를 피한다. GitHub token은 shell environment에 일반 전달하거나 checkout credential로 저장하지 않고, push 단계의 stdin login에만 전달한다. workflow job 권한은 `contents: read`, `packages: write`로 제한한다. 이 설계에서는 권한 범위가 workflow job 자체에는 부여되지만, 비밀 credential은 빌드/테스트 명령에 주지 않는다. Source checkout에서 실행하는 코드를 검토한 후 protected Environment 승인까지 통과시키며, login 이후에는 source-controlled script를 실행하지 않는다.

workflow는 source commit SHA를 OCI `org.opencontainers.image.revision` label, `NEXT_PUBLIC_VERSION`, SHA 태그에 사용한다. build context의 Git HEAD가 input SHA와 다른 경우 즉시 실패한다. `org.opencontainers.image.source`는 실제 source 저장소 URL로 기록한다. 비밀정보 검사는 build context 및 생성 image config/history/filesystem scan을 push 직전에 다시 하고 하나라도 탐지되면 게시하지 않는다. tag는 `:<full-source-sha>`이며 `latest`는 만들지 않는다. `docker push` 응답의 manifest digest를 기록하고, private read로 digest pull 후 플랫폼·revision·digest를 재확인한다.

검사 job과 push job을 별도 job으로 분리해 push job에만 `packages: write`를 주는 구조도 비교했다. 이를 위해 약 4.77GB로 알려진 image를 job 사이 Actions artifact로 전송해야 할 수 있고, 현재 계정의 artifact 용량·보관 비용/한도는 확인하지 못했다. 과금 없는지 확인 전까지 artifact 전송을 전제하지 않는다. Artifact 방식이 무료 한도에 들어오면 그 방식이 token 권한을 더 엄격히 분리한다. 그렇지 않으면 위의 단일 보호 job 방식에서 token을 최종 push 단계에만 노출한다.

### GHCR 첫 push와 access 상속 안전 게이트

이번 read-only 확인에서 package가 확인되지 않았으므로 package가 없다고 단정할 수도, 기존 Private 설정이 있다고 단정할 수도 없다. GHCR의 실제 대상 계정에서 package가 이미 있으면 package settings의 owner/name/visibility와 granular permissions를 확인하고, private publisher 저장소의 Actions access를 필요한 범위로만 추가해야 한다. source public 저장소의 권한을 자동 상속하는 상태인지도 확인한다.

Package가 없으면 첫 push가 package 생성/연결의 순간이 될 수 있다. 첫 push가 자동으로 private일 것이라고 추정하지 않는다. GHCR UI 또는 계정의 package creation/default visibility 설정에서 private 상태를 **push 전 보장**할 수 있는지 먼저 확인한다. 보장 경로가 없으면 이번 요구(비공개를 보장하지 못하면 중단)에 따라 `ghcr.io/goldeget/putduk-social-auto`로는 게시하지 않는다. 첫 push로 공개될 가능성을 시험하는 방식은 금지한다. GitHub 공식 참고: [패키지 접근 제어/visibility](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility).

publisher workflow의 사전 점검은 가능해지면 인증된 read token으로 package owner/name와 `visibility == private`를 검사하고, package 없음/404/권한 부족/API 오류는 모두 fail-closed 처리해야 한다. package permission의 쓰기 접근은 publisher 저장소에만 부여한다. 이 환경에서는 해당 API 확인과 write 권한 실험을 하지 않았으며, write 권한 실험은 push 없이 검증할 수 없으므로 미수행이다.
- `.env.production.example`은 퍼뜩 GHCR 후보 경로와 의도적으로 치환 문자열인 digest를 사용한다. 이 값으로는 pull 또는 운영 기동이 불가능하다.

## 게시 전 승인 게이트

1. 별도 private publisher 저장소 생성은 사용자 승인 후에만 한다. source repository의 `main`은 변경하지 않는다.
2. 게시 전에 대상 package의 `goldeget/putduk-social-auto` 소유자·이름·Private visibility·repository linkage·권한 상속 설정을 확인한다. 패키지가 없거나 private 상태를 push 전에 보장할 방법이 없으면 workflow는 fail-closed 처리하고 push하지 않는다.
3. publisher 저장소의 수동 `workflow_dispatch`는 기본 branch `main`에서만 허용하고 전체 source SHA와 private 게시 확인 입력을 요구한다. source SHA가 공개 저장소 `work`의 commit ancestry 안에 없으면 실패한다.
4. 보호된 GitHub Environment와 required reviewer를 구성할 수 있는 plan인지 확인한다. reviewer gate가 가능하면 required reviewer를 적용한다. 불가능하면 지정 사용자만 dispatch 가능한 private repo 권한을 gate로 사용하는 대안을 사용자 승인을 받아야 한다.
5. workflow에는 `contents: read`, package push가 필요한 단일 release job에는 `packages: write`만 부여한다. 외부 PAT는 저장하지 않고 `GITHUB_TOKEN`을 사용한다. 토큰은 build/test 명령에 환경변수로 주지 않고 마지막 registry login/push 단계에만 전달한다. login 뒤에는 source checkout에서 가져온 script를 추가 실행하지 않는다.
6. 통합 검증 전에 이미지 한 번을 build하고 그 로컬 이미지에서 회귀 검사 및 Step 10 전체 격리 검사를 한다. 성공한 동일 local image만 SHA tag로 push한다. 검증 뒤 다시 build하지 않는다. build/test와 push job을 분리하려면 image artifact 이동이 필요하다. 알려진 이미지 크기가 약 4.77GB이므로 artifact quota/storage cost를 확인하기 전 이 구조를 선택하지 않는다.
7. 일반 push/tag는 운영 이미지 게시를 실행하지 않는다. 현재 source `main`의 `build-containers.yml`은 `gitroomhq/postiz-app`에 push하고 `latest` manifest를 갱신하므로 사용하지 않는다. BuildKit secret이 필요해도 image layer/args/log에 포함하지 않는다.

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

현재 권장안은 **별도 private publisher 저장소 + 수동 workflow_dispatch + 보호 승인 + 같은 후보 image를 검증한 뒤 같은 local image를 한 번 push**하는 방식이다. 별도 저장소는 source `main`을 건드리지 않고 GitHub 수동 배포 workflow 조건을 만족시키기 위해 필요하지만 아직 승인·생성되지 않았다. GHCR package 존재/소유권/private 상태/권한 모두 **UNKNOWN**이다. 첫 push 전에 비공개성을 보장할 수 있는 경로가 확인되지 않으면 게시하지 않는다. 이번 작업의 실제 GHCR push는 **NO**, 서버 구매/운영 배포는 **NO-GO**다.
