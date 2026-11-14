import SwiftUI

enum GameMode: Hashable {
    /// 컴퓨터 대전 — 난이도와 내가 둘 진영
    case vsBot(BotLevel, Side)
    /// 온라인 대전 — 연관값은 내가 둘 진영 (방장이 고르거나 서버가 배정)
    case online(Side)

    var title: String {
        switch self {
        case .vsBot(let level, _): return String(localized: "컴퓨터 대전 · \(level.localizedName)")
        case .online: return String(localized: "온라인 대전")
        }
    }
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published var game = Game()
    @Published var selected: Square?
    @Published var isBotThinking = false
    @Published var opponentLeft = false
    /// 승급할 기물을 고르는 중인 폰의 이동 (from, to)
    @Published var pendingPromotion: Move?
    /// 무르기용 이전 상태
    @Published private(set) var history: [Game] = []

    let mode: GameMode
    /// 사람이 조종하는 진영
    let humanSide: Side
    private let client: RoomClient?
    /// 무르기·재시작 후 늦게 도착한 AI 응수를 버리기 위한 토큰
    private var botToken = UUID()

    init(mode: GameMode, client: RoomClient? = nil) {
        self.mode = mode
        self.client = client
        switch mode {
        case .vsBot(_, let side), .online(let side): self.humanSide = side
        }
        client?.onRemoteMove = { [weak self] move in
            self?.applyRemote(move)
        }
        client?.onOpponentLeft = { [weak self] in
            self?.opponentLeft = true
        }
    }

    var botLevel: BotLevel? {
        if case .vsBot(let level, _) = mode { return level }
        return nil
    }

    var isOnline: Bool {
        if case .online = mode { return true }
        return false
    }

    /// 화면 아래쪽 진영 — 항상 내 진영
    var bottomSide: Side { humanSide }

    var isHumanTurn: Bool {
        !game.isFinished && !opponentLeft && game.sideToMove == humanSide
    }

    var canUndo: Bool {
        guard !isOnline, !isBotThinking else { return false }
        return history.contains { $0.sideToMove == humanSide }
    }

    var targets: Set<Square> {
        guard let sel = selected else { return [] }
        return Set(game.legalMoves(from: sel).map(\.to))
    }

    /// 체크(장군)당한 킹/궁의 칸
    var checkedSquare: Square? {
        guard game.isInCheck else { return nil }
        return game.board.royalSquare(of: game.sideToMove)
    }

    /// 이 진영이 잡은 상대 기물 (값진 순)
    func captures(by side: Side) -> [Piece] {
        game.captured.filter { $0.side != side }.sorted { $0.kind.value > $1.kind.value }
    }

    func handleTap(_ sq: Square) {
        guard isHumanTurn, pendingPromotion == nil else { return }

        if let sel = selected {
            let moves = game.legalMoves(from: sel).filter { $0.to == sq }
            if let move = moves.first {
                selected = nil
                if move.promotion != nil {
                    // 승급: 어떤 기물로 바꿀지 묻는다
                    pendingPromotion = Move(from: move.from, to: move.to)
                    Haptics.tap()
                } else {
                    perform(move)
                }
                return
            }
        }

        if let piece = game.board[sq], piece.side == game.sideToMove,
           !game.legalMoves(from: sq).isEmpty {
            selected = (selected == sq) ? nil : sq
            Haptics.tap()
        } else {
            selected = nil
        }
    }

