import XCTest
@testable import CVJEngine

final class RulesTests: XCTestCase {

    private func sq(_ file: Int, _ rank: Int) -> Square { SquareUtil.make(file: file, rank: rank) }

    private func targets(_ board: Board, _ side: Side, from: Square) -> Set<Square> {
        Set(Rules.legalMoves(for: side, on: board).filter { $0.from == from }.map(\.to))
    }

    // MARK: - 초기 배치

    func testInitialSetup() {
        let board = Board.initial()
        XCTAssertEqual(board.pieces(of: .chess).count, 17) // 뒷줄 8 + 폰 9
        XCTAssertEqual(board.pieces(of: .janggi).count, 16)
        XCTAssertEqual(board.royalSquare(of: .chess), sq(4, 0))
        XCTAssertEqual(board.royalSquare(of: .janggi), sq(4, 8))
        XCTAssertNil(board[sq(7, 0)])
        XCTAssertEqual(board[sq(8, 0)]?.kind, .rook)
        XCTAssertFalse(Rules.isInCheck(.chess, on: board))
        XCTAssertFalse(Rules.isInCheck(.janggi, on: board))
    }

    func testInitialMoveCounts() {
        let board = Board.initial()
        // 폰 9개 × 2 + 나이트 둘 × 2 + 룩 i: 1(빈 h1 칸)
        XCTAssertEqual(Rules.legalMoves(for: .chess, on: board).count, 18 + 4 + 1)
        XCTAssertFalse(Rules.legalMoves(for: .janggi, on: board).isEmpty)
        XCTAssertNil(Game().result)
        XCTAssertEqual(Game().sideToMove, .chess)
    }

    // MARK: - 폰

    func testPawnMoves() {
        var board = Board.custom([(4, 0, .king), (4, 8, .general), (2, 1, .pawn), (3, 2, .soldier), (2, 3, .soldier)])
        // 한 칸 전진 + 대각 캡처. 두 칸은 (2,3)이 막혀서 불가
        XCTAssertEqual(targets(board, .chess, from: sq(2, 1)), [sq(2, 2), sq(3, 2)])
        board[sq(2, 3)] = nil
        XCTAssertEqual(targets(board, .chess, from: sq(2, 1)), [sq(2, 2), sq(2, 3), sq(3, 2)])
        // 앞이 막히면 전진 불가 (정면으로는 못 잡는다)
        board[sq(2, 2)] = Piece(.soldier)
        XCTAssertEqual(targets(board, .chess, from: sq(2, 1)), [sq(3, 2)])
    }

    func testPawnPromotion() {
        let board = Board.custom([(0, 0, .king), (4, 8, .general), (0, 8, .pawn)])
        let moves = Rules.legalMoves(for: .chess, on: board).filter { $0.from == sq(0, 8) }
        XCTAssertEqual(Set(moves.compactMap(\.promotion)), [.queen, .rook, .bishop, .knight])
        XCTAssertTrue(moves.allSatisfy { $0.to == sq(0, 9) })

        var game = Game(board: board, sideToMove: .chess)
        XCTAssertFalse(game.play(Move(from: sq(0, 8), to: sq(0, 9)))) // 승급 기물 없이는 불가
        XCTAssertTrue(game.play(Move(from: sq(0, 8), to: sq(0, 9), promotion: .rook)))
        XCTAssertEqual(game.board[sq(0, 9)]?.kind, .rook)
    }

    // MARK: - 캐슬링

    func testCastling() {
        let placements: [(Int, Int, PieceKind)] = [(4, 0, .king), (0, 0, .rook), (8, 0, .rook), (4, 8, .general)]
        let board = Board.custom(placements, castling: true)
        let kingTargets = targets(board, .chess, from: sq(4, 0))
        XCTAssertTrue(kingTargets.contains(sq(6, 0)))
        XCTAssertTrue(kingTargets.contains(sq(2, 0)))

        let kingside = board.applying(Move(from: sq(4, 0), to: sq(6, 0)))
        XCTAssertEqual(kingside[sq(6, 0)]?.kind, .king)
        XCTAssertEqual(kingside[sq(5, 0)]?.kind, .rook)
        XCTAssertNil(kingside[sq(8, 0)])
        XCTAssertFalse(kingside.canCastleQueenside)

        let queenside = board.applying(Move(from: sq(4, 0), to: sq(2, 0)))
        XCTAssertEqual(queenside[sq(2, 0)]?.kind, .king)
        XCTAssertEqual(queenside[sq(3, 0)]?.kind, .rook)
        XCTAssertNil(queenside[sq(0, 0)])
    }

