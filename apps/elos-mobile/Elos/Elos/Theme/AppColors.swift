import SwiftUI
import UIKit

// MARK: - Hex Color Init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Design Tokens
extension Color {
    // Accent
    static let tint     = Color(red: 0.84, green: 0.35, blue: 0.18)
    static let tintSoft = Color(red: 0.84, green: 0.35, blue: 0.18).opacity(0.12)

    // Semantic
    static let good = Color(hex: "34C759")
    static let warn = Color(hex: "FF9F0A")
    static let bad  = Color(hex: "FF3B30")

    // Module colors
    static let mGym    = Color(hex: "30D158")
    static let mHabits = Color(hex: "FF9F0A")
    static let mNutri  = Color(hex: "32ADE6")
    static let mHealth = Color(hex: "FF6369")
    static let mSched  = Color(hex: "007AFF")
    static let mAssign = Color(hex: "AF52DE")
    static let mExams  = Color(hex: "FF9F0A")

    // Muscle diagram
    static let muscleHi  = Color(hex: "3B82F6")
    static let muscleSec = Color(hex: "F59E0B")
}

// MARK: - Vigil palette stub (keeps existing font references valid)
extension Color {
    static let vigil = VigilPalette()

    struct VigilPalette {
        let pearl     = Color.primary
        let secondary = Color.secondary
        let accent    = Color.tint
        let danger    = Color.bad
        let warning   = Color.warn
        let success   = Color.good
        let separator = Color.secondary.opacity(0.15)
        var border: Color { separator }
    }
}

// MARK: - Card Modifier
struct ElosCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    func body(content: Content) -> some View {
        content
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func elosCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(ElosCardModifier(cornerRadius: cornerRadius))
    }
    func strndCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(ElosCardModifier(cornerRadius: cornerRadius))
    }
    func elosGlow(_: Color = .clear, radius _: CGFloat = 0) -> some View { self }
    func elosGlassCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(ElosCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Button Styles
struct ElosFilledButtonStyle: ButtonStyle {
    var color: Color = .tint
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ElosButtonStyle: ButtonStyle {
    var color: Color = .tint
    func makeBody(configuration: Configuration) -> some View {
        ElosFilledButtonStyle(color: color).makeBody(configuration: configuration)
    }
}

struct ElosSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ElosDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.bad.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func elosPrimaryButton(color: Color = .tint) -> some View { buttonStyle(ElosFilledButtonStyle(color: color)) }
    func elosSecondaryButton() -> some View { buttonStyle(ElosSecondaryButtonStyle()) }
    func elosDestructiveButton() -> some View { buttonStyle(ElosDestructiveButtonStyle()) }
}
