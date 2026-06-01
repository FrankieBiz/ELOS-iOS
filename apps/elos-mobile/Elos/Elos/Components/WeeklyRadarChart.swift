import SwiftUI

struct RadarAxis {
    let label: String
    let current: Double  // 0...1 normalized
    let prior: Double    // 0...1 normalized
}

struct WeeklyRadarChart: View {
    let axes: [RadarAxis]
    var size: CGFloat = 200

    private var tintColor: Color { Color(red: 0.84, green: 0.35, blue: 0.18) }

    var body: some View {
        ZStack {
            Canvas { ctx, canvasSize in
                guard axes.count >= 3 else { return }
                let n = axes.count
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let maxR = min(canvasSize.width, canvasSize.height) / 2 - 28

                // Grid rings
                for ring in [0.33, 0.67, 1.0] {
                    var path = Path()
                    for i in 0..<n {
                        let angle = 2 * Double.pi * Double(i) / Double(n) - Double.pi / 2
                        let r = maxR * ring
                        let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                    let opacity = ring == 1.0 ? 0.2 : 0.1
                    ctx.stroke(path, with: .color(.gray.opacity(opacity)), lineWidth: 1)
                }

                // Axis spokes
                for i in 0..<n {
                    let angle = 2 * Double.pi * Double(i) / Double(n) - Double.pi / 2
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x + maxR * cos(angle), y: center.y + maxR * sin(angle)))
                    ctx.stroke(path, with: .color(.gray.opacity(0.1)), lineWidth: 1)
                }

                // Prior week polygon (dashed outline)
                let hasAnything = axes.contains { $0.prior > 0 }
                if hasAnything {
                    var priorPath = Path()
                    for i in 0..<n {
                        let angle = 2 * Double.pi * Double(i) / Double(n) - Double.pi / 2
                        let r = maxR * max(0.03, axes[i].prior)
                        let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                        if i == 0 { priorPath.move(to: pt) } else { priorPath.addLine(to: pt) }
                    }
                    priorPath.closeSubpath()
                    ctx.stroke(priorPath,
                               with: .color(.gray.opacity(0.45)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }

                // Current week polygon (filled + stroke)
                var currentPath = Path()
                for i in 0..<n {
                    let angle = 2 * Double.pi * Double(i) / Double(n) - Double.pi / 2
                    let r = maxR * max(0.03, axes[i].current)
                    let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                    if i == 0 { currentPath.move(to: pt) } else { currentPath.addLine(to: pt) }
                }
                currentPath.closeSubpath()
                ctx.fill(currentPath, with: .color(Color(red: 0.84, green: 0.35, blue: 0.18).opacity(0.28)))
                ctx.stroke(currentPath,
                           with: .color(Color(red: 0.84, green: 0.35, blue: 0.18).opacity(0.85)),
                           lineWidth: 2)
            }
            .frame(width: size, height: size)

            // Axis labels
            GeometryReader { geo in
                let n = axes.count
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let maxR = min(geo.size.width, geo.size.height) / 2 - 28
                let labelR = maxR + 18

                ForEach(0..<n, id: \.self) { i in
                    let angle = 2 * Double.pi * Double(i) / Double(n) - Double.pi / 2
                    let x = center.x + labelR * cos(angle)
                    let y = center.y + labelR * sin(angle)

                    Text(axes[i].label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize()
                        .position(x: x, y: y)
                }
            }
            .frame(width: size, height: size)
        }
    }
}
