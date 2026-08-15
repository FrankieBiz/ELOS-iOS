import SwiftUI

/// One day's headline numbers, built by the split builder (which owns the day data) so this view
/// stays a pure presenter.
struct SplitDaySummary: Identifiable {
    let id: Int            // day index
    let name: String
    let exerciseCount: Int
    let sets: Int
    let score: Int?        // nil when the day has too little to score
    /// This day's own single-session report — already computed by `daySummaries` for `score`
    /// above; kept in full so tapping a row can open the day's own coverage bars, which is where
    /// a day-scoped "Skip muscles" choice is actually visible.
    let report: QualityReport
}

/// The full weekly report — the "bigger screen". Answers, in order: how good is this week, is every
/// muscle covered, are the movements any good, is frequency right, and what should I change?
struct SplitQualityReportView: View {
    let report: QualityReport
    let days: [SplitDaySummary]
    var onTapTip: ((QualityTip) -> Void)? = nil
    /// When set, an auto-fixable tip opens the fix preview instead of `onTapTip`'s usual behavior.
    var onAutoFix: ((QualityTip) -> Void)? = nil
    var onTapMuscle: ((MuscleVolumeBar) -> Void)? = nil
    var onSelectDay: ((SplitDaySummary) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    if !report.dimensions.isEmpty { dimensionsCard }
                    coverageCard
                    movementCard
                    frequencyCard
                    suggestionsCard
                    if !days.isEmpty { perDayCard }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Split Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            QualityScoreRing(score: report.overall, size: 76, lineWidth: 7)
            VStack(alignment: .leading, spacing: 4) {
                Text(report.tier.rawValue)
                    .font(.elosTitle)
                    .foregroundStyle(QualityPalette.color(forScore: report.overall))
                Text(verdict)
                    .font(.elosBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Split quality \(report.overall) out of 100, \(report.tier.rawValue)")
        .accessibilityValue(verdict)
        .cardPadding()
    }

    /// Plain-English summary: name the weakest thing, since that's what to fix next.
    private var verdict: String {
        guard report.isScored else {
            return "Add a few more exercises and this will start scoring."
        }
        let applicable = report.dimensions(for: .weeklySplit)
        guard let weakest = applicable.min(by: { $0.score < $1.score }) else { return "" }
        if weakest.score >= 85 { return "Everything checks out — this is a well-built week." }
        switch weakest.dimension {
        case .volume:    return "Weakest link is how much work each muscle gets."
        case .balance:   return "Weakest link is coverage — some muscles are missing or lopsided."
        case .selection: return "Weakest link is exercise choice and order."
        case .repRest:   return "Weakest link is your rep ranges and rest times."
        case .frequency: return "Weakest link is frequency — too much lands on single days."
        case .fatigue:   return "Weakest link is session length and exercise order."
        }
    }

    // MARK: Dimensions

    private var dimensionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("BREAKDOWN")
            QualityDimensionBars(dimensions: report.dimensions(for: .weeklySplit), labelWidth: 86)
        }
        .cardPadding()
    }

    // MARK: Coverage

    private var coverageCard: some View {
        MuscleCoverageBars(report: report.volume,
                           title: "MUSCLE COVERAGE",
                           hidesUnexpected: false,   // an empty group is the finding here
                           showsLegend: true,
                           onTapMuscle: onTapMuscle)
            .cardPadding()
    }

    // MARK: Movement quality

