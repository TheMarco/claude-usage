import Foundation

/// Scans `~/.claude/projects/**/*.jsonl` and `~/.codex/sessions/**/*.jsonl`
/// and produces a `UsageSummary`. Synchronous, thread-safe via lock,
/// with a short on-disk cache so widget reloads stay snappy.
public final class UsageStore {
    public static let shared = UsageStore()

    private let lock = NSLock()
    private let fm = FileManager.default
    private var memoryCache: UsageSummary?
    private var memoryLoadedAt: Date?
    private let cacheTTL: TimeInterval = 60

    public func summary(forceRefresh: Bool = false) -> UsageSummary {
        lock.lock(); defer { lock.unlock() }

        if !forceRefresh,
           let mem = memoryCache,
           let when = memoryLoadedAt,
           Date().timeIntervalSince(when) < cacheTTL {
            return mem
        }
        if !forceRefresh,
           let disk = readDiskCache(),
           Date().timeIntervalSince(disk.generated) < cacheTTL {
            memoryCache = disk; memoryLoadedAt = Date()
            return disk
        }

        let fresh = scan()
        memoryCache = fresh
        memoryLoadedAt = Date()
        writeDiskCache(fresh)
        return fresh
    }

    public func clearCache() {
        lock.lock(); defer { lock.unlock() }
        memoryCache = nil; memoryLoadedAt = nil
        SharedContainer.remove(key: Self.summaryKey)
    }

    // MARK: - Paths

    /// Use the real user home directory — `NSHomeDirectory()` is redirected to
    /// the sandbox container in the widget extension.
    private var realHomeURL: URL {
        let path = NSHomeDirectoryForUser(NSUserName()) ?? ("/Users/" + NSUserName())
        return URL(fileURLWithPath: path)
    }
    private var claudeDir: URL { realHomeURL.appendingPathComponent(".claude/projects") }
    private var codexDir: URL  { realHomeURL.appendingPathComponent(".codex/sessions") }

    private static let summaryKey = "usage.summary"

    private func readDiskCache() -> UsageSummary? {
        SharedContainer.read(UsageSummary.self, key: Self.summaryKey)
    }

    private func writeDiskCache(_ s: UsageSummary) {
        SharedContainer.write(s, key: Self.summaryKey)
    }

    // MARK: - Top-level scan

    private func scan() -> UsageSummary {
        let claudeRecs = scanClaude()
        let (codexRecs, codexLimits) = scanCodex()

        var byProvider: [String: UsageSummary.ProviderSummary] = [:]
        byProvider[UsageRecord.Provider.claude.rawValue] =
            aggregate(records: claudeRecs, primaryLimit: nil, secondaryLimit: nil)
        byProvider[UsageRecord.Provider.codex.rawValue] =
            aggregate(records: codexRecs,
                      primaryLimit: codexLimits.primary,
                      secondaryLimit: codexLimits.secondary)

        return UsageSummary(byProvider: byProvider, generated: Date())
    }

    private func aggregate(records: [UsageRecord],
                           primaryLimit: RateLimit?,
                           secondaryLimit: RateLimit?) -> UsageSummary.ProviderSummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!

        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"
        dayFmt.timeZone = .current
        dayFmt.locale = Locale(identifier: "en_US_POSIX")

        var todayCost = 0.0, todayTokens = 0
        var monthCost = 0.0, monthTokens = 0
        var dayBuckets: [String: (cost: Double, tokens: Int)] = [:]
        var modelCosts: [String: Double] = [:]

        for r in records {
            let cost = Pricing.cost(model: r.model,
                                    input: r.inputTokens,
                                    output: r.outputTokens,
                                    cacheRead: r.cacheReadTokens,
                                    cacheWrite: r.cacheWriteTokens)
            let day = dayFmt.string(from: r.timestamp)
            let prev = dayBuckets[day] ?? (0, 0)
            dayBuckets[day] = (prev.cost + cost, prev.tokens + r.totalTokens)
            modelCosts[r.model, default: 0] += cost

            if calendar.isDate(r.timestamp, inSameDayAs: today) {
                todayCost += cost
                todayTokens += r.totalTokens
            }
            if r.timestamp >= monthStart {
                monthCost += cost
                monthTokens += r.totalTokens
            }
        }

