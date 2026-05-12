import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            // Two ring blocks at the top — equal heights via maxHeight + .top
            // alignment so the orange and blue borders line up exactly.
            HStack(alignment: .top, spacing: 10) {
                if entry.showClaude { claudeCard }
                if entry.showCodex  { codexCard  }
            }
            .fixedSize(horizontal: false, vertical: true)

            // Full Claude plan panel.
            VStack(alignment: .leading, spacing: 5) {
                if entry.showClaude, let plan = entry.plan {
                    if let week = plan.weeklyAllModels {
                        PlanRow(
                            title: "Weekly · All models",
                            subtitle: week.resetsLabel.map { "Resets \($0)" },
                            percent: week.usedPercent,
                            trailing: "\(Int(week.usedPercent.rounded()))% used",
                            trackColor: Color.white.opacity(0.07),
                            fillGradient: Theme.claudeLinear,
                            compact: true
                        )
                    }
                    if let s = plan.weeklySonnetOnly {
                        PlanRow(
                            title: "Sonnet only",
                            subtitle: s.subtitle,
                            percent: s.usedPercent,
                            trailing: "\(Int(s.usedPercent.rounded()))%",
                            trackColor: Color.white.opacity(0.07),
                            fillGradient: Theme.claudeLinear,
                            compact: true
                        )
                    }
                    if let cd = plan.weeklyClaudeDesign {
                        PlanRow(
                            title: "Claude Design",
                            subtitle: cd.subtitle,
                            percent: cd.usedPercent,
                            trailing: "\(Int(cd.usedPercent.rounded()))%",
                            trackColor: Color.white.opacity(0.07),
                            fillGradient: Theme.claudeLinear,
                            compact: true
                        )
                    }
                    if let r = plan.dailyRoutineRuns {
                        PlanRow(
                            title: "Daily routine runs",
                            subtitle: r.subtitle,
                            percent: r.total > 0 ? Double(r.used) / Double(r.total) * 100 : 0,
                            trailing: "\(r.used) / \(r.total)",
                            trackColor: Color.white.opacity(0.07),
                            fillGradient: Theme.claudeLinear,
                            compact: true
                        )
                    }
                } else if entry.claudeStatus == .needsAuth {
                    Text("Open the AI Usage app to sign in to claude.ai.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Codex weekly — symmetric with Claude's weekly bar.
                if entry.showCodex, let cw = entry.codex?.weekly {
                    PlanRow(
                        title: "Codex · Weekly",
                        subtitle: cw.resetsAt.map { "Resets \(Fmt.absoluteShort($0))" },
                        percent: cw.usedPercent,
                        trailing: "\(Int(cw.usedPercent.rounded()))% used",
                        trackColor: Color.white.opacity(0.07),
                        fillGradient: Theme.codexLinear,
                        compact: true
                    )
                }
            }

            footer
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .containerBackground(for: .widget) {
            Theme.surface
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("clawd")
                .resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 22)
            VStack(alignment: .leading, spacing: -2) {
                Text("AI USAGE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.5))
                Text(entry.plan?.planTier.map { "Plan: \($0)" } ?? formattedDate)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            if let bal = entry.plan?.currentBalanceUSD {
                VStack(alignment: .trailing, spacing: -2) {
                    Text(Fmt.currencyExact(bal))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("balance")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Ring cards

    private var claudeCard: some View {
        let session = entry.plan?.currentSession
        let pct = session?.usedPercent ?? 0
        return ringCard(
            asset: "clawd", assetSize: CGSize(width: 24, height: 16),
            label: "CLAUDE",
            tier: entry.plan?.planTier,
            sublabel: "session",
            value: "\(Int(pct.rounded()))%",
            subtitle: session?.resetsAt.map { "resets in \(Fmt.resetsIn($0))" } ?? "no session data",
            progress: pct / 100.0,
            angular: Theme.claudeAngular,
            linear: Theme.claudeLinear
        )
    }

    private var codexCard: some View {
        let local = entry.summary.byProvider["codex"]
        let pct = entry.codex?.fiveHour?.usedPercent ?? local?.primaryLimit?.usedPercent ?? 0
        let resets = entry.codex?.fiveHour?.resetsAt ?? local?.primaryLimit?.resetsAt
        return ringCard(
            asset: "openai", assetSize: CGSize(width: 22, height: 16),
            label: "CODEX",
            tier: entry.codex?.planTier,
            sublabel: "5h",
            value: "\(Int(pct.rounded()))%",
            subtitle: resets.map { "resets in \(Fmt.resetsIn($0))" } ?? "no Codex data",
            progress: pct / 100.0,
            angular: Theme.codexAngular,
            linear: Theme.codexLinear
        )
    }

    private func ringCard(asset: String,
                          assetSize: CGSize,
                          label: String,
                          tier: String?,
                          sublabel: String,
                          value: String,
                          subtitle: String,
                          progress: Double,
                          angular: AngularGradient,
                          linear: LinearGradient) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(asset)
                    .resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                    .frame(width: assetSize.width, height: assetSize.height)
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 4)
                if let tier {
                    Text(tier)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            ZStack {
                UsageRing(progress: progress, gradient: angular, lineWidth: 6)
                    .frame(width: 60, height: 60)
                VStack(spacing: -2) {
                    Text(value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(linear)
                        .contentTransition(.numericText())
                    Text(sublabel)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Text(subtitle)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(linear.opacity(0.22), lineWidth: 1)
                )
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if let plan = entry.plan {
                if let spent = plan.extraUsageSpentUSD, let limit = plan.monthlySpendLimitUSD {
                    footerStat(
                        label: "EXTRA THIS MONTH",
                        value: "\(Fmt.currencyExact(spent)) of \(Fmt.currencyExact(limit))"
                    )
                }
                Spacer()
                Text("Updated \(plan.lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            } else {
                Text("Local data only · plan API not yet connected")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private func footerStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: Date())
    }
}
