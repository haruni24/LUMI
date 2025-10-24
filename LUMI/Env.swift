import Foundation

final class Env {
    static let shared = Env()
    private var store: [String: String] = [:]

    private init() {
        // 優先度: ProcessInfo > .env(バンドル) > Info.plist
        // 1) 環境変数
        store.merge(ProcessInfo.processInfo.environment) { current, _ in current }

        // 2) .env（アプリバンドル内に含めた場合）
        if let url = Bundle.main.url(forResource: ".env", withExtension: nil) {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                for line in text.split(separator: "\n") {
                    guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("#") else { continue }
                    let parts = line.split(separator: "=", maxSplits: 1).map { String($0) }
                    if parts.count == 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        store[key] = value
                    }
                }
            }
        }

        // 3) Info.plist
        if let info = Bundle.main.infoDictionary {
            for (k, v) in info {
                if let key = k as? String, let value = v as? String {
                    store[key] = value
                }
            }
        }
    }

    func string(_ key: String) -> String? {
        store[key]
    }
}

