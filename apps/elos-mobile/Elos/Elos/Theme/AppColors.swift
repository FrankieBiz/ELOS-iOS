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
    // Accent.
    //
    // Computed rather than stored, so the ~600 existing `Color.tint` call sites follow the accent the
    // user picked without any of them changing. That indirection is the entire reason personalization
    // could be added without a sweep through every view in the app: the token is the seam.
    //
    // Statics can't publish changes, so `ContentView` keys its content on `ThemeStore.revision` — the
    // tree re-reads these on the next render. See `ThemeStore`.
    static var tint: Color     { ThemeStore.shared.accentColor }
    static var tintSoft: Color { ThemeStore.shared.accentColor.opacity(0.12) }

    /// Legible foreground for content sitting *on* `tint`. The app used to hard-code `.white`, which
    /// is fine for one fixed dark orange and wrong the moment someone picks a pale custom colour.
    static var onTint: Color   { ThemeStore.shared.onAccentColor }

    /// White or black, whichever reads better on `background`.
    static func legibleForeground(on background: Color) -> Color {
        relativeLuminance(of: background) > 0.45 ? .black : .white
    }

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

    // Per-muscle palette. One definition: `muscleGroupColor` (template strips) and `dayFocusColor`
    // (split day chips) each carried their own copy of these exact hexes, so a palette tweak had to be
    // made twice or the two views would disagree about what colour "back" is.
    static let mBack       = Color(hex: "007AFF")
    static let mBiceps     = Color(hex: "AF52DE")
    static let mTriceps    = Color(hex: "BF5AF2")
    static let mQuads      = Color(hex: "FFD60A")
    static let mHamstrings = Color(hex: "FF9F0A")
    static let mGlutes     = Color(hex: "FF6369")
    static let mCore       = Color(hex: "32ADE6")
}

// MARK: - Elevation
//
// The app's one card surface, and the depth language behind it. Details that matter:
// - `.continuous` corners (squircles) rather than the default circular arc — the shape iOS itself
//   uses, and one of the clearest tells between a stock-looking and a considered SwiftUI app.
// - One radius for every card, from `Radius.card`, so nothing drifts.
//
// The app runs dark on a near-black page, and a **black shadow is invisible on black** — so the one
// depth cue `elosCard` had did nothing, and every surface read as the same flat grey rectangle with a
// mushy edge. Depth in dark UI comes from two things instead: surface lightness, and a hairline that
// catches "light" along the edge. The system greys already give the lightness ramp
// (page → secondary → tertiary); this adds the edge.
//
// Three levels, and that's deliberately all:
//   0 page      systemGroupedBackground        no border
//   1 card      secondarySystemGroupedBackground  hairline — the default surface
//   2 well      tertiarySystemGroupedBackground   fainter hairline — nested content inside a card
//
// The shadow stays for light mode, where it does read. Keep it soft: a hard drop shadow is the fastest
// way to make an app look like a 2013 template.
enum Elevation {
    /// Hairline along a level-1 surface. White at low alpha, so it lightens the edge in dark mode and
    /// effectively disappears in light mode (where the shadow is doing the work).
    static let cardHairline = Color.white.opacity(0.07)
    /// Nested surfaces sit closer to their parent, so their edge is quieter.
    static let wellHairline = Color.white.opacity(0.05)
}

// The five looks `CardStyle` offers. `elevated` is the original, to the value — the fill, hairline
// and shadow above. The others change all three together, because a "flat" card that keeps its drop
// shadow hasn't actually gone flat.
struct ElosCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.card

    private var style: CardStyle { ThemeStore.shared.cardStyle }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(shape)
            .overlay { shape.strokeBorder(border, lineWidth: borderWidth) }
            .shadow(color: .black.opacity(shadowOpacity), radius: 10, x: 0, y: 3)
    }

    @ViewBuilder
    private var fill: some View {
        switch style {
        case .elevated, .flat:
            Color(UIColor.secondarySystemGroupedBackground)
        case .outlined:
            // Page-coloured, so the drawn edge is the only thing defining the card.
            Color(UIColor.systemGroupedBackground)
        case .glass:
            Rectangle().fill(.ultraThinMaterial)
        case .tinted:
            Color(UIColor.secondarySystemGroupedBackground)
                .overlay(Color.tint.opacity(0.10))
        }
    }

    private var border: Color {
        switch style {
        case .elevated, .glass: return Elevation.cardHairline
        case .flat:             return .clear
        case .outlined:         return Color.primary.opacity(0.14)
        case .tinted:           return Color.tint.opacity(0.30)
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .elevated, .glass: return 0.5
        case .flat:             return 0
        case .outlined:         return 1
        case .tinted:           return 1
        }
    }

    private var shadowOpacity: Double {
        // Only `elevated` claims depth. On the others a shadow is the tell that the style change
        // was cosmetic.
        style == .elevated ? 0.055 : 0
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
            // Derived from the fill rather than assumed white: this style is used with `.tint` (now
            // whatever accent the user picked, custom hex included) and with module colours like
            // `.mGym`, some of which are light enough that white text on them fails contrast.
            .foregroundStyle(Color.legibleForeground(on: color))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.elosPress, value: configuration.isPressed)
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
            .animation(.elosPress, value: configuration.isPressed)
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
            .animation(.elosPress, value: configuration.isPressed)
    }
}

extension View {
    func elosPrimaryButton(color: Color = .tint) -> some View { buttonStyle(ElosFilledButtonStyle(color: color)) }
    func elosSecondaryButton() -> some View { buttonStyle(ElosSecondaryButtonStyle()) }
    func elosDestructiveButton() -> some View { buttonStyle(ElosDestructiveButtonStyle()) }
}
