import Foundation

public struct UsageRecord {
    public let timestamp: Date
    public let model: String
    public let provider: Provider
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
    public let cacheWriteTokens: Int

    public var totalTokens: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens
    }

    public enum Provider: String, Codable, CaseIterable, Sendable {
        case claude
        case codex

        public var displayName: String {
            switch self {
            case .claude: return "Claude"
            case .codex: return "Codex"
            }
        }
    }
}

public struct RateLimit: Codable, Equatable, Sendable {
    public var usedPercent: Double      // 0...100
    public var windowMinutes: Int
    public var resetsAt: Date
}

public struct UsageSummary: Codable, Equatable, Sendable {
    public var byProvider: [String: ProviderSummary]
    public var generated: Date

    public struct ProviderSummary: Codable, Equatable, Sendable {
        public var todayCost: Double
        public var todayTokens: Int
        public var monthCost: Double
        public var monthTokens: Int
        public var last7Days: [DailyUsage]   // oldest first, length 7
        public var topModel: String?
        public var primaryLimit: RateLimit?  // e.g. Codex 5h window
        public var secondaryLimit: RateLimit?
    }

    public struct DailyUsage: Codable, Equatable, Sendable {
        public let date: String  // YYYY-MM-DD
        public let cost: Double
        public let tokens: Int
    }

    public static let empty = UsageSummary(byProvider: [:], generated: Date())
}
