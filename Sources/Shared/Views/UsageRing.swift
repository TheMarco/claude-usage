import SwiftUI

struct UsageRing: View {
    var progress: Double      // 0...∞ (rendered clamped, with overflow accent if > 1)
    var gradient: AngularGradient
    var lineWidth: CGFloat = 8

    @State private var displayedProgress: Double?
    @State private var hasAppeared = false

    private var shown: Double { displayedProgress ?? progress }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(min(shown, 1.0)))
                .stroke(gradient,
                        style: StrokeStyle(lineWidth: lineWidth,
                                           lineCap: .round))
                .rotationEffect(.degrees(-90))

            if shown > 1.0 {
                Circle()
                    .trim(from: 0, to: CGFloat(min(shown - 1.0, 1.0)))
                    .stroke(Color(red: 1, green: 0.25, blue: 0.35),
                            style: StrokeStyle(lineWidth: lineWidth * 0.45,
                                               lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .onAppear {
            // Render at the actual value immediately, no animation.
            displayedProgress = progress
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                hasAppeared = true
            }
        }
        .onChange(of: progress) { _, newValue in
            if hasAppeared {
                withAnimation(.easeOut(duration: 0.6)) {
                    displayedProgress = newValue
                }
            } else {
                displayedProgress = newValue
            }
        }
    }
}
