import Foundation

/// Development-only .env loader. The app copies Env/.env into the app bundle at build time (Debug only)
/// via a Run Script build phase. We parse it at runtime to prime the Keychain on first run so you don't
/// have to paste keys repeatedly while iterating.
struct EnvLoader {
    static func loadFromBundle() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "DevSecrets", withExtension: "env") else {
            return [:]
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var dict: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            dict[key] = value
        }
        return dict
    }
}