    func testCastlingBlockedByAttackAndMovedPieces() {
        // 차가 f열(5)을 겨누면 킹사이드 불가, 퀸사이드는 가능
        var board = Board.custom(
            [(4, 0, .king), (0, 0, .rook), (8, 0, .rook), (4, 8, .general), (5, 5, .chariot)], castling: true)
        var kingTargets = targets(board, .chess, from: sq(4, 0))
        XCTAssertFalse(kingTargets.contains(sq(6, 0)))
        XCTAssertTrue(kingTargets.contains(sq(2, 0)))

        // 체크 중에는 캐슬링 불가
        board = Board.custom(
            [(4, 0, .king), (0, 0, .rook), (8, 0, .rook), (3, 8, .general), (4, 5, .chariot)], castling: true)
        kingTargets = targets(board, .chess, from: sq(4, 0))
        XCTAssertFalse(kingTargets.contains(sq(6, 0)))
        XCTAssertFalse(kingTargets.contains(sq(2, 0)))

        // 룩이 움직였다 돌아오면 그쪽 권리가 없다
        board = Board.custom([(4, 0, .king), (0, 0, .rook), (8, 0, .rook), (4, 8, .general)], castling: true)
        board.apply(Move(from: sq(8, 0), to: sq(8, 1)))
        board.apply(Move(from: sq(8, 1), to: sq(8, 0)))
        kingTargets = targets(board, .chess, from: sq(4, 0))
        XCTAssertFalse(kingTargets.contains(sq(6, 0)))
        XCTAssertTrue(kingTargets.contains(sq(2, 0)))

        // 사이에 기물이 있으면 불가
        board = Board.custom(
            [(4, 0, .king), (0, 0, .rook), (8, 0, .rook), (1, 0, .knight), (4, 8, .general)], castling: true)
        XCTAssertFalse(targets(board, .chess, from: sq(4, 0)).contains(sq(2, 0)))
    }

    // MARK: - 체스 기물

    func testKnightJumpsAndBishopSlides() {
        let board = Board.custom([
            (4, 0, .king), (4, 8, .general),
            (1, 0, .knight), (1, 1, .pawn), (0, 1, .pawn), (2, 1, .pawn),
            (6, 3, .bishop), (8, 5, .soldier),
        ])
        // 나이트는 막혀 있어도 뛰어넘는다
        XCTAssertEqual(targets(board, .chess, from: sq(1, 0)), [sq(0, 2), sq(2, 2), sq(3, 1)])
        let bishop = targets(board, .chess, from: sq(6, 3))
        XCTAssertTrue(bishop.contains(sq(8, 5)))   // 캡처
        XCTAssertTrue(bishop.contains(sq(2, 7)))
        XCTAssertFalse(bishop.contains(sq(6, 4)))
    }

    // MARK: - 장기 기물

    func testGeneralAndAdvisorStayInPalace() {
        let board = Board.custom([(4, 0, .king), (3, 7, .general), (5, 9, .advisor)])
        // 궁성 귀퉁이(3,7): 옆·뒤·대각(중앙)으로만. 궁성 밖(2,7), (3,6)은 못 간다
        XCTAssertEqual(targets(board, .janggi, from: sq(3, 7)), [sq(4, 7), sq(3, 8), sq(4, 8)])
        XCTAssertEqual(targets(board, .janggi, from: sq(5, 9)), [sq(4, 9), sq(5, 8), sq(4, 8)])

        // 변 가운데(4,7)에서는 대각선이 없다
        let edge = Board.custom([(0, 0, .king), (4, 7, .general)])
        XCTAssertEqual(targets(edge, .janggi, from: sq(4, 7)), [sq(3, 7), sq(5, 7), sq(4, 8)])
    }

