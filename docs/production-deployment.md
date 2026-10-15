# 운영 배포 구성 설계

이 문서는 향후 Ubuntu 서버에서 Postiz를 운영할 때 사용할 Compose 초안과 복구 절차를 설명합니다. 현재 서버는 구매되지 않았으며, 이 Compose는 실행·배포하지 않았습니다. 정적 문법 검사는 실제 서버에서의 동작 검증을 대신하지 않습니다.

## 구성과 네트워크

`docker-compose.production.yaml`에는 다음 서비스가 있습니다.

| 서비스 | 역할 | 데이터 보존 |
| --- | --- | --- |
| `caddy` | 공개 HTTP에서 HTTPS 인증서를 발급하고 Postiz로 전달 | 인증서와 설정 볼륨 |
| `postiz` | 웹 화면, API, Postiz의 Temporal worker 프로세스 | 설정 및 업로드 볼륨 |
| `postiz-postgres` | 사용자·채널·게시물 등 Postiz 데이터베이스 | PostgreSQL named volume |
| `postiz-redis` | Postiz 런타임 큐/캐시 데이터 | AOF가 켜진 Redis named volume |
| `temporal` | 예약 작업 워크플로 실행 | Temporal DB와 검색 서비스에 의존 |
| `temporal-postgresql` | Temporal 워크플로 이력과 타이머 | PostgreSQL named volume |
| `temporal-elasticsearch` | Temporal 검색/visibility 저장소 | Elasticsearch named volume |

Spotlight, Temporal UI와 Admin Tools는 운영 Compose에서 제외했습니다. 개발 Compose에서 Temporal이 `ENABLE_ES=true`이고 Elasticsearch를 seed로 사용하므로 Elasticsearch와 Temporal PostgreSQL은 그대로 유지했습니다. 이를 임의로 제거하면 지원되지 않는 설정이 됩니다.

Caddy만 호스트의 80/443 포트를 엽니다. Postiz의 5000 포트는 Caddy와 컨테이너 내부에서만 연결되고, 데이터베이스·Redis·Temporal(7233)·Elasticsearch(9200)는 호스트 포트를 공개하지 않습니다. `app-data`와 `temporal` 네트워크는 외부 라우팅이 차단된 내부 네트워크입니다. Postiz는 SNS 제공자 API로 나갈 수 있도록 `edge`에도 연결됩니다. 실제 방화벽과 Docker 네트워크 동작은 서버에서 별도로 검증해야 합니다.

재시작 정책은 `unless-stopped`이며 서비스별 healthcheck 및 시작 의존 조건을 넣었습니다. Docker 데몬 자체가 부팅 시 시작되도록 Ubuntu에서 활성화해야 합니다. Compose health 상태는 장애 감지에 도움을 주지만, 자동으로 모든 애플리케이션 오류를 고치거나 데이터 복구를 보장하지는 않습니다.

모든 이미지 태그는 고정했으며 `latest`는 사용하지 않았습니다. Postiz는 움직이는 태그를 직접 지정하지 않고 `POSTIZ_IMAGE`에 **검증된 코드 빌드의 immutable SHA-256 digest**를 요구합니다. 예제의 대체 문구는 실제 digest가 아니므로 배포할 수 없습니다. 소스의 개발 이미지 시작 스크립트가 Prisma `db push`를 실행하는 경로가 확인되어 있으므로, 정확한 운영 이미지 동작과 스키마 변경 절차도 격리 환경에서 확인하기 전에는 업데이트하지 마세요.

## 비밀값과 최초 관리자 설정

`.env.production.example`은 값 형식 안내용이며 그대로 사용하지 않습니다. 실제 설정 파일은 저장소 밖인 `/etc/putduk/.env.production`에 두고 root만 읽게 합니다(예: 소유자 `root:root`, 권한 `0600`). 실제 비밀값, OAuth 토큰, 백업 파일은 GitHub에 저장하지 않습니다. 운영 비밀번호는 서로 다른 긴 난수로 생성하고 주기적인 회전 절차를 별도로 마련하세요. PostgreSQL/Redis 접속 URL에 들어가는 세 비밀번호는 URL 인코딩 문제를 피하도록 영문자·숫자·밑줄·하이픈 등 URL-safe 문자만 사용해야 합니다. JWT 비밀값도 다른 비밀번호와 공유하지 마세요.

