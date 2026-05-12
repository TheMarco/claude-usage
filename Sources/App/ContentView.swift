import SwiftUI
import WidgetKit

private enum PreviewMode: String, CaseIterable, Identifiable {
    case live, both, claudeOnly, codexOnly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .live:       return "Live"
        case .both:       return "Both"
        case .claudeOnly: return "Claude only"
        case .codexOnly:  return "Codex only"
        }
    }
}

struct ContentView: View {
    @State private var summary: UsageSummary = .placeholder
    @State private var plan: PlanUsage? = .placeholder
    @State private var codex: CodexUsage? = .placeholder
    @StateObject private var refresher = Refresher.shared
    @State private var refreshing = false
    @State private var lastError: String?
    @State private var hasSession: Bool = SessionCookie.load() != nil
    @State private var showLoginSheet: Bool = false
    @State private var previewMode: PreviewMode = .live

    private var claudeStatus: ProviderStatus {
        ProviderDetection.claudeStatus(planLoaded: plan != nil && hasSession)
    }
    private var codexStatus: ProviderStatus {
        ProviderDetection.codexStatus(codexLoaded: codex != nil)
    }

    private var liveEntry: UsageEntry {
        UsageEntry(date: Date(), summary: summary, plan: plan, codex: codex,
                   claudeStatus: claudeStatus, codexStatus: codexStatus)
    }