    private var movementCard: some View {
        let m = report.movement
        let total = m.classifiedSets
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("MOVEMENT QUALITY")

            if total <= 0 {
                Text("Add some exercises to see your movement mix.")
                    .font(.elosCaption).foregroundStyle(.secondary)
            } else {
                // Compound vs isolation, by set volume.
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        HStack(spacing: 2) {
                            if m.compoundSets > 0 {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.tint)
                                    .frame(width: max(4, w * (m.compoundSets / total) - 1))
                            }
                            if m.isolationSets > 0 {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.tint.opacity(0.3))
                            }
                        }
                    }
                    .frame(height: 10)

                    HStack(spacing: 12) {
                        swatch(.tint, "Compound \(pct(m.compoundSets / total))")
                        swatch(.tint.opacity(0.3), "Isolation \(pct(m.isolationSets / total))")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Movement mix")
                .accessibilityValue("\(pct(m.compoundSets / total)) compound, \(pct(m.isolationSets / total)) isolation")

                // Pattern spread.
                let present = MovementQualityAnalyzer.displayOrder
                    .compactMap { p -> (String, Double)? in
                        guard let v = m.setsByPattern[p], v > 0 else { return nil }
                        return (p, v)
                    }
                if !present.isEmpty {
                    FlowRow(spacing: 6) {
                        ForEach(present, id: \.0) { pattern, sets in
                            patternPill(MovementQualityAnalyzer.label(forPattern: pattern),
                                        "\(VolumeScorer.setsText(sets))", isMissing: false)
                        }
                        ForEach(m.missingPatterns, id: \.self) { pattern in
                            patternPill(MovementQualityAnalyzer.label(forPattern: pattern),
                                        "none", isMissing: true)
                        }
                    }
                }

                if let first = m.missingPatterns.first {
                    let examples = MovementQualityAnalyzer.examples(forPattern: first)
                    Text("Missing a \(MovementQualityAnalyzer.label(forPattern: first).lowercased()) pattern\(examples.isEmpty ? "" : " — \(examples)").")
                        .font(.elosCaption)
                        .foregroundStyle(Color.warn)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .cardPadding()
    }

    private func pct(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

    private func swatch(_ c: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(c).frame(width: 12, height: 8)
            Text(text).font(.system(.caption2, weight: .medium)).foregroundStyle(.secondary)
        }
    }

    private func patternPill(_ name: String, _ value: String, isMissing: Bool) -> some View {
        HStack(spacing: 4) {
            Text(name).font(.system(.caption2, weight: .semibold))
            Text(value).font(.elosNumeric(.caption2, weight: .regular))
                .foregroundStyle(isMissing ? Color.warn : Color.secondary)
        }
        .foregroundStyle(isMissing ? Color.warn : Color.primary)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(isMissing ? Color.warn.opacity(0.12) : Color(.tertiarySystemGroupedBackground))
        .overlay(Capsule().stroke(isMissing ? Color.warn.opacity(0.3) : .clear, lineWidth: 1))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) pattern")
        .accessibilityValue(isMissing ? "not trained" : "\(value) sets")
    }

    // MARK: Frequency

    private var frequencyCard: some View {
        // Shown per fine muscle: frequency is only meaningful for muscles actually trained directly.
        let rows = FineMuscle.allCases
            .filter { report.volume.directSets(for: $0) > 0 }
            .map { ($0, report.volume.directDaysByFine[$0] ?? 0) }
            .sorted { $0.1 < $1.1 }

        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("FREQUENCY")
            if rows.isEmpty {
                Text("No direct muscle work yet.")
                    .font(.elosCaption).foregroundStyle(.secondary)
            } else {
                Text("Training a muscle \(TrainingScience.targetWeeklyFrequency)×/week beats once at the same volume.")
                    .font(.elosMicro)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                FlowRow(spacing: 6) {
                    ForEach(rows, id: \.0) { muscle, days in
                        let ok = days >= TrainingScience.targetWeeklyFrequency
                        HStack(spacing: 4) {
                            Text(muscle.displayName).font(.system(.caption2, weight: .semibold))
                            Text("×\(days)").font(.elosNumeric(.caption2, weight: .bold))
                        }
                        .foregroundStyle(ok ? Color.good : Color.warn)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background((ok ? Color.good : Color.warn).opacity(0.12))
                        .clipShape(Capsule())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(muscle.displayName)
                        .accessibilityValue("trained \(days) time\(days == 1 ? "" : "s") a week")
                    }
                }
            }
        }
        .cardPadding()
    }

    // MARK: Suggestions

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("SUGGESTIONS")
            if report.tips.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.elosBody).foregroundStyle(Color.good)
                    Text("Nothing to flag — this week looks dialed in.")
                        .font(.elosBody).foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(report.tips.enumerated()), id: \.element.id) { i, tip in
                        if i > 0 { Divider().padding(.vertical, 9) }
                        TipRow(tip: tip, onTap: onTapTip, onAutoFix: onAutoFix)
                    }
                }
            }
        }
        .cardPadding()
    }

    // MARK: Per day

    private var perDayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("BY DAY")
            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { i, day in
                    if i > 0 { Divider().padding(.vertical, 8) }
                    Button {
                        onSelectDay?(day)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.name.isEmpty ? "Day \(day.id + 1)" : day.name)
                                    .font(.system(.subheadline, weight: .semibold))
                                    .lineLimit(1)
                                Text("\(day.exerciseCount) exercise\(day.exerciseCount == 1 ? "" : "s") · \(day.sets) sets")
                                    .font(.elosMicro).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if let s = day.score {
                                Text("\(s)")
                                    .font(.elosNumeric(.subheadline, weight: .bold))
                                    .foregroundStyle(QualityPalette.color(forScore: s))
                            } else {
                                Text("—").font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            if onSelectDay != nil {
                                Image(systemName: "chevron.right")
                                    .font(.system(.caption2, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelectDay == nil)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(day.name.isEmpty ? "Day \(day.id + 1)" : day.name)
                    .accessibilityValue(day.score.map { "\($0) out of 100, \(day.exerciseCount) exercises, \(day.sets) sets" }
                                        ?? "not scored, \(day.exerciseCount.pluralized("exercise"))")
                    .accessibilityAddTraits(onSelectDay != nil ? .isButton : [])
                }
            }
        }
        .cardPadding()
    }

    // MARK: Bits

    private func sectionTitle(_ s: String) -> some View {
        Text(s).elosSectionLabel()
    }
}

