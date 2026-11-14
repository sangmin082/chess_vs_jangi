import XCTest
@testable import CVJEngine

/// 규칙 밸런스 확인용 AI 자가대국. 오래 걸리므로 평소에는 건너뛴다.
///   SELFPLAY_GAMES=40 swift test -c release -Xswiftc -enable-testing --filter SelfPlay
/// SELFPLAY_LEVEL=easy|normal|hard (기본 normal), SELFPLAY_MAX_PLIES (기본 300, 넘으면 미결)
final class SelfPlayTests: XCTestCase {

    func testSelfPlayStatistics() throws {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["SELFPLAY_GAMES"], let games = Int(raw) else {
            throw XCTSkip("SELFPLAY_GAMES 환경변수가 없으면 건너뜀")
        }
        let level = BotLevel(rawValue: env["SELFPLAY_LEVEL"] ?? "normal") ?? .normal
        let maxPlies = Int(env["SELFPLAY_MAX_PLIES"] ?? "") ?? 300

        var wins: [Side: Int] = [.chess: 0, .janggi: 0]
        var reasons: [String: Int] = [:]
        var totalPlies = 0
        var materialDiffAtEnd = 0

        for _ in 0..<games {
            var game = Self.makeGame(env: env)
            while !game.isFinished, game.moveCount < maxPlies,
                  let move = Bot.bestMove(in: game, level: level) {
                XCTAssertTrue(game.play(move))
            }
            totalPlies += game.moveCount
            materialDiffAtEnd += game.board.material(of: .chess) - game.board.material(of: .janggi)
            switch game.result {
            case .win(let side, let reason):
                wins[side, default: 0] += 1
                reasons["\(side):\(reason)", default: 0] += 1
            case .draw(let reason):
                reasons["draw:\(reason)", default: 0] += 1
            case nil:
                reasons["unfinished", default: 0] += 1
            }
        }
        print("""
            SELFPLAY games=\(games) level=\(level.rawValue) setup=\(env["SELFPLAY_SETUP"] ?? "기본") first=\(env["SELFPLAY_FIRST"] ?? Game.firstSide.rawValue)
              chess 승=\(wins[.chess]!) janggi 승=\(wins[.janggi]!)
              평균 수=\(totalPlies / max(games, 1)) 종료 시 평균 기물차(체스-장기)=\(materialDiffAtEnd / max(games, 1))
              사유=\(reasons.sorted { $0.key < $1.key })
            """)
    }

    /// 실험용 변형 배치. 줄마다 9글자, 대문자 = 체스(RNBQKP), 소문자 = 장기(r차 h마 e상 a사 g궁 c포 s졸), 그 외 = 빈칸.
    ///   SELFPLAY_SETUP="RNBQKBBNR/PPPPPPPPP/sssssssss/rc..r..cr/....g..../rhea.aehr" (rank 0,1,6,7,8,9 순)
    ///   SELFPLAY_FIRST=chess|janggi
    static func makeGame(env: [String: String]) -> Game {
        let first = Side(rawValue: env["SELFPLAY_FIRST"] ?? "") ?? Game.firstSide
        guard let setup = env["SELFPLAY_SETUP"] else { return Game(sideToMove: first) }
        let kinds: [Character: PieceKind] = [
            "R": .rook, "N": .knight, "B": .bishop, "Q": .queen, "K": .king, "P": .pawn,
            "r": .chariot, "h": .horse, "e": .elephant, "a": .advisor, "g": .general, "c": .cannon, "s": .soldier,
        ]
        var placements: [(Int, Int, PieceKind)] = []
        for (row, rank) in zip(setup.split(separator: "/"), [0, 1, 6, 7, 8, 9]) {
            for (file, ch) in row.enumerated() {
                if let kind = kinds[ch] { placements.append((file, rank, kind)) }
            }
        }
        return Game(board: Board.custom(placements, castling: true), sideToMove: first)
    }
}
