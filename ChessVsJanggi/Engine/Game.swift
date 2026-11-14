import Foundation

/// 게임 종료 사유
enum GameResult: Equatable {
    case win(Side, WinReason)
    case draw(DrawReason)

    enum WinReason: Equatable {
        /// 상대 킹/궁을 체크메이트(외통)
        case checkmate
    }

    enum DrawReason: Equatable {
        /// 체크가 아닌데 둘 수 있는 수가 없음
        case stalemate
        case threefoldRepetition
        /// 캡처도 폰 전진도 없이 50수
        case fiftyMoveRule
    }
}

/// 한 판의 진행 상태 (값 타입)
struct Game {
    /// 선공 진영
    static let firstSide: Side = .chess

    private(set) var board: Board
    private(set) var sideToMove: Side
    private(set) var result: GameResult?
    private(set) var lastMove: Move?
    private(set) var moveCount: Int = 0
    /// 잡힌 기물 (잡힌 순서대로)
    private(set) var captured: [Piece] = []

    /// 50수 규칙: 캡처·폰 전진 없이 지나간 반수(half-move) 수
    private(set) var quietHalfMoves: Int = 0
    private var positionCounts: [String: Int] = [:]

    init(board: Board = .initial(), sideToMove: Side = Game.firstSide) {
        self.board = board
        self.sideToMove = sideToMove
        self.positionCounts[board.positionKey(sideToMove: sideToMove)] = 1
        self.result = Self.terminalResult(board: board, sideToMove: sideToMove)
    }

    var isFinished: Bool { result != nil }

    func legalMoves() -> [Move] {
        isFinished ? [] : Rules.legalMoves(for: sideToMove, on: board)
    }

    func legalMoves(from sq: Square) -> [Move] {
        legalMoves().filter { $0.from == sq }
    }

    var isInCheck: Bool { Rules.isInCheck(sideToMove, on: board) }

    @discardableResult
    mutating func play(_ move: Move) -> Bool {
        guard !isFinished, legalMoves().contains(move) else { return false }

        let capturedPiece = board[move.to]
        let isPawnMove = board[move.from]?.kind == .pawn
        board.apply(move)
        if let capturedPiece { captured.append(capturedPiece) }
        lastMove = move
        moveCount += 1
        quietHalfMoves = (capturedPiece != nil || isPawnMove) ? 0 : quietHalfMoves + 1
        sideToMove = sideToMove.opposite

        let key = board.positionKey(sideToMove: sideToMove)
        positionCounts[key, default: 0] += 1

        if let terminal = Self.terminalResult(board: board, sideToMove: sideToMove) {
            result = terminal
        } else if positionCounts[key] ?? 0 >= 3 {
            result = .draw(.threefoldRepetition)
        } else if quietHalfMoves >= 100 {
            result = .draw(.fiftyMoveRule)
        }
        return true
    }

    /// 수순 기록 없이 판정 가능한 종료 (AI 탐색에서도 사용). `sideToMove`는 지금 둘 차례인 쪽.
    static func terminalResult(board: Board, sideToMove: Side, legalMoves: [Move]? = nil) -> GameResult? {
        let moves = legalMoves ?? Rules.legalMoves(for: sideToMove, on: board)
        guard moves.isEmpty else { return nil }
        return Rules.isInCheck(sideToMove, on: board)
            ? .win(sideToMove.opposite, .checkmate)
            : .draw(.stalemate)
    }
}
