# PUTDUK SOCIAL AUTO 작업 기록

## 현재 상태

- 마지막 작업 일시: 2026-10-15 (UTC; GitHub 체크포인트 생성 시각은 커밋 기록 참조)
- 개발 단계: Codex Cloud 환경 검증 및 Jest 설정 오류 진단
- 저장소: `goldeget/putduk-social-auto`
- 현재 작업 브랜치: `work`
- 마지막 작업 전 검증 기준 커밋: `0956d49ab79acb314f700779b92677830ac83a9d` (`main`과 동일)
- GitHub 작업 브랜치 백업: 최초 체크포인트 준비 중

## 완료된 작업

- 지정된 클라우드 활성화 스크립트로 Node.js 22.20.0과 pnpm 10.6.1을 확인했다.
- 원격 저장소 주소와 로컬 브랜치를 확인했다. 초기 확인 시 `main`은 기준 커밋을 가리키며 원격 `work` 브랜치는 아직 없었다.
- 현재 체크포인트 작성 전 작업 트리는 깨끗했고, 선행 미커밋 변경은 없었다.
- Jest를 실행해 실패가 테스트 파일 실행 이전의 설정 로드 단계에서 발생함을 재현했다.

## 검증 결과

- 통과한 테스트: 이번 세션에서 새로 실행한 테스트 없음.
- 이전 환경 세션 기록: 백엔드 빌드, 오케스트레이터 빌드, 프런트엔드 타입 검사가 통과한 것으로 보고됐다. 이번 복구 세션에서는 아직 재검증하지 않았다.
- 실패한 테스트: `source /workspace/.cloud-onboarding/activate.sh && pnpm test --runInBand`가 실패했다. Jest 설정 컴파일 단계에서 `jest.config.ts`의 `@nx/jest` import를 찾지 못해 종료됐고 테스트 파일은 실행되지 않았다.

## 미완료 작업 및 다음 단계

- 첫 번째 안전 체크포인트를 원격 `work` 브랜치에 푸시하고 로컬/원격 커밋 SHA를 대조한다.
- Jest/Nx 설정과 의존성·lockfile의 실제 불일치를 추가 진단한다.
- 사용자 승인 범위가 확인된 뒤 Jest 설정 수정, 의미 있는 기능 테스트, 백엔드·오케스트레이터 빌드 및 프런트엔드 타입 검사를 수행한다.
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
- 이번 Jest 실패는 테스트 결과가 아니라 Jest 설정 로딩 실패이며, 성공으로 간주하면 안 된다.
- `.env`, API 키, 비밀번호, OAuth 토큰, 세션 정보, 인증서, 데이터베이스 실데이터/덤프, 민감한 로그, `node_modules`, 빌드 산출물은 Git에 저장하지 않는다.
- Instagram, Facebook, TikTok, YouTube, Threads의 실제 SNS 인증과 게시 기능은 아직 실행하지 않는다.
- 기존 `goldeget/putduk-mining` 및 `phonarawd/ai-auto-pro` 저장소는 변경하지 않는다. 유료 자원 생성 및 공개 배포도 하지 않는다.
