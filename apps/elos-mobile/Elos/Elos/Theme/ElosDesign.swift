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

// MARK: - Podium badge

/// Rank indicator for leaderboards.
///
/// Replaces 🥇🥈🥉, which were duplicated as literal emoji in both `LeaderboardView` and the Train
/// tab's weekly board. Emoji render at the system's own scale and colour, so they ignored the type
/// ramp and the palette, and next to SF Symbols everywhere else they looked pasted in. This draws
/// the placing itself — the number stays readable at any Dynamic Type size, and ranks past third
/// degrade to a plain numeral instead of nothing.
struct PodiumBadge: View {
    let rank: Int
    var size: CGFloat = 28

    private var medal: Color? {
        switch rank {
        case 1:  return Color(red: 0.83, green: 0.69, blue: 0.22)   // gold
        case 2:  return Color(red: 0.75, green: 0.75, blue: 0.78)   // silver
        case 3:  return Color(red: 0.80, green: 0.50, blue: 0.20)   // bronze
        default: return nil
        }
    }

    var body: some View {
        Group {
            if let medal {
                ZStack {
                    Circle().fill(medal.opacity(0.18))
                    Circle().strokeBorder(medal.opacity(0.55), lineWidth: 1)
                    Text("\(rank)")
                        .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                        .foregroundStyle(medal)
                }
                .frame(width: size, height: size)
            } else {
                Text("\(rank)")
                    .font(.elosNumeric(.caption, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityLabel(rank <= 3 ? "Rank \(rank), podium" : "Rank \(rank)")
    }
}

// MARK: - Segmented control

/// A tab switcher in the app's own visual language.
///
/// `.pickerStyle(.segmented)` was the one control on screen that read as stock UIKit: its selected
/// segment is a grey capsule regardless of tint, so on a dark card the *unselected* labels (full
/// white) out-weighted the selected one and the control appeared to have nothing selected. This
/// draws selection with the accent instead, and slides it, so the current tab is unmistakable.
struct ElosSegmentedControl<Tab: Hashable>: View {
    let tabs: [Tab]
    let label: (Tab) -> String
    @Binding var selection: Tab

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = tab }
                } label: {
                    Text(label(tab))
                        .font(.system(.footnote, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                Capsule().fill(Color.tint)
                                    .matchedGeometryEffect(id: "elosSegment", in: indicator)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(tab))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }
}
