import XCTest

/// 시뮬레이터에서 실제로 앱을 눌러 보며 주요 흐름을 확인하고 App Store용 스크린샷을 남긴다.
/// 스크린샷은 xcresult 첨부로 저장되어 ui-tests 워크플로가 아티팩트로 올린다.
final class PlaythroughTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        launch(language: "ko", locale: "ko_KR")
    }

    // MARK: - 도우미

    private func launch(language: String, locale: String) {
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func tapButton(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = button(containing: text)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "버튼 없음: \(text)", file: file, line: line)
        element.tap()
    }

    private func point(_ sq: Int) -> XCUIElement {
        app.descendants(matching: .any)["pt-\(sq)"]
    }

    /// 내 기물(라벨이 "체스 …" / "Chess …"로 시작하는 교차점)
    private func myPieces(sidePrefix: String) -> [XCUIElement] {
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'pt-' AND label BEGINSWITH %@", sidePrefix + " ")
        return app.descendants(matching: .any).matching(predicate).allElementsBoundByIndex
    }

    private var targets: XCUIElementQuery {
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'pt-' AND value IN %@", ["갈 수 있음", "Can move here"])
        return app.descendants(matching: .any).matching(predicate)
    }

    /// 움직일 수 있는 내 기물을 하나 골라 선택한다 (컴퓨터가 생각 중이면 기다린다).
    @discardableResult
    private func selectMovablePiece(sidePrefix: String, timeout: TimeInterval = 60) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            for piece in myPieces(sidePrefix: sidePrefix).reversed() {
                piece.tap()
                if targets.firstMatch.exists { return true }
                if Date().timeIntervalSince(start) > timeout { break }
            }
            usleep(500_000)
        }
        return false
    }

    private func playOneMove(sidePrefix: String) {
        XCTAssertTrue(selectMovablePiece(sidePrefix: sidePrefix), "움직일 수 있는 기물이 없습니다")
        targets.firstMatch.tap()
        // 승급 선택창이 뜨면 퀸으로
        let queen = app.buttons["promote-queen"]
        if queen.exists { queen.tap() }
    }

    private var isGameOver: Bool { button(containing: "홈으로").exists }

    // MARK: - 시나리오

    func test1_HomeAndRules() {
        XCTAssertTrue(app.staticTexts["체스 vs 장기"].waitForExistence(timeout: 5))
        shot("01 홈")

        tapButton("규칙 한 장 보기")
        XCTAssertTrue(app.staticTexts["규칙 한 장"].waitForExistence(timeout: 5))
        shot("02 규칙")
    }

    func test2_VsComputerAsChess() {
        tapButton("보통")
        tapButton("컴퓨터 대전")
        XCTAssertTrue(point(0).waitForExistence(timeout: 5))
        shot("03 대국 시작 (체스)")

        XCTAssertTrue(selectMovablePiece(sidePrefix: "체스"))
        shot("04 갈 수 있는 자리 표시")
        targets.firstMatch.tap()

        for move in 0..<8 where !isGameOver {
            playOneMove(sidePrefix: "체스")
            if move == 4 { shot("05 대국 중반") }
        }
        shot("06 대국 후반")

        if !isGameOver {
            tapButton("무르기")
            shot("07 무르기 후")
        }
    }

    func test3_VsComputerAsJanggi() {
        tapButton("장기로 두기")
        tapButton("컴퓨터 대전")
        XCTAssertTrue(point(0).waitForExistence(timeout: 5))
        // 컴퓨터(체스)가 먼저 둔다
        for _ in 0..<5 where !isGameOver {
            playOneMove(sidePrefix: "장기")
        }
        shot("08 장기로 두기")
    }

    func test4_OnlineLobby() {
        tapButton("온라인 대전")
        XCTAssertTrue(app.staticTexts["친구와 한 판"].waitForExistence(timeout: 5))
        tapButton("체스 (선공)")
        shot("09 온라인 로비")
    }

    func test5_English() {
        launch(language: "en", locale: "en_US")
        XCTAssertTrue(app.staticTexts["Chess vs Janggi"].waitForExistence(timeout: 5))
        shot("10 English home")

        tapButton("Normal")
        tapButton("vs Computer")
        XCTAssertTrue(point(0).waitForExistence(timeout: 5))
        for _ in 0..<4 where !isGameOver { playOneMove(sidePrefix: "Chess") }
        XCTAssertTrue(selectMovablePiece(sidePrefix: "Chess"))
        shot("11 English game")

        app.navigationBars.buttons.firstMatch.tap()
        tapButton("Online")
        XCTAssertTrue(app.staticTexts["Play a Friend"].waitForExistence(timeout: 5))
        shot("12 English online lobby")
    }
}
