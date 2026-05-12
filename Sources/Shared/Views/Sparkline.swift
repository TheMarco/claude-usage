import SwiftUI

struct Sparkline: View {
    let values: [Double]
    let gradient: LinearGradient

    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 0.0001)
            let stepX = values.count > 1
                ? geo.size.width / CGFloat(values.count - 1)
                : 0

            let line = Path { p in
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height - CGFloat(v / maxV) * geo.size.height
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else      { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            let fill = Path { p in
                guard !values.isEmpty else { return }
                p.move(to: CGPoint(x: 0, y: geo.size.height))
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height - CGFloat(v / maxV) * geo.size.height
                    p.addLine(to: CGPoint(x: x, y: y))
                }
                p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                p.closeSubpath()
            }

            ZStack {
                fill.fill(gradient).opacity(0.18)
                line.stroke(gradient,
                            style: StrokeStyle(lineWidth: 1.6,
                                               lineCap: .round,
                                               lineJoin: .round))
            }
        }
    }
}
