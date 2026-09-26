import SwiftUI
import UIKit

// MARK: - Accent
//
// Every accent here is dark enough that white text on it clears WCAG AA at body size, because that's
// what the app already does in `ElosFilledButtonStyle`, the segmented control and a dozen filled
// chips. A pastel accent would look fine on a swatch and be unreadable everywhere it's actually used.
// Custom colours get the same treatment through `Color.onTint`, which picks white or black by
// luminance instead of assuming white.

struct AccentOption: Identifiable, Hashable {
    let id: String
    let name: String
    let hex: String

    var color: Color { Color(hex: hex) }
}

enum AccentPalette {
    /// `ember` is the app's original accent, to the hex — switching accents and switching back has
    /// to land exactly where you started.
    static let defaultID = "ember"

    static let all: [AccentOption] = [
        AccentOption(id: "ember",   name: "Ember",   hex: "D6592E"),
        AccentOption(id: "rust",    name: "Rust",    hex: "A63D1F"),
        AccentOption(id: "crimson", name: "Crimson", hex: "E02D46"),
        AccentOption(id: "magenta", name: "Magenta", hex: "D62D78"),
        AccentOption(id: "violet",  name: "Violet",  hex: "8E44D0"),
        AccentOption(id: "indigo",  name: "Indigo",  hex: "5E5CE6"),
        AccentOption(id: "cobalt",  name: "Cobalt",  hex: "0A6CFF"),
        AccentOption(id: "teal",    name: "Teal",    hex: "0E8F9E"),
        AccentOption(id: "forest",  name: "Forest",  hex: "1E8E4E"),
        AccentOption(id: "olive",   name: "Olive",   hex: "6B7A2E"),
        AccentOption(id: "bronze",  name: "Bronze",  hex: "9A6B1F"),
        AccentOption(id: "slate",   name: "Slate",   hex: "556070"),
    ]

    static func option(id: String) -> AccentOption? { all.first { $0.id == id } }

    /// Sentinel id meaning "use `customAccentHex` instead of a preset".
    static let customID = "custom"
}

// MARK: - Appearance

enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Density

/// Multiplies every value in `Space`. Compact fits noticeably more on a screen; spacious is for
/// people who want the app to breathe (and reads better at large Dynamic Type sizes).
enum Density: String, CaseIterable, Codable, Identifiable {
    case compact, cozy, spacious
    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact:  return "Compact"
        case .cozy:     return "Cozy"
        case .spacious: return "Spacious"
        }
    }

    var scale: CGFloat {
        switch self {
        case .compact:  return 0.7
        case .cozy:     return 1.0
        case .spacious: return 1.35
        }
    }

    var icon: String {
        switch self {
        case .compact:  return "arrow.down.right.and.arrow.up.left"
        case .cozy:     return "square.grid.2x2"
        case .spacious: return "arrow.up.left.and.arrow.down.right"
        }
    }
}

// MARK: - Corners

enum CornerStyle: String, CaseIterable, Codable, Identifiable {
    case square, soft, rounded, pill
    var id: String { rawValue }

    var label: String {
        switch self {
        case .square:  return "Square"
        case .soft:    return "Soft"
        case .rounded: return "Rounded"
        case .pill:    return "Pill"
        }
    }

    /// Cards and primary surfaces.
    var card: CGFloat {
        switch self {
        case .square: return 2
        case .soft: return 9
        case .rounded: return 16
        case .pill: return 26
        }
    }
    /// Chips, wells, small controls.
    var control: CGFloat {
        switch self {
        case .square: return 2
        case .soft: return 6
        case .rounded: return 10
        case .pill: return 18
        }
    }
    /// Buttons.
    var button: CGFloat {
        switch self {
        case .square: return 2
        case .soft: return 7
        case .rounded: return 12
        case .pill: return 24
        }
    }
}

// MARK: - Card style