    func choosePromotion(_ kind: PieceKind?) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        if let kind {
            perform(Move(from: pending.from, to: pending.to, promotion: kind))
        }
    }

    private func perform(_ move: Move, fromRemote: Bool = false) {
        let before = game
        let isCapture = game.board[move.to] != nil
        guard game.play(move) else { return }
        history.append(before)
        isCapture ? Haptics.capture() : Haptics.move()

        if isOnline && !fromRemote {
            client?.send(move: move)
        }

        if game.isFinished {
            announceResult()
        } else {
            scheduleBotIfNeeded()
        }
    }

    /// 온라인 상대의 무브 적용
    func applyRemote(_ move: Move) {
        guard isOnline, game.sideToMove != humanSide else { return }
        perform(move, fromRemote: true)
    }

    /// 컴퓨터 차례이면 응수를 계산해 둔다. 화면이 뜰 때(컴퓨터가 선공인 경우)와 매 수 뒤에 부른다.
    func scheduleBotIfNeeded() {
        guard let level = botLevel, !game.isFinished, game.sideToMove != humanSide, !isBotThinking else { return }
        isBotThinking = true
        let snapshot = game
        let token = UUID()
        botToken = token
        Task.detached(priority: .userInitiated) {
            let started = Date()
            let move = Bot.bestMove(in: snapshot, level: level)
            // 최소한의 "생각하는" 연출
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < 0.45 {
                try? await Task.sleep(nanoseconds: UInt64((0.45 - elapsed) * 1_000_000_000))
            }
            await MainActor.run { [weak self] in
                guard let self, self.botToken == token else { return }
                self.isBotThinking = false
                if let move, !self.game.isFinished { self.perform(move) }
            }
        }
    }

    /// 한 수 무르기 — 내 차례가 될 때까지 되돌린다.
    func undo() {
        guard canUndo else { return }
        botToken = UUID()
        isBotThinking = false
        selected = nil
        pendingPromotion = nil
        while let previous = history.popLast() {
            game = previous
            if previous.sideToMove == humanSide { break }
        }
        Haptics.tap()
    }

    private func announceResult() {
        guard case .win(let winner, _)? = game.result else { return }
        winner == humanSide ? Haptics.success() : Haptics.failure()
    }

    func restart() {
        botToken = UUID()
        game = Game()
        history = []
        selected = nil
        pendingPromotion = nil
        isBotThinking = false
        scheduleBotIfNeeded()
    }
}

struct GameScreen: View {
    @StateObject private var model: GameViewModel
    @Environment(\.dismiss) private var dismiss

    init(mode: GameMode) {
        _model = StateObject(wrappedValue: GameViewModel(mode: mode))
    }

    /// 외부에서 구성한 모델로 표시 (온라인 대전)
    init(model: GameViewModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 12) {
                playerPanel(for: model.bottomSide.opposite)

                BoardView(
                    board: model.game.board,
                    lastMove: model.game.lastMove,
                    selected: model.selected,
                    targets: model.targets,
                    checkedSquare: model.checkedSquare,
                    bottomSide: model.bottomSide,
                    onTap: model.handleTap
                )
                .padding(.horizontal, 14)

                playerPanel(for: model.bottomSide)
                statusBanner
                Spacer(minLength: 0)
            }
            .padding(.top, 8)

