import Foundation
import WidgetKit

struct UsageEntry: TimelineEntry {
    let date: Date
    let summary: UsageSummary
    let plan: PlanUsage?
    let codex: CodexUsage?
    let claudeStatus: ProviderStatus
    let codexStatus: ProviderStatus

    init(date: Date,
         summary: UsageSummary,
         plan: PlanUsage?,
         codex: CodexUsage? = nil,
         claudeStatus: ProviderStatus = .connected,
         codexStatus: ProviderStatus = .connected) {
        self.date = date
        self.summary = summary
        self.plan = plan
        self.codex = codex
        self.claudeStatus = claudeStatus
        self.codexStatus = codexStatus
    }

    /// Show a provider's column iff it is installed. We render `needsAuth`
    /// columns (so the user sees a "sign in" hint right inside the widget),
    /// but hide `notInstalled` ones entirely.
    var showClaude: Bool { claudeStatus != .notInstalled }
    var showCodex: Bool { codexStatus != .notInstalled }
}

extension UsageSummary {
    /// Sample data used by widget previews and the in-app preview pane.
    static let placeholder: UsageSummary = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")

        func lastWeek(seed: Double) -> [DailyUsage] {
            (0..<7).reversed().map { offset in
                let d = cal.date(byAdding: .day, value: -offset, to: today)!
                let factor = sin(Double(offset) * 0.7) * 0.5 + 0.7
                return DailyUsage(
                    date: f.string(from: d),
                    cost: max(0.5, seed * factor),
                    tokens: Int(max(50_000, seed * factor * 100_000))
                )
            }
        }

        return UsageSummary(
            byProvider: [
                "claude": .init(
                    todayCost: 18.40,
                    todayTokens: 1_240_000,
                    monthCost: 245.0,
                    monthTokens: 24_500_000,
                    last7Days: lastWeek(seed: 14),
                    topModel: "claude-opus-4-7",
                    primaryLimit: nil,
                    secondaryLimit: nil
                ),
                "codex": .init(
                    todayCost: 6.80,
                    todayTokens: 480_000,
                    monthCost: 86.0,
                    monthTokens: 8_600_000,
                    last7Days: lastWeek(seed: 5),
                    topModel: "gpt-5-codex",
                    primaryLimit: RateLimit(
                        usedPercent: 38,
                        windowMinutes: 300,
                        resetsAt: Date().addingTimeInterval(3 * 3600 + 1200)
                    ),
                    secondaryLimit: RateLimit(
                        usedPercent: 12,
                        windowMinutes: 10080,
                        resetsAt: Date().addingTimeInterval(4 * 86400)
                    )
                )
            ],
            generated: Date()
        )
    }()
}
