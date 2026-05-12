import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        Group {
            if entry.showClaude && entry.showCodex {
                dualBody
            } else if entry.showCodex {
                singleBody(
                    asset: "openai",
                    label: "CODEX",
                    tier: entry.codex?.planTier,
                    percent: codexPct,
                    sublabel: "5h",
                    resets: codexResets,
                    angular: Theme.codexAngular,
                    linear: Theme.codexLinear
                )
            } else {
                singleBody(
                    asset: "clawd",
                    label: "CLAUDE",
                    tier: entry.plan?.planTier,
                    percent: claudePct,
                    sublabel: "session",
                    resets: claudeResets,
                    angular: Theme.claudeAngular,
                    linear: Theme.claudeLinear
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .containerBackground(for: .widget) {
            Theme.surface
        }
    }

    // MARK: - Data

    private var claudePct: Double {
        entry.plan?.currentSession?.usedPercent ?? 0
    }
    private var claudeResets: Date? {
        entry.plan?.currentSession?.resetsAt
    }
    private var codexPct: Double {
        let local = entry.summary.byProvider["codex"]
        return entry.codex?.fiveHour?.usedPercent ?? local?.primaryLimit?.usedPercent ?? 0
    }
    private var codexResets: Date? {
        let local = entry.summary.byProvider["codex"]
        return entry.codex?.fiveHour?.resetsAt ?? local?.primaryLimit?.resetsAt
    }

    // MARK: - Dual provider layout (both Claude + Codex)

    private var dualBody: some View {
        VStack(spacing: 8) {
            providerStripe(
                asset: "clawd",
                assetSize: CGSize(width: 18, height: 12),
                label: "CLAUDE",
                percent: claudePct,
                sublabel: "session",
                angular: Theme.claudeAngular,
                linear: Theme.claudeLinear
            )
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
            providerStripe(
                asset: "openai",
                assetSize: CGSize(width: 14, height: 12),
                label: "CODEX",
                percent: codexPct,
                sublabel: "5h",
                angular: Theme.codexAngular,
                linear: Theme.codexLinear
            )
        }
    }

    private func providerStripe(asset: String,
                                assetSize: CGSize,
                                label: String,
                                percent: Double,
                                sublabel: String,
                                angular: AngularGradient,
                                linear: LinearGradient) -> some View {
        HStack(spacing: 10) {
            ZStack {
                UsageRing(progress: percent / 100.0, gradient: angular, lineWidth: 5)
                    .frame(width: 48, height: 48)
                Text("\(Int(percent.rounded()))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(linear)
                    .contentTransition(.numericText())
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(asset)
                        .resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                        .frame(width: assetSize.width, height: assetSize.height)
                    Text(label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text("\(Int(percent.rounded()))% · \(sublabel)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Single-provider layout (full ring)

    private func singleBody(asset: String,
                            label: String,
                            tier: String?,
                            percent: Double,
                            sublabel: String,
                            resets: Date?,
                            angular: AngularGradient,
                            linear: LinearGradient) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(asset)
                    .resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 14)
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                if let tier {
                    Text(tier)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            ZStack {
                UsageRing(progress: percent / 100.0, gradient: angular, lineWidth: 8)
                    .frame(width: 84, height: 84)
                VStack(spacing: -3) {
                    HStack(alignment: .top, spacing: 1) {
                        Text("\(Int(percent.rounded()))")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(linear)
                            .contentTransition(.numericText())
                        Text("%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.top, 6)
                    }
                    Text(sublabel)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let resets {
                Text("resets in \(Fmt.resetsIn(resets))")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }
}
