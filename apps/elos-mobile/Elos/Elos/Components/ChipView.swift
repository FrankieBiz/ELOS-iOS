import SwiftUI

struct ChipView: View {
    var label: String
    var foreground: Color
    var background: Color
    var font: Font = .caption

    var body: some View {
        Text(label)
            .font(font)
            .fontWeight(.semibold)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

enum SmallButtonStyle { case filled, outline, ghost }

struct SmallButton: View {
    var label: String
    var style: SmallButtonStyle = .filled
    var color: Color = .tint
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(style == .filled ? .white : color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    switch style {
                    case .filled:
                        RoundedRectangle(cornerRadius: 7).fill(color)
                    case .outline:
                        RoundedRectangle(cornerRadius: 7).stroke(color, lineWidth: 1)
                    case .ghost:
                        RoundedRectangle(cornerRadius: 7).fill(Color.clear)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct ModuleBarView: View {
    var color: Color
    var opacity: Double = 1.0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(opacity))
            .frame(width: 3, height: 36)
    }
}

#Preview {
    VStack {
        ChipView(label: "Due soon", foreground: .mExams, background: .mExams.opacity(0.15))
        SmallButton(label: "Start", style: .filled, color: .tint) {}
        SmallButton(label: "Swap",  style: .outline, color: .tint) {}
    }
    .padding()
}
