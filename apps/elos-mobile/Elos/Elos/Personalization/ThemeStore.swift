import Combine
import SwiftUI
import UIKit

/// The app's appearance, as data.
///
/// There are two ways this reaches the UI, and both matter:
///
/// * **As a singleton**, because `Color.tint`, `Space.*`, `Radius.*` and `elosCard()` are static
///   tokens used at well over a thousand call sites. Rewriting those call sites to thread an
///   environment value through would have been a far larger and far riskier change than making the
///   tokens themselves read from here.
/// * **As an `EnvironmentObject`**, so views that need to *re-render* on a change can observe it.
///   Statics can't publish; `ContentView` keys its content on `revision` so a theme change rebuilds
///   the tree that just read those statics.
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    private static let storageKey = "elos.personalization.theme.v1"

    @Published private(set) var config: ThemeConfig {
        didSet {
            guard config != oldValue else { return }
            revision &+= 1
            persist()
        }
    }

    /// Bumped on every change. Used as a view identity so the statics above get re-read.
    @Published private(set) var revision: Int = 0

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(ThemeConfig.self, from: data) {
            config = decoded
        } else {
            config = ThemeConfig()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    // MARK: Mutation

    /// Single funnel for every edit, so persistence and `revision` can't be forgotten at a call site.
    func update(_ change: (inout ThemeConfig) -> Void) {
        var next = config
        change(&next)
        config = next
    }

    func reset() { config = ThemeConfig() }

    // MARK: Resolved values

    var accentColor: Color {
        if config.accentID == AccentPalette.customID {
            return Color(hex: config.customAccentHex)
        }
        return AccentPalette.option(id: config.accentID)?.color
            ?? Color(hex: AccentPalette.all[0].hex)
    }

    /// Text/glyph colour that sits legibly *on* the accent. Threshold 0.45 rather than the textbook
    /// 0.5: at 0.5 mid-tone accents like Olive flip to black text, which reads worse than white
    /// against a saturated fill.
    var onAccentColor: Color {
        Color.relativeLuminance(of: accentColor) > 0.45 ? .black : .white
    }

    var corners: CornerStyle { config.corners }
    var densityScale: CGFloat { config.density.scale }
    var cardStyle: CardStyle { config.cardStyle }
    var colorScheme: ColorScheme? { config.appearance.colorScheme }
    var fontDesign: Font.Design { config.fontDesign.design }

    /// Motion, gated. `animationsEnabled: false` returns nil so `withAnimation(nil)` and
    /// `.animation(nil, value:)` short-circuit rather than each call site testing the flag.
    func animation(_ animation: Animation) -> Animation? {
        config.animationsEnabled ? animation : nil
    }

    // MARK: Page background

    @ViewBuilder
    var pageBackground: some View {
        switch config.background {
        case .system:
            Color(.systemGroupedBackground)
        case .plain:
            Color(.systemBackground)
        case .contrast:
            // Deliberately the extreme of whatever scheme is active: pure black or pure white.
            Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
        case .wash:
            LinearGradient(
                colors: [accentColor.opacity(0.22), accentColor.opacity(0.04), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Page background modifier

extension View {
    /// The page beneath a screen's scrolling content. Every customizable screen applies this so the
    /// background choice actually reaches all five of them, instead of only the one that happened to
    /// set its own colour.
    func elosPageBackground() -> some View {
        background(ThemeStore.shared.pageBackground.ignoresSafeArea())
    }
}

// MARK: - Numerals

extension ThemeStore {
    /// The design used for figures — stat tiles, counters, volume readouts.
    ///
    /// At the default setting this stays `.rounded`, which is what those call sites have always
    /// used and what pairs with `monospacedDigit()`. Pick a face deliberately and the numbers follow
    /// it, because leaving them rounded while every label turned serif looked like a bug.
    var numericDesign: Font.Design {
        config.fontDesign == .standard ? .rounded : config.fontDesign.design
    }
}
