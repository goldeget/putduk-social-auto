# PUTDUK SOCIAL AUTO 작업 기록

## 현재 상태

- 마지막 작업 일시: 2026-10-15 (Asia/Seoul)
- 개발 단계: Jest 설정 복구 및 필수 빌드/타입 검증 완료
- 저장소: `goldeget/putduk-social-auto`
- 현재 작업 브랜치: `work`
- 복구 기준 커밋: `4355c579980b2e8c1231c43256cf1b9a7dc0a666`
- 이번 작업 시작 시 로컬 `work`와 원격 `work`가 모두 `4355c579980b2e8c1231c43256cf1b9a7dc0a666`을 가리킴을 확인했다. `main`은 변경하지 않았다.
- 작업 시작 시 미커밋 변경은 없었다.
- 이번 기록 갱신 전 마지막 검증 원격 체크포인트: `595ba52cdef27317f4449ea273776f17b1ddc4aa` (`work`)
- GitHub 작업 브랜치 백업: 검증 완료

## 완료된 작업

- 지정된 클라우드 활성화 스크립트로 Node.js 22.20.0과 pnpm 10.6.1을 확인했다.
- 저장소 원격 주소는 `https://github.com/goldeget/putduk-social-auto.git`, 작업 브랜치는 `work`로 확인했다.
- 복구 기준 이후의 기존 작업 변경을 확인했다. 이전 진단 문서 외 코드 수정은 없었고, 작업 트리는 깨끗했다.
- Jest를 실행해 실패가 테스트 파일 실행 이전의 설정 로드 단계에서 발생함을 재현했다.
- `jest.config.ts`에서 Nx 프로젝트 검색을 제거하고, `jest.preset.js`에 독립 ts-jest 설정을 구성했다.
- `ConfigurationChecker`의 정상 설정 및 잘못된 필수값/URL 검증 테스트 2개를 추가했다.
- ts-jest의 기본 전체 타입 검사 경로는 테스트 실행 중 Node 힙 한도에 도달했다. Jest transform에서 TypeScript `isolatedModules` 옵션을 적용해 해결했고, 저장소 tsconfig나 패키지 버전은 변경하지 않았다.
- `pnpm exec jest --showConfig`로 설정 로딩을 확인했고, `pnpm test --runInBand`가 테스트 2개를 모두 통과했다.
- 테스트 파일을 프로젝트의 null-check 옵션에 맞춰 독립 TypeScript 검사했고 통과했다.
- `pnpm run build:backend`, `pnpm run build:orchestrator`, `pnpm exec tsc -p apps/frontend/tsconfig.json --noEmit`를 모두 통과했다.
- Nx/Jest 충돌을 읽기 전용으로 조사했다. 두 Jest 설정 파일이 `@nx/jest`를 참조하지만 의존성·lockfile에 없고, `nx.json`, Nx 프로젝트 설정, 테스트 파일도 찾지 못했다. `jest`와 `ts-jest`는 설치돼 있다.
- 백엔드 빌드, 오케스트레이터 빌드, 프런트엔드 TypeScript 타입 검사를 다시 실행해 모두 통과했다.
- SNS provider 코드의 앱 자격증명 변수명, 요청 scope 및 콜백 경로를 확인했다. 제공자 콘솔의 앱 승인 상태나 실제 계정 연결은 확인하지 않았다.

## 검증 결과

- 통과한 테스트: `pnpm test --runInBand` — 1개 suite, 2개 테스트 통과.
- 통과한 설정 확인: `pnpm exec jest --showConfig`.
- 통과한 테스트 파일 타입 검사: `pnpm exec tsc --noEmit --skipLibCheck --strict --strictNullChecks false --strictPropertyInitialization false --esModuleInterop --module commonjs --target ES2020 --moduleResolution node --types jest,node libraries/helpers/src/configuration/configuration.checker.spec.ts`.
- 통과한 빌드/정적 검사: `pnpm run build:backend`, `pnpm run build:orchestrator`, `pnpm exec tsc -p apps/frontend/tsconfig.json --noEmit`.
- 해결한 선행 실패: 초기 설정은 `@nx/jest`를 찾지 못해 테스트 실행 전에 중단됐고, 기존 ts-jest type-check 실행은 힙 한도를 초과했다. 현재 독립 설정에선 두 문제가 재현되지 않았다.

