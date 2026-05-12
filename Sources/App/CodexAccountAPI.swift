import Foundation

/// Best-effort fetcher for ChatGPT's Codex usage data using the bearer token
/// the Codex CLI already wrote to ~/.codex/auth.json. We probe a handful of
/// candidate endpoints (the chatgpt.com web app exposes them at non-public
/// URLs that occasionally change), and write whatever we successfully parse
/// to ~/Library/Application Support/ClaudeUsage/codex-plan.json.
public actor CodexAccountAPI {
    public static let shared = CodexAccountAPI()

    public enum FetchError: Error, LocalizedError {
        case noAuth
        case allEndpointsFailed(String)
        case parseFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noAuth:
                return "No ~/.codex/auth.json — install OpenAI Codex CLI and run `codex` once."
            case .allEndpointsFailed(let detail):
                return "Codex API unreachable. Tried:\n\(detail)"
            case .parseFailed(let m):
                return "Codex response parse failed: \(m)"
            }
        }
    }

    /// Single endpoint that returns everything — rate limits, plan tier,
    /// email, and credit balance. Matches the chatgpt.com web UI XHR.
    private static let usageURL = "https://chatgpt.com/backend-api/codex/usage"

    public func refresh() async throws -> CodexUsage {
        let creds: CodexAuth.Credentials
        do { creds = try CodexAuth.load() } catch { throw FetchError.noAuth }

        let data = try await fetch(url: Self.usageURL, token: creds.accessToken)
        guard let parsed = Self.parseUsage(data) else {
            throw FetchError.parseFailed("unexpected /codex/usage shape")
        }
        var usage = parsed
        usage.lastUpdated = Date()
        CodexCache.save(usage)
        return usage
    }

    private static func appendDebugLog(_ msg: String) {
        let realHome = NSHomeDirectoryForUser(NSUserName()) ?? ("/Users/" + NSUserName())
        let url = URL(fileURLWithPath: realHome)
            .appendingPathComponent("Library/Application Support/ClaudeUsage/debug.log")
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let line = "[\(f.string(from: Date()))] \(msg)\n"
        if let data = line.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(data); try? h.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    private func fetch(url urlString: String, token: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw FetchError.parseFailed("bad URL: \(urlString)")
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("ClaudeUsageWidget/1.0", forHTTPHeaderField: "User-Agent")
        req.setValue("OpenAI-Codex/1.0", forHTTPHeaderField: "X-OpenAI-Client")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw FetchError.parseFailed("no HTTPURLResponse")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FetchError.parseFailed("HTTP \(http.statusCode)")
        }
        return data
    }

    // MARK: - Parser
    //
    // chatgpt.com/backend-api/codex/usage response shape (verified):
    //   {
    //     "account_id": "...", "user_id": "...",
    //     "email": "...", "plan_type": "plus|pro|team|enterprise|free",
    //     "rate_limit": {
    //       "primary_window":   { "used_percent": N, "reset_at": <unix-seconds>,
    //                             "limit_window_seconds": N },
    //       "secondary_window": { same shape }
    //     },
    //     "credits": { "balance": "$X.XX", "has_credits": 0|1, "unlimited": 0|1, ... },
    //     "spend_control": { "individual_limit": null|N, "reached": 0|1 }
    //   }

    private static func parseUsage(_ data: Data) -> CodexUsage? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        var u = CodexUsage(lastUpdated: Date())

        if let email = raw["email"] as? String, !email.isEmpty { u.accountEmail = email }
        if let plan = raw["plan_type"] as? String { u.planTier = displayName(for: plan) }

        if let rate = raw["rate_limit"] as? [String: Any] {
            u.fiveHour = section(from: rate["primary_window"] as? [String: Any])
            u.weekly   = section(from: rate["secondary_window"] as? [String: Any])
        }

        if let credits = raw["credits"] as? [String: Any] {
            // balance is a currency-formatted string like "$0.00" or "$12.34"
            if let bal = credits["balance"] as? String {
                u.creditRemainingUSD = parseCurrency(bal)
            } else if let n = (credits["balance"] as? Double) ?? (credits["balance"] as? Int).map(Double.init) {
                u.creditRemainingUSD = n
            }
        }
        return u
    }

    private static func section(from dict: [String: Any]?) -> CodexUsage.Section? {
        guard let dict else { return nil }
        let used: Double = (dict["used_percent"] as? Double)
            ?? (dict["used_percent"] as? Int).map(Double.init) ?? 0
        let resets: Date? = {
            if let n = dict["reset_at"] as? Double {
                // chatgpt.com gives seconds; older payloads sometimes ms.
                return n > 1e12 ? Date(timeIntervalSince1970: n / 1000)
                                : Date(timeIntervalSince1970: n)
            }
            if let n = dict["reset_at"] as? Int {
                let d = Double(n)
                return d > 1e12 ? Date(timeIntervalSince1970: d / 1000)
                                : Date(timeIntervalSince1970: d)
            }
            if let s = dict["reset_at"] as? String { return parseISO(s) }
            if let after = dict["reset_after_seconds"] as? Double {
                return Date().addingTimeInterval(after)
            }
            return nil
        }()
        return .init(usedPercent: used, resetsAt: resets)
    }

    private static func parseCurrency(_ s: String) -> Double? {
        let cleaned = s.trimmingCharacters(in: CharacterSet(charactersIn: "$ €£,"))
        return Double(cleaned)
    }

    private static func displayName(for raw: String) -> String {
        let r = raw.lowercased()
        if r.contains("enterprise") { return "Enterprise" }
        if r.contains("team")       { return "Team" }
        if r.contains("pro")        { return "Pro" }
        if r.contains("plus")       { return "Plus" }
        if r.contains("free")       { return "Free" }
        return raw.capitalized
    }

    /// Returns a flat list of dotted key paths (no values) for a JSON blob,
    /// up to depth 3, so the response shape can be safely logged.
    private static func keyTree(_ data: Data, maxDepth: Int = 3) -> String {
        guard let any = try? JSONSerialization.jsonObject(with: data) else { return "<non-JSON>" }
        var paths: [String] = []
        func walk(_ v: Any, prefix: String, depth: Int) {
            if depth > maxDepth { paths.append(prefix + "(…)"); return }
            if let dict = v as? [String: Any] {
                for k in dict.keys.sorted() {
                    let p = prefix.isEmpty ? k : "\(prefix).\(k)"
                    walk(dict[k]!, prefix: p, depth: depth + 1)
                }
            } else if let arr = v as? [Any], let first = arr.first {
                walk(first, prefix: prefix + "[0]", depth: depth + 1)
            } else {
                let kind: String
                switch v {
                case is String: kind = "<str>"
                case is Int, is Double: kind = "<num>"
                case is Bool: kind = "<bool>"
                case is NSNull: kind = "<null>"
                default: kind = "<?>"
                }
                paths.append("\(prefix) \(kind)")
            }
        }
        walk(any, prefix: "", depth: 0)
        return paths.joined(separator: ", ")
    }

    private static func parseISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        let g = ISO8601DateFormatter()
        g.formatOptions = [.withInternetDateTime]
        return g.date(from: s)
    }
}
