import SwiftUI

struct AvatarCircle: View {
    let initials: String
    let hex: String
    let size: CGFloat

    private var color: Color { Color(hex: hex) }

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}