    func testCannonUsesChessPieceAsScreen() {
        let board = Board.custom([
            (4, 0, .king), (4, 8, .general),
            (1, 7, .cannon), (1, 1, .pawn), (1, 0, .knight),
        ])
        let cannon = targets(board, .janggi, from: sq(1, 7))
        // 폰을 다리 삼아 나이트를 잡는다. 다리 없이는 움직이지 못한다
        XCTAssertTrue(cannon.contains(sq(1, 0)))
        XCTAssertFalse(cannon.contains(sq(1, 1)))
        XCTAssertFalse(cannon.contains(sq(1, 5)))
        XCTAssertFalse(cannon.contains(sq(0, 7)))
        XCTAssertTrue(Rules.isAttacked(sq(1, 0), by: .janggi, on: board))
    }

    func testCannonCannotJumpCannon() {
        let board = Board.custom([
            (4, 0, .king), (4, 8, .general),
            (1, 7, .cannon), (1, 4, .cannon), (1, 1, .pawn),
        ])
        XCTAssertFalse(targets(board, .janggi, from: sq(1, 7)).contains(sq(1, 1)))
        // 아래쪽 포는 폰을 넘어 (1,0)으로 갈 수 있다
        XCTAssertTrue(targets(board, .janggi, from: sq(1, 4)).contains(sq(1, 0)))
    }

    func testHorseAndElephantBlocking() {
        var board = Board.custom([(4, 0, .king), (4, 8, .general), (2, 5, .horse), (6, 5, .elephant)])
        XCTAssertEqual(targets(board, .janggi, from: sq(2, 5)).count, 8)
        XCTAssertTrue(targets(board, .janggi, from: sq(6, 5)).contains(sq(4, 2)))

        // 멱이 막히면 그 방향으로 못 간다 (체스 기물도 멱을 막는다)
        board[sq(2, 4)] = Piece(.pawn)
        let horse = targets(board, .janggi, from: sq(2, 5))
        XCTAssertFalse(horse.contains(sq(1, 3)))
        XCTAssertFalse(horse.contains(sq(3, 3)))
        XCTAssertEqual(horse.count, 6)

        board[sq(5, 3)] = Piece(.pawn) // 상의 (6,5)→(4,2) 길목
        XCTAssertFalse(targets(board, .janggi, from: sq(6, 5)).contains(sq(4, 2)))
    }

    func testSoldierMovesForwardAndSideways() {
        let board = Board.custom([(4, 0, .king), (4, 8, .general), (2, 4, .soldier)])
        XCTAssertEqual(targets(board, .janggi, from: sq(2, 4)), [sq(2, 3), sq(1, 4), sq(3, 4)])
    }

    func testChariotUsesPalaceDiagonal() {
        let board = Board.custom([(0, 0, .king), (4, 9, .general), (3, 7, .chariot)])
        let chariot = targets(board, .janggi, from: sq(3, 7))
        XCTAssertTrue(chariot.contains(sq(4, 8)))
        XCTAssertTrue(chariot.contains(sq(5, 9)))
        XCTAssertFalse(chariot.contains(sq(2, 6))) // 궁성 밖 대각선은 없다
    }

    // MARK: - 체크 · 종료

    func testCannotLeaveRoyalInCheck() {
        // 비숍이 룩의 줄을 막고 있다 — 비키면 킹이 차에 잡히므로 못 움직인다
        let board = Board.custom([(4, 0, .king), (4, 2, .bishop), (4, 6, .chariot), (3, 8, .general)])
        XCTAssertTrue(targets(board, .chess, from: sq(4, 2)).isEmpty)

        // 궁은 퀸이 지키는 칸으로 못 간다
        let palace = Board.custom([(0, 0, .king), (4, 8, .general), (3, 2, .queen)])
        XCTAssertFalse(targets(palace, .janggi, from: sq(4, 8)).contains(sq(3, 8)))
    }

    func testChecksFromBothArmies() {
        let board = Board.custom([(4, 0, .king), (4, 8, .general), (2, 1, .horse)])
        XCTAssertTrue(Rules.isInCheck(.chess, on: board)) // 마 (2,1)→(4,0)
        let blocked = Board.custom([(4, 0, .king), (4, 8, .general), (2, 1, .horse), (3, 1, .pawn)])
        XCTAssertFalse(Rules.isInCheck(.chess, on: blocked)) // 멱이 막힘

        let knight = Board.custom([(4, 0, .king), (4, 8, .general), (3, 6, .knight)])
        XCTAssertTrue(Rules.isInCheck(.janggi, on: knight))
        let pawn = Board.custom([(4, 0, .king), (4, 8, .general), (5, 7, .pawn)])
        XCTAssertTrue(Rules.isInCheck(.janggi, on: pawn))
    }

