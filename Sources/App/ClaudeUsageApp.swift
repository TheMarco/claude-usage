import SwiftUI
import AppKit

@main
struct ClaudeUsageApp: App {
    var body: some Scene {
        WindowGroup("AI Usage") {
            ContentView()
                .background(WindowAccessor())
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About AI Usage") {
                    showAboutPanel()
                }
            }
        }
    }
}

private func showAboutPanel() {
    let credits = NSMutableAttributedString()
    let body: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11),
        .foregroundColor: NSColor.labelColor
    ]
    credits.append(NSAttributedString(string: "By Marco van Hylckama Vlieg\n\n", attributes: body))
    credits.append(link("ai-created.com",  url: "https://ai-created.com/"))
    credits.append(NSAttributedString(string: "   ·   ", attributes: body))
    credits.append(link("@AIandDesign",    url: "https://x.com/AIandDesign"))
    credits.append(NSAttributedString(string: "\n\n", attributes: body))
    credits.append(link("☕ Buy me a coffee", url: "https://ko-fi.com/aianddesign"))

    NSApp.orderFrontStandardAboutPanel(options: [
        .credits: credits,
        .applicationName: "AI Usage",
        NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 Marco van Hylckama Vlieg"
    ])
    NSApp.activate(ignoringOtherApps: true)
}

private func link(_ text: String, url: String) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
        .link: URL(string: url) as Any,
        .foregroundColor: NSColor.linkColor
    ])
}

/// Sets dark appearance and a transparent titlebar — no size manipulation.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.appearance = NSAppearance(named: .darkAqua)
            w.titlebarAppearsTransparent = true
            w.styleMask.insert(.fullSizeContentView)
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
