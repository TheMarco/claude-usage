import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        Group {
            if entry.showClaude && entry.showCodex {
                HStack(spacing: 12) {
                    claudeColumn
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                    codexColumn
                }
            } else if entry.showClaude {
                claudeSolo
            } else if entry.showCodex {
                codexSolo
            } else {
                emptyState
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .containerBackground(for: .widget) {
            Theme.surface
        }
    }

    // MARK: - Solo layouts (single provider, full width)

    private var claudeSolo: some View {
        let session = entry.plan?.currentSession
        let weekly = entry.plan?.weeklyAllModels
        let pct = session?.usedPercent ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image("clawd").resizable().interpolation(.none).aspectRatio(contentMode: .fit).frame(width: 24, height: 16)
                Text("CLAUDE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.3).foregroundStyle(.white.opacity(0.7))
                Spacer()
                if let tier = entry.plan?.planTier {
                    Text(tier).font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            HStack(spacing: 14) {
                ZStack {
                    UsageRing(progress: pct / 100, gradient: Theme.claudeAngular, lineWidth: 9)
                        .frame(width: 88, height: 88)
                    VStack(spacing: -2) {
                        Text("\(Int(pct.rounded()))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.claudeLinear)
                        Text("session").font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    PlanRow(title: "Weekly · All models", subtitle: nil,
                            percent: weekly?.usedPercent ?? 0,
                            trailing: weekly.map { "\(Int($0.usedPercent.rounded()))%" } ?? "—",
                            trackColor: Color.white.opacity(0.08),
                            fillGradient: Theme.claudeLinear)
                    if let resets = session?.resetsAt {
                        Text("session resets in \(Fmt.resetsIn(resets))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
    }

    private var codexSolo: some View {
        let local = entry.summary.byProvider["codex"]
        let primaryPct = entry.codex?.fiveHour?.usedPercent ?? local?.primaryLimit?.usedPercent ?? 0
        let secondaryPct = entry.codex?.weekly?.usedPercent ?? local?.secondaryLimit?.usedPercent ?? 0
        let codex = local
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Theme.codexLinear).frame(width: 8, height: 8)
                Text("CODEX")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.3).foregroundStyle(.white.opacity(0.7))
                Spacer()
                if let lim = codex?.primaryLimit {
                    Text("resets in \(Fmt.resetsIn(lim.resetsAt))")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            HStack(spacing: 14) {
                ZStack {
                    UsageRing(progress: primaryPct / 100, gradient: Theme.codexAngular, lineWidth: 9)
                        .frame(width: 88, height: 88)
                    VStack(spacing: -2) {
                        Text("\(Int(primaryPct.rounded()))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.codexLinear)
                        Text("5h").font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    PlanRow(title: "Weekly", subtitle: nil,
                            percent: secondaryPct,
                            trailing: codex?.secondaryLimit.map { "\(Int($0.usedPercent.rounded()))%" } ?? "—",
                            trackColor: Color.white.opacity(0.08),
                            fillGradient: Theme.codexLinear)
                    if let topModel = codex?.topModel {
                        Text("Most used: \(Fmt.shortModel(topModel))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.3))
            Text("Open the AI Usage app to sign in")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Claude side

    private var claudeColumn: some View {
        let session = entry.plan?.currentSession
        let weekly = entry.plan?.weeklyAllModels
        let pct = session?.usedPercent ?? 0

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image("clawd")
                    .resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 14)
                Text("CLAUDE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                if let tier = entry.plan?.planTier {
                    Text(tier)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer(minLength: 6)

            ZStack {
                UsageRing(progress: pct / 100.0,
                          gradient: Theme.claudeAngular,
                          lineWidth: 8)
                    .frame(width: 72, height: 72)

                VStack(spacing: -2) {
                    HStack(alignment: .top, spacing: 1) {
                        Text("\(Int(pct.rounded()))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.claudeLinear)
                            .contentTransition(.numericText())
                        Text("%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.top, 6)
                    }
                    Text("session")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 6)

            PlanRow(
                title: "Weekly · All models",
                subtitle: nil,
                percent: weekly?.usedPercent ?? 0,
                trailing: weekly.map { "\(Int($0.usedPercent.rounded()))%" } ?? "—",
                trackColor: Color.white.opacity(0.08),
                fillGradient: Theme.claudeLinear,
                compact: true
            )

            if entry.plan == nil {
                Text("Sign in via `claude login`")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Codex side

    private var codexColumn: some View {
        let local = entry.summary.byProvider["codex"]
        // Prefer live CodexUsage (from chatgpt.com API) over local jsonl values.
        let primaryPct = entry.codex?.fiveHour?.usedPercent
            ?? local?.primaryLimit?.usedPercent ?? 0
        let secondaryPct = entry.codex?.weekly?.usedPercent
            ?? local?.secondaryLimit?.usedPercent ?? 0
        let primaryReset = entry.codex?.fiveHour?.resetsAt ?? local?.primaryLimit?.resetsAt

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image("openai")
                    .resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 14)
                Text("CODEX")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                if let tier = entry.codex?.planTier {
                    Text(tier)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                } else if let reset = primaryReset {
                    Text("resets \(Fmt.resetsIn(reset))")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 6)

            ZStack {
                UsageRing(progress: primaryPct / 100.0,
                          gradient: Theme.codexAngular,
                          lineWidth: 8)
                    .frame(width: 72, height: 72)

                VStack(spacing: -2) {
                    HStack(alignment: .top, spacing: 1) {
                        Text("\(Int(primaryPct.rounded()))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.codexLinear)
                            .contentTransition(.numericText())
                        Text("%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.top, 6)
                    }
                    Text("5h")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 6)

            PlanRow(
                title: "Weekly",
                subtitle: nil,
                percent: secondaryPct,
                trailing: "\(Int(secondaryPct.rounded()))%",
                trackColor: Color.white.opacity(0.08),
                fillGradient: Theme.codexLinear,
                compact: true
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
