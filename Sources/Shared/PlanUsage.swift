import Foundation

/// Mirrors the data on https://claude.ai/settings/usage.
public struct PlanUsage: Codable, Equatable, Sendable {
    public var planTier: String?            // "Max (5x)", "Pro", "Free"
    public var currentSession: Section?     // 5h rolling
    public var weeklyAllModels: Section?
    public var weeklySonnetOnly: Section?
    public var weeklyClaudeDesign: Section?
    public var dailyRoutineRuns: Ratio?     // 0/15
    public var extraUsageEnabled: Bool?
    public var extraUsageSpentUSD: Double?
    public var extraUsageResetsAt: Date?
    public var monthlySpendLimitUSD: Double?
    public var currentBalanceUSD: Double?
    public var lastUpdated: Date

    public struct Section: Codable, Equatable, Sendable {
        public var usedPercent: Double      // 0...100
        public var resetsAt: Date?
        public var resetsLabel: String?     // "Mon 9:00 AM" if absolute date isn't useful
        public var subtitle: String?        // e.g. "You haven't used Sonnet yet"
    }

    public struct Ratio: Codable, Equatable, Sendable {
        public var used: Int
        public var total: Int
        public var subtitle: String?
    }

    public static let empty = PlanUsage(lastUpdated: Date())

    public static let placeholder = PlanUsage(
        planTier: "Max (5x)",
        currentSession: .init(usedPercent: 10, resetsAt: Date().addingTimeInterval(50 * 60), resetsLabel: nil, subtitle: nil),
        weeklyAllModels: .init(usedPercent: 2, resetsAt: nil, resetsLabel: "Mon 9:00 AM", subtitle: nil),
        weeklySonnetOnly: .init(usedPercent: 0, resetsAt: nil, resetsLabel: "Mon 9:00 AM", subtitle: "You haven't used Sonnet yet"),
        weeklyClaudeDesign: .init(usedPercent: 0, resetsAt: nil, resetsLabel: "Mon 9:00 AM", subtitle: "You haven't used Claude Design yet"),
        dailyRoutineRuns: .init(used: 0, total: 15, subtitle: "You haven't run any routines yet"),
        extraUsageEnabled: true,
        extraUsageSpentUSD: 0,
        extraUsageResetsAt: nil,
        monthlySpendLimitUSD: 70,
        currentBalanceUSD: 105.09,
        lastUpdated: Date()
    )
}

/// On-disk cache the host app writes and the widget reads.
public enum PlanCache {
    private static let key = "claude.plan"

    public static func load() -> PlanUsage? {
        SharedContainer.read(PlanUsage.self, key: key)
    }

    public static func save(_ plan: PlanUsage) {
        SharedContainer.write(plan, key: key)
    }
}
