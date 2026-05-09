import SwiftUI

// =====================================================================
//  OBSIDIAN  ·  the only design system this app has.
//  material black · platinum white · restrained · wealth · aura
// =====================================================================

// MARK: - Color tokens

extension Color {
    // Surfaces — warm-leaning blacks for material depth
    static let obsidian     = Color(hex: "#050505") // root background
    static let onyx         = Color(hex: "#0B0B0D") // primary card surface
    static let graphite     = Color(hex: "#14141A") // elevated surface
    static let smoke        = Color(hex: "#1C1C24") // input / inset
    static let mist         = Color(hex: "#2A2A33") // hairline high / emphasized border
    static let hairlineClr  = Color(hex: "#1A1A20") // default hairline

    // Text — warm whites, never pure
    static let pearl        = Color(hex: "#F2F2F4") // primary text
    static let silver       = Color(hex: "#A8A8B0") // secondary text
    static let shadowTxt    = Color(hex: "#5A5A62") // tertiary / disabled

    // Aura — the glow, slightly cool
    static let auraCore     = Color(hex: "#FFFFFF")
    static let auraHalo     = Color(hex: "#E8EEFF") // blue-white premium halo

    // Status
    static let crimson      = Color(hex: "#E04848") // destructive only
    static let sterling     = Color(hex: "#D4D4DA") // success / positive
    static let amber        = Color(hex: "#C9A86A") // warning — used sparingly

    // Legacy vBG / vSurface / vSignal aliases (all non-touched files keep compiling)
    static let vBG          = obsidian
    static let vSurface     = onyx
    static let vSurfaceHigh = graphite
    static let vInk         = smoke
    static let vInset       = smoke
    static let vLine        = hairlineClr
    static let vLineHigh    = mist
    static let vLabel       = pearl
    static let vLabelMute   = silver
    static let vLabelFaint  = shadowTxt
    static let vSignal      = pearl        // was yellow, now platinum
    static let vSignalDeep  = silver
    static let vSignalSoft  = Color(hex: "#FFFFFF").opacity(0.08)
    static let vAura        = auraCore
    static let vDanger      = crimson
    static let vSuccess     = sterling
    static let vWarn        = amber
}

// Back-compat brand aliases
extension Color {
    static let brand        = pearl
    static let brandSuccess = sterling
    static let brandWarn    = amber
    static let brandDanger  = crimson
    static let brandInfo    = pearl
    static let brandTrophy  = amber

    static let surfaceBG     = obsidian
    static let surfaceRaised = onyx
    static let surfaceInset  = smoke
    static let hairline      = hairlineClr
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

    static var vSignal:      Color { .vSignal }
    static var vLabel:       Color { .vLabel }
    static var vLabelMute:   Color { .vLabelMute }
    static var vLabelFaint:  Color { .vLabelFaint }
    static var vBG:          Color { .vBG }
    static var vSurface:     Color { .vSurface }
    static var vSurfaceHigh: Color { .vSurfaceHigh }
    static var vInk:         Color { .vInk }
    static var vInset:       Color { .vInset }
    static var vLine:        Color { .vLine }
    static var vLineHigh:    Color { .vLineHigh }
    static var vDanger:      Color { .vDanger }
    static var vSuccess:     Color { .vSuccess }
    static var vWarn:        Color { .vWarn }
    static var pearl:        Color { .pearl }
    static var silver:       Color { .silver }
    static var obsidian:     Color { .obsidian }
    static var onyx:         Color { .onyx }
    static var graphite:     Color { .graphite }
    static var smoke:        Color { .smoke }
    static var mist:         Color { .mist }
    static var crimson:      Color { .crimson }
    static var sterling:     Color { .sterling }
    static var amber:        Color { .amber }
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

// MARK: - Theme namespace

enum Theme {
    enum Space {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 10
        static let sm:  CGFloat = 14
        static let md:  CGFloat = 20
        static let lg:  CGFloat = 28
        static let xl:  CGFloat = 40
        static let xxl: CGFloat = 56
    }

    enum Radius {
        static let none: CGFloat = 0
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 22
        static let pill: CGFloat = 999
    }

