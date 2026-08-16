import Foundation
import SwiftUI
import Testing
@testable import Elos

struct ThemeConfigTests {
    /// The reason `ThemeConfig` hand-writes its decoder: a synthesized one throws on a missing key
    /// even when the property has a default, so adding any future setting would wipe everyone's
    /// saved appearance. A payload from an older build has to keep working.
    @Test func decodingAPartialPayloadFillsTheRestWithDefaults() throws {
        let json = #"{"accentID":"cobalt","corners":"pill"}"#.data(using: .utf8)!
        let config = try JSONDecoder().decode(ThemeConfig.self, from: json)

        #expect(config.accentID == "cobalt")
        #expect(config.corners == .pill)
        // Everything absent falls back rather than throwing.
        #expect(config.cardStyle == ThemeConfig().cardStyle)
        #expect(config.density == ThemeConfig().density)
        #expect(config.hapticsEnabled == ThemeConfig().hapticsEnabled)
    }

    @Test func decodingAnEmptyObjectGivesTheShippedDefaults() throws {
        let config = try JSONDecoder().decode(ThemeConfig.self, from: "{}".data(using: .utf8)!)
        #expect(config == ThemeConfig())
    }

    @Test func roundTripsThroughJSON() throws {
        var config = ThemeConfig()
        config.accentID = AccentPalette.customID
        config.customAccentHex = "12AB34"
        config.appearance = .dark
        config.density = .compact
        config.fontDesign = .serif
        config.animationsEnabled = false

        let data = try JSONEncoder().encode(config)
        #expect(try JSONDecoder().decode(ThemeConfig.self, from: data) == config)
    }
}

struct ThemeStoreTests {
    private func makeStore() -> ThemeStore {
        ThemeStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test func shipsWithTheOriginalAccent() {
        let store = makeStore()
        #expect(store.config.accentID == AccentPalette.defaultID)
        // The app's original accent was `Color(red: 0.84, green: 0.35, blue: 0.18)`; switching away
        // and back has to land exactly there.
        #expect(AccentPalette.option(id: "ember")?.hex == "D6592E")
    }

    @Test func everyPresetAccentResolves() {
        for preset in ThemePreset.all where preset.config.accentID != AccentPalette.customID {
            #expect(AccentPalette.option(id: preset.config.accentID) != nil,
                    "\(preset.name) names an accent that isn't in the palette")
        }
    }

    /// White text on the accent is used by the filled button style, the segmented control and a
    /// dozen chips — so every shipped accent has to be dark enough to take it.
    @Test func everyPresetAccentTakesWhiteText() {
        for option in AccentPalette.all {
            #expect(Color.relativeLuminance(of: option.color) <= 0.45,
                    "\(option.name) is too light for white text")
        }
    }

    @Test func foregroundFlipsToBlackOnALightCustomAccent() {
        let store = makeStore()
        store.update {
            $0.accentID = AccentPalette.customID
            $0.customAccentHex = "FFF3B0"      // pale yellow
        }
        #expect(store.onAccentColor == Color.black)

        store.update { $0.customAccentHex = "101820" }   // near-black
        #expect(store.onAccentColor == Color.white)
    }

    @Test func unknownAccentIDFallsBackRatherThanRenderingNothing() {
        let store = makeStore()
        store.update { $0.accentID = "a-preset-that-was-removed" }
        #expect(store.accentColor == AccentPalette.all[0].color)
    }

    @Test func revisionAdvancesOnlyOnRealChanges() {
        let store = makeStore()
        let start = store.revision
        store.update { $0.density = .compact }
        #expect(store.revision == start + 1)

        store.update { $0.density = .compact }   // same value
        #expect(store.revision == start + 1)
    }

    @Test func settingsSurviveAReload() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store = ThemeStore(defaults: defaults)
        store.update {
            $0.accentID = "teal"
            $0.cardStyle = .glass
            $0.textScale = .larger
        }

        let reloaded = ThemeStore(defaults: defaults)
        #expect(reloaded.config.accentID == "teal")
        #expect(reloaded.config.cardStyle == .glass)
        #expect(reloaded.config.textScale == .larger)
    }

    @Test func resetReturnsToTheShippedLook() {
        let store = makeStore()
        store.update { $0.accentID = "violet"; $0.corners = .square }
        store.reset()
        #expect(store.config == ThemeConfig())
    }

    @Test func animationsToggleGatesMotion() {
        let store = makeStore()
        #expect(store.animation(.elosStandard) != nil)
        store.update { $0.animationsEnabled = false }
        #expect(store.animation(.elosStandard) == nil)
    }

    @Test func numeralsStayRoundedUntilATypefaceIsChosen() {
        let store = makeStore()
        #expect(store.numericDesign == .rounded)
        store.update { $0.fontDesign = .serif }
        #expect(store.numericDesign == .serif)
    }
}

struct TextScaleTests {
    /// Text size is an offset from the system setting, never a replacement — someone running iOS at
    /// an accessibility size and picking "L" here must end up larger, not reset to a fixed value.
    @Test func shiftingMovesRelativeToTheSystemSize() {
        #expect(DynamicTypeSize.large.shifted(by: 1) == .xLarge)
        #expect(DynamicTypeSize.large.shifted(by: -1) == .medium)
        #expect(DynamicTypeSize.accessibility3.shifted(by: 1) == .accessibility4)
    }

    @Test func shiftingClampsAtBothEnds() {
        #expect(DynamicTypeSize.xSmall.shifted(by: -5) == .xSmall)
        #expect(DynamicTypeSize.accessibility5.shifted(by: 5) == .accessibility5)
    }

    @Test func zeroShiftIsIdentity() {
        for size in DynamicTypeSize.allCases {
            #expect(size.shifted(by: 0) == size)
        }
    }
}

struct DensityAndCornerTests {
    @Test func cozyAndRoundedReproduceTheOriginalValues() {
        #expect(Density.cozy.scale == 1.0)
        #expect(CornerStyle.rounded.card == 16)
        #expect(CornerStyle.rounded.control == 10)
        #expect(CornerStyle.rounded.button == 12)
    }

    @Test func densityScalesInTheExpectedDirection() {
        #expect(Density.compact.scale < Density.cozy.scale)
        #expect(Density.spacious.scale > Density.cozy.scale)
    }

    @Test func cornerStylesAreOrderedAndNonNegative() {
        let ordered: [CornerStyle] = [.square, .soft, .rounded, .pill]
        for (a, b) in zip(ordered, ordered.dropFirst()) {
            #expect(a.card < b.card)
            #expect(a.button < b.button)
            #expect(a.control < b.control)
        }
        #expect(CornerStyle.square.card >= 0)
    }
}

struct HexRoundTripTests {
    @Test func colorSurvivesHexRoundTrip() {
        for hex in ["D6592E", "0A6CFF", "000000", "FFFFFF", "12AB34"] {
            #expect(Color(hex: hex).hexString == hex)
        }
    }
}
