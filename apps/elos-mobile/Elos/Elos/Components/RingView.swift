import SwiftUI

/// The one progress-ring component in the app. There used to be three near-identical
/// stroke-and-trim circles (this file, `TodayView`'s private `SmallRingView`, and `MeView`'s
/// `wellnessRing`), each with its own track colour and no shared visual language. This is the
/// single implementation all three now use — a neutral track (colour on screen always means real
/// progress, never a muddy tint of the ring's own hue) and a subtle angular gradient sweep on the
/// fill instead of a flat stroke, which is what actually sells "premium" on a ring: compare Apple's
/// own Activity rings, which are never a single flat colour.
struct ProgressRing<Content: View>: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 6
    var size: CGFloat = 46
    @ViewBuilder var content: () -> Content

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.16), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.55), color],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(clamped, 0.001))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.elosProgress, value: clamped)

            content()
        }
        .frame(width: size, height: size)
    }
}

extension ProgressRing where Content == EmptyView {
    init(progress: Double, color: Color, lineWidth: CGFloat = 6, size: CGFloat = 46) {
        self.init(progress: progress, color: color, lineWidth: lineWidth, size: size) { EmptyView() }
    }
}

#Preview {
    VStack(spacing: 24) {
        ProgressRing(progress: 0.65, color: .mNutri, size: 90) {
            VStack(spacing: 2) {
                Text("1950").font(.system(size: 18, weight: .bold, design: .monospaced))
                Text("kcal").font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        ProgressRing(progress: 0.4, color: .mHabits, size: 28)
    }
    .padding()
    .background(Color.black)
}