            if model.pendingPromotion != nil {
                Theme.ink.opacity(0.25).ignoresSafeArea()
                    .onTapGesture { model.choosePromotion(nil) }
                promotionPicker
            } else if model.game.isFinished {
                Theme.ink.opacity(0.25).ignoresSafeArea()
                resultOverlay
            } else if model.opponentLeft {
                Theme.ink.opacity(0.25).ignoresSafeArea()
                opponentLeftOverlay
            }
        }
        .navigationTitle(model.mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .toolbar {
            if !model.isOnline {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.undo()
                    } label: {
                        Label("무르기", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!model.canUndo)
                }
            }
        }
        .onAppear { model.scheduleBotIfNeeded() }
    }

    // MARK: - 구성 요소

    private func playerPanel(for side: Side) -> some View {
        let isTurn = !model.game.isFinished && model.game.sideToMove == side
        let name: String = {
            if side == model.humanSide { return String(localized: "나 · \(side.localizedName)") }
            return model.isOnline
                ? String(localized: "상대 · \(side.localizedName)")
                : String(localized: "컴퓨터 · \(side.localizedName)")
        }()
        let captures = model.captures(by: side)

        return HStack(spacing: 10) {
            PieceView(piece: Piece(side == .chess ? .king : .general), cell: 28)

            Text(name)
                .font(.system(.subheadline, design: .serif, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .layoutPriority(1)

            if isTurn {
                if model.isBotThinking {
                    Text("생각 중…")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                } else {
                    Circle().fill(Theme.color(for: side)).frame(width: 7, height: 7)
                }
            }
            Spacer(minLength: 4)

            // 이 진영이 잡은 기물
            Text(captures.map(\.glyph).joined())
                .font(.system(size: 15, weight: .bold, design: side == .chess ? .serif : .default))
                .foregroundStyle(Theme.color(for: side.opposite))
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityLabel(String(localized: "잡은 기물 \(captures.count)개"))
        }
        .frame(height: 30)
        .padding(.horizontal, 22)
    }

    private var statusBanner: some View {
        Group {
            if !model.game.isFinished {
                if model.game.isInCheck {
                    bannerLabel(model.game.sideToMove == .chess
                        ? "체크 — 킹을 지켜야 합니다"
                        : "장군 — 궁을 지켜야 합니다")
                } else if model.game.quietHalfMoves >= 60 {
                    bannerLabel("잡거나 폰을 밀지 않고 \(model.game.quietHalfMoves / 2)수 — 50수가 되면 무승부")
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.game.moveCount)
    }

    private func bannerLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .padding(.top, 2)
    }

    private var promotionPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("승급")
                .font(.system(size: 26, weight: .black, design: .serif))
                .foregroundStyle(Theme.ink)
            Rectangle().fill(Theme.accent).frame(width: 44, height: 3)
            Text("폰이 끝줄에 닿았습니다. 바꿀 기물을 고르세요.")
                .font(.system(.subheadline))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                ForEach(PieceKind.promotions, id: \.self) { kind in
                    Button {
                        model.choosePromotion(kind)
                    } label: {
                        PieceView(piece: Piece(kind), cell: 58)
                            .frame(width: 58, height: 58)
                    }
                    .accessibilityLabel(kind.localizedName)
                    .accessibilityIdentifier("promote-\(kind.rawValue)")
                }
            }
            .padding(.top, 4)
        }
        .padding(26)
        .frame(maxWidth: 330, alignment: .leading)
        .panelStyle()
        .padding(24)
    }

    private var resultOverlay: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(resultTitle)
                .font(.system(size: 34, weight: .black, design: .serif))
                .foregroundStyle(Theme.ink)
            Rectangle().fill(Theme.accent).frame(width: 44, height: 3)
            Text(resultDetail)
                .font(.system(.subheadline))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if !model.isOnline {
                    Button("한 판 더") { model.restart() }
                        .buttonStyle(InkButtonStyle(filled: true))
                }
                Button("홈으로") { dismiss() }
                    .buttonStyle(InkButtonStyle(filled: model.isOnline))
            }
            .padding(.top, 8)

            if model.canUndo {
                Button {
                    model.undo()
                } label: {
                    Text("마지막 수 무르기")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .underline()
                }
            }
        }
        .padding(26)
        .frame(maxWidth: 330, alignment: .leading)
        .panelStyle()
        .padding(24)
        .transition(.scale.combined(with: .opacity))
    }

    private var opponentLeftOverlay: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("상대가 나갔습니다")
                .font(.system(size: 26, weight: .black, design: .serif))
                .foregroundStyle(Theme.ink)
            Rectangle().fill(Theme.accent).frame(width: 44, height: 3)
            Text("연결이 끊어져 대국을 계속할 수 없습니다.")
                .font(.system(.subheadline))
                .foregroundStyle(Theme.inkSoft)
            Button("홈으로") { dismiss() }
                .buttonStyle(InkButtonStyle(filled: true))
                .padding(.top, 8)
        }
        .padding(26)
        .frame(maxWidth: 330, alignment: .leading)
        .panelStyle()
        .padding(24)
        .transition(.scale.combined(with: .opacity))
    }

    private var resultTitle: String {
        switch model.game.result {
        case .win(let winner, _):
            return winner == model.humanSide ? String(localized: "승리") : String(localized: "패배")
        case .draw: return String(localized: "무승부")
        case nil: return ""
        }
    }

    private var resultDetail: String {
        switch model.game.result {
        case .win(let winner, .checkmate):
            return winner == .chess
                ? String(localized: "체크메이트 — 체스가 장기의 궁을 잡았습니다.")
                : String(localized: "외통수 — 장기가 체스의 킹을 잡았습니다.")
        case .draw(let reason):
            switch reason {
            case .stalemate:
                return String(localized: "둘 수 있는 수가 없어 무승부입니다.")
            case .threefoldRepetition:
                return String(localized: "같은 국면이 세 번 반복되어 무승부입니다.")
            case .fiftyMoveRule:
                return String(localized: "잡는 수도 폰의 전진도 없이 50수가 지나 무승부입니다.")
            }
        case nil: return ""
        }
    }
}
