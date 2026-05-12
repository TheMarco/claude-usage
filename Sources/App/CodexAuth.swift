import Foundation

/// Reads the OpenAI Codex CLI's plain-JSON credential file at
/// `~/.codex/auth.json`. No keychain prompt — Codex CLI keeps tokens on disk.
public enum CodexAuth {

    public struct Credentials {
        public let accessToken: String
        public let idToken: String?
        public let refreshToken: String?
        public let accountId: String?
        public let authMode: String?     // "chatgpt" | "apikey"
        public let lastRefresh: Date?
    }

    public enum Error: Swift.Error, LocalizedError {
        case notFound
        case unreadable(String)
        case decodeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notFound:           return "~/.codex/auth.json not found. Run `codex` once to sign in."
            case .unreadable(let m):  return "Could not read ~/.codex/auth.json: \(m)"
            case .decodeFailed(let m):return "Could not decode Codex credentials: \(m)"
            }
        }
    }

    private static var path: URL {
        let home = NSHomeDirectoryForUser(NSUserName()) ?? "/Users/\(NSUserName())"
        return URL(fileURLWithPath: home).appendingPathComponent(".codex/auth.json")
    }

    public static func load() throws -> Credentials {
        let url = path
        guard FileManager.default.fileExists(atPath: url.path) else { throw Error.notFound }
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw Error.unreadable(error.localizedDescription) }

        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.decodeFailed("not a JSON object")
        }

        let tokens = (raw["tokens"] as? [String: Any]) ?? [:]
        guard let access = tokens["access_token"] as? String, !access.isEmpty else {
            throw Error.decodeFailed("missing tokens.access_token")
        }

        let lastRefresh: Date? = {
            guard let s = raw["last_refresh"] as? String else { return nil }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.date(from: s)
        }()

        return Credentials(
            accessToken: access,
            idToken: tokens["id_token"] as? String,
            refreshToken: tokens["refresh_token"] as? String,
            accountId: tokens["account_id"] as? String,
            authMode: raw["auth_mode"] as? String,
            lastRefresh: lastRefresh
        )
    }

    // MARK: - JWT helpers

    /// Decodes a JWT payload to a dictionary. No signature verification — we
    /// only read claims that the user's own CLI also reads.
    public static func decodeJWT(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        // Base64url → base64 + padding.
        payload = payload.replacingOccurrences(of: "-", with: "+")
                         .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return dict
    }

    /// Recursively flattens a dictionary into "a.b.c" key paths.
    /// Values are NOT included — just the keys, for safe diagnostic logging.
    public static func keyPaths(in dict: [String: Any], prefix: String = "") -> [String] {
        var out: [String] = []
        for k in dict.keys.sorted() {
            let p = prefix.isEmpty ? k : "\(prefix).\(k)"
            if let nested = dict[k] as? [String: Any] {
                out.append(p)
                out.append(contentsOf: keyPaths(in: nested, prefix: p))
            } else if let arr = dict[k] as? [[String: Any]], let first = arr.first {
                out.append("\(p)[]")
                out.append(contentsOf: keyPaths(in: first, prefix: "\(p)[]"))
            } else {
                out.append(p)
            }
        }
        return out
    }
}
