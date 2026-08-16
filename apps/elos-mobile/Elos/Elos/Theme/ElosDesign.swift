import SwiftUI

// MARK: - Spacing
//
// A 4pt rhythm. Every gap and inset should come from here rather than a literal, so screens line
// up with each other instead of each drifting a point or two.

// The base rhythm is unchanged; every value now runs through the density setting, so "Compact" and
// "Spacious" reach the whole app instead of the handful of screens someone remembered to update.
// Rounded to whole points — a 2.8pt gap renders as a soft smear on a 3× screen.
enum Space {
    private static var scale: CGFloat { ThemeStore.shared.densityScale }
    private static func step(_ base: CGFloat) -> CGFloat { max(1, (base * scale).rounded()) }

    static var xs: CGFloat  { step(4) }
    static var s:  CGFloat  { step(8) }
    static var m:  CGFloat  { step(12) }
    static var l:  CGFloat  { step(16) }
    static var xl: CGFloat  { step(20) }
    static var xxl: CGFloat { step(28) }

    /// Standard inset inside a card.
    static var card: CGFloat { step(16) }
    /// Standard screen-edge gutter. Floored at 8 so a compact layout still clears the display's
    /// curved corners rather than running content into the bezel.
    static var gutter: CGFloat { max(8, step(16)) }
}

// MARK: - Radius

enum Radius {
    /// Chips, small controls, inner wells.
    static var control: CGFloat { ThemeStore.shared.corners.control }
    /// Cards and primary surfaces.
    static var card: CGFloat { ThemeStore.shared.corners.card }
    /// Buttons.
    static var button: CGFloat { ThemeStore.shared.corners.button }
}

// MARK: - Typography
//
// Built on Dynamic Type text styles (`.caption`, `.body`, …) rather than fixed point sizes, so the
// whole app scales with the user's setting — the fixed `.system(size:)` literals scattered through
// the app silently ignored it. Weight/design ride on top.
//
// Numbers use `.rounded` + `monospacedDigit()`: digits stay column-aligned as values change (no
// jitter in a live set counter or a volume readout) without the techy feel of full SF Mono.

// The typeface itself is a preference now. Prose styles take whatever design is set (the app-wide
// `.fontDesign` at the root catches everything using plain `.subheadline` and friends); figures keep
// `monospacedDigit()` regardless, since column alignment is structural, not decorative.
extension Font {
    /// Big hero figures — the number on a stat tile.
    static var elosDisplay: Font {
        .system(.largeTitle, design: ThemeStore.shared.numericDesign, weight: .bold).monospacedDigit()
    }
    /// Section/screen titles.
    static var elosTitle: Font    { .system(.title3, design: ThemeStore.shared.fontDesign, weight: .bold) }
    /// Card headings.
    static var elosHeadline: Font { .system(.headline, design: ThemeStore.shared.fontDesign, weight: .semibold) }
    /// Default reading text.
    static var elosBody: Font     { .system(.subheadline, design: ThemeStore.shared.fontDesign) }
    /// Supporting text, tips, secondary rows.
    static var elosCaption: Font  { .system(.caption, design: ThemeStore.shared.fontDesign) }
    /// Smallest supporting text.
    static var elosMicro: Font    { .system(.caption2, design: ThemeStore.shared.fontDesign) }

    /// Aligned numerals at an arbitrary text style — use for any figure that updates in place.
    static func elosNumeric(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: ThemeStore.shared.numericDesign, weight: weight).monospacedDigit()
    }
}

// MARK: - Motion
//
// Three durations, by role. Before this there were 52 `withAnimation` sites using roughly fifteen
// different curve/duration pairs — 0.15, 0.18, 0.2, 0.22, 0.25, 0.3, 0.35 across easeInOut, snappy and
// spring — so nothing in the app moved quite like anything else. Same failure as the font-size literals:
// no shared vocabulary, every call site drifting a few hundredths.
//
// Pick by what the change *is*, not by how long you want it to take.

extension Animation {
    /// A small state flip the eye should barely register: a chip selecting, a checkbox, a disclosure
    /// chevron. Fast enough to feel instant, slow enough not to snap.
    static let elosQuick = Animation.snappy(duration: 0.18)

    /// The default. Layout and appearance changes — a card expanding, a row inserting, a sheet's
    /// content settling. If you're unsure, this is the one.
    static let elosStandard = Animation.snappy(duration: 0.26)

    /// Physical, for moments that should feel like they landed: logging a set, adding an exercise,
    /// reordering. Damping 0.78 gives a little overshoot — noticeably alive, but not the cartoon bounce
    /// that `dampingFraction: 0.5` was producing at three call sites.
    static let elosEmphasis = Animation.spring(response: 0.34, dampingFraction: 0.78)

    /// Press feedback only. Faster than `elosQuick` on purpose: a button that takes even 0.18s to
    /// acknowledge a touch feels laggy, because the user's finger is the reference clock.
    static let elosPress = Animation.easeOut(duration: 0.11)

    /// A value sweeping to its position — ring fills, progress arcs, a score counting up. Deliberately
    /// slow: the motion *is* the information, so it has to be followable.
    static let elosProgress = Animation.easeInOut(duration: 0.6)
}

extension View {
    /// The small uppercase tracked header above a group of content ("MUSCLE COVERAGE").
    ///
    /// Reads the accent-headers preference here rather than at each of its call sites — that's the
    /// whole reason section headers were centralised into one modifier in the first place.
    func elosSectionLabel() -> some View {
        let accented = ThemeStore.shared.config.accentSectionLabels
        return self.font(.system(.caption2, design: ThemeStore.shared.fontDesign, weight: .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(accented ? AnyShapeStyle(Color.tint) : AnyShapeStyle(.secondary))
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
    /// nested card would be too heavy. Elevation level 2: see the note in `AppColors.swift`.
    func elosWell(cornerRadius: CGFloat = Radius.control) -> some View {
        self.background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Elevation.wellHairline, lineWidth: 0.5)
            }
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
    /// Observed so the control re-renders when the accent changes.
    ///
    /// `Color.tint` is a static, so it can't publish; SwiftUI skips re-running `body` for a child
    /// whose own inputs haven't changed, and this control's inputs don't change when the theme does.
    /// In the customizer that showed up immediately — every control on the screen turned magenta
    /// except the segmented control at the top of it. Subscribing here fixes it for every call site
    /// at once, rather than each one remembering to pass a refresh token down.
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    withAnimation(.elosStandard) { selection = tab }
                } label: {
                    Text(label(tab))
                        .font(.system(.footnote, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(isSelected ? AnyShapeStyle(Color.onTint) : AnyShapeStyle(.secondary))
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
        // N fixed segments in one capsule can't reflow, so cap the ramp — at accessibility sizes the
        // labels were truncating to "Sched…"/"Assign…" while the last two overflowed the capsule
        // entirely. Same reasoning as the tab bar.
        .elosDenseLayout()
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .clipShape(Capsule())
    }
}
