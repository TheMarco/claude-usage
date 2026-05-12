import Foundation
import Security

/// claude.ai's web API uses a `sessionKey=...` cookie for auth, NOT the
/// OAuth bearer token Claude Code uses for api.anthropic.com. We store the
/// cookie under our own Keychain item so the user only pastes it once.
public enum SessionCookie {
    private static let service = "ClaudeUsageWidget-Session"
    private static let account = "claude.ai"

    public static func load() -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        let s = SecItemCopyMatching(q as CFDictionary, &out)
        guard s == errSecSuccess, let data = out as? Data else { return nil }
        let raw = String(data: data, encoding: .utf8) ?? ""
        return cleaned(raw).nonEmptyOrNil
    }

    public static func save(_ value: String) {
        let trimmed = cleaned(value)
        guard let data = trimmed.data(using: .utf8) else { return }

        // Delete existing first; then add. Avoids "already exists" updates needing matching attrs.
        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(del as CFDictionary)

        if trimmed.isEmpty { return }

        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemAdd(add as CFDictionary, nil)
    }

    /// Accepts: a raw cookie value, `sessionKey=...`, or a full cURL line.
    /// Returns just the cookie value with no name= prefix or stray quotes.
    private static func cleaned(_ s: String) -> String {
        var v = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // If they pasted a whole cURL, extract the sessionKey cookie out of -b/--cookie.
        if v.contains("curl ") || v.contains("'sessionKey=") || v.contains("\"sessionKey=") {
            if let range = v.range(of: #"sessionKey=([^;'"\s]+)"#, options: .regularExpression) {
                let match = String(v[range])
                v = match.replacingOccurrences(of: "sessionKey=", with: "")
            }
        } else if v.hasPrefix("sessionKey=") {
            v = String(v.dropFirst("sessionKey=".count))
        }

        // Strip surrounding quotes / trailing semicolons.
        v = v.trimmingCharacters(in: CharacterSet(charactersIn: " ;\"'"))
        return v
    }
}

private extension String {
    var nonEmptyOrNil: String? { isEmpty ? nil : self }
}