/// How `elosCard()` draws a surface. Five genuinely different looks rather than five shades of grey:
/// the fill, the border and the shadow all change together, because a card that keeps its drop
/// shadow when you asked for "flat" hasn't really changed.
enum CardStyle: String, CaseIterable, Codable, Identifiable {
    case elevated, flat, outlined, glass, tinted
    var id: String { rawValue }

    var label: String {
        switch self {
        case .elevated: return "Elevated"
        case .flat:     return "Flat"
        case .outlined: return "Outlined"
        case .glass:    return "Glass"
        case .tinted:   return "Tinted"
        }
    }

    var blurb: String {
        switch self {
        case .elevated: return "Raised surface with a soft shadow. The default."
        case .flat:     return "Fill only — no border, no shadow."
        case .outlined: return "Page-coloured with a drawn edge."
        case .glass:    return "Translucent, blurring whatever sits behind."
        case .tinted:   return "Washed with your accent colour."
        }
    }
}

// MARK: - Type

enum FontDesignChoice: String, CaseIterable, Codable, Identifiable {
    case standard, rounded, serif, monospaced
    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard:   return "Default"
        case .rounded:    return "Rounded"
        case .serif:      return "Serif"
        case .monospaced: return "Mono"
        }
    }

    var design: Font.Design {
        switch self {
        case .standard:   return .default
        case .rounded:    return .rounded
        case .serif:      return .serif
        case .monospaced: return .monospaced
        }
    }
}

/// Nudges text up or down **relative to** the size the user picked in iOS Settings, rather than
/// replacing it. Someone running the system at an accessibility size and choosing "Larger" here gets
/// larger still — pinning an absolute size would have quietly shrunk their text instead.
enum TextScale: String, CaseIterable, Codable, Identifiable {
    case smaller, small, standard, large, larger
    var id: String { rawValue }

    var label: String {
        switch self {
        case .smaller:  return "XS"
        case .small:    return "S"
        case .standard: return "Default"
        case .large:    return "L"
        case .larger:   return "XL"
        }
    }

    var steps: Int {
        switch self {
        case .smaller:  return -2
        case .small:    return -1
        case .standard: return 0
        case .large:    return 1
        case .larger:   return 2
        }
    }
}

extension DynamicTypeSize {
    /// Move `steps` notches along the ramp, clamped at both ends.
    func shifted(by steps: Int) -> DynamicTypeSize {
        guard steps != 0 else { return self }
        let all = DynamicTypeSize.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        let target = min(max(0, index + steps), all.count - 1)
        return all[target]
    }
}

// MARK: - Page background

enum BackgroundStyle: String, CaseIterable, Codable, Identifiable {
    case system, plain, contrast, wash
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:   return "Grouped"
        case .plain:    return "Plain"
        case .contrast: return "Contrast"
        case .wash:     return "Accent wash"
        }
    }
}

// MARK: - Config

