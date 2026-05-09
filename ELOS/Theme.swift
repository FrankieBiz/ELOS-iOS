import SwiftUI

// MARK: - Theme Mode

enum ThemeMode: String, CaseIterable, Codable {
    case carbon   // pure black, mono
    case iron     // black + electric blue
    case inferno  // black + scarlet
    case chalk    // white, charcoal

    var label: String {
        switch self {
        case .carbon:  return "Carbon"
        case .iron:    return "Iron"
        case .inferno: return "Inferno"
        case .chalk:   return "Chalk"
        }
    }

    var description: String {
        switch self {
        case .carbon:  return "Pure black, no-color minimal"
        case .iron:    return "Black with electric blue"
        case .inferno: return "Black with scarlet"
        case .chalk:   return "White with charcoal"
        }
    }

    var icon: String {
        switch self {
        case .carbon:  return "circle.fill"
        case .iron:    return "bolt.circle.fill"
        case .inferno: return "flame.circle.fill"
        case .chalk:   return "sun.max.circle.fill"
        }
    }

    var isDark: Bool { self != .chalk }
    var colorScheme: ColorScheme { isDark ? .dark : .light }
}

// MARK: - Theme Skin (all semantic tokens per theme)

struct ThemeSkin {
    let background: Color
    let surface: Color
    let surfaceHigh: Color
    let accent: Color
    let accentSubtle: Color
    let onAccent: Color
    let label: Color
    let labelSub: Color
    let labelFaint: Color
    let hairline: Color
    let destructive: Color
    let success: Color
    let colorScheme: ColorScheme
}

extension ThemeSkin {
    static let carbon = ThemeSkin(
        background:   Color(hex: "#000000"),
        surface:      Color(hex: "#111111"),
        surfaceHigh:  Color(hex: "#1C1C1E"),
        accent:       Color(hex: "#F4F4F5"),
        accentSubtle: Color(hex: "#F4F4F5").opacity(0.08),
        onAccent:     Color(hex: "#000000"),
        label:        Color(hex: "#FFFFFF"),
        labelSub:     Color(hex: "#8A8A8E"),
        labelFaint:   Color(hex: "#48484A"),
        hairline:     Color(hex: "#2C2C2E"),
        destructive:  Color(hex: "#E11D2A"),
        success:      Color(hex: "#30D158"),
        colorScheme:  .dark
    )

    static let iron = ThemeSkin(
        background:   Color(hex: "#000000"),
        surface:      Color(hex: "#0D0D14"),
        surfaceHigh:  Color(hex: "#16161E"),
        accent:       Color(hex: "#3B82F6"),
        accentSubtle: Color(hex: "#3B82F6").opacity(0.12),
        onAccent:     Color(hex: "#FFFFFF"),
        label:        Color(hex: "#FFFFFF"),
        labelSub:     Color(hex: "#8A8A8E"),
        labelFaint:   Color(hex: "#48484A"),
        hairline:     Color(hex: "#1E1E2A"),
        destructive:  Color(hex: "#E11D2A"),
        success:      Color(hex: "#30D158"),
        colorScheme:  .dark
    )

    static let inferno = ThemeSkin(
        background:   Color(hex: "#000000"),
        surface:      Color(hex: "#0F0F0F"),
        surfaceHigh:  Color(hex: "#181818"),
        accent:       Color(hex: "#DC2626"),
        accentSubtle: Color(hex: "#DC2626").opacity(0.10),
        onAccent:     Color(hex: "#FFFFFF"),
        label:        Color(hex: "#FFFFFF"),
        labelSub:     Color(hex: "#8A8A8E"),
        labelFaint:   Color(hex: "#48484A"),
        hairline:     Color(hex: "#2A1818"),
        destructive:  Color(hex: "#DC2626"),
        success:      Color(hex: "#30D158"),
        colorScheme:  .dark
    )

