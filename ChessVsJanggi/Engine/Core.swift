import Foundation

// MARK: - 기본 타입

/// 진영. 체스는 데이터상 아래쪽(rank 0~1)에서 위로, 장기는 위쪽(rank 6~9)에서 아래로 진행한다.
enum Side: String, Codable, Hashable, CaseIterable {
    case chess, janggi

    var opposite: Side { self == .chess ? .janggi : .chess }

    /// 폰/졸의 전진 방향 (rank 증감)
    var forward: Int { self == .chess ? 1 : -1 }
}

/// 기물 종류. 종류가 곧 진영을 결정한다 (체스 6종 + 장기 7종).
enum PieceKind: String, Codable, Hashable, CaseIterable {
    case king, queen, rook, bishop, knight, pawn
    case general, chariot, cannon, horse, elephant, advisor, soldier

    var side: Side {
        switch self {
        case .king, .queen, .rook, .bishop, .knight, .pawn: return .chess
        case .general, .chariot, .cannon, .horse, .elephant, .advisor, .soldier: return .janggi
        }
    }

    var isRoyal: Bool { self == .king || self == .general }

    /// AI 평가·기물 점수 표시용 가치 (폰 = 100)
    var value: Int {
        switch self {
        case .king, .general: return 0
        case .queen: return 900
        case .rook: return 500
        case .bishop: return 330
        case .knight: return 300
        case .pawn: return 100
        case .chariot: return 500
        case .cannon: return 300
        case .horse: return 260
        case .elephant: return 170
        case .advisor: return 130
        case .soldier: return 110
        }
    }

    /// 폰이 승급할 수 있는 기물
    static let promotions: [PieceKind] = [.queen, .knight, .rook, .bishop]
}

struct Piece: Hashable, Codable {
    let kind: PieceKind

    init(_ kind: PieceKind) { self.kind = kind }

    var side: Side { kind.side }

    /// 말에 그리는 글자. 체스는 유니코드 기물(텍스트 표시 강제), 장기는 한자.
    var glyph: String {
        switch kind {
        case .king: return "\u{265A}\u{FE0E}"
        case .queen: return "\u{265B}\u{FE0E}"
        case .rook: return "\u{265C}\u{FE0E}"
        case .bishop: return "\u{265D}\u{FE0E}"
        case .knight: return "\u{265E}\u{FE0E}"
        case .pawn: return "\u{265F}\u{FE0E}"
        case .general: return "漢"
        case .chariot: return "車"
        case .cannon: return "包"
        case .horse: return "馬"
        case .elephant: return "象"
        case .advisor: return "士"
        case .soldier: return "兵"
        }
    }
}

/// 0..<90. file = sq % 9 (체스 진영에서 볼 때 왼쪽=0), rank = sq / 9 (체스 진영 끝줄 = 0)
typealias Square = Int

enum SquareUtil {
    static let files = 9
    static let ranks = 10
    static let count = files * ranks

    static func make(file: Int, rank: Int) -> Square { rank * files + file }
    static func file(_ sq: Square) -> Int { sq % files }
    static func rank(_ sq: Square) -> Int { sq / files }
    static func isValid(file: Int, rank: Int) -> Bool {
        file >= 0 && file < files && rank >= 0 && rank < ranks
    }

    // MARK: 궁성 — 장기 진영 쪽에만 있다 (file 3~5, rank 7~9)

    static func isInPalace(file: Int, rank: Int) -> Bool {
        file >= 3 && file <= 5 && rank >= 7 && rank <= 9
    }

    static func isInPalace(_ sq: Square) -> Bool {
        isInPalace(file: file(sq), rank: rank(sq))
    }

    static func isPalaceCenter(file: Int, rank: Int) -> Bool {
        file == 4 && rank == 8
    }

