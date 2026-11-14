# 빌드와 배포 (맥 없이 GitHub Actions로)

## 구성

| 워크플로 | 언제 | 하는 일 |
|---|---|---|
| `iOS` | 모든 푸시와 PR | 엔진 테스트, 서명 없는 앱 빌드 (시크릿 필요 없음) |
| `UI tests` | 앱 소스가 바뀐 푸시, 또는 Run workflow | 시뮬레이터에서 주요 흐름을 눌러 보고 스크린샷을 아티팩트로 올림 |
| `TestFlight` | Actions 탭에서 Run workflow, 또는 `v*` 태그 푸시 | 번들 ID 등록, 빌드 번호 결정, match 서명, 빌드, 업로드 |

서명은 다른 앱들과 같은 **fastlane match** 저장소(`sangmin082/ios-certificates`)를 씁니다.
- 기존 배포 인증서를 재사용합니다.
- 이 앱(`com.chessvsjanggi.game`)의 App Store 프로파일은 첫 실행 때 match가 만들어 저장소에 추가합니다.

## 처음 한 번 하는 일

1. **시크릿 복사** — `ios-certificates` 저장소의 Actions 탭 → **Provision app secrets → Run workflow** →
   대상 저장소 이름에 `chess_vs_jangi` 입력. 시크릿 5개
   (`ASC_KEY_ID` `ASC_ISSUER_ID` `ASC_KEY_P8` `MATCH_PASSWORD` `MATCH_GIT_BASIC_AUTHORIZATION`)가 이 저장소에 들어옵니다.
2. **TestFlight 실행** — 이 저장소의 Actions 탭 → **TestFlight → Run workflow**.
   처음 실행하면 번들 ID를 자동으로 등록한 뒤 "App Store Connect에 앱을 만들어 주세요"라며 멈춥니다.
   애플이 API로 앱 생성을 막아 두어서 이 단계만 사람이 해야 합니다.
   실행 요약(Summary)에 이름, 번들 ID, SKU가 표로 나오므로 그대로 입력하면 됩니다.
3. 다시 **Run workflow**를 누르면 업로드됩니다. TestFlight 앱에서 설치합니다.

`workflow_dispatch`는 워크플로 파일이 기본 브랜치(main)에 있어야 Actions 탭에 나타납니다.
빌드 번호는 TestFlight에 있는 가장 큰 번호 + 1로 자동으로 정해집니다.

## 온라인 대전 서버

`server/`는 방코드 매칭과 무브 릴레이만 하는 작은 Node 서버입니다.

1. render.com → **New → Blueprint** → 이 저장소 연결 (`render.yaml`을 읽어 `chess-vs-janggi-server`를 만듭니다).
2. 배포되면 주소는 `wss://chess-vs-janggi-server.onrender.com` — 앱의 `ChessVsJanggi/Online/OnlineConfig.swift`에 적힌 주소와 같아야 합니다.
   서비스 이름을 바꾸면 그 파일도 함께 고칩니다.
3. `https://chess-vs-janggi-server.onrender.com/privacy`는 개인정보처리방침, 그 밖의 주소는 지원 페이지로 쓸 수 있습니다.

무료 플랜은 한동안 접속이 없으면 잠들어서, 첫 연결에 최대 1분쯤 걸립니다.