        var last7: [UsageSummary.DailyUsage] = []
        for offset in (0..<7).reversed() {
            let d = calendar.date(byAdding: .day, value: -offset, to: today)!
            let key = dayFmt.string(from: d)
            let bucket = dayBuckets[key] ?? (0, 0)
            last7.append(.init(date: key, cost: bucket.cost, tokens: bucket.tokens))
        }

        let topModel = modelCosts.max { $0.value < $1.value }?.key

        // If a rate-limit window has already reset, the cached used_percent
        // belongs to the previous window — treat the current window as 0%
        // (we have no events for it yet).
        let now = Date()
        let primary  = (primaryLimit?.resetsAt).map { $0 < now } == true
            ? RateLimit(usedPercent: 0,
                        windowMinutes: primaryLimit!.windowMinutes,
                        resetsAt: nextReset(after: now, every: primaryLimit!.windowMinutes))
            : primaryLimit
        let secondary = (secondaryLimit?.resetsAt).map { $0 < now } == true
            ? RateLimit(usedPercent: 0,
                        windowMinutes: secondaryLimit!.windowMinutes,
                        resetsAt: nextReset(after: now, every: secondaryLimit!.windowMinutes))
            : secondaryLimit

        return .init(
            todayCost: todayCost,
            todayTokens: todayTokens,
            monthCost: monthCost,
            monthTokens: monthTokens,
            last7Days: last7,
            topModel: topModel,
            primaryLimit: primary,
            secondaryLimit: secondary
        )
    }

    private func nextReset(after now: Date, every windowMinutes: Int) -> Date {
        guard windowMinutes > 0 else { return now }
        return now.addingTimeInterval(TimeInterval(windowMinutes * 60))
    }

    /// Whether the user has Claude Code installed (i.e. `~/.claude/projects/`
    /// has at least one project subdirectory).
    public func hasClaudeData() -> Bool {
        guard let entries = try? fm.contentsOfDirectory(atPath: claudeDir.path) else { return false }
        return !entries.isEmpty
    }

    /// Whether the user has Codex CLI installed (auth.json present OR sessions exist).
    public func hasCodexData() -> Bool {
        let realHome = NSHomeDirectoryForUser(NSUserName()) ?? "/Users/\(NSUserName())"
        let authPath = realHome + "/.codex/auth.json"
        if fm.fileExists(atPath: authPath) { return true }
        guard let entries = try? fm.contentsOfDirectory(atPath: codexDir.path) else { return false }
        return !entries.isEmpty
    }

    // MARK: - Claude (~/.claude/projects/<encoded>/<session>.jsonl)

    private func scanClaude() -> [UsageRecord] {
        guard fm.fileExists(atPath: claudeDir.path) else { return [] }
        var out: [UsageRecord] = []
        let cutoff = Date().addingTimeInterval(-35 * 86400)

        guard let projects = try? fm.contentsOfDirectory(
            at: claudeDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for project in projects {
            guard let files = try? fm.contentsOfDirectory(
                at: project,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                if let attr = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                   let mod = attr.contentModificationDate, mod < cutoff { continue }

                guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
                for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                    if let rec = parseClaudeLine(String(line)) {
                        out.append(rec)
                    }
                }
            }
        }
        return out
    }

    private func parseClaudeLine(_ line: String) -> UsageRecord? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = obj["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any],
              let model = message["model"] as? String,
              let tsStr = obj["timestamp"] as? String else { return nil }

        guard let date = parseISO8601(tsStr) else { return nil }

        let i  = (usage["input_tokens"] as? Int) ?? 0
        let o  = (usage["output_tokens"] as? Int) ?? 0
        let cr = (usage["cache_read_input_tokens"] as? Int) ?? 0
        let cw = (usage["cache_creation_input_tokens"] as? Int) ?? 0

        // Skip empty pings.
        if i == 0 && o == 0 && cr == 0 && cw == 0 { return nil }

        return UsageRecord(
            timestamp: date, model: model, provider: .claude,
            inputTokens: i, outputTokens: o,
            cacheReadTokens: cr, cacheWriteTokens: cw
        )
    }

    // MARK: - Codex (~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl)

    private struct CodexLimits {
        var primary: RateLimit?
        var secondary: RateLimit?
    }

    private func scanCodex() -> ([UsageRecord], CodexLimits) {
        guard fm.fileExists(atPath: codexDir.path) else { return ([], .init()) }
        var out: [UsageRecord] = []
        let cutoff = Date().addingTimeInterval(-35 * 86400)

        // Track the latest rate-limits seen across all sessions.
        var latestRecord: (when: Date, limits: CodexLimits)?

        // Collect candidate files first so we can sort by mtime (newest last → latest limits win).
        var candidates: [(URL, Date)] = []
        if let enumerator = fm.enumerator(
            at: codexDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator where url.pathExtension == "jsonl" {
                let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                if mod < cutoff { continue }
                candidates.append((url, mod))
            }
        }
        candidates.sort { $0.1 < $1.1 }  // oldest first

        for (file, _) in candidates {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            var currentModel: String?

            for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let data = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }

                let type = obj["type"] as? String

                if type == "turn_context", let payload = obj["payload"] as? [String: Any],
                   let model = payload["model"] as? String {
                    currentModel = model
                    continue
                }

                if type == "session_meta", let payload = obj["payload"] as? [String: Any],
                   let model = payload["model"] as? String, currentModel == nil {
                    currentModel = model
                    continue
                }

                if type == "event_msg", let payload = obj["payload"] as? [String: Any],
                   (payload["type"] as? String) == "token_count" {

                    // Capture rate_limits if present.
                    if let rl = payload["rate_limits"] as? [String: Any],
                       let tsStr = obj["timestamp"] as? String,
                       let when = parseISO8601(tsStr) {
                        var limits = CodexLimits()
                        if let p = rl["primary"] as? [String: Any] { limits.primary = parseLimit(p) }
                        if let s = rl["secondary"] as? [String: Any] { limits.secondary = parseLimit(s) }
                        if limits.primary != nil || limits.secondary != nil {
                            if let cur = latestRecord {
                                if when > cur.when { latestRecord = (when, limits) }
                            } else {
                                latestRecord = (when, limits)
                            }
                        }
                    }

                    // Capture per-turn token usage from `last_token_usage`.
                    if let info = payload["info"] as? [String: Any],
                       let last = info["last_token_usage"] as? [String: Any],
                       let tsStr = obj["timestamp"] as? String,
                       let when = parseISO8601(tsStr) {

                        let total      = (last["input_tokens"] as? Int) ?? 0
                        let cached     = (last["cached_input_tokens"] as? Int) ?? 0
                        let output     = (last["output_tokens"] as? Int) ?? 0
                        let nonCached  = max(0, total - cached)

                        if total + output == 0 { continue }
                        let model = currentModel ?? "gpt-5-codex"
                        out.append(UsageRecord(
                            timestamp: when, model: model, provider: .codex,
                            inputTokens: nonCached, outputTokens: output,
                            cacheReadTokens: cached, cacheWriteTokens: 0
                        ))
                    }
                }
            }
        }

        return (out, latestRecord?.limits ?? .init())
    }

    private func parseLimit(_ dict: [String: Any]) -> RateLimit? {
        guard let used = dict["used_percent"] as? Double else { return nil }
        let window = (dict["window_minutes"] as? Int) ?? 0
        let resets: Date = {
            if let n = dict["resets_at"] as? Double { return Date(timeIntervalSince1970: n) }
            if let n = dict["resets_at"] as? Int { return Date(timeIntervalSince1970: TimeInterval(n)) }
            return Date()
        }()
        return RateLimit(usedPercent: used, windowMinutes: window, resetsAt: resets)
    }

    // MARK: - Helpers

    private func parseISO8601(_ s: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }
}