    /// (file, rank)에서 (df, dr) 대각 방향으로 궁성 대각선이 이어져 있는가.
    /// 궁성 대각선은 네 귀퉁이와 중앙을 잇는 선뿐이다.
    static func hasPalaceDiagonal(file: Int, rank: Int, df: Int, dr: Int) -> Bool {
        let nf = file + df, nr = rank + dr
        guard isInPalace(file: file, rank: rank), isInPalace(file: nf, rank: nr) else { return false }
        return isPalaceCenter(file: file, rank: rank) || isPalaceCenter(file: nf, rank: nr)
    }

    static let orthogonal = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    static let diagonal = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    static let allDirections = orthogonal + diagonal
    static let knightJumps = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]

    // 체스 진영의 고정 칸
    static let kingHome = make(file: 4, rank: 0)
    static let queensideRookHome = make(file: 0, rank: 0)
    static let kingsideRookHome = make(file: 7, rank: 0)
    static let pawnHomeRank = 1
    static let promotionRank = ranks - 1
}

struct Move: Hashable, Codable {
    let from: Square
    let to: Square
    /// 폰이 끝줄에 닿을 때 승급할 기물 (그 외에는 nil)
    var promotion: PieceKind? = nil

    init(from: Square, to: Square, promotion: PieceKind? = nil) {
        self.from = from
        self.to = to
        self.promotion = promotion
    }
}

// MARK: - 보드

struct Board: Hashable {
    /// 90칸. nil = 빈 칸
    private(set) var cells: [Piece?]
    /// 캐슬링 권리 (킹과 해당 룩이 한 번도 움직이지 않았는가)
    private(set) var canCastleKingside: Bool
    private(set) var canCastleQueenside: Bool

    init(cells: [Piece?], canCastleKingside: Bool = false, canCastleQueenside: Bool = false) {
        precondition(cells.count == SquareUtil.count)
        self.cells = cells
        self.canCastleKingside = canCastleKingside
        self.canCastleQueenside = canCastleQueenside
    }

    static func empty() -> Board {
        Board(cells: [Piece?](repeating: nil, count: SquareUtil.count))
    }

    /// 초기 배치.
    /// - 체스(아래): 뒷줄 왼쪽부터 룩·나이트·비숍·퀸·킹·비숍·나이트·룩(오른쪽 끝 칸은 비움), 그 앞줄에 폰 9개.
    ///   킹이 가운데 줄에 서서 장기의 궁과 마주 본다.
    /// - 장기(위): 표준 배치(마상상마)에 지원군을 더한 대군 — 졸 9개, 포 줄에 차 3대 추가(차 모두 5대).
    ///   표준 장기 그대로는 체스가 일방적으로 이겨서 자가대국으로 맞춘 편성이다 (RULES.md 참고).
    static func initial() -> Board {
        var board = Board.empty()
        let chessBack: [PieceKind?] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook, nil]
        for (file, kind) in chessBack.enumerated() {
            if let kind { board[SquareUtil.make(file: file, rank: 0)] = Piece(kind) }
        }
        for file in 0..<SquareUtil.files {
            board[SquareUtil.make(file: file, rank: 1)] = Piece(.pawn)
        }