## 미완료 작업 및 다음 단계

- 최종 작업 기록 체크포인트를 `work`에 푸시하고 원격 SHA 일치를 확인한다.
- 다음 개발 단계는 사용자 별도 승인 전 시작하지 않는다.
- SNS 제공자별 공식 앱 설정과 코드상 OAuth scope/callback 구성을 문서 대조한다. 실제 인증이나 게시 기능은 실행하지 않는다.

## 복구 안내

1. GitHub `goldeget/putduk-social-auto`의 마지막 검증된 작업 브랜치와 SHA를 확인한다.
2. `docs/PUTDUK_WORK_LOG.md`를 읽고, 기록된 검증 기준 이후의 원격 커밋을 확인한다.
3. 저장소 루트에서 `source /workspace/.cloud-onboarding/activate.sh`를 실행한다.
4. `node --version`과 `pnpm --version`이 각각 `v22.20.0`, `10.6.1`인지 확인한 다음 의존성과 서비스 상태를 점검한다.
5. Jest와 빌드/타입 검사를 다시 실행하고, 이 기록을 갱신한다.

## 복구 시 주의사항 및 운영 위험

- 클라우드 작업 공간은 임시 공간이다. GitHub 원격 작업 브랜치와 커밋 SHA가 일치해야 백업 완료로 간주한다.
- 기본 셸은 프로젝트 범위를 벗어난 Node.js 24/pnpm 11일 수 있다. 검사 전에 반드시 활성화 스크립트를 실행한다.
- Jest는 `isolatedModules` 변환을 사용하므로 테스트 실행 단계 자체에서 전체 TypeScript 타입검사를 하지 않는다. 테스트 파일은 별도 `tsc` 검사로 확인하고, 애플리케이션 코드는 빌드/타입 검사로 확인한다.
- `.env`, API 키, 비밀번호, OAuth 토큰, 세션 정보, 인증서, 데이터베이스 실데이터/덤프, 민감한 로그, `node_modules`, 빌드 산출물은 Git에 저장하지 않는다.
- Instagram, Facebook, TikTok, YouTube, Threads의 실제 SNS 인증과 게시 기능은 아직 실행하지 않는다.
- provider 코드가 요청하는 권한은 다음과 같다: Facebook `pages_show_list`, `business_management`, `pages_manage_posts`, `pages_manage_engagement`, `pages_read_engagement`, `read_insights`; Instagram(Facebook 로그인) `instagram_basic`, `pages_show_list`, `pages_read_engagement`, `business_management`, `instagram_content_publish`, `instagram_manage_comments`, `instagram_manage_insights`; Instagram standalone `instagram_business_basic`, `instagram_business_content_publish`, `instagram_business_manage_comments`, `instagram_business_manage_insights`; TikTok `video.list`, `user.info.basic`, `video.publish`, `video.upload`, `user.info.profile`, `user.info.stats`; YouTube `userinfo.profile`, `userinfo.email`, `youtube`, `youtube.force-ssl`, `youtube.readonly`, `youtube.upload`, `youtubepartner`, `yt-analytics.readonly`; Threads `threads_basic`, `threads_content_publish`, `threads_manage_replies`, `threads_manage_insights`.
- 콜백 경로는 `/integrations/social/facebook`, `/integrations/social/instagram`, `/integrations/social/instagram-standalone`, `/integrations/social/tiktok`, `/integrations/social/youtube`, `/integrations/social/threads`이며 도메인은 `FRONTEND_URL`을 사용한다. 각 개발자 콘솔에 이 도메인/경로를 등록하고 필요한 권한 심사·제품 설정을 마쳐야 하나, 콘솔 설정은 아직 하지 않았다.
- 기존 `goldeget/putduk-mining` 및 `phonarawd/ai-auto-pro` 저장소는 변경하지 않는다. 유료 자원 생성 및 공개 배포도 하지 않는다.