    static let chalk = ThemeSkin(
        background:   Color(hex: "#F5F5F7"),
        surface:      Color(hex: "#FFFFFF"),
        surfaceHigh:  Color(hex: "#FFFFFF"),
        accent:       Color(hex: "#1A1A1A"),
        accentSubtle: Color(hex: "#1A1A1A").opacity(0.06),
        onAccent:     Color(hex: "#FFFFFF"),
        label:        Color(hex: "#0A0A0A"),
        labelSub:     Color(hex: "#6E6E73"),
        labelFaint:   Color(hex: "#AEAEB2"),
        hairline:     Color(hex: "#D1D1D6"),
        destructive:  Color(hex: "#E11D2A"),
        success:      Color(hex: "#28A745"),
        colorScheme:  .light
    )

    static func forMode(_ mode: ThemeMode) -> ThemeSkin {
        switch mode {
        case .carbon:  return .carbon
        case .iron:    return .iron
        case .inferno: return .inferno
        case .chalk:   return .chalk
        }
    }
}

// MARK: - Environment Key

private struct SkinKey: EnvironmentKey {
    static let defaultValue = ThemeSkin.inferno
}

extension EnvironmentValues {
    var skin: ThemeSkin {
        get { self[SkinKey.self] }
        set { self[SkinKey.self] = newValue }
    }
}

// MARK: - Design Tokens

enum Theme {
    enum Space {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 20
        static let xl:  CGFloat = 28
        static let xxl: CGFloat = 40
    }

    enum Radius {
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 10
        static let lg:   CGFloat = 14
        static let pill: CGFloat = 999
    }

    enum Font {
        static func display(_ size: CGFloat = 56) -> SwiftUI.Font {
            .system(size: size, weight: .black)
        }
        static func heading(_ size: CGFloat = 22) -> SwiftUI.Font {
            .system(size: size, weight: .heavy)
        }
        static func body(_ size: CGFloat = 15, _ weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight)
        }
        static func mono(_ size: CGFloat = 15, _ weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
        static let label:   SwiftUI.Font = .system(size: 10, weight: .heavy)
        static let section: SwiftUI.Font = .system(size: 11, weight: .heavy)
    }

    enum Motion {
        static let snappy = Animation.spring(response: 0.26, dampingFraction: 0.82)
        static let quick  = Animation.spring(response: 0.18, dampingFraction: 0.88)
        static let smooth = Animation.easeInOut(duration: 0.22)
        static let bouncy = Animation.spring(response: 0.38, dampingFraction: 0.68)
        static let celebrate = Animation.spring(response: 0.42, dampingFraction: 0.60)
    }
}

// MARK: - Backwards-compat color aliases (non-themed views fall back to Inferno palette)

extension Color {
    static let brand        = Color(hex: "#DC2626")
    static let brandSuccess = Color(hex: "#30D158")
    static let brandWarn    = Color(hex: "#FF9F0A")
    static let brandDanger  = Color(hex: "#DC2626")
    static let brandInfo    = Color(hex: "#3B82F6")
    static let brandTrophy  = Color(hex: "#F59E0B")

    static let surfaceBG       = Color(hex: "#000000")
    static let surfaceRaised   = Color(hex: "#111111")
    static let surfaceInset    = Color(hex: "#1C1C1E")
    static let hairline        = Color(hex: "#2C2C2E")
}

extension ShapeStyle where Self == Color {
    static var brand:         Color { .brand }
    static var brandSuccess:  Color { .brandSuccess }
    static var brandWarn:     Color { .brandWarn }
    static var brandDanger:   Color { .brandDanger }
    static var brandInfo:     Color { .brandInfo }
    static var brandTrophy:   Color { .brandTrophy }
    static var surfaceBG:     Color { .surfaceBG }
    static var surfaceRaised: Color { .surfaceRaised }
    static var surfaceInset:  Color { .surfaceInset }
    static var hairline:      Color { .hairline }
}

// MARK: - Hex Color init

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

// MARK: - Haptics

enum Haptic {
    static func light()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft()      { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid()     { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func medium()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()     { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success()   { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()   { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()     { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Date helpers

extension Date {
    var dayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: self)
    }
    var prettyDay: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f.string(from: self).uppercased()
    }
    var shortDate: String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f.string(from: self)
    }
    var hourMinute: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: self)
    }
}

// MARK: - Numeric helpers

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
    var prettyWeight: String {
        truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", self)
            : String(format: "%.1f", self)
    }
}

extension Int { var nonZero: Int? { self == 0 ? nil : self } }
