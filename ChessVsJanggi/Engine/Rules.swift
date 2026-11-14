import Foundation

/// 체스 vs 장기 규칙 엔진.
///
/// 규칙 요약 (자세한 내용은 RULES.md):
/// - 장기판(9×10 교차점)에서 둔다. 궁성은 장기 진영 쪽에만 있다
/// - 체스 기물은 체스 규칙대로, 장기 기물은 장기 규칙대로 움직인다
/// - 폰: 첫 수 두 칸 가능, 대각선 앞으로 잡기, 끝줄에서 승급. 앙파상 없음
/// - 캐슬링 가능 (킹은 가운데 e줄에서 두 칸, 룩은 a줄과 h줄)
/// - 포는 체스 기물도 다리로 쓸 수 있다. 포끼리는 넘지 못한다
/// - 자기 킹/궁을 체크(장군) 상태로 두는 수는 둘 수 없다. 빅장·한수쉼 없음
enum Rules {

    // MARK: - 공격 판정

    /// `side`가 `target` 칸을 잡을 수 있는가 (체크/장군 판정용)
    static func isAttacked(_ target: Square, by side: Side, on board: Board) -> Bool {
        side == .chess
            ? isAttackedByChess(target, on: board)
            : isAttackedByJanggi(target, on: board)
    }

    private static func isAttackedByChess(_ target: Square, on board: Board) -> Bool {
        let tf = SquareUtil.file(target)
        let tr = SquareUtil.rank(target)

        // 폰: 한 줄 아래 대각선에서 올라오며 잡는다
        if board.piece(file: tf - 1, rank: tr - 1)?.kind == .pawn
            || board.piece(file: tf + 1, rank: tr - 1)?.kind == .pawn { return true }

        for (df, dr) in SquareUtil.knightJumps where board.piece(file: tf + df, rank: tr + dr)?.kind == .knight {
            return true
        }
        for (df, dr) in SquareUtil.allDirections where board.piece(file: tf + df, rank: tr + dr)?.kind == .king {
            return true
        }

        // 퀸 · 룩 · 비숍
        for (df, dr) in SquareUtil.allDirections {
            let slider: PieceKind = (df == 0 || dr == 0) ? .rook : .bishop
            var f = tf + df, r = tr + dr
            while SquareUtil.isValid(file: f, rank: r) {
                if let p = board.piece(file: f, rank: r) {
                    if p.kind == .queen || p.kind == slider { return true }
                    break
                }
                f += df
                r += dr
            }
        }
        return false
    }

    private static func isAttackedByJanggi(_ target: Square, on board: Board) -> Bool {
        let tf = SquareUtil.file(target)
        let tr = SquareUtil.rank(target)

        func has(_ f: Int, _ r: Int, _ kind: PieceKind) -> Bool {
            board.piece(file: f, rank: r)?.kind == kind
        }
        func isEmpty(_ f: Int, _ r: Int) -> Bool {
            SquareUtil.isValid(file: f, rank: r) && board.piece(file: f, rank: r) == nil
        }

        // 차 · 포: 직선 및 궁성 대각선
        for (df, dr) in SquareUtil.allDirections {
            let isDiagonal = df != 0 && dr != 0
            var f = tf, r = tr
            var screenFound = false
            while true {
                if isDiagonal {
                    guard SquareUtil.hasPalaceDiagonal(file: f, rank: r, df: df, dr: dr) else { break }
                }
                f += df
                r += dr
                guard SquareUtil.isValid(file: f, rank: r) else { break }
                guard let p = board.piece(file: f, rank: r) else { continue }
                if !screenFound {
                    if p.kind == .chariot { return true }
                    // 포는 포를 넘을 수 없다
                    if p.kind == .cannon { break }
                    screenFound = true
                } else {
                    if p.kind == .cannon { return true }
                    break
                }
            }
        }

        // 마: 공격하는 마는 T - (2o + p), 멱 자리는 T - o - p
        for (ox, oy) in SquareUtil.orthogonal {
            for s in [-1, 1] {
                let px = ox == 0 ? s : 0, py = oy == 0 ? s : 0
                if has(tf - 2 * ox - px, tr - 2 * oy - py, .horse),
                   isEmpty(tf - ox - px, tr - oy - py) { return true }
            }
        }

        // 상: 공격하는 상은 T - (3o + 2p), 멱 자리는 T - 2o - 2p 와 T - o - p
        for (ox, oy) in SquareUtil.orthogonal {
            for s in [-1, 1] {
                let px = ox == 0 ? s : 0, py = oy == 0 ? s : 0
                if has(tf - 3 * ox - 2 * px, tr - 3 * oy - 2 * py, .elephant),
                   isEmpty(tf - 2 * ox - 2 * px, tr - 2 * oy - 2 * py),
                   isEmpty(tf - ox - px, tr - oy - py) { return true }
            }
        }

        // 졸: 뒤(위쪽)에서 전진, 옆에서 옆걸음
        if has(tf, tr + 1, .soldier) || has(tf - 1, tr, .soldier) || has(tf + 1, tr, .soldier) {
            return true
        }

        // 궁 · 사: 궁성 안에서 선을 따라 한 칸
        if SquareUtil.isInPalace(target) {
            for (df, dr) in SquareUtil.allDirections {
                let sf = tf - df, sr = tr - dr
                guard SquareUtil.isInPalace(file: sf, rank: sr),
                      let p = board.piece(file: sf, rank: sr),
                      p.kind == .general || p.kind == .advisor else { continue }
                if df == 0 || dr == 0 || SquareUtil.hasPalaceDiagonal(file: sf, rank: sr, df: df, dr: dr) {
                    return true
                }
            }
        }
        return false
    }