    private var previewEntry: UsageEntry {
        switch previewMode {
        case .live:
            return liveEntry
        case .both:
            return UsageEntry(date: Date(), summary: .placeholder,
                              plan: .placeholder, codex: .placeholder,
                              claudeStatus: .connected, codexStatus: .connected)
        case .claudeOnly:
            return UsageEntry(date: Date(), summary: .placeholder,
                              plan: .placeholder, codex: nil,
                              claudeStatus: .connected, codexStatus: .notInstalled)
        case .codexOnly:
            return UsageEntry(date: Date(), summary: .placeholder,
                              plan: nil, codex: .placeholder,
                              claudeStatus: .notInstalled, codexStatus: .connected)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            hero
            setupCard
            previewSection
            footer
            creditsRow
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLoginSheet) {
            ClaudeAILoginSheet(isPresented: $showLoginSheet) { sessionKey in
                SessionCookie.save(sessionKey)
                hasSession = true
                Task { await refreshNow() }
            }
        }
        .task {
            await refreshNow()
            refresher.start(intervalSeconds: 300)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .center, spacing: 14) {
            HStack(spacing: 8) {
                Image("clawd")
                    .resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 32)
                Image("openai")
                    .resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("AI USAGE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(LinearGradient(colors: [Theme.claudeStart, Theme.codexStart],
                                                    startPoint: .leading, endPoint: .trailing))
                Text("Claude Code + Codex, on your desktop.")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text("Add via Notification Center → Edit Widgets")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 200, alignment: .trailing)
        }
    }

    // MARK: - Compact setup card

    private var setupCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SETUP")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Toggle(isOn: Binding(
                    get: { refresher.isLoginItemEnabled },
                    set: { refresher.setLoginItem(enabled: $0) }
                )) {
                    Text("Run at login")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .padding(.bottom, 10)

            providerRow(
                image: "clawd",
                imageSize: CGSize(width: 22, height: 14),
                name: "Claude",
                status: claudeStatus,
                tier: plan?.planTier,
                accent: Theme.claude,
                action: claudeAction
            )

            Divider().overlay(Color.white.opacity(0.06)).padding(.vertical, 8)

            providerRow(
                image: "openai",
                imageSize: CGSize(width: 18, height: 14),
                name: "Codex",
                status: codexStatus,
                tier: codex?.planTier,
                accent: Theme.codex,
                action: codexAction
            )

            if let err = lastError ?? refresher.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(err)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.top, 10)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private struct ProviderAction {
        let label: String
        let symbol: String?
        let prominent: Bool
        let tint: Color?
        let url: URL?
        let onTap: (() -> Void)?
    }

    private var claudeAction: ProviderAction {
        switch claudeStatus {
        case .notInstalled:
            return ProviderAction(label: "Install →", symbol: nil, prominent: false, tint: nil,
                                  url: URL(string: "https://docs.claude.com/en/docs/claude-code/overview"),
                                  onTap: nil)
        case .needsAuth:
            return ProviderAction(label: "Sign in", symbol: "arrow.right.circle.fill",
                                  prominent: true, tint: Color(red: 1, green: 0.5, blue: 0.21),
                                  url: nil, onTap: { showLoginSheet = true })
        case .connected:
            return ProviderAction(label: "Sign out", symbol: nil, prominent: false, tint: nil,
                                  url: nil, onTap: {
                                      SessionCookie.save("")
                                      hasSession = false
                                  })
        }
    }

    private var codexAction: ProviderAction {
        switch codexStatus {
        case .notInstalled:
            return ProviderAction(label: "Install →", symbol: nil, prominent: false, tint: nil,
                                  url: URL(string: "https://github.com/openai/codex"),
                                  onTap: nil)
        case .needsAuth, .connected:
            return ProviderAction(label: "", symbol: nil, prominent: false, tint: nil,
                                  url: nil, onTap: nil)
        }
    }

    @ViewBuilder
    private func providerRow(image: String,
                             imageSize: CGSize,
                             name: String,
                             status: ProviderStatus,
                             tier: String?,
                             accent: Color,
                             action: ProviderAction) -> some View {
        HStack(spacing: 14) {
            Image(image)
                .resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                .frame(width: imageSize.width, height: imageSize.height)
                .frame(width: 28, alignment: .center)
            Text(name.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 60, alignment: .leading)

            statusDot(status, accent: accent)
                .frame(width: 12, alignment: .center)

            Text(statusLabel(status))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 110, alignment: .leading)

            tierBadge(tier, accent: accent)
                .frame(width: 70, alignment: .leading)

            Spacer(minLength: 8)

            if !action.label.isEmpty {
                actionButton(action)
            }
        }
    }

    @ViewBuilder
    private func tierBadge(_ tier: String?, accent: Color) -> some View {
        if let tier {
            Text(tier)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.vertical, 2).padding(.horizontal, 7)
                .background(Capsule().fill(accent.opacity(0.22)))
                .foregroundStyle(.white)
        } else {
            Color.clear
        }
    }

    private func statusDot(_ status: ProviderStatus, accent: Color) -> some View {
        let color: Color = {
            switch status {
            case .connected:    return .green
            case .needsAuth:    return .yellow
            case .notInstalled: return Color.white.opacity(0.25)
            }
        }()
        return Circle().fill(color).frame(width: 8, height: 8)
    }

    private func statusLabel(_ status: ProviderStatus) -> String {
        switch status {
        case .connected:    return "Connected"
        case .needsAuth:    return "Not signed in"
        case .notInstalled: return "Not detected"
        }
    }

    @ViewBuilder
    private func actionButton(_ action: ProviderAction) -> some View {
        if let url = action.url {
            Link(destination: url) {
                Text(action.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else if let onTap = action.onTap {
            Button {
                onTap()
            } label: {
                if let symbol = action.symbol {
                    Label(action.label, systemImage: symbol)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                } else {
                    Text(action.label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
            }
            .applyButtonStyle(prominent: action.prominent, tint: action.tint)
            .controlSize(.small)
        }
    }

    // MARK: - Preview section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("PREVIEW")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Picker("Preview mode", selection: $previewMode) {
                    ForEach(PreviewMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
            }

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 14) {
                    previewTile(title: "Small", size: CGSize(width: 170, height: 170)) {
                        SmallWidgetView(entry: previewEntry)
                    }
                    previewTile(title: "Medium", size: CGSize(width: 364, height: 170)) {
                        MediumWidgetView(entry: previewEntry)
                    }
                }
                previewTile(title: "Large", size: CGSize(width: 364, height: 382)) {
                    LargeWidgetView(entry: previewEntry)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func previewTile<V: View>(title: String,
                                      size: CGSize,
                                      @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))
            content()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 10)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                Task { await refreshNow() }
            } label: {
                Label(refreshing ? "Refreshing…" : "Refresh now",
                      systemImage: "arrow.clockwise")
            }
            .disabled(refreshing)
            Spacer()
            if let when = refresher.lastFetchedAt {
                Text("Last refresh: \(when.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Credits

    private var creditsRow: some View {
        HStack(spacing: 8) {
            Text("Made by")
                .foregroundStyle(.white.opacity(0.4))
            Text("Marco van Hylckama Vlieg")
                .foregroundStyle(.white.opacity(0.7))
            Text("·").foregroundStyle(.white.opacity(0.25))
            Link("ai-created.com", destination: URL(string: "https://ai-created.com/")!)
            Text("·").foregroundStyle(.white.opacity(0.25))
            Link("@AIandDesign", destination: URL(string: "https://x.com/AIandDesign")!)
            Spacer()
            Link(destination: URL(string: "https://ko-fi.com/aianddesign")!) {
                Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(Color(red: 1, green: 0.5, blue: 0.21))
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .padding(.top, 4)
    }

    // MARK: - Refresh

    @MainActor
    private func refreshNow() async {
        refreshing = true
        await refresher.tick()
        let s = await Task.detached(priority: .userInitiated) {
            UsageStore.shared.summary()
        }.value
        summary = s
        plan = PlanCache.load() ?? .placeholder
        codex = CodexCache.load() ?? .placeholder
        lastError = refresher.lastError
        refreshing = false
    }
}

private extension View {
    @ViewBuilder
    func applyButtonStyle(prominent: Bool, tint: Color?) -> some View {
        if prominent {
            self.buttonStyle(.borderedProminent).tint(tint ?? .accentColor)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
