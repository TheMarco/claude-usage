import Foundation

/// Hits claude.ai's internal usage API and writes a `PlanUsage` to disk for
/// the widget to consume.
public actor ClaudeAccountAPI {
    public static let shared = ClaudeAccountAPI()

    public enum FetchError: Error, LocalizedError {
        case noCredentials
        case noSessionCookie
        case http(Int, String)
        case parseFailed(String)
        case missingOrganization

        public var errorDescription: String? {
            switch self {
            case .noCredentials:        return "Sign in via `claude login` first."
            case .noSessionCookie:      return "Paste your claude.ai sessionKey cookie in the app to enable live plan data."
            case .http(401, _), .http(403, _):
                return "claude.ai sessionKey expired or invalid — re-paste it from DevTools."
            case .http(let s, let b):   return "claude.ai returned HTTP \(s): \(b.prefix(200))"
            case .parseFailed(let m):   return "Could not parse claude.ai response: \(m)"
            case .missingOrganization:  return "No organization found on this claude.ai account."
            }
        }
    }

    private static let usageURL = "https://claude.ai/api/organizations/{org}/usage"
    private static let orgsURL  = "https://claude.ai/api/organizations"

    /// Cached org UUID — looked up once, then reused.
    private var cachedOrg: String?

    public func refresh() async throws -> PlanUsage {
        guard let cookie = SessionCookie.load() else {
            throw FetchError.noSessionCookie
        }
        // Plan tier comes from the OAuth credential (no extra round-trip).
        let planTier = (try? ClaudeKeychain.load())?.planTierDisplay

        let org = try await organizationUUID(cookie: cookie)

        var plan = PlanUsage(lastUpdated: Date())
        plan.planTier = planTier
        let usageData = try await get(template: Self.usageURL, org: org, cookie: cookie)
        plan = try Self.parseUsage(usageData, into: plan)
        PlanCache.save(plan)
        return plan
    }

    private func organizationUUID(cookie: String) async throws -> String {
        if let cachedOrg, !cachedOrg.isEmpty { return cachedOrg }
        let data = try await get(template: Self.orgsURL, org: "", cookie: cookie)
        if let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]],
           let first = arr.first,
           let uuid = (first["uuid"] ?? first["id"]) as? String, !uuid.isEmpty {
            cachedOrg = uuid
            return uuid
        }
        if let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let arr = dict["organizations"] as? [[String: Any]],
           let first = arr.first,
           let uuid = (first["uuid"] ?? first["id"]) as? String, !uuid.isEmpty {
            cachedOrg = uuid
            return uuid
        }
        throw FetchError.missingOrganization
    }

    private func get(template: String, org: String, cookie: String) async throws -> Data {
        let urlString = template.replacingOccurrences(of: "{org}", with: org)
        guard let url = URL(string: urlString) else {
            throw FetchError.http(0, "bad URL: \(urlString)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X) ClaudeUsageWidget/1.0", forHTTPHeaderField: "User-Agent")
        req.setValue("sessionKey=\(cookie)", forHTTPHeaderField: "Cookie")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw FetchError.http(0, "no HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            throw FetchError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    // MARK: - Parsers

    /// Maps claude.ai's `/usage` payload (the one the user sampled) onto PlanUsage.
    /// Schema (codename → public name):
    ///   five_hour              → Current session
    ///   seven_day              → Weekly · All models
    ///   seven_day_sonnet       → Sonnet only
    ///   seven_day_omelette     → Claude Design
    ///   seven_day_opus         → (Opus only — shown when present)
    ///   extra_usage            → Extra usage (cents-denominated)
    ///   tangelo / iguana_necktie / seven_day_cowork → other product-specific buckets
    private static func parseUsage(_ data: Data, into seed: PlanUsage) throws -> PlanUsage {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.parseFailed("usage payload is not a JSON object")
        }
        var p = seed

        func section(_ key: String, label: String? = nil) -> PlanUsage.Section? {
            guard let dict = raw[key] as? [String: Any] else { return nil }
            let util = (dict["utilization"] as? Double) ?? 0
            let resets = (dict["resets_at"] as? String).flatMap(parseISO)
            return .init(usedPercent: util,
                         resetsAt: resets,
                         resetsLabel: resets == nil ? "—" : nil,
                         subtitle: label)
        }

        p.currentSession      = section("five_hour")
        p.weeklyAllModels     = section("seven_day")
        p.weeklySonnetOnly    = section("seven_day_sonnet")
        p.weeklyClaudeDesign  = section("seven_day_omelette")

        if let extra = raw["extra_usage"] as? [String: Any] {
            p.extraUsageEnabled = extra["is_enabled"] as? Bool
            // monthly_limit and used_credits are in cents.
            if let cents = extra["monthly_limit"] as? Double { p.monthlySpendLimitUSD = cents / 100 }
            if let cents = (extra["used_credits"] as? Double) ?? (extra["used_credits"] as? Int).map(Double.init) {
                p.extraUsageSpentUSD = cents / 100
            }
        }
        return p
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
