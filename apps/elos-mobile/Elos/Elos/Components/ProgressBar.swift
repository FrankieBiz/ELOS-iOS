import SwiftUI

struct ProgressBar: View {
    var value: Double   // 0.0 – 1.0
    var color: Color
    var height: CGFloat = 6
    var animate: Bool = true

    private var clamped: Double { min(1, max(0, value)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.15))

                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: height)
        .animation(animate ? .easeInOut(duration: 0.6) : nil, value: clamped)
    }
}

#Preview {
    ProgressBar(value: 0.65, color: .tint)
        .padding()
}
