import SwiftUI

// =====================================================================
//  VIGIL  ·  the only design system this app has.
//  pure black · signal yellow · sharp · condensed · tactical
// =====================================================================

// MARK: - Color tokens

extension Color {
    // Surfaces — all sit on pure black
    static let vBG          = Color(hex: "#000000") // void
    static let vSurface     = Color(hex: "#0A0A0A") // card
    static let vSurfaceHigh = Color(hex: "#121212") // elevated card
    static let vInk         = Color(hex: "#181818") // pressable ink
    static let vInset       = Color(hex: "#0E0E0E") // input fields

    // Lines
    static let vLine        = Color(hex: "#1F1F1F") // hairline
    static let vLineHigh    = Color(hex: "#2D2D2D") // emphasized border

    // Text
    static let vLabel       = Color(hex: "#F5F5F5") // primary
    static let vLabelMute   = Color(hex: "#8A8A8A") // secondary
    static let vLabelFaint  = Color(hex: "#4A4A4A") // tertiary

    // Signal (the one accent)
    static let vSignal      = Color(hex: "#F5C518") // bat-signal gold
    static let vSignalDeep  = Color(hex: "#C99A0F") // pressed/dim
    static let vSignalSoft  = Color(hex: "#F5C518").opacity(0.14)

    // Status
    static let vDanger      = Color(hex: "#E11D2A")
    static let vSuccess     = Color(hex: "#00D26A")
    static let vWarn        = Color(hex: "#FF8C00")
}

// Backwards-compat aliases (so non-touched files still compile)
extension Color {
    static let brand        = vSignal
    static let brandSuccess = vSuccess
    static let brandWarn    = vWarn
    static let brandDanger  = vDanger
    static let brandInfo    = vSignal
    static let brandTrophy  = vSignal

    static let surfaceBG     = vBG
    static let surfaceRaised = vSurface
    static let surfaceInset  = vInset
    static let hairline      = vLine
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

    static var vSignal:       Color { .vSignal }
    static var vLabel:        Color { .vLabel }
    static var vLabelMute:    Color { .vLabelMute }
    static var vLabelFaint:   Color { .vLabelFaint }
    static var vBG:           Color { .vBG }
    static var vSurface:      Color { .vSurface }
    static var vSurfaceHigh:  Color { .vSurfaceHigh }
    static var vInk:          Color { .vInk }
    static var vInset:        Color { .vInset }
    static var vLine:         Color { .vLine }
    static var vLineHigh:     Color { .vLineHigh }
    static var vDanger:       Color { .vDanger }
    static var vSuccess:      Color { .vSuccess }
    static var vWarn:         Color { .vWarn }
}

// MARK: - Hex init

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

// MARK: - Theme namespace (back-compat alias retained)

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
        static let none: CGFloat = 0
        static let xs:   CGFloat = 2
        static let sm:   CGFloat = 4
        static let md:   CGFloat = 6
        static let lg:   CGFloat = 8
        static let xl:   CGFloat = 12
        static let pill: CGFloat = 999
    }

    enum Font {
        // Display: huge condensed black
        static func display(_ size: CGFloat = 64) -> SwiftUI.Font {
            .system(size: size, weight: .black, design: .default)
        }
        // Title: page titles
        static func title(_ size: CGFloat = 28) -> SwiftUI.Font {
            .system(size: size, weight: .black, design: .default)
        }
        // Heading: card titles
        static func heading(_ size: CGFloat = 16) -> SwiftUI.Font {
            .system(size: size, weight: .heavy, design: .default)
        }
        // Body
        static func body(_ size: CGFloat = 14, _ weight: SwiftUI.Font.Weight = .medium) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
        // Mono — numbers/codes
        static func mono(_ size: CGFloat = 14, _ weight: SwiftUI.Font.Weight = .heavy) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
        // Tag — tiny all-caps
        static let tag:   SwiftUI.Font = .system(size: 9,  weight: .heavy)
        static let micro: SwiftUI.Font = .system(size: 10, weight: .heavy)
        static let label: SwiftUI.Font = .system(size: 11, weight: .heavy)
        static let section: SwiftUI.Font = .system(size: 11, weight: .heavy)
    }

    enum Motion {
        static let snappy   = Animation.spring(response: 0.22, dampingFraction: 0.86)
        static let quick    = Animation.easeOut(duration: 0.14)
        static let smooth   = Animation.easeInOut(duration: 0.20)
        static let bouncy   = Animation.spring(response: 0.34, dampingFraction: 0.70)
        static let celebrate = Animation.spring(response: 0.40, dampingFraction: 0.62)
    }
}

// MARK: - Skin (single Vigil skin — kept for environment compatibility)

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

    static let vigil = ThemeSkin(
        background:   .vBG,
        surface:      .vSurface,
        surfaceHigh:  .vSurfaceHigh,
        accent:       .vSignal,
        accentSubtle: .vSignalSoft,
        onAccent:     .vBG,
        label:        .vLabel,
        labelSub:     .vLabelMute,
        labelFaint:   .vLabelFaint,
        hairline:     .vLine,
        destructive:  .vDanger,
        success:      .vSuccess,
        colorScheme:  .dark
    )

    static func forMode(_ mode: ThemeMode) -> ThemeSkin { .vigil }
}

// Single theme. Enum kept for back-compat with AppState persistence.
enum ThemeMode: String, CaseIterable, Codable {
    case vigil
    var label: String       { "Vigil" }
    var description: String { "Pure black. Signal yellow. The only theme." }
    var icon: String        { "moon.stars.fill" }
    var isDark: Bool        { true }
    var colorScheme: ColorScheme { .dark }
}

private struct SkinKey: EnvironmentKey {
    static let defaultValue = ThemeSkin.vigil
}

extension EnvironmentValues {
    var skin: ThemeSkin {
        get { self[SkinKey.self] }
        set { self[SkinKey.self] = newValue }
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

// MARK: - Date / Numeric helpers

extension Date {
    var dayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: self)
    }
    var prettyDay: String {
        let f = DateFormatter(); f.dateFormat = "EEEE · MMM d"; return f.string(from: self).uppercased()
    }
    var shortDate: String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f.string(from: self)
    }
    var hourMinute: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: self)
    }
}

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
    var prettyWeight: String {
        truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", self)
            : String(format: "%.1f", self)
    }
}

extension Int { var nonZero: Int? { self == 0 ? nil : self } }