`DISABLE_REGISTRATION=true`로 일반 가입을 닫습니다. Postiz 코드상 최초 조직이 없을 때 초기 가입 예외가 가능한 것으로 보이나, 운영 이미지와 최신 코드에서 이를 재검증해야 합니다. 공개 서버를 열기 전 방화벽과 SSH 터널 등으로 접근을 제한한 상태에서 최초 관리자 계정을 만들고, 별도 테스트를 거쳐 가입이 닫혔는지 확인하세요. 이 초안의 환경 변수만으로 첫 사용자가 전역 super-admin이 되는지는 **미검증**입니다. 운영 개방 전에 실제 격리 복제본에서 관리자 권한과 접근 통제를 확인해야 합니다.

OAuth 공급자 콘솔에는 실제 HTTPS 도메인과 저장소 코드에서 사용하는 콜백 경로를 등록해야 합니다. 현재 코드 기준 경로는 Facebook `/integrations/social/facebook`, Instagram `/integrations/social/instagram` 및 `/integrations/social/instagram-standalone`, Threads `/integrations/social/threads`, TikTok `/integrations/social/tiktok`, YouTube `/integrations/social/youtube`입니다. 앱 심사, 허용 계정, 기능별 권한은 공급자별로 다르며 현재 승인 상태는 확인되지 않았습니다. 공개 HTTPS 주소와 필요한 앱 승인 없이는 실제 인증을 검증할 수 없습니다.

## 향후 서버에서 수행할 절차

아래는 안내용 명령이며 이번 작업에서는 실행하지 않았습니다.

1. 서버에서 SSH 키 로그인, 최소 방화벽(공개 80/443과 관리자용 제한 SSH), 보안 업데이트 및 Docker 부팅 자동 시작을 구성합니다. Docker 소켓을 인터넷에 공개하지 않습니다.
2. 실제 도메인 DNS를 서버로 연결하고 HTTPS 프록시 발급에 필요한 80/443 도달성을 확인합니다. Cloudflare는 DNS 프록시나 R2가 꼭 필요한 구성 요소가 아닙니다. 도메인/외부 저장소의 별도 요금과 계정은 현재 미확인입니다.
3. `.env.production.example`을 참고해 비밀 저장소에서 `/etc/putduk/.env.production`을 만듭니다. 준비되지 않은 OAuth 값은 비워 둡니다. `POSTIZ_IMAGE`에는 검사된 정확한 이미지 digest를 사용합니다.
4. 먼저 설정만 렌더링합니다: `docker compose --env-file /etc/putduk/.env.production -f docker-compose.production.yaml config --quiet`.
5. 격리된 복구·업데이트 계획과 백업을 확인하고 승인된 운영 절차로만 서비스를 시작합니다. 이 문서는 서버 실행 승인이 아닙니다.

Compose의 `unless-stopped`는 프로세스 재기동 정책이고, 데이터베이스 스키마 롤백·손상 데이터 복원·중복 게시 방지의 보장은 아닙니다. 배포 전에 테스트 서버에서 전체 절차를 연습해야 합니다. `docker compose down -v`는 모든 named volume을 지울 수 있으므로 절대로 데이터 보존 명령으로 사용하지 마세요.

## 데이터, 백업과 복원

| 저장소 | 담는 내용 | 복구 중요도와 주의 |
| --- | --- | --- |
| Postiz PostgreSQL | 계정, 연결된 채널의 자격 증명/메타데이터, 게시물과 일정 | 핵심 데이터. 자격 증명이 포함될 수 있으므로 암호화 백업 필요 |
| Temporal PostgreSQL | 워크플로 이력, 예약 타이머, 실행 상태 | 핵심 데이터. Postiz DB와 함께 일관된 시점으로 복구해야 함 |
| Elasticsearch | Temporal visibility/search 데이터 | 설정에서 활성화되어 있으므로 보존 대상으로 둠. 재생성 가능 여부는 공식 복구 절차로 별도 검증 전까지 가정하지 않음 |
| Redis AOF/volume | 큐, 캐시, 임시 런타임 상태 | 재생성 가능한 캐시와 복구가 필요한 미처리 작업을 구분해 검증. AOF는 데이터베이스 백업을 대체하지 않음 |
| Postiz uploads | 이미지·영상 및 업로드 파일 | 게시물 레코드가 참조하므로 함께 백업. 파일만 복원하거나 DB만 복원하면 연결이 깨질 수 있음 |
| Postiz config, Caddy data/config | 애플리케이션 설정/HTTPS 인증서 | 재생성 절차를 문서화하고 권한을 제한해 백업 |