        let janggiBack: [PieceKind?] = [.chariot, .horse, .elephant, .advisor, nil, .advisor, .elephant, .horse, .chariot]
        let janggiFront: [PieceKind?] = [.chariot, .cannon, nil, nil, .chariot, nil, nil, .cannon, .chariot]
        for file in 0..<SquareUtil.files {
            if let kind = janggiBack[file] { board[SquareUtil.make(file: file, rank: 9)] = Piece(kind) }
            if let kind = janggiFront[file] { board[SquareUtil.make(file: file, rank: 7)] = Piece(kind) }
            board[SquareUtil.make(file: file, rank: 6)] = Piece(.soldier)
        }
        board[SquareUtil.make(file: 4, rank: 8)] = Piece(.general)
        board.canCastleKingside = true
        board.canCastleQueenside = true
        return board
    }

    /// 테스트 등 임의 배치를 위한 생성자. (file, rank, 기물) 목록. 캐슬링 권리는 없다.
    static func custom(_ placements: [(Int, Int, PieceKind)], castling: Bool = false) -> Board {
        var board = Board.empty()
        for (file, rank, kind) in placements {
            board[SquareUtil.make(file: file, rank: rank)] = Piece(kind)
        }
        board.canCastleKingside = castling
        board.canCastleQueenside = castling
        return board
    }

    subscript(_ sq: Square) -> Piece? {
        get { cells[sq] }
        set { cells[sq] = newValue }
    }

    func piece(file: Int, rank: Int) -> Piece? {
        guard SquareUtil.isValid(file: file, rank: rank) else { return nil }
        return cells[SquareUtil.make(file: file, rank: rank)]
    }

    func pieces(of side: Side) -> [(Square, Piece)] {
        var result: [(Square, Piece)] = []
        result.reserveCapacity(18)
        for sq in 0..<SquareUtil.count {
            if let p = cells[sq], p.side == side { result.append((sq, p)) }
        }
        return result
    }

    /// 킹(체스) 또는 궁(장기)의 위치
    func royalSquare(of side: Side) -> Square? {
        let kind: PieceKind = side == .chess ? .king : .general
        for sq in 0..<SquareUtil.count where cells[sq]?.kind == kind { return sq }
        return nil
    }

    func material(of side: Side) -> Int {
        var total = 0
        for p in cells {
            if let p, p.side == side { total += p.kind.value }
        }
        return total
    }

    /// 캐슬링인가 (킹이 가로로 두 칸 이동)
    func isCastling(_ move: Move) -> Bool {
        cells[move.from]?.kind == .king && abs(SquareUtil.file(move.to) - SquareUtil.file(move.from)) == 2
    }

    mutating func apply(_ move: Move) {
        guard let piece = cells[move.from] else { return }

        if piece.kind == .king {
            if isCastling(move) {
                let kingside = SquareUtil.file(move.to) > SquareUtil.file(move.from)
                let rookFrom = kingside ? SquareUtil.kingsideRookHome : SquareUtil.queensideRookHome
                let rookTo = SquareUtil.make(file: kingside ? 5 : 3, rank: 0)
                cells[rookTo] = cells[rookFrom]
                cells[rookFrom] = nil
            }
            canCastleKingside = false
            canCastleQueenside = false
        }
        // 룩이 움직이거나 잡히면 그쪽 캐슬링 권리가 사라진다
        if move.from == SquareUtil.kingsideRookHome || move.to == SquareUtil.kingsideRookHome {
            canCastleKingside = false
        }
        if move.from == SquareUtil.queensideRookHome || move.to == SquareUtil.queensideRookHome {
            canCastleQueenside = false
        }

        cells[move.to] = move.promotion.map { Piece($0) } ?? piece
        cells[move.from] = nil
    }

    func applying(_ move: Move) -> Board {
        var b = self
        b.apply(move)
        return b
    }

    /// 동형 반복 판정용 위치 키
    func positionKey(sideToMove: Side) -> String {
        var chars: [Character] = [
            sideToMove == .chess ? "w" : "j",
            canCastleKingside ? "K" : "-",
            canCastleQueenside ? "Q" : "-",
        ]
        chars.reserveCapacity(SquareUtil.count + 3)
        for p in cells {
            guard let p else { chars.append("."); continue }
            let c: Character
            switch p.kind {
            case .king: c = "K"
            case .queen: c = "Q"
            case .rook: c = "R"
            case .bishop: c = "B"
            case .knight: c = "N"
            case .pawn: c = "P"
            case .general: c = "g"
            case .chariot: c = "r"
            case .cannon: c = "c"
            case .horse: c = "h"
            case .elephant: c = "e"
            case .advisor: c = "a"
            case .soldier: c = "s"
            }
            chars.append(c)
        }
        return String(chars)
    }
}