    /// 체크(장군) 상태인가
    static func isInCheck(_ side: Side, on board: Board) -> Bool {
        guard let royal = board.royalSquare(of: side) else { return false }
        return isAttacked(royal, by: side.opposite, on: board)
    }

    // MARK: - 수 생성

    /// 합법수: 의사 합법수 중 자기 킹/궁이 체크 상태로 남지 않는 수
    static func legalMoves(for side: Side, on board: Board) -> [Move] {
        var moves: [Move] = []
        moves.reserveCapacity(64)
        for (sq, piece) in board.pieces(of: side) {
            appendPseudoMoves(for: piece, at: sq, on: board, into: &moves)
        }
        return moves.filter { !isInCheck(side, on: board.applying($0)) }
    }

    /// 한 기물의 의사 합법수 (체크 여부 미확인)
    static func appendPseudoMoves(for piece: Piece, at sq: Square, on board: Board, into moves: inout [Move]) {
        let f = SquareUtil.file(sq)
        let r = SquareUtil.rank(sq)
        let side = piece.side

        func canLand(_ nf: Int, _ nr: Int) -> Bool {
            guard SquareUtil.isValid(file: nf, rank: nr) else { return false }
            return board.piece(file: nf, rank: nr)?.side != side
        }
        func add(_ nf: Int, _ nr: Int) {
            moves.append(Move(from: sq, to: SquareUtil.make(file: nf, rank: nr)))
        }
        func isEmpty(_ nf: Int, _ nr: Int) -> Bool {
            SquareUtil.isValid(file: nf, rank: nr) && board.piece(file: nf, rank: nr) == nil
        }
        func isEnemy(_ nf: Int, _ nr: Int) -> Bool {
            guard let p = board.piece(file: nf, rank: nr) else { return false }
            return p.side != side
        }
        /// 막힐 때까지 직선으로 (퀸·룩·비숍)
        func slide(_ directions: [(Int, Int)]) {
            for (df, dr) in directions {
                var nf = f + df, nr = r + dr
                while SquareUtil.isValid(file: nf, rank: nr) {
                    if let occupant = board.piece(file: nf, rank: nr) {
                        if occupant.side != side { add(nf, nr) }
                        break
                    }
                    add(nf, nr)
                    nf += df
                    nr += dr
                }
            }
        }

        switch piece.kind {

        // MARK: 체스

        case .king:
            for (df, dr) in SquareUtil.allDirections where canLand(f + df, r + dr) {
                add(f + df, r + dr)
            }
            appendCastling(from: sq, on: board, into: &moves)

        case .queen:
            slide(SquareUtil.allDirections)
        case .rook:
            slide(SquareUtil.orthogonal)
        case .bishop:
            slide(SquareUtil.diagonal)

        case .knight:
            for (df, dr) in SquareUtil.knightJumps where canLand(f + df, r + dr) {
                add(f + df, r + dr)
            }

        case .pawn:
            func addPawnMove(_ nf: Int, _ nr: Int) {
                let to = SquareUtil.make(file: nf, rank: nr)
                if nr == SquareUtil.promotionRank {
                    for kind in PieceKind.promotions {
                        moves.append(Move(from: sq, to: to, promotion: kind))
                    }
                } else {
                    moves.append(Move(from: sq, to: to))
                }
            }
            if isEmpty(f, r + 1) {
                addPawnMove(f, r + 1)
                if r == SquareUtil.pawnHomeRank, isEmpty(f, r + 2) { addPawnMove(f, r + 2) }
            }
            for df in [-1, 1] where isEnemy(f + df, r + 1) {
                addPawnMove(f + df, r + 1)
            }

        // MARK: 장기

        case .general, .advisor:
            // 궁성 안에서 선을 따라 한 칸
            for (df, dr) in SquareUtil.allDirections {
                let nf = f + df, nr = r + dr
                guard SquareUtil.isInPalace(file: nf, rank: nr) else { continue }
                if df != 0 && dr != 0 && !SquareUtil.hasPalaceDiagonal(file: f, rank: r, df: df, dr: dr) { continue }
                if canLand(nf, nr) { add(nf, nr) }
            }

        case .chariot, .cannon:
            for (df, dr) in SquareUtil.allDirections {
                let isDiagonal = df != 0 && dr != 0
                var nf = f, nr = r
                var screenFound = false
                while true {
                    if isDiagonal {
                        guard SquareUtil.hasPalaceDiagonal(file: nf, rank: nr, df: df, dr: dr) else { break }
                    }
                    nf += df
                    nr += dr
                    guard SquareUtil.isValid(file: nf, rank: nr) else { break }
                    let occupant = board.piece(file: nf, rank: nr)

                    if piece.kind == .chariot {
                        if let occupant {
                            if occupant.side != side { add(nf, nr) }
                            break
                        }
                        add(nf, nr)
                    } else if !screenFound {
                        // 포: 넘을 기물(포가 아닌)을 찾을 때까지 이동 불가
                        guard let occupant else { continue }
                        if occupant.kind == .cannon { break }
                        screenFound = true
                    } else {
                        if let occupant {
                            if occupant.side != side { add(nf, nr) }
                            break
                        }
                        add(nf, nr)
                    }
                }
            }

        case .horse:
            // 직선 한 칸(멱) → 대각 한 칸
            for (ox, oy) in SquareUtil.orthogonal where isEmpty(f + ox, r + oy) {
                for s in [-1, 1] {
                    let px = ox == 0 ? s : 0, py = oy == 0 ? s : 0
                    let nf = f + 2 * ox + px, nr = r + 2 * oy + py
                    if canLand(nf, nr) { add(nf, nr) }
                }
            }

        case .elephant:
            // 직선 한 칸(멱) → 대각 두 칸 (중간 멱 포함)
            for (ox, oy) in SquareUtil.orthogonal where isEmpty(f + ox, r + oy) {
                for s in [-1, 1] {
                    let px = ox == 0 ? s : 0, py = oy == 0 ? s : 0
                    guard isEmpty(f + 2 * ox + px, r + 2 * oy + py) else { continue }
                    let nf = f + 3 * ox + 2 * px, nr = r + 3 * oy + 2 * py
                    if canLand(nf, nr) { add(nf, nr) }
                }
            }

        case .soldier:
            // 앞(아래쪽)이나 옆으로 한 칸
            for (df, dr) in [(0, -1), (-1, 0), (1, 0)] where canLand(f + df, r + dr) {
                add(f + df, r + dr)
            }
        }
    }

