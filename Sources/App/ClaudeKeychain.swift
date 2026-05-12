import Foundation
import Security

/// Reads the credential blob Claude Code stores in the macOS Keychain
/// under service "Claude Code-credentials". The first read triggers a
/// keychain prompt — clicking "Always Allow" makes subsequent reads silent.
public enum ClaudeKeychain {
    public struct Credentials: Decodable {
        public let accessToken: String
        public let refreshToken: String?
        public let expiresAt: Date?
        public let organizationUUID: String?
        public let subscriptionType: String?     // "max", "pro", "free"
        public let rateLimitTier: String?        // "max_5x", "max_20x", ...

        public var isExpired: Bool {
            guard let expiresAt else { return false }
            return Date() >= expiresAt.addingTimeInterval(-60)
        }

        /// Display string like "Max (5x)" / "Pro" / "Free".
        public var planTierDisplay: String? {
            let sub = subscriptionType?.lowercased()
            let tier = rateLimitTier?.lowercased() ?? ""
            switch sub {
            case "max":
                if tier.contains("20x") { return "Max (20x)" }
                if tier.contains("5x")  { return "Max (5x)" }
                return "Max"
            case "pro":   return "Pro"
            case "free":  return "Free"
            case let s?:  return s.capitalized
            case nil:     return nil
            }
        }
    }

    public enum Error: Swift.Error, LocalizedError {
        case notFound
        case keychainStatus(OSStatus)
        case decodeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notFound:
                return "No 'Claude Code-credentials' item in Keychain. Run `claude login` first."
            case .keychainStatus(let s):
                return "Keychain returned status \(s) (\(SecCopyErrorMessageString(s, nil) as String? ?? "unknown"))."
            case .decodeFailed(let m):
                return "Could not decode credential blob: \(m)"
            }
        }
    }

    public static func load() throws -> Credentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { throw Error.notFound }
        guard status == errSecSuccess else { throw Error.keychainStatus(status) }
        guard let data = result as? Data else { throw Error.decodeFailed("non-Data result") }

        // Diagnostic — write the JSON key tree (no values) so the parser can
        // be patched without exposing the access token.
        dumpKeyShape(data: data)

        // The credential payload Claude Code writes is JSON. Try a few known shapes.
        return try parse(data: data)
    }

    private static func dumpKeyShape(data: Data) {
        guard let any = try? JSONSerialization.jsonObject(with: data) else { return }
        func walk(_ v: Any, prefix: String) -> [String] {
            if let dict = v as? [String: Any] {
                return dict.keys.sorted().flatMap { k -> [String] in
                    let path = prefix.isEmpty ? k : "\(prefix).\(k)"
                    let child = dict[k]!
                    if child is [String: Any] || child is [Any] {
                        return [path] + walk(child, prefix: path)
                    }
                    let typeTag: String
                    switch child {
                    case is String: typeTag = "<str>"
                    case is Int, is Double: typeTag = "<num>"
                    case is Bool: typeTag = "<bool>"
                    case is NSNull: typeTag = "<null>"
                    default: typeTag = "<?>"
                    }
                    return ["\(path) \(typeTag)"]
                }
            }
            if let arr = v as? [Any], let first = arr.first {
                return walk(first, prefix: prefix + "[0]")
            }
            return []
        }
        let lines = walk(any, prefix: "")
        let text = "[keychain shape] " + lines.joined(separator: ", ") + "\n"
        let realHome = NSHomeDirectoryForUser(NSUserName()) ?? ("/Users/" + NSUserName())
        let dir = URL(fileURLWithPath: realHome)
            .appendingPathComponent("Library/Application Support/ClaudeUsage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("debug.log")
        if let d = text.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(d); try? h.close()
            } else {
                try? d.write(to: url)
            }
        }
    }

    private static func parse(data: Data) throws -> Credentials {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            if let n = try? c.decode(Double.self) {
                // Claude Code writes ms since epoch.
                return n > 1_000_000_000_000 ? Date(timeIntervalSince1970: n / 1000)
                                              : Date(timeIntervalSince1970: n)
            }
            if let s = try? c.decode(String.self),
               let date = ISO8601DateFormatter().date(from: s) { return date }
            return Date.distantPast
        }
        dec.keyDecodingStrategy = .convertFromSnakeCase

        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let preview = String(data: data.prefix(120), encoding: .utf8) ?? "<binary>"
            throw Error.decodeFailed("not JSON: \(preview)")
        }

        // Walk known wrapper keys; fall through to root if none match.
        let inner: [String: Any] =
            (raw["claudeAiOauth"] as? [String: Any])
            ?? (raw["claude_ai_oauth"] as? [String: Any])
            ?? (raw["auth"] as? [String: Any])
            ?? (raw["credentials"] as? [String: Any])
            ?? raw

        guard let token = (inner["accessToken"] ?? inner["access_token"]) as? String, !token.isEmpty else {
            throw Error.decodeFailed("no accessToken; keys=\(Array(inner.keys).sorted())")
        }

        return Credentials(
            accessToken: token,
            refreshToken: (inner["refreshToken"] ?? inner["refresh_token"]) as? String,
            expiresAt: dateFromAny(inner["expiresAt"] ?? inner["expires_at"]),
            organizationUUID: (inner["organizationUuid"] ?? inner["organization_uuid"]) as? String,
            subscriptionType: (inner["subscriptionType"] ?? inner["subscription_type"]) as? String,
            rateLimitTier: (inner["rateLimitTier"] ?? inner["rate_limit_tier"]) as? String
        )
    }

    private static func dateFromAny(_ any: Any?) -> Date? {
        if let n = any as? Double { return n > 1e12 ? Date(timeIntervalSince1970: n/1000) : Date(timeIntervalSince1970: n) }
        if let n = any as? Int { let d = Double(n); return d > 1e12 ? Date(timeIntervalSince1970: d/1000) : Date(timeIntervalSince1970: d) }
        if let s = any as? String { return ISO8601DateFormatter().date(from: s) }
        return nil
    }
}
