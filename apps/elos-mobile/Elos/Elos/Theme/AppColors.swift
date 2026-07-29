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

// MARK: - Card Modifier

/// The app's one card surface. Three deliberate details:
/// - `.continuous` corners (squircles) rather than the default circular arc — the shape iOS itself
///   uses, and the single clearest tell between a stock-looking and a considered SwiftUI app.
/// - One radius for every card, from `Radius.card`, so nothing drifts (this file previously said
///   12 while several hand-rolled cards used 16).
/// - A whisper of elevation. The app was entirely flat, so cards and the grouped background read as
///   one sheet; this separates them without looking like a drop-shadowed 2013 skeuomorph.
struct ElosCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.card
    func body(content: Content) -> some View {
        content
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.055), radius: 10, x: 0, y: 3)
    }
}

extension View {
    func elosCard(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(ElosCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Button Styles
struct ElosFilledButtonStyle: ButtonStyle {
    var color: Color = .tint
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            // Was `tertiarySystemGroupedBackground`, which is the *same* grey as the
            // `systemGroupedBackground` pages these buttons sit on in light mode — the button was
            // effectively invisible, reading as bare floating text. A raised fill plus a hairline
            // border gives it a real edge on both light and dark.
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ElosDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .bold))
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
