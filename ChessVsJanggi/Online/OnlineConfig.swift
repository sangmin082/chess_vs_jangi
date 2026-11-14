import Foundation

/// 온라인 대전 서버 설정
enum OnlineConfig {
    /// 릴레이 서버 주소 — server/ 디렉터리를 Render에 배포한 주소.
    /// (render.yaml 의 서비스 이름을 바꾸면 여기도 함께 수정)
    static let defaultServerURLString = "wss://chess-vs-janggi-server.onrender.com"

    static func resolvedServerURL() -> URL? {
        // UI 테스트·개발용: -serverURL ws://127.0.0.1:8080 으로 덮어쓸 수 있다
        if let override = UserDefaults.standard.string(forKey: "serverURL"), let url = URL(string: override) {
            return url
        }
        return URL(string: defaultServerURLString)
    }
}
