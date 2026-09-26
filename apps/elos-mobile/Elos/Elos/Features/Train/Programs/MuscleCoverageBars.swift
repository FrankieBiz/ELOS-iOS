import SwiftUI

// MARK: - Status colours

extension VolumeStatus {
    var color: Color {
        switch self {
        case .productive, .high: return .good
        case .light:             return .warn
        case .under:             return .warn
        case .excessive:         return .bad
        case .untrained:         return .bad
        }
    }

    /// Short spoken/label form, e.g. under the bar in the full report.
    var label: String {
        switch self {
        case .untrained:  return "Not trained"
        case .under:      return "Below minimum"
        case .light:      return "Light"
        case .productive: return "On target"
        case .high:       return "Above target"
        case .excessive:  return "Too much"
        }
    }
}

// MARK: - The bar

/// One volume bar. Reads as a single idea: **fill it to the goal line**.
///
/// - solid segment = sets where this muscle is the primary mover (direct work)
/// - translucent segment = sets earned secondarily, at half credit
/// - goal line = bottom of the productive band, which sits at 75% of the track by design, so the
///   productive range occupies the last quarter and a "full" bar means "in range"
struct VolumeBarTrack: View {
    let fill: Double
    let directFill: Double
    let color: Color
    var height: CGFloat = 9
    /// Dimmed styling for muscles the current focus doesn't ask for.
    var isMuted: Bool = false

    private let goalLine = 0.75

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemGroupedBackground))

                // The productive band — the stretch you're aiming to land in.
                Capsule()
                    .fill(color.opacity(isMuted ? 0.04 : 0.10))
                    .frame(width: w * (1 - goalLine))
                    .offset(x: w * goalLine)

                // Indirect contribution, behind the direct segment.
                if fill > 0 {
                    Capsule()
                        .fill(color.opacity(isMuted ? 0.18 : 0.38))
                        .frame(width: max(height, w * fill))
                }
                // Direct work reads solid — it's what actually drives the muscle.
                if directFill > 0 {
                    Capsule()
                        .fill(color.opacity(isMuted ? 0.45 : 1))
                        .frame(width: max(height, w * directFill))
                }

                // Goal line, drawn last so it stays legible over a full bar.
                Rectangle()
                    .fill(Color.primary.opacity(fill >= goalLine ? 0.28 : 0.16))
                    .frame(width: 1.5, height: height)
                    .offset(x: w * goalLine)
            }
        }
        .frame(height: height)
    }
}

// MARK: - One row

struct MuscleBarRow: View {
    let bar: MuscleVolumeBar
    let isChild: Bool
    /// Attached ONLY when non-nil. An unconditional `.onTapGesture` here would swallow the enclosing
    /// row's expand gesture — a child gesture wins over its parent — so group rows pass nil and let
    /// `MuscleCoverageBars` own the tap.
    var onTap: ((MuscleVolumeBar) -> Void)? = nil
    /// Announce as a button even when the tap is handled by the parent.
    var isButton: Bool = false

    private var isMuted: Bool { !bar.isExpected || bar.isOptional }
    private var color: Color { isMuted ? .secondary : bar.status.color }
    /// Explicit `Color`s rather than `.tertiary`/`.primary`: the hierarchical styles aren't `Color`,
    /// so they can't share a ternary with one.
    private var nameColor: Color { isMuted ? Color.secondary.opacity(0.7) : Color.primary }

