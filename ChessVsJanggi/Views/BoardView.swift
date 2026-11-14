import SwiftUI

/// 장기판 렌더링 + 터치 입력.
/// 기물은 선의 교차점에 놓인다. `bottomSide` 진영이 화면 아래쪽에 오도록 판 전체를 180° 돌려 그린다.
struct BoardView: View {
    let board: Board
    let lastMove: Move?
    let selected: Square?
    let targets: Set<Square>
    /// 체크(장군)당한 킹/궁의 칸
    var checkedSquare: Square? = nil
    /// 화면 아래쪽에 놓일 진영
    var bottomSide: Side = .chess
    let onTap: (Square) -> Void

    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(SquareUtil.files)
            ZStack(alignment: .topLeading) {
                BoardLines(palaceAtTop: bottomSide == .chess)
                    .stroke(Theme.boardLine, lineWidth: 1)
                    .frame(width: geo.size.width, height: cell * CGFloat(SquareUtil.ranks))

                ForEach(0..<SquareUtil.count, id: \.self) { sq in
                    let point = position(of: sq)
                    pointView(sq, cell: cell)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(point.col) * cell, y: CGFloat(point.row) * cell)
                }
            }
        }
        .aspectRatio(CGFloat(SquareUtil.files) / CGFloat(SquareUtil.ranks), contentMode: .fit)
        .background(Theme.board)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: 2)
        )
    }

    /// 데이터 좌표 → 화면 (열, 행). 행 0이 화면 맨 위.
    private func position(of sq: Square) -> (col: Int, row: Int) {
        let f = SquareUtil.file(sq), r = SquareUtil.rank(sq)
        // 데이터상 체스는 아래쪽(rank 0). 장기가 아래로 오려면 180° 회전
        return bottomSide == .chess ? (f, SquareUtil.ranks - 1 - r) : (SquareUtil.files - 1 - f, r)
    }

    @ViewBuilder
    private func pointView(_ sq: Square, cell: CGFloat) -> some View {
        let isLast = lastMove?.from == sq || lastMove?.to == sq
        let piece = board[sq]

        ZStack {
            Color.clear
            if isLast {
                Circle()
                    .fill(Theme.boardLastMove)
                    .frame(width: cell * 0.9, height: cell * 0.9)
            }
            if selected == sq {
                Circle()
                    .fill(Theme.boardSelected)
                    .frame(width: cell * 1.0, height: cell * 1.0)
            }
            if checkedSquare == sq {
                Circle()
                    .fill(Theme.accent.opacity(0.55))
                    .frame(width: cell * 1.0, height: cell * 1.0)
            }
            if let piece {
                PieceView(piece: piece, cell: cell)
            }
            if targets.contains(sq) {
                if piece != nil {
                    // 캡처 타깃: 링
                    Circle()
                        .strokeBorder(Theme.accent, lineWidth: cell * 0.08)
                        .frame(width: cell * 0.98, height: cell * 0.98)
                } else {
                    Circle()
                        .fill(Theme.ink.opacity(0.45))
                        .frame(width: cell * 0.26, height: cell * 0.26)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap(sq) }
        .accessibilityElement()
        .accessibilityLabel(piece.map { "\($0.side.localizedName) \($0.kind.localizedName)" } ?? "")
        .accessibilityValue(accessibilityState(of: sq))
        .accessibilityIdentifier("pt-\(sq)")
        .accessibilityAddTraits(.isButton)
    }

    /// VoiceOver·UI 테스트용 상태: 선택됨 / 갈 수 있음
    private func accessibilityState(of sq: Square) -> String {
        if targets.contains(sq) { return String(localized: "갈 수 있음") }
        if selected == sq { return String(localized: "선택됨") }
        return ""
    }
}

/// 가로 10줄 · 세로 9줄 + 장기 진영 쪽 궁성 대각선.
struct BoardLines: Shape {
    /// 궁성이 화면 위쪽인가 (체스가 아래일 때)
    let palaceAtTop: Bool

    func path(in rect: CGRect) -> Path {
        let cell = rect.width / CGFloat(SquareUtil.files)
        func pt(_ col: Int, _ row: Int) -> CGPoint {
            CGPoint(x: (CGFloat(col) + 0.5) * cell, y: (CGFloat(row) + 0.5) * cell)
        }
        var path = Path()
        for col in 0..<SquareUtil.files {
            path.move(to: pt(col, 0))
            path.addLine(to: pt(col, SquareUtil.ranks - 1))
        }
        for row in 0..<SquareUtil.ranks {
            path.move(to: pt(0, row))
            path.addLine(to: pt(SquareUtil.files - 1, row))
        }
        let top = palaceAtTop ? 0 : SquareUtil.ranks - 3
        path.move(to: pt(3, top))
        path.addLine(to: pt(5, top + 2))
        path.move(to: pt(5, top))
        path.addLine(to: pt(3, top + 2))
        return path
    }
}

/// 기물 한 개. 장기는 팔각형 알에 한자, 체스는 먹색 원판에 체스 기호.
struct PieceView: View {
    let piece: Piece
    let cell: CGFloat

    private var scale: CGFloat {
        switch piece.kind {
        case .general, .king, .queen: return 0.94
        case .chariot, .cannon, .horse, .elephant, .rook, .bishop, .knight: return 0.84
        case .advisor, .soldier, .pawn: return 0.70
        }
    }

    var body: some View {
        let d = cell * scale
        Group {
            if piece.side == .janggi {
                ZStack {
                    Octagon().fill(Theme.pieceFace)
                    Octagon().stroke(Theme.janggi, lineWidth: max(1.2, d * 0.06))
                    Octagon()
                        .stroke(Theme.janggi.opacity(0.35), lineWidth: 0.8)
                        .padding(d * 0.1)
                    Text(piece.glyph)
                        .font(.system(size: d * 0.54, weight: .heavy, design: .serif))
                        .foregroundStyle(Theme.janggi)
                        .minimumScaleFactor(0.5)
                }
            } else {
                ZStack {
                    Circle().fill(Theme.chess)
                    Circle()
                        .stroke(Theme.pieceFace.opacity(0.45), lineWidth: 0.8)
                        .padding(d * 0.08)
                    Text(piece.glyph)
                        .font(.system(size: d * 0.66))
                        .foregroundStyle(Theme.pieceFace)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .frame(width: d, height: d)
        .shadow(color: Theme.ink.opacity(0.28), radius: 0, x: 0, y: max(1, d * 0.04))
    }
}

struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let cut = s / (2 + 2.squareRoot())
        let x = rect.midX - s / 2, y = rect.midY - s / 2
        var path = Path()
        path.move(to: CGPoint(x: x + cut, y: y))
        path.addLine(to: CGPoint(x: x + s - cut, y: y))
        path.addLine(to: CGPoint(x: x + s, y: y + cut))
        path.addLine(to: CGPoint(x: x + s, y: y + s - cut))
        path.addLine(to: CGPoint(x: x + s - cut, y: y + s))
        path.addLine(to: CGPoint(x: x + cut, y: y + s))
        path.addLine(to: CGPoint(x: x, y: y + s - cut))
        path.addLine(to: CGPoint(x: x, y: y + cut))
        path.closeSubpath()
        return path
    }
}