    func testCheckmateWinsForAttacker() {
        // 궁이 (3,9) 귀퉁이, 퀸이 (3,8)에서 체크 — 룩이 퀸을 지킨다
        let board = Board.custom([(0, 0, .king), (3, 9, .general), (3, 8, .queen), (3, 0, .rook)])
        let game = Game(board: board, sideToMove: .janggi)
        XCTAssertEqual(game.result, .win(.chess, .checkmate))

        // 장기가 체스를 외통: 킹 (0,0), 차 두 대
        let mated = Board.custom([(0, 0, .king), (4, 8, .general), (0, 5, .chariot), (1, 5, .chariot)])
        XCTAssertEqual(Game(board: mated, sideToMove: .chess).result, .win(.janggi, .checkmate))
    }

    func testStalemateIsDraw() {
        // 킹 (0,0): (0,1)·(1,0)·(1,1) 모두 공격받지만 체크는 아님
        let board = Board.custom([(0, 0, .king), (4, 8, .general), (1, 5, .chariot), (5, 1, .chariot)])
        XCTAssertFalse(Rules.isInCheck(.chess, on: board))
        XCTAssertEqual(Game(board: board, sideToMove: .chess).result, .draw(.stalemate))
    }

    func testThreefoldRepetition() {
        var game = Game(board: Board.custom([(4, 0, .king), (4, 8, .general), (8, 0, .rook), (0, 9, .chariot)]),
                        sideToMove: .chess)
        for _ in 0..<2 {
            XCTAssertTrue(game.play(Move(from: sq(8, 0), to: sq(8, 1))))
            XCTAssertTrue(game.play(Move(from: sq(0, 9), to: sq(1, 9))))
            XCTAssertTrue(game.play(Move(from: sq(8, 1), to: sq(8, 0))))
            XCTAssertTrue(game.play(Move(from: sq(1, 9), to: sq(0, 9))))
        }
        XCTAssertEqual(game.result, .draw(.threefoldRepetition))
    }

    func testCapturedPiecesAreRecorded() {
        var game = Game(board: Board.custom([(0, 0, .king), (4, 8, .general), (8, 0, .rook), (8, 5, .soldier)]),
                        sideToMove: .chess)
        XCTAssertTrue(game.play(Move(from: sq(8, 0), to: sq(8, 5))))
        XCTAssertEqual(game.captured.map(\.kind), [.soldier])
        XCTAssertEqual(game.sideToMove, .janggi)
    }

    func testMoveCodableRoundTrip() throws {
        let plain = Move(from: 3, to: 12)
        let promo = Move(from: 80, to: 89, promotion: .queen)
        for move in [plain, promo] {
            let data = try JSONEncoder().encode(move)
            XCTAssertEqual(try JSONDecoder().decode(Move.self, from: data), move)
        }
        // 승급이 없는 수는 promotion 키 없이도 읽힌다
        XCTAssertEqual(try JSONDecoder().decode(Move.self, from: Data(#"{"from":3,"to":12}"#.utf8)), plain)
    }

    // MARK: - AI

    func testBotFindsMateInOne() {
        // 퀸이 (3,8)로 가면 외통 (룩이 지킴)
        let board = Board.custom([(0, 0, .king), (3, 9, .general), (0, 8, .queen), (3, 0, .rook)])
        let game = Game(board: board, sideToMove: .chess)
        let move = Bot.bestMove(in: game, level: .hard)
        var next = game
        XCTAssertTrue(next.play(try! XCTUnwrap(move)))
        XCTAssertEqual(next.result, .win(.chess, .checkmate))
    }

    func testBotPlaysLegalGame() {
        var game = Game()
        var plies = 0
        while !game.isFinished, plies < 40, let move = Bot.bestMove(in: game, level: .easy) {
            XCTAssertTrue(game.play(move))
            plies += 1
        }
        XCTAssertGreaterThan(plies, 10)
    }
}
