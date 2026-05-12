import Foundation
import ServiceManagement
import WidgetKit

/// Hides the host app behind a 5-minute background loop that fetches the
/// Claude plan + walks the local jsonl files, then nudges WidgetKit.
@MainActor
public final class Refresher: ObservableObject {
    public static let shared = Refresher()

    @Published public private(set) var lastError: String?
    @Published public private(set) var lastFetchedAt: Date?
    @Published public private(set) var isLoginItemEnabled: Bool = false

    private var timer: Timer?

    public func start(intervalSeconds: TimeInterval = 300) {
        timer?.invalidate()
        Task { await tick() }
        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { _ in
            Task { await Refresher.shared.tick() }
        }
        refreshLoginItemState()
    }

    public func stop() {
        timer?.invalidate(); timer = nil
    }

    public func tick() async {
        log("tick start")
        // 1. Local jsonl scan — always works.
        _ = UsageStore.shared.summary(forceRefresh: true)
        log("local scan ok")

        // 2. Live claude.ai plan — best-effort.
        do {
            let plan = try await ClaudeAccountAPI.shared.refresh()
            lastError = nil
            log("claude plan: tier=\(plan.planTier ?? "?") session=\(plan.currentSession?.usedPercent ?? -1)% weekly=\(plan.weeklyAllModels?.usedPercent ?? -1)%")
        } catch {
            lastError = error.localizedDescription
            log("claude plan FAILED: \(error.localizedDescription)")
        }

        // 3. Live Codex / ChatGPT plan — best-effort, never blocks the rest.
        do {
            let cdx = try await CodexAccountAPI.shared.refresh()
            log("codex plan: tier=\(cdx.planTier ?? "?") 5h=\(cdx.fiveHour?.usedPercent ?? -1)% weekly=\(cdx.weekly?.usedPercent ?? -1)%")
        } catch {
            log("codex plan FAILED (using local jsonl): \(error.localizedDescription.prefix(160))")
        }

        lastFetchedAt = Date()
        WidgetCenter.shared.reloadAllTimelines()
        log("tick end")
    }

    private func log(_ message: String) {
        let realHome = NSHomeDirectoryForUser(NSUserName()) ?? ("/Users/" + NSUserName())
        let dir = URL(fileURLWithPath: realHome)
            .appendingPathComponent("Library/Application Support/ClaudeUsage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("debug.log")
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let line = "[\(f.string(from: Date()))] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(data); try? h.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    // MARK: - Login Item

    public func setLoginItem(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = "Login Item: \(error.localizedDescription)"
        }
        refreshLoginItemState()
    }

    public func refreshLoginItemState() {
        isLoginItemEnabled = SMAppService.mainApp.status == .enabled
    }
}