    var body: some View {
        if let onTap {
            rowContent
                .contentShape(Rectangle())
                .onTapGesture { onTap(bar) }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: Space.s + 2) {
            Text(bar.displayName)
                .font(isChild ? .elosCaption : .system(.footnote, weight: .semibold))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: isChild ? 88 : 96, alignment: .leading)

            VolumeBarTrack(fill: bar.fill, directFill: bar.directFill,
                           color: color, height: isChild ? 7 : 9, isMuted: isMuted)

            // Tabular figures so the column doesn't jitter as values change while editing.
            Text(valueText)
                .font(.elosNumeric(isChild ? .caption2 : .caption, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .frame(width: 58, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bar.displayName)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits((onTap != nil || isButton) ? .isButton : [])
    }

    /// `7/14` — sets against the target — only where a real band exists (fine rows and the
    /// single-child groups). Multi-child group rows show their plain set total: they have no
    /// meaningful aggregate target, and reusing the `x/y` form there made "4/4 sets vs target" and
    /// "1/1 muscles in range" look like the same measurement. Colour and the goal line carry the
    /// group's verdict; expanding it names the muscle at fault.
    private var valueText: String {
        // A muscle the lifter excluded must never just read as a plain zero or vanish — that's
        // indistinguishable from a real gap, and for the new weekly intersection specifically
        // (a muscle skipped on every training day) it can be flat wrong mid-build. Muting always
        // stays visible and explained, ahead of the science-driven `isOptional` case below.
        if bar.isExcluded { return "Skipped" }
        let sets = VolumeScorer.setsText(bar.sets)
        guard let band = bar.band else { return sets }
        return "\(sets)/\(VolumeScorer.setsText(band.targetLow))"
    }

    private var accessibilityValue: String {
        if bar.isExcluded { return "Excluded from coverage" }
        if bar.isOptional { return "\(bar.sets.pluralized("set")), optional" }
        if !bar.isExpected { return "\(bar.sets.pluralized("set")), not part of this focus" }
        var s = bar.sets.pluralized("set")
        if let band = bar.band {
            s += ", target \(VolumeScorer.setsText(band.targetLow)) to \(VolumeScorer.setsText(band.targetHigh))"
        } else if bar.expectedCount > 0 {
            s += ", \(bar.inRangeCount) of \(bar.expectedCount) muscles on target"
        }
        return s + ". \(bar.status.label)"
    }
}

// MARK: - The list

/// The coverage bars: one row per muscle group, tappable to reveal the individual muscles.
/// Shared by the template builder (inline) and the split report (full screen).
struct MuscleCoverageBars: View {
    let report: MuscleVolumeReport
    var title: String? = "MUSCLE COVERAGE"
    /// Hide groups the current focus doesn't ask for — right for a focused template,
    /// wrong for a weekly report where an empty group *is* the finding.
    var hidesUnexpected: Bool = false
    var showsLegend: Bool = false
    var onTapMuscle: ((MuscleVolumeBar) -> Void)? = nil

    @State private var expanded: Set<String> = []

    private var rows: [MuscleVolumeBar] {
        hidesUnexpected ? report.bars.filter { $0.isExpected || $0.sets > 0 } : report.bars
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            if let title {
                Text(title).elosSectionLabel()
            }

            VStack(spacing: Space.s + 1) {
                ForEach(rows) { bar in
                    groupRow(bar)
                }
            }

            if showsLegend { legend }
        }
        // Column-aligned bars can't reflow to the largest accessibility sizes without the label,
        // track and value collapsing into each other.
        .elosDenseLayout()
    }

    @ViewBuilder private func groupRow(_ bar: MuscleVolumeBar) -> some View {
        let isOpen = expanded.contains(bar.id)

        VStack(spacing: 8) {
            // A real Button rather than `.onTapGesture`: the row contains a `GeometryReader`
            // (the bar track), and a tap gesture layered over that proved unreliable to hit.
            // Button also gets focus, press feedback and VoiceOver activation for free.
            Button {
                guard bar.isExpandable else { onTapMuscle?(bar); return }
                withAnimation(.elosStandard) {
                    if isOpen { expanded.remove(bar.id) } else { expanded.insert(bar.id) }
                }
            } label: {
                HStack(spacing: 8) {
                    // Tap handling lives on this Button, so the row itself takes no gesture.
                    MuscleBarRow(bar: bar, isChild: false, onTap: nil,
                                 isButton: bar.isExpandable || onTapMuscle != nil)

                    if bar.isExpandable {
                        Image(systemName: "chevron.down")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isOpen ? 0 : -90))
                            .frame(width: 12)
                    } else {
                        Spacer().frame(width: 12)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!bar.isExpandable && onTapMuscle == nil)
            .accessibilityHint(bar.isExpandable
                               ? (isOpen ? "Collapse individual muscles" : "Show individual muscles")
                               : "")

            if isOpen {
                VStack(spacing: 7) {
                    ForEach(bar.children) { child in
                        HStack(spacing: 8) {
                            MuscleBarRow(bar: child, isChild: true, onTap: onTapMuscle)
                            Spacer().frame(width: 12)
                        }
                        .padding(.leading, 10)
                    }
                }
                .padding(.top, 1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(opacity: 1, text: "Direct")
            legendItem(opacity: 0.38, text: "Indirect")
            HStack(spacing: 5) {
                Rectangle().fill(Color.primary.opacity(0.28)).frame(width: 1.5, height: 9)
                Text("Target").font(.elosMicro).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    private func legendItem(opacity: Double, text: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(Color.secondary.opacity(opacity)).frame(width: 14, height: 7)
            Text(text).font(.elosMicro).foregroundStyle(.secondary)
        }
    }
}