    /// 캐슬링: 킹과 룩이 움직인 적 없고, 사이가 비었고, 킹이 체크가 아니며 지나는 칸이 공격받지 않을 때.
    /// (도착 칸이 공격받는지는 합법수 필터가 걸러 준다)
    private static func appendCastling(from sq: Square, on board: Board, into moves: inout [Move]) {
        guard sq == SquareUtil.kingHome,
              board.canCastleKingside || board.canCastleQueenside,
              !isAttacked(sq, by: .janggi, on: board) else { return }

        func isEmpty(_ files: ClosedRange<Int>) -> Bool {
            files.allSatisfy { board.piece(file: $0, rank: 0) == nil }
        }
        if board.canCastleKingside,
           board[SquareUtil.kingsideRookHome]?.kind == .rook,
           isEmpty(5...6),
           !isAttacked(SquareUtil.make(file: 5, rank: 0), by: .janggi, on: board) {
            moves.append(Move(from: sq, to: SquareUtil.make(file: 6, rank: 0)))
        }
        if board.canCastleQueenside,
           board[SquareUtil.queensideRookHome]?.kind == .rook,
           isEmpty(1...3),
           !isAttacked(SquareUtil.make(file: 3, rank: 0), by: .janggi, on: board) {
            moves.append(Move(from: sq, to: SquareUtil.make(file: 2, rank: 0)))
        }
    }
}
