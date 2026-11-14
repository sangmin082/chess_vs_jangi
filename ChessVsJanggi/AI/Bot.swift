import Foundation

enum BotLevel: String, CaseIterable, Identifiable {
    case easy, normal, hard

    var id: String { rawValue }

    /// 기본 탐색 깊이 (반수)
    var depth: Int {
        switch self {
        case .easy: return 1
        case .normal: return 2
        case .hard: return 4
        }
    }

    /// 한 수에 쓸 최대 시간(초). 넘으면 마지막으로 끝난 깊이의 결과를 쓴다.
    var timeBudget: TimeInterval {
        switch self {
        case .easy: return 0.5
        case .normal: return 1.2
        case .hard: return 2.5
        }
    }

    /// 상위 후보 중 무작위로 고를 확률 (실수 유도)
    var blunderPercent: Int {
        switch self {
        case .easy: return 45
        case .normal: return 12
        case .hard: return 0
        }
    }
}

/// 체스 vs 장기 AI — 네가맥스 + 알파베타 + 캡처 연장(정지 탐색).
enum Bot {

    private static let winScore = 1_000_000

    static func bestMove(in game: Game, level: BotLevel) -> Move? {
        let moves = ordered(game.legalMoves(), on: game.board)
        guard !moves.isEmpty else { return nil }
        if moves.count == 1 { return moves[0] }

        var search = Search(deadline: Date().addingTimeInterval(level.timeBudget))
        var scored: [(Move, Int)] = moves.map { ($0, 0) }

        // 반복 심화: 시간이 넘치면 마지막으로 완료된 깊이의 점수를 사용
        for depth in 1...level.depth {
            var current: [(Move, Int)] = []
            for (move, _) in scored {
                let next = game.board.applying(move)
                let score = -search.negamax(
                    board: next, side: game.sideToMove.opposite, depth: depth - 1,
                    alpha: -winScore * 2, beta: winScore * 2, ply: 1
                )
                if search.timedOut { break }
                current.append((move, score))
            }
            if search.timedOut && current.count < scored.count { break }
            current.shuffle()
            current.sort { $0.1 > $1.1 }
            scored = current
            // 이미 이기는 수를 찾았으면 더 볼 필요 없음
            if let top = scored.first, top.1 > winScore / 2 { break }
        }

        if level.blunderPercent > 0, scored.count > 1, Int.random(in: 0..<100) < level.blunderPercent {
            // 바로 지는 수는 피해서 고른다
            let pool = scored.prefix(3).filter { $0.1 > -winScore / 2 }
            if let pick = pool.randomElement() { return pick.0 }
        }
        return scored.first?.0
    }

    /// 값비싼 기물을 싼 기물로 잡는 수부터 보도록 정렬 (알파베타 가지치기 효율)
    private static func ordered(_ moves: [Move], on board: Board) -> [Move] {
        func priority(_ move: Move) -> Int {
            var p = 0
            if let victim = board[move.to] {
                p += 10_000 + victim.kind.value * 10 - (board[move.from]?.kind.value ?? 0)
            }
            if let promotion = move.promotion { p += promotion.value }
            return p
        }
        return moves.map { ($0, priority($0)) }.sorted { $0.1 > $1.1 }.map(\.0)
    }

    private struct Search {
        let deadline: Date
        var nodes = 0
        var timedOut = false

        /// 깊이가 다 된 뒤 캡처 수순을 이만큼 더 본다
        let maxQuiescence = 4

        mutating func negamax(board: Board, side: Side, depth: Int, alpha: Int, beta: Int, ply: Int) -> Int {
            nodes += 1
            if nodes & 511 == 0, Date() > deadline { timedOut = true }
            if timedOut { return 0 }

            let moves = Rules.legalMoves(for: side, on: board)
            if let result = Game.terminalResult(board: board, sideToMove: side, legalMoves: moves) {
                switch result {
                case .win(let winner, _):
                    return winner == side ? Bot.winScore - ply : -Bot.winScore + ply
                case .draw:
                    return 0
                }
            }

            var alpha = alpha
            var best = -Bot.winScore * 2
            var candidates = moves

            if depth <= 0 {
                // 정지 탐색: 그대로 두는 값(stand pat)과 캡처·승급만 비교
                let standPat = Bot.evaluate(board: board, for: side)
                if -depth >= maxQuiescence || standPat >= beta { return standPat }
                best = standPat
                alpha = max(alpha, standPat)
                candidates = moves.filter { board[$0.to] != nil || $0.promotion == .queen }
                if candidates.isEmpty { return standPat }
            }

            for move in Bot.ordered(candidates, on: board) {
                let score = -negamax(
                    board: board.applying(move), side: side.opposite, depth: depth - 1,
                    alpha: -beta, beta: -alpha, ply: ply + 1
                )
                if timedOut { return 0 }
                best = max(best, score)
                alpha = max(alpha, score)
                if alpha >= beta { break }
            }
            return best
        }
    }

    /// 관점 진영 기준 점수: 기물 가치 + 간단한 위치 점수
    static func evaluate(board: Board, for side: Side) -> Int {
        var score = 0 // 체스 진영 기준
        for sq in 0..<SquareUtil.count {
            guard let piece = board[sq] else { continue }
            let f = SquareUtil.file(sq), r = SquareUtil.rank(sq)
            let centerFile = 4 - abs(f - 4) // 0(가장자리)…4(가운데)
            var v = piece.kind.value
            switch piece.kind {
            case .pawn:
                // 전진할수록, 특히 승급이 가까울수록 값지다
                v += (r - 1) * 8 + (r >= 6 ? (r - 5) * 25 : 0)
            case .knight, .bishop:
                v += centerFile * 4 + (r > 0 ? 10 : 0)
            case .soldier:
                v += (6 - r) * 6 + centerFile * 2
            case .horse, .elephant:
                v += centerFile * 3 + (r < 9 ? 8 : 0)
            case .king:
                // 초·중반에는 뒷줄에 머무는 편이 안전하다
                v -= r * 6
            default:
                break
            }
            score += piece.side == .chess ? v : -v
        }
        return side == .chess ? score : -score
    }
}