서버와 다른 장애 영역의 암호화된 백업 저장소를 사용합니다. 예를 들면 별도 계정의 S3 호환 오브젝트 저장소와 restic 같은 도구를 검토할 수 있으나, 비용·계정·지역·암호키 보관 방식은 아직 선정되지 않았습니다. 비밀 env 파일은 일반 백업 대상과 분리하고 별도 비밀 관리 절차를 사용합니다.

운영 전 설계 목표는 하루 한 번 암호화된 전체 백업, 데이터베이스의 더 잦은 증분/WAL 보존 검토, 7일/4주/6개월 보존입니다. 이는 정책 초안이지 실제 수행 결과가 아닙니다. 목표 복구 시점(RPO)과 복구 시간(RTO)을 소유자와 정하고, 최소 분기별로 격리된 서버/볼륨에 복원하여 DB, 미디어, 예약 워크플로를 확인합니다. 백업 작업 성공 로그는 복원 성공과 다릅니다. 복구 후 예약 시각과 게시 상태를 대조해 이미 외부 게시됐을 수 있는 작업을 수동 확인해야 합니다. 외부 API의 불확실한 응답을 고려할 때 모든 SNS에서 정확히 한 번만 게시된다고 보장할 수 없습니다.

## 운영, 관측과 비용

로그는 컨테이너별 `json-file` 크기/개수 제한(10MB × 5개)을 두었습니다. 호스트 디스크, 업로드 용량, 백업 성공 시각, 컨테이너 상태, 늦은/실패한 예약, SNS API 오류를 외부 알림으로 감시해야 합니다. 알림 서비스와 저장 비용은 미정입니다. Ubuntu 보안 업데이트는 백업 및 재부팅 창을 정하고 적용한 뒤 서비스/예약 대기열을 확인합니다. 앱 이미지를 업데이트하기 전 DB 스키마 변경 및 이전 이미지와의 호환성을 확인하세요.

사용자가 제시한 Cloud VPS 6 사양은 6 vCPU, 12GB RAM, 200GB SSD, 월 $9, 아직 구매 전입니다. 독립된 운영 모드 메모리 측정은 없으므로 12GB 적합성은 **조건부**입니다. Elasticsearch가 최소 512MB heap을 쓰고 Postgres 두 개, Redis, Temporal, 앱/워커, 프록시와 Ubuntu가 같은 서버에 올라가며, 미디어 변환 시 순간 메모리가 늘어날 수 있습니다. 디스크 200GB도 업로드·로그·백업 보존량을 정하고 경보를 설정하기 전에는 충분하다고 확정할 수 없습니다. 서버 기본료 외 도메인과 외부 백업/알림 비용은 미확인입니다.

Meta 광고 자동화는 이번 범위에서 구현하지 않았습니다. 나중에 필요하면 별도 worker/권한/비밀값 공간과 독립된 게시·광고 검증을 설계해 일반 SNS 게시 권한과 분리합니다.

## 검사 결과와 미검증 사항

Compose YAML 파싱, 환경변수 참조, 포트·네트워크·볼륨·재시작 정책은 정적 검사할 수 있습니다. 실제 이미지 pull, ARM/서버 자원 사용, 컨테이너 시작, Caddy 인증서 발급, readiness/healthcheck 동작, 복구, OAuth 및 실제 게시 기능은 이 단계에서 검증하지 않았습니다. healthcheck의 이미지별 명령 호환성도 대상 이미지 digest로 서버에서 확인해야 합니다.
