import SwiftUI

struct RingView: View {
    var value: Double
    var maxValue: Double = 100
    var size: CGFloat = 80
    var strokeWidth: CGFloat = 8
    var color: Color = .tint
    var label: String
    var sublabel: String = ""

    private var progress: Double {
        guard maxValue > 0 else { return 0 }
        return min(1, max(0, value / maxValue))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.7), value: progress)

            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: size * 0.2, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if !sublabel.isEmpty {
                    Text(sublabel)
                        .font(.system(size: size * 0.13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(strokeWidth + 4)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    RingView(value: 65, maxValue: 100, size: 90, color: .mNutri, label: "1950\nkcal")
}