    enum Font {
        // Display — SF Pro Display, light, tight tracking
        static func display(_ size: CGFloat = 56) -> SwiftUI.Font {
            .system(size: size, weight: .light, design: .default)
        }
        // Title — regular weight
        static func title(_ size: CGFloat = 28) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .default)
        }
        // Heading — medium
        static func heading(_ size: CGFloat = 16) -> SwiftUI.Font {
            .system(size: size, weight: .medium, design: .default)
        }
        // Body
        static func body(_ size: CGFloat = 15, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
        // Mono — tabular numbers only
        static func mono(_ size: CGFloat = 14, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
        // Label — the only ALL CAPS usage (micro text, nav, section headers)
        static let tag:     SwiftUI.Font = .system(size: 9,  weight: .semibold)
        static let micro:   SwiftUI.Font = .system(size: 10, weight: .semibold)
        static let label:   SwiftUI.Font = .system(size: 10, weight: .semibold)
        static let section: SwiftUI.Font = .system(size: 10, weight: .semibold)
    }

    enum Motion {
        static let silk      = Animation.easeOut(duration: 0.45)
        static let glide     = Animation.easeInOut(duration: 0.55)
        static let press     = Animation.easeOut(duration: 0.18)
        static let snappy    = Animation.easeOut(duration: 0.22) // back-compat
        static let quick     = Animation.easeOut(duration: 0.14)
        static let smooth    = Animation.easeInOut(duration: 0.30)
        static let bouncy    = Animation.spring(response: 0.40, dampingFraction: 0.75) // back-compat
        static let celebrate = Animation.spring(response: 0.50, dampingFraction: 0.70)
        static let breath    = Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)
    }
}

// MARK: - Material fill (subtle vertical gradient for depth)

struct MaterialFill: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        LinearGradient(
            colors: [
                Color.onyx.opacity(0.98),
                Color.onyx
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Glow modifier (layered white shadows = halo aura)

struct GlowModifier: ViewModifier {
    var active: Bool = true
    var radius: CGFloat = 14
    var color: Color = .auraCore
    var intensity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(active ? 0.50 * intensity : 0), radius: radius * 0.4, x: 0, y: 0)
            .shadow(color: color.opacity(active ? 0.28 * intensity : 0), radius: radius,        x: 0, y: 0)
            .shadow(color: color.opacity(active ? 0.14 * intensity : 0), radius: radius * 2.0,  x: 0, y: 0)
            .animation(Theme.Motion.smooth, value: active)
            .animation(Theme.Motion.smooth, value: intensity)
    }
}

extension View {
    func glow(active: Bool = true, radius: CGFloat = 14, color: Color = .auraCore, intensity: Double = 1.0) -> some View {
        modifier(GlowModifier(active: active, radius: radius, color: color, intensity: intensity))
    }
}

// MARK: - Breath glow (ambient, looping)

struct BreathGlowModifier: ViewModifier {
    @State private var breathing = false
    var minIntensity: Double = 0.15
    var maxIntensity: Double = 0.38
    var radius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .shadow(color: Color.auraCore.opacity(breathing ? maxIntensity : minIntensity), radius: radius * 0.5, x: 0, y: 0)
            .shadow(color: Color.auraHalo.opacity(breathing ? maxIntensity * 0.6 : minIntensity * 0.4), radius: radius, x: 0, y: 0)
            .shadow(color: Color.auraCore.opacity(breathing ? maxIntensity * 0.3 : 0), radius: radius * 2, x: 0, y: 0)
            .onAppear {
                withAnimation(Theme.Motion.breath) { breathing = true }
            }
    }
}

extension View {
    func breathGlow(minIntensity: Double = 0.15, maxIntensity: Double = 0.38, radius: CGFloat = 20) -> some View {
        modifier(BreathGlowModifier(minIntensity: minIntensity, maxIntensity: maxIntensity, radius: radius))
    }
}

// MARK: - Edge highlight (milled surface feel)

struct EdgeHighlightModifier: ViewModifier {
    var radius: CGFloat = Theme.Radius.md

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.black.opacity(0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }
}

extension View {
    func edgeHighlight(radius: CGFloat = Theme.Radius.md) -> some View {
        modifier(EdgeHighlightModifier(radius: radius))
    }
}

// MARK: - Skin (kept for environment compatibility)

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
        background:   .obsidian,
        surface:      .onyx,
        surfaceHigh:  .graphite,
        accent:       .pearl,
        accentSubtle: .vSignalSoft,
        onAccent:     .obsidian,
        label:        .pearl,
        labelSub:     .silver,
        labelFaint:   .shadowTxt,
        hairline:     .hairlineClr,
        destructive:  .crimson,
        success:      .sterling,
        colorScheme:  .dark
    )

    static func forMode(_ mode: ThemeMode) -> ThemeSkin { .vigil }
}

enum ThemeMode: String, CaseIterable, Codable {
    case vigil
    var label: String       { "Obsidian" }
    var description: String { "Material black. Platinum white. The only theme." }
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
        let f = DateFormatter(); f.dateFormat = "EEEE · MMM d"; return f.string(from: self)
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
