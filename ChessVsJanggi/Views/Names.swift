import Foundation

// 엔진 타입의 표시 이름. 엔진은 Linux에서도 테스트하므로 현지화 코드는 앱 쪽에 둔다.

extension Side {
    var localizedName: String {
        self == .chess ? String(localized: "체스") : String(localized: "장기")
    }
}

extension PieceKind {
    var localizedName: String {
        switch self {
        case .king: return String(localized: "킹")
        case .queen: return String(localized: "퀸")
        case .rook: return String(localized: "룩")
        case .bishop: return String(localized: "비숍")
        case .knight: return String(localized: "나이트")
        case .pawn: return String(localized: "폰")
        case .general: return String(localized: "궁")
        case .chariot: return String(localized: "차")
        case .cannon: return String(localized: "포")
        case .horse: return String(localized: "마")
        case .elephant: return String(localized: "상")
        case .advisor: return String(localized: "사")
        case .soldier: return String(localized: "졸")
        }
    }
}

extension BotLevel {
    var localizedName: String {
        switch self {
        case .easy: return String(localized: "쉬움")
        case .normal: return String(localized: "보통")
        case .hard: return String(localized: "어려움")
        }
    }
}
