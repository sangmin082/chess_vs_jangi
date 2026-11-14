import SwiftUI

struct HomeView: View {
    @State private var botLevel: BotLevel = .easy
    @State private var botSide: Side = .chess
    @State private var showRules = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    wordmark
                        .padding(.top, 48)

                    Spacer()

                    menu

                    Spacer()

                    Button {
                        showRules = true
                    } label: {
                        Text("규칙 한 장 보기")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .underline()
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 28)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showRules) { RulesSheet() }
        }
        .tint(Theme.ink)
    }

    // MARK: - 워드마크

    private var wordmark: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 마주 선 두 임금
            HStack(spacing: 10) {
                PieceView(piece: Piece(.king), cell: 64)
                Text(verbatim: "vs")
                    .font(.system(.title3, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.inkSoft)
                PieceView(piece: Piece(.general), cell: 64)
            }
            .accessibilityHidden(true)

            Text("체스 vs 장기")
                .font(.system(size: 42, weight: .black, design: .serif))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("서로 다른 두 군대, 하나의 판")
                .font(.system(.body, design: .serif))
                .italic()
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: - 메뉴

    private var menu: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuRow(title: "컴퓨터 대전", detail: "혼자서 한 판") {
                GameScreen(mode: .vsBot(botLevel, botSide))
            }

            VStack(alignment: .leading, spacing: 16) {
                TextToggle(
                    options: [
                        (value: Side.chess, title: String(localized: "체스로 두기")),
                        (value: Side.janggi, title: String(localized: "장기로 두기")),
                    ],
                    selection: $botSide
                )
                TextToggle(
                    options: BotLevel.allCases.map { (value: $0, title: $0.localizedName) },
                    selection: $botLevel
                )
            }
            .padding(.leading, 2)
            .padding(.top, 2)
            .padding(.bottom, 22)

            menuRow(title: "온라인 대전", detail: "방을 만들어 친구와 대결") {
                OnlineScreen()
            }
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    private func menuRow<Destination: View>(
        title: LocalizedStringKey, detail: LocalizedStringKey,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            NavigationLink {
                destination()
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
        }
    }
}

// MARK: - 규칙 시트

struct RulesSheet: View {
    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("규칙 한 장")
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 12) {
                        ruleLine("장기판 위에서 체스 군대와 장기 군대가 싸웁니다. 모든 기물은 선이 만나는 점에 놓입니다.")
                        ruleLine("체스가 먼저 둡니다.")
                        ruleLine("체스 기물은 체스 규칙대로, 장기 기물은 장기 규칙대로 움직입니다.")
                        ruleLine("상대의 킹(궁)을 피할 수 없게 공격하면 승리합니다 — 체크메이트, 곧 외통수.")
                        ruleLine("자기 킹(궁)이 잡히는 수는 둘 수 없습니다.")
                        ruleLine("체스는 정규 편성에 폰이 9개입니다. 장기는 대군입니다 — 졸 9개, 차 5대(포 줄에 3대 추가).")
                        ruleLine("빅장과 한수쉼은 없습니다. 앙파상도 없습니다.")
                        ruleLine("둘 수가 없을 때, 같은 국면이 세 번 반복될 때, 잡는 수도 폰의 전진도 없이 50수가 지나면 무승부입니다.")
                    }

                    sectionTitle("체스 기물")
                    VStack(alignment: .leading, spacing: 10) {
                        pieceLine(.king, "어느 방향으로든 한 칸. 판 어디든 갈 수 있습니다. 캐슬링도 됩니다.")
                        pieceLine(.queen, "가로·세로·대각선으로 원하는 만큼.")
                        pieceLine(.rook, "가로·세로로 원하는 만큼.")
                        pieceLine(.bishop, "대각선으로 원하는 만큼.")
                        pieceLine(.knight, "날 일(日)자로 뜁니다. 막히지 않습니다.")
                        pieceLine(.pawn, "앞으로 한 칸(첫 수는 두 칸도), 잡을 때는 대각선 앞으로. 끝줄에 닿으면 승급합니다.")
                    }

                    sectionTitle("장기 기물")
                    VStack(alignment: .leading, spacing: 10) {
                        pieceLine(.general, "궁성 안에서 선을 따라 한 칸. 궁성 밖으로 나갈 수 없습니다.")
                        pieceLine(.advisor, "궁과 같습니다.")
                        pieceLine(.chariot, "가로·세로로 원하는 만큼. 궁성 안에서는 대각선도.")
                        pieceLine(.cannon, "반드시 기물 하나를 넘어서 움직이고 잡습니다. 체스 기물도 넘을 수 있지만, 포는 넘지 못합니다.")
                        pieceLine(.horse, "한 칸 직진 후 한 칸 대각선. 첫 칸이 막히면 못 갑니다.")
                        pieceLine(.elephant, "한 칸 직진 후 두 칸 대각선. 지나는 칸이 막히면 못 갑니다.")
                        pieceLine(.soldier, "앞이나 옆으로 한 칸. 뒤로는 못 갑니다.")
                    }
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 28)
            }
        }
        .presentationDetents([.large])
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(.headline, design: .serif, weight: .bold))
            .foregroundStyle(Theme.ink)
            .padding(.top, 10)
    }

    private func ruleLine(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(verbatim: "—")
                .foregroundStyle(Theme.accent)
                .font(.system(.body, weight: .bold))
            Text(text)
                .font(.system(.callout))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pieceLine(_ kind: PieceKind, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .center, spacing: 12) {
            PieceView(piece: Piece(kind), cell: 34)
                .frame(width: 34, height: 34)
            Text(text)
                .font(.system(.callout))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
