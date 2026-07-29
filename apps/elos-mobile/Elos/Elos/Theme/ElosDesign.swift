import SwiftUI

// MARK: - Spacing
//
// A 4pt rhythm. Every gap and inset should come from here rather than a literal, so screens line
// up with each other instead of each drifting a point or two.

enum Space {
    static let xs: CGFloat = 4
    static let s:  CGFloat = 8
    static let m:  CGFloat = 12
    static let l:  CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28

    /// Standard inset inside a card.
    static let card: CGFloat = 16
    /// Standard screen-edge gutter.
    static let gutter: CGFloat = 16
}

// MARK: - Radius

enum Radius {
    /// Chips, small controls, inner wells.
    static let control: CGFloat = 10
    /// Cards and primary surfaces.
    static let card: CGFloat = 16
    /// Buttons.
    static let button: CGFloat = 12
}

// MARK: - Typography
//
// Built on Dynamic Type text styles (`.caption`, `.body`, …) rather than fixed point sizes, so the
// whole app scales with the user's setting — the fixed `.system(size:)` literals scattered through
// the app silently ignored it. Weight/design ride on top.
//
// Numbers use `.rounded` + `monospacedDigit()`: digits stay column-aligned as values change (no
// jitter in a live set counter or a volume readout) without the techy feel of full SF Mono.

extension Font {
    /// Big hero figures — the number on a stat tile.
    static let elosDisplay = Font.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit()
    /// Section/screen titles.
    static let elosTitle    = Font.system(.title3, weight: .bold)
    /// Card headings.
    static let elosHeadline = Font.system(.headline, weight: .semibold)
    /// Default reading text.
    static let elosBody     = Font.system(.subheadline)
    /// Supporting text, tips, secondary rows.
    static let elosCaption  = Font.system(.caption)
    /// Smallest supporting text.
    static let elosMicro    = Font.system(.caption2)

    /// Aligned numerals at an arbitrary text style — use for any figure that updates in place.
    static func elosNumeric(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight).monospacedDigit()
    }
}

extension View {
    /// The small uppercase tracked header above a group of content ("MUSCLE COVERAGE").
    func elosSectionLabel() -> some View {
        self.font(.system(.caption2, weight: .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    /// Clamp Dynamic Type on dense, column-aligned panels (bar charts, stat rows) that genuinely
    /// cannot reflow to the largest accessibility sizes. Everything else should scale freely —
    /// reach for this only where the layout is truly grid-like.
    func elosDenseLayout() -> some View {
        self.dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

// MARK: - Surfaces

extension View {
    /// A raised inner well — used for stat strips and expandable detail inside a card, where a
    /// nested card would be too heavy.
    func elosWell(cornerRadius: CGFloat = Radius.control) -> some View {
        self.background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
