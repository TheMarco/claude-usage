import SwiftUI

/// One bar row from the claude.ai usage page — title left, % right, bar below.
struct PlanRow: View {
    let title: String
    let subtitle: String?
    let percent: Double          // 0...100
    let trailing: String?        // "10% used" / "0 / 15"
    let trackColor: Color
    let fillGradient: LinearGradient
    var compact: Bool = false

    @State private var displayedPercent: Double?
    @State private var hasAppeared = false

    private var shown: Double { displayedPercent ?? percent }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: compact ? 11 : 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackColor)
                    Capsule()
                        .fill(fillGradient)
                        .frame(width: max(4, geo.size.width * CGFloat(min(max(shown / 100.0, 0), 1.0))))
                }
            }
            .frame(height: compact ? 5 : 6)
        }
        .onAppear {
            displayedPercent = percent
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                hasAppeared = true
            }
        }
        .onChange(of: percent) { _, newValue in
            if hasAppeared {
                withAnimation(.easeOut(duration: 0.6)) {
                    displayedPercent = newValue
                }
            } else {
                displayedPercent = newValue
            }
        }
    }
}
