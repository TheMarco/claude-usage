import Foundation

/// Mirrors what the Codex usage page shows (5h limit, weekly limit, credit).
public struct CodexUsage: Codable, Equatable, Sendable {
    public var planTier: String?         // "Plus" / "Pro" / "Team" / "Enterprise"
    public var accountEmail: String?
    public var fiveHour: Section?
    public var weekly: Section?
    public var creditRemainingUSD: Double?
    public var lastUpdated: Date

    public struct Section: Codable, Equatable, Sendable {
        public var usedPercent: Double   // 0...100, used (not left)
        public var resetsAt: Date?
    }

    public static let empty = CodexUsage(lastUpdated: Date())

    public static let placeholder = CodexUsage(
        planTier: "Pro",
        accountEmail: nil,
        fiveHour: .init(usedPercent: 3, resetsAt: Date().addingTimeInterval(2 * 3600)),
        weekly: .init(usedPercent: 47, resetsAt: Date().addingTimeInterval(2 * 86400)),
        creditRemainingUSD: 0,
        lastUpdated: Date()
    )
}

public enum CodexCache {
    private static let key = "codex.plan"

    public static func load() -> CodexUsage? {
        SharedContainer.read(CodexUsage.self, key: key)
    }

    public static func save(_ u: CodexUsage) {
        SharedContainer.write(u, key: key)
    }
}
