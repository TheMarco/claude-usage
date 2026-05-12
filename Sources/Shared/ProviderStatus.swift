import Foundation

/// Three-state lifecycle for each provider that the widget + host app branch on.
public enum ProviderStatus: String, Codable, Sendable, Equatable {
    case notInstalled        // no install evidence on disk
    case needsAuth           // installed, but our app still needs to authenticate
    case connected           // installed + we have live data
}

/// Cheap on-disk checks the widget extension can also run.
public enum ProviderDetection {
    private static var realHome: URL {
        let path = NSHomeDirectoryForUser(NSUserName()) ?? ("/Users/" + NSUserName())
        return URL(fileURLWithPath: path)
    }

    /// `~/.claude` exists (created by the Claude Code CLI on first run).
    public static var claudeInstalled: Bool {
        FileManager.default.fileExists(
            atPath: realHome.appendingPathComponent(".claude").path
        )
    }

    /// `~/.codex/auth.json` exists (Codex CLI writes it on `codex login`).
    public static var codexInstalled: Bool {
        FileManager.default.fileExists(
            atPath: realHome.appendingPathComponent(".codex/auth.json").path
        )
    }

    public static func claudeStatus(planLoaded: Bool) -> ProviderStatus {
        guard claudeInstalled else { return .notInstalled }
        return planLoaded ? .connected : .needsAuth
    }

    public static func codexStatus(codexLoaded: Bool) -> ProviderStatus {
        // Codex needs no extra auth from us — auth.json already has the bearer.
        // A failing API call still leaves codex == .connected (we'll show a
        // hint in the UI, but the provider is "set up").
        codexInstalled ? .connected : .notInstalled
    }
}
