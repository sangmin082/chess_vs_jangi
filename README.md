# 체스 vs 장기 — iOS

체스 군대와 장기 군대가 장기판 하나에서 맞붙는 게임. SwiftUI로 만든 네이티브 iOS 앱.

- Bundle ID: `com.chessvsjanggi.game`
- 데이터 수집 없음 (온라인 대전만 릴레이 서버 사용)
- 규칙 전문과 결정 근거: [RULES.md](./RULES.md) · 빌드와 배포: [docs/RELEASE.md](./docs/RELEASE.md)

## 게임 규칙 요약

- 장기판(9×10 교차점)에서 둔다. **체스가 선공**
- 체스 기물은 체스 규칙대로, 장기 기물은 장기 규칙대로 움직인다
- **상대 킹/궁을 체크메이트(외통)하면 승리**
- 체스: 뒷줄 9개(비숍 3) + 폰 9개. 첫 수 두 칸·승급·캐슬링 있음, 앙파상 없음
- 장기: 표준 배치 + 졸 9개 + 차 5대. 궁·사는 궁성 안에서만, 포는 체스 기물도 넘는다. 빅장·한수쉼 없음
- 무승부: 둘 수 없음 · 3회 동형 · 50수 규칙

## 앱 구성

```
ChessVsJanggi/
  App/       ChessVsJanggiApp.swift
  Engine/    Core.swift(타입·보드·궁성·초기 배치) Rules.swift(수 생성·체크·캐슬링)
             Game.swift(진행·종료 판정)
  AI/        Bot.swift (네가맥스+알파베타+캡처 연장, 쉬움/보통/어려움, 시간 제한)
  Online/    RoomClient(WebSocket) · OnlineConfig(서버 주소)
  Views/     Home(규칙 시트 포함) / GameScreen / BoardView / OnlineScreen / Theme / Haptics / Names
Tests/       엔진 단위 테스트 · 자가대국 통계
server/      온라인 대전 릴레이 서버 (Node, Render 배포)
scripts/     asc.py(App Store Connect 준비) · make_strings.py(한/영 문자열 카탈로그 생성)
```

- **컴퓨터 대전**: 체스 또는 장기 진영을 골라 쉬움/보통/어려움과 대국 · 무르기 지원
- **온라인 대전**: 방을 만들면 6자리 방코드가 나오고, 친구가 코드로 입장하면 시작.
  방장이 진영(체스/장기/무작위)을 고른다. 내 진영이 항상 화면 아래

## 빌드 · 테스트

- 앱: `ChessVsJanggi.xcodeproj`를 Xcode 16+로 열고 실행 (iOS 17 이상)
- 엔진 테스트 (macOS/Linux): `swift test`
- 규칙 밸런스 자가대국: `SELFPLAY_GAMES=30 swift test -c release -Xswiftc -enable-testing --filter SelfPlay`
- 서버 테스트: `cd server && npm install && npm test`
- 화면 문구를 바꿨으면: `python3 scripts/make_strings.py` (번역이 빠지면 실패한다)

CI (GitHub Actions):

- `ios.yml` — push/PR 시 엔진 테스트 + 서명 없이 컴파일 검증
- `ui-tests.yml` — 시뮬레이터에서 주요 흐름을 눌러 보고 스크린샷을 아티팩트로 올림
- `testflight.yml` — Actions 탭에서 Run workflow 또는 `v*` 태그 푸시 시 TestFlight 업로드