/// Every appearance choice, in one Codable value.
///
/// The decoder is written by hand rather than synthesized. Synthesized `init(from:)` throws on a
/// missing key even when the property has a default, which would mean every future setting added
/// here wipes the settings already on disk. `decodeIfPresent` makes old payloads keep working.
struct ThemeConfig: Codable, Equatable {
    var accentID: String = AccentPalette.defaultID
    var customAccentHex: String = "D6592E"
    var appearance: AppearanceMode = .system
    var density: Density = .cozy
    var corners: CornerStyle = .rounded
    var cardStyle: CardStyle = .elevated
    var fontDesign: FontDesignChoice = .standard
    var textScale: TextScale = .standard
    var background: BackgroundStyle = .system
    /// Section headers ("QUICK STATS") take the accent colour instead of secondary grey.
    var accentSectionLabels: Bool = false
    var animationsEnabled: Bool = true
    var hapticsEnabled: Bool = true
    /// Icon-only tab bar.
    var compactTabBar: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var out = ThemeConfig()
        out.accentID            = try c.decodeIfPresent(String.self, forKey: .accentID) ?? out.accentID
        out.customAccentHex     = try c.decodeIfPresent(String.self, forKey: .customAccentHex) ?? out.customAccentHex
        out.appearance          = try c.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? out.appearance
        out.density             = try c.decodeIfPresent(Density.self, forKey: .density) ?? out.density
        out.corners             = try c.decodeIfPresent(CornerStyle.self, forKey: .corners) ?? out.corners
        out.cardStyle           = try c.decodeIfPresent(CardStyle.self, forKey: .cardStyle) ?? out.cardStyle
        out.fontDesign          = try c.decodeIfPresent(FontDesignChoice.self, forKey: .fontDesign) ?? out.fontDesign
        out.textScale           = try c.decodeIfPresent(TextScale.self, forKey: .textScale) ?? out.textScale
        out.background          = try c.decodeIfPresent(BackgroundStyle.self, forKey: .background) ?? out.background
        out.accentSectionLabels = try c.decodeIfPresent(Bool.self, forKey: .accentSectionLabels) ?? out.accentSectionLabels
        out.animationsEnabled   = try c.decodeIfPresent(Bool.self, forKey: .animationsEnabled) ?? out.animationsEnabled
        out.hapticsEnabled      = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? out.hapticsEnabled
        out.compactTabBar       = try c.decodeIfPresent(Bool.self, forKey: .compactTabBar) ?? out.compactTabBar
        self = out
    }
}

// MARK: - Presets

/// A named starting point. Every setting in a preset is one the user can then change individually —
/// these exist because "pick eight things that go together" is a lot to ask before you've seen what
/// any of them do, not because the combinations are special.
struct ThemePreset: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let config: ThemeConfig

    static let all: [ThemePreset] = [
        ThemePreset(id: "elos", name: "Elos", blurb: "How the app ships.", config: ThemeConfig()),

        ThemePreset(id: "midnight", name: "Midnight", blurb: "Dark, flat, tight.", config: {
            var c = ThemeConfig()
            c.accentID = "cobalt"
            c.appearance = .dark
            c.background = .contrast
            c.cardStyle = .flat
            c.corners = .soft
            c.density = .compact
            return c
        }()),

        ThemePreset(id: "paper", name: "Paper", blurb: "Light, serif, roomy.", config: {
            var c = ThemeConfig()
            c.accentID = "bronze"
            c.appearance = .light
            c.background = .system
            c.cardStyle = .outlined
            c.corners = .soft
            c.density = .spacious
            c.fontDesign = .serif
            return c
        }()),

        ThemePreset(id: "neon", name: "Neon", blurb: "Glass cards, accent wash.", config: {
            var c = ThemeConfig()
            c.accentID = "magenta"
            c.appearance = .dark
            c.background = .wash
            c.cardStyle = .glass
            c.corners = .pill
            c.accentSectionLabels = true
            return c
        }()),

        ThemePreset(id: "focus", name: "Focus", blurb: "Mono type, no motion, no chrome.", config: {
            var c = ThemeConfig()
            c.accentID = "slate"
            c.cardStyle = .flat
            c.corners = .square
            c.density = .compact
            c.fontDesign = .monospaced
            c.animationsEnabled = false
            c.compactTabBar = true
            return c
        }()),

        ThemePreset(id: "sunrise", name: "Sunrise", blurb: "Warm, rounded, generous.", config: {
            var c = ThemeConfig()
            c.accentID = "ember"
            c.background = .wash
            c.cardStyle = .tinted
            c.corners = .pill
            c.density = .spacious
            c.fontDesign = .rounded
            c.accentSectionLabels = true
            return c
        }()),
    ]
}

// MARK: - Contrast

extension Color {
    /// Relative luminance of an sRGB colour, per WCAG. Used to decide whether text on top of an
    /// arbitrary accent should be white or black — the app can't assume white once the accent is
    /// something the user typed in.
    static func relativeLuminance(of color: Color) -> Double {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0 }
        func channel(_ v: CGFloat) -> Double {
            let value = Double(v)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