// MARK: - Shared tip row

/// A single suggestion. Tappable when it carries an action, with the chevron as the affordance.
struct TipRow: View {
    let tip: QualityTip
    var onTap: ((QualityTip) -> Void)? = nil
    /// When set and the tip is auto-fixable, tapping opens the fix preview instead of `onTap`'s
    /// usual behavior — one tap target per row, no competing second button in a small row.
    var onAutoFix: ((QualityTip) -> Void)? = nil

    private var isAutoFixable: Bool { onAutoFix != nil && QualityFixEngine.canFix(tip) }
    private var canTap: Bool { isAutoFixable || (tip.action.isActionable && onTap != nil) }

    var body: some View {
        Button {
            if isAutoFixable { onAutoFix?(tip) }
            else if canTap { onTap?(tip) }
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: QualityPalette.icon(for: tip.severity))
                    .font(.elosCaption)
                    .foregroundStyle(QualityPalette.color(for: tip.severity))
                    .padding(.top, 1)
                Text(tip.message)
                    .font(.elosCaption)
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if canTap {
                    Image(systemName: "chevron.right")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canTap)
        .accessibilityHint(canTap ? "Double tap to fix" : "")
    }
}

// MARK: - Card padding

private extension View {
    /// Standard card inset for the report's sections. The surface itself comes from the shared
    /// `.elosCard()` rather than a hand-rolled background + clipShape, so radius, corner style and
    /// elevation stay in one place.
    func cardPadding() -> some View {
        self.padding(Space.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .elosCard()
    }
}

// MARK: - Flow layout

/// Wrapping row of pills. A tiny `Layout` beats a horizontal ScrollView here — the pill count varies
/// and hiding some off-screen would hide findings.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
