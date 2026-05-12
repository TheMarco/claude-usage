import WidgetKit
import SwiftUI

struct UsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), summary: .placeholder, plan: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        if context.isPreview {
            completion(UsageEntry(date: Date(), summary: .placeholder, plan: .placeholder))
            return
        }
        completion(makeEntry(forceRefresh: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = makeEntry(forceRefresh: true)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: entry.date)
            ?? entry.date.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry(forceRefresh: Bool) -> UsageEntry {
        let summary = UsageStore.shared.summary(forceRefresh: forceRefresh)
        let plan = PlanCache.load()
        let codex = CodexCache.load()

        // Widget is sandboxed and can't read ~/.claude or ~/.codex directly,
        // so derive provider status from cache presence. The host app (which
        // *is* unsandboxed) writes a cache only after a provider is set up,
        // so cache != nil ⇒ installed + connected.
        var claudeStatus: ProviderStatus = (plan != nil) ? .connected : .notInstalled
        let codexStatus: ProviderStatus = (codex != nil) ? .connected : .notInstalled

        // If nothing is configured at all, fall back to showing Claude as
        // needsAuth so the widget renders a hint instead of going empty.
        if claudeStatus == .notInstalled && codexStatus == .notInstalled {
            claudeStatus = .needsAuth
        }

        let dir = SharedContainer.directory.path
        let planURL = SharedContainer.directory.appendingPathComponent("claude.plan.json")
        let exists = FileManager.default.fileExists(atPath: planURL.path)
        var readErr = "ok"
        do { _ = try Data(contentsOf: planURL) } catch { readErr = "\(error)" }
        widgetDiag("dir=\(dir) exists=\(exists) read=\(readErr.prefix(120)) planLoaded=\(plan != nil) claude=\(claudeStatus.rawValue) codex=\(codexStatus.rawValue)")

        return UsageEntry(date: Date(), summary: summary, plan: plan, codex: codex,
                          claudeStatus: claudeStatus, codexStatus: codexStatus)
    }

    private func widgetDiag(_ message: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("widget-debug.log")
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
}
