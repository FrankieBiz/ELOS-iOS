import SwiftUI

// MARK: - Design System

/// ELOS design tokens. Single source of truth for color, typography, spacing,
/// radii, and animations. Use these everywhere instead of magic numbers.
enum Theme {

    // MARK: Color
    enum Palette {
        /// Primary action color — deep iOS-leaning orange. Used for CTAs, highlights, brand.
        static let accent = Color("AccentColor", bundle: nil, fallback: Color(red: 1.00, green: 0.42, blue: 0.21))
        /// Secondary brand — used for PRs, achievement, success states.
        static let success = Color(red: 0.18, green: 0.83, blue: 0.42)
        /// Warning — destructive / over-target / over-RPE.
        static let warning = Color(red: 1.00, green: 0.66, blue: 0.06)
        /// Destructive — discard, delete.
        static let danger  = Color(red: 1.00, green: 0.27, blue: 0.22)
        /// Cool accent for rest, recovery, secondary info.
        static let info    = Color(red: 0.39, green: 0.66, blue: 1.00)
        /// PR / royalty / milestone accent.
        static let trophy  = Color(red: 1.00, green: 0.78, blue: 0.04)

        /// Adaptive surface tones (light/dark aware).
        static let surface       = Color(.systemBackground)
        static let surfaceRaised = Color(.secondarySystemBackground)
        static let surfaceInset  = Color(.tertiarySystemBackground)
        static let hairline      = Color(.separator)

        /// Text tokens.
        static let textPrimary   = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary  = Color(.tertiaryLabel)
    }

    // MARK: Typography
    enum Font {
        // Display — for big numbers (weight on plate, time, total volume).
        static func display(_ size: CGFloat = 64) -> SwiftUI.Font {
            .system(size: size, weight: .black, design: .rounded)
        }
        // Title — large headers.
        static func title(_ size: CGFloat = 34) -> SwiftUI.Font {
            .system(size: size, weight: .heavy, design: .rounded)
        }
        // Card heading.
        static func heading(_ size: CGFloat = 20) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        // Body sizes.
        static func body(_ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: 15, weight: weight)
        }
        // Caption / sub-label.
        static func caption(_ weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            .system(size: 12, weight: weight)
        }
        // Section header (uppercase tracked).
        static let section: SwiftUI.Font = .system(size: 12, weight: .semibold)
        // Tabular numbers (for set rows, charts, leaderboards).
        static func mono(_ size: CGFloat = 15, _ weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    // MARK: Spacing scale
    enum Space {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 20
        static let xl:  CGFloat = 28
        static let xxl: CGFloat = 40
    }

    // MARK: Radii
    enum Radius {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
        static let pill: CGFloat = 999
    }

    // MARK: Animations
    enum Motion {
        static let snappy:    Animation = .spring(response: 0.32, dampingFraction: 0.78)
        static let bouncy:    Animation = .spring(response: 0.45, dampingFraction: 0.62)
        static let smooth:    Animation = .easeInOut(duration: 0.28)
        static let soft:      Animation = .spring(response: 0.55, dampingFraction: 0.85)
        static let celebrate: Animation = .spring(response: 0.5, dampingFraction: 0.55)
    }
}

// MARK: - Color helper for fallback if AccentColor asset not present

extension Color {
    /// Fall back to a known color if the named asset is missing — keeps the app
    /// rendering even before the user adds an Asset Catalog entry.
    init(_ name: String, bundle: Bundle?, fallback: Color) {
        // Asset lookup is best-effort. If missing, SwiftUI silently shows clear,
        // so we just always use the fallback to be safe.
        self = fallback
    }
}

// MARK: - Brand color shortcuts (used widely; kept for terseness)

extension Color {
    static let brand        = Theme.Palette.accent
    static let brandSuccess = Theme.Palette.success
    static let brandWarn    = Theme.Palette.warning
    static let brandDanger  = Theme.Palette.danger
    static let brandInfo    = Theme.Palette.info
    static let brandTrophy  = Theme.Palette.trophy

    static let surfaceBG       = Theme.Palette.surface
    static let surfaceRaised   = Theme.Palette.surfaceRaised
    static let surfaceInset    = Theme.Palette.surfaceInset
    static let hairline        = Theme.Palette.hairline
}

// MARK: - ShapeStyle bridge so `.brand` works in foregroundStyle/fill/tint contexts

extension ShapeStyle where Self == Color {
    static var brand:        Color { .brand }
    static var brandSuccess: Color { .brandSuccess }
    static var brandWarn:    Color { .brandWarn }
    static var brandDanger:  Color { .brandDanger }
    static var brandInfo:    Color { .brandInfo }
    static var brandTrophy:  Color { .brandTrophy }

    static var surfaceBG:     Color { .surfaceBG }
    static var surfaceRaised: Color { .surfaceRaised }
    static var surfaceInset:  Color { .surfaceInset }
    static var hairline:      Color { .hairline }
}

// MARK: - Hex initializer (used for habit color hex strings)

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let a, r, g, b: UInt64
        switch s.count {
        case 3:  (a, r, g, b) = (255, (v >> 8) * 17, (v >> 4 & 0xF) * 17, (v & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, v >> 16, v >> 8 & 0xFF, v & 0xFF)
        case 8:  (a, r, g, b) = (v >> 24, v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Haptics (centralized, low-friction)

enum Haptic {
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft()    { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid()   { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()   { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Date helpers

extension Date {
    var dayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }
    var prettyDay: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: self).uppercased()
    }
    var shortDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }
    var hourMinute: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: self)
    }
}

// MARK: - Numeric helpers

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
    /// Format weight cleanly: 225 -> "225", 87.5 -> "87.5"
    var prettyWeight: String {
        truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", self)
            : String(format: "%.1f", self)
    }
}

extension Int { var nonZero: Int? { self == 0 ? nil : self } }
