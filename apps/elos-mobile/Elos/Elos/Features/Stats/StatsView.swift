import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @EnvironmentObject var vm: AppViewModel
    @Query(sort: \WorkoutSessionRecord.startedAt, order: .reverse)
    private var allSessions: [WorkoutSessionRecord]
    @Query private var allSleep: [SleepRecord]
    @Query private var allSets: [ExerciseSetRecord]
    @Query private var profiles: [UserProfileRecord]

    @StateObject private var analyticsVM = AnalyticsViewModel()

    /// How far back the volume card looks. A week is the unit the productive-volume landmarks in
    /// `TrainingScience` are defined in, so anything else would compare against the wrong number.
    private static let volumeWindowDays = 7

    /// Height per bar. Scaled, because a fixed value let the muscle labels grow into each other at
    /// larger text sizes — "Triceps", "Forearms" and "Hamstrings" overlapped into one smear.
    @ScaledMetric(relativeTo: .caption) private var volumeRowHeight: CGFloat = 26

    /// Full catalog name plus the chip label, rather than deriving the label from the last word of
    /// the name: "Barbell Bench Press" and "Barbell Overhead Press" both end in "Press", so the
    /// picker rendered two identical, indistinguishable chips.
    private struct Lift: Identifiable {
        let name: String
        let short: String
        var id: String { name }
    }

    private let commonLifts: [Lift] = [
        .init(name: "Barbell Back Squat",     short: "Squat"),
        .init(name: "Barbell Bench Press",    short: "Bench"),
        .init(name: "Conventional Deadlift",  short: "Deadlift"),
        .init(name: "Barbell Overhead Press", short: "Overhead"),
        .init(name: "Barbell Row",            short: "Row"),
    ]

    // MARK: Computed

    private var mySessions: [WorkoutSessionRecord] {
        allSessions.filter { $0.ownerID == vm.currentUserID && $0.finishedAt != nil }
    }

    private var totalVolumeKg: Double {
        mySessions.reduce(0) { $0 + $1.totalVolume }
    }

    private var monthSessionCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return mySessions.filter { $0.startedAt >= cutoff }.count
    }

    /// Deliberately the *workout* streak, not the habit streak. This cell sits in a grid of
    /// Workouts / Volume / Sleep, so a habit streak here read as a training stat: with 15 sessions
    /// logged and no habits created it showed "Best Streak 0 days", which looks like broken data.
    private var bestWorkoutStreak: Int {
        GamificationEngine.bestWorkoutStreak(sessions: mySessions)
    }

    private var avgSleepHours: Double {
        let mySleep = allSleep.filter { $0.ownerID == vm.currentUserID }
        guard !mySleep.isEmpty else { return 0 }
        return mySleep.map(\.duration).reduce(0, +) / Double(mySleep.count)
    }

    // MARK: Weekly volume — computed locally
    //
    // Not from `/analytics/volume`. That endpoint buckets by
    // `LEFT JOIN exercise_definitions ON lower(exercise_name) = lower(name)`, so every set logged on a
    // brand machine ("PRIME Fitness Low Back Extension") falls into `'other'` and the chart showed a
    // lifter's machine work as one grey "Unmatched" bar. Each set records what it trained, so the
    // client can answer properly — and offline.

    private var volumeRows: [LoggedVolumeAnalyzer.MuscleRow] {
        let since = Calendar.current.date(
            byAdding: .day, value: -Self.volumeWindowDays, to: Date()) ?? Date()
        // Window first, then resolve. Resolving every set the lifter has ever logged and *then*
        // discarding all but the last week meant the cost grew forever while the chart never changed.
        let byName = catalogByNormalizedName
        let logged = allSets
            .filter { $0.ownerID == vm.currentUserID && $0.isDone }
            .compactMap { set -> LoggedVolumeAnalyzer.LoggedSet? in
                guard let at = set.completedAt, at >= since else { return nil }
                let targets = resolvedTargets(for: set, byName: byName)
                guard !targets.isEmpty else { return nil }
                return .init(targets: targets, completedAt: at)
            }
        return LoggedVolumeAnalyzer.rows(
            sets: logged, since: since,
            profile: TrainingProfile(record: profiles.first, volumeOverrides: vm.volumeOverrides))
    }

    /// What a logged set trained, via the shared precedence chain: recorded at log time → catalog by
    /// name → the machine → the movement lexicon.
    private func resolvedTargets(for set: ExerciseSetRecord,
                                 byName: [String: ExerciseCandidate]) -> MuscleTargets {
        if let recorded = set.muscleTargets, !recorded.isEmpty { return recorded }
        return ResolvedExercise(
            exercise: ScoredExercise(id: "", name: set.exerciseName, sets: 1, repsText: "",
                                     equipmentId: set.equipmentId),
            candidate: byName[MuscleTaxonomy.normalize(set.exerciseName)]
        ).targets
    }

    @Query(sort: \ExerciseDefinitionRecord.name) private var exerciseDefs: [ExerciseDefinitionRecord]

    /// Catalog indexed by normalized name, built once per pass. This was a `.first { normalize($0.name)
    /// == normalize(set.exerciseName) }` — a linear scan of ~1,000 definitions with two string
    /// normalizations per comparison, run for every logged set, on every re-render of the tab.
    /// Best set per lift, from **local** logged sets.
    ///
    /// The board used to read `/analytics/prs`, which disagreed with the `/prs` endpoint the Train tab
    /// uses — one reported eleven records while this showed none — and was empty whenever the device was
    /// offline, sitting directly beneath a volume card that works offline. Every set is already here.
    private var localPRs: [StrengthMath.Best] {
        StrengthMath.personalRecords(
            from: allSets
                .filter { $0.ownerID == vm.currentUserID && $0.isDone }
                .map { (name: $0.exerciseName, dedupeKey: $0.equipmentDedupeKey,
                        brand: $0.equipmentBrandName, weightKg: $0.weightKg,
                        reps: $0.reps, at: $0.completedAt) })
    }

    private var catalogByNormalizedName: [String: ExerciseCandidate] {
        Dictionary(exerciseDefs.map { (MuscleTaxonomy.normalize($0.name), ExerciseCandidate(record: $0)) },
                   uniquingKeysWith: { a, _ in a })
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.xl) {
                    SectionStack(screen: .stats, spacing: Space.xl) { section in
                        switch section {
                        case .statsSummary:    summaryHeader
                        case .statsLiftPicker: liftPicker
                        case .statsE1RM:       e1rmCard
                        case .statsVolume:     volumeCard
                        case .statsPRs:        prCard
                        default: EmptyView()
                        }
                    }
                    if let err = analyticsVM.loadError {
                        Text(err).font(.elosCaption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                .padding(Space.gutter)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            // Was a hard-coded grouped background; now the app-wide page style, so this screen picks
            // up the background choice along with the other four.
            .elosPageBackground()
            .navigationTitle("Stats")
            // Inline, like Train, Plan and Me. As the only large title in the tab bar it both broke
            // the header rhythm between tabs and spent ~66pt of empty black above the first card.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CustomizeScreenButton(screen: .stats)
                }
            }
            .onAppear {
                // Only the e1RM trend still comes from the server. Volume and the PR board are
                // computed from local logged sets, so they work offline and can't disagree with the
                // rest of the app.
                analyticsVM.loadE1RM(liftName: analyticsVM.selectedLift)
            }
        }
    }

    // MARK: Summary Header

    private var summaryHeader: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Space.m) {
            summaryCell(
                value: "\(mySessions.count)",
                unit: "total",
                label: "Workouts",
                icon: "dumbbell.fill",
                color: Color.tint
            )
            summaryCell(
                value: {
                    let v = vm.weightUnit.fromKg(totalVolumeKg)
                    return v >= 1000 ? String(format: "%.0fk", v / 1000) : String(format: "%.0f", v)
                }(),
                unit: vm.weightUnit.label,
                label: "Volume Lifted",
                icon: "scalemass.fill",
                color: Color.good
            )
            summaryCell(
                value: "\(bestWorkoutStreak)",
                unit: "days",
                label: "Best Streak",
                icon: "flame.fill",
                color: Color.warn
            )
            summaryCell(
                value: avgSleepHours > 0
                    ? String(format: "%.1f", avgSleepHours)
                    : "--",
                unit: "hrs",
                label: "Avg Sleep",
                icon: "moon.fill",
                color: Color.blue
            )
        }
    }

    private func summaryCell(value: String, unit: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.s) {
                // No fixed width: at larger text sizes the glyph outgrew its 14pt box and sat flush
                // against the label with no gap at all.
                Image(systemName: icon)
                    .font(.elosCaption)
                    .foregroundStyle(color)
                Text(label)
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.elosNumeric(.title, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.l)
        .elosCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }

    // MARK: Lift Picker

    private var liftPicker: some View {
        // The chips live inside the page's 16pt gutter, so a plain horizontal ScrollView clipped the
        // first and last capsule flush against the card edge and gave the row no room to scroll into.
        // Padding in by the gutter and pulling the scroll view back out by the same amount lets the
        // chips run edge-to-edge while still starting aligned with everything above them.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(commonLifts) { lift in
                    let sel = lift.name == analyticsVM.selectedLift
                    Button(lift.short) {
                        analyticsVM.selectedLift = lift.name
                        analyticsVM.loadE1RM(liftName: lift.name)
                    }
                    .font(.elosCaption).fontWeight(.semibold)
                    .foregroundStyle(sel ? .white : Color.primary)
                    .padding(.horizontal, Space.m).padding(.vertical, 7)
                    .background {
                        Capsule().fill(sel ? Color.tint : Color(.secondarySystemGroupedBackground))
                    }
                    .overlay {
                        Capsule().strokeBorder(
                            sel ? .clear : Color.primary.opacity(0.07), lineWidth: 1
                        )
                    }
                    .accessibilityLabel(lift.name)
                    .accessibilityAddTraits(sel ? .isSelected : [])
                }
            }
            .padding(.horizontal, Space.gutter)
        }
        .padding(.horizontal, -Space.gutter)
        .scrollClipDisabled()
    }

    // MARK: e1RM Card

    private var e1rmCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated 1RM").font(.elosHeadline)
                    Text(analyticsVM.selectedLift)
                        .font(.elosCaption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: Space.s)
                if analyticsVM.isLoading { ProgressView().scaleEffect(0.7) }
                if let last = analyticsVM.e1rmHistory.last {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(vm.weightUnit.formatWeight(kg: last.e1rm))
                            .font(.elosNumeric(.title3, weight: .bold))
                        Text("current").font(.elosMicro).foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }
            }
            if analyticsVM.e1rmHistory.count >= 2 {
                Chart(analyticsVM.e1rmHistory) { p in
                    LineMark(x: .value("Day", p.day), y: .value("e1RM", vm.weightUnit.fromKg(p.e1rm)))
                        .foregroundStyle(Color.tint).interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Day", p.day), y: .value("e1RM", vm.weightUnit.fromKg(p.e1rm)))
                        .foregroundStyle(Color.tint.opacity(0.12)).interpolationMethod(.catmullRom)
                }
                .frame(height: 160).chartXAxis(.hidden).chartYAxisLabel(vm.weightUnit.label)
            } else {
                // Distinguish "no data" from "one point". With a single session the card was
                // showing a concrete current e1RM *and* "log a few sessions" underneath it, which
                // reads as though the number it just displayed doesn't count.
                emptyState(
                    analyticsVM.e1rmHistory.isEmpty
                        ? "No logged sets for this lift yet."
                        : "One session so far — log another to plot the trend.",
                    // Was 80, which reserved most of a chart's worth of blank card under a one-line
                    // message. The card now hugs its content instead of leaving a hole.
                    minHeight: 44
                )
            }
        }
        .padding(Space.gutter).elosCard()
    }

    // MARK: Volume Card

    private var volumeCard: some View {
        let rows = volumeRows
        let score = LoggedVolumeAnalyzer.onTargetCount(rows)
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Volume by Muscle").font(.elosHeadline)
                    Text("Last 7 days").font(.elosCaption).foregroundStyle(.secondary)
                }
                Spacer(minLength: Space.s)
                // A count of eight bars is not a conclusion. Say how many muscles are actually in
                // their productive range, so the card answers a question on its own.
                if !rows.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(score.onTarget)/\(score.total)")
                            .font(.elosNumeric(.title3, weight: .bold))
                            .foregroundStyle(score.onTarget == score.total ? Color.good : Color.primary)
                        Text("in range").font(.elosMicro).foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }
            }

            if rows.isEmpty {
                emptyState("Complete a few sets to see your volume by muscle.", minHeight: 80)
            } else {
                Chart {
                    ForEach(rows) { row in
                        // A muscle the lifter has told the app to skip (VolumeOverrides.excludedMuscles)
                        // renders muted and labeled, the same distinction MuscleVolumeAnalyzer's
                        // fineRow already draws for the builder's coverage bars — never the same tint
                        // as an ordinary in-progress muscle, and never silently absent either.
                        let label = row.isExcluded ? "\(row.displayName) (Skipped)" : row.displayName
                        let barColor = row.isExcluded ? Color.secondary.opacity(0.35) : Color.tint

                        // Direct and indirect stacked, in the same language as the builder's coverage
                        // bars: solid tint is work where the muscle was the target, translucent is
                        // what it picked up assisting.
                        BarMark(x: .value("Sets", row.credit.direct),
                                y: .value("Muscle", label), stacking: .standard)
                            .foregroundStyle(barColor)
                            .cornerRadius(3)
                        if row.credit.indirect > 0 {
                            BarMark(x: .value("Sets", row.credit.indirect),
                                    y: .value("Muscle", label), stacking: .standard)
                                .foregroundStyle(barColor.opacity(0.35))
                                .cornerRadius(3)
                        }
                        // Where the productive band starts for this muscle — the bar means nothing
                        // without it. 10 sets is plenty of side delts and not enough quads.
                        //
                        // A `PointMark` with a tick symbol, not a `RuleMark` (which would span the
                        // whole chart at one x, and the target differs per muscle) and not a
                        // zero-width `RectangleMark` (which draws nothing at all — the legend
                        // advertised a marker that wasn't there).
                        PointMark(x: .value("Target", row.target),
                                  y: .value("Muscle", label))
                            .symbol {
                                Capsule()
                                    .fill(Color.primary.opacity(0.5))
                                    .frame(width: 2, height: 16)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks { AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                                AxisValueLabel().font(.elosMicro) }
                }
                .chartYAxis {
                    AxisMarks(preset: .aligned, position: .leading) { _ in
                        AxisValueLabel().font(.elosCaption)
                    }
                }
                .frame(height: CGFloat(rows.count) * volumeRowHeight + volumeRowHeight)
                // A twelve-row bar chart cannot reflow to the largest accessibility sizes; this is the
                // case `elosDenseLayout` exists for. The rows still scale, just not without limit.
                .elosDenseLayout()
                .animation(.elosStandard, value: rows.count)

                volumeLegend

                if let worst = LoggedVolumeAnalyzer.gaps(rows, limit: 2).first {
                    Text("\(worst.displayName) is furthest below its weekly range — \(Self.setsCount(worst.total)) of \(Self.setsText(worst.target)).")
                        .font(.elosCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Space.gutter).elosCard()
    }

    /// Three keys on one line, wrapping to two lines rather than breaking a single key across them —
    /// "Weekly target" was splitting after "Weekly", stranding the word under an unrelated swatch.
    private var volumeLegend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.m) { legendKeys; Spacer(minLength: 0) }
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.m) {
                    legendSwatch(Color.tint, "Direct")
                    legendSwatch(Color.tint.opacity(0.35), "Assisting")
                    Spacer(minLength: 0)
                }
                targetKey
            }
        }
    }

    @ViewBuilder private var legendKeys: some View {
        legendSwatch(Color.tint, "Direct")
        legendSwatch(Color.tint.opacity(0.35), "Assisting")
        targetKey
    }

    private var targetKey: some View {
        HStack(spacing: 5) {
            Capsule().fill(Color.primary.opacity(0.5))
                .frame(width: 2, height: 12)
            Text("Weekly target").font(.elosMicro).foregroundStyle(.secondary)
        }
        .fixedSize()
    }

    private func legendSwatch(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: 10, height: 8)
            Text(label).font(.elosMicro).foregroundStyle(.secondary)
        }
        .fixedSize()
    }

    /// "4" / "4.5" — half-sets exist because assisting work is credited at half.
    private func prLift(_ pr: StrengthMath.Best) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(pr.label)
                .font(.elosBody).lineLimit(2)
            HStack(spacing: 4) {
                Text(vm.weightUnit.formatWeight(kg: pr.weightKg))
                    .font(.elosNumeric(.caption, weight: .semibold))
                Text("× \(pr.reps)")
                    .font(.elosCaption).foregroundStyle(.secondary)
            }
        }
    }

    private func prBadge(_ pr: StrengthMath.Best) -> some View {
        Text("e1RM \(vm.weightUnit.formatValue(kg: pr.e1rm, decimals: 0))")
            .font(.elosNumeric(.caption2, weight: .semibold))
            .foregroundStyle(Color.good)
            .padding(.horizontal, Space.s).padding(.vertical, 3)
            .background(Color.good.opacity(0.12), in: Capsule())
            .fixedSize()
    }

    private static func setsCount(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    /// "8 sets", for the trailing half of "4 of 8 sets".
    private static func setsText(_ v: Double) -> String {
        "\(setsCount(v)) set\(v == 1 ? "" : "s")"
    }

    // MARK: PR Board

    private var prCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Personal Records").font(.elosHeadline)
            let prs = localPRs
            if prs.isEmpty {
                emptyState("Log a few working sets to build your PR board.", minHeight: 60)
            } else {
                // Four competing columns in one row left the exercise name truncating at ~12 chars
                // while the e1RM badge hogged the trailing edge. Stacking the lift over its set gives
                // the name the full width and reads as one record instead of four scattered numbers.
                let top = Array(prs.prefix(8))
                VStack(spacing: 0) {
                    ForEach(top) { pr in
                        // The badge is `fixedSize`, so on one line it took its width first and left the
                        // lift name whatever remained — at large text that was "Relentless I…". Drop the
                        // badge below the name when the row can't hold both.
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: Space.m) {
                                prLift(pr)
                                Spacer(minLength: 0)
                                prBadge(pr)
                            }
                            VStack(alignment: .leading, spacing: Space.xs) {
                                prLift(pr)
                                prBadge(pr)
                            }
                            // The HStack variant fills the width via its Spacer; this one sizes to its
                            // content, so without this `ViewThatFits` centred the whole row and a long
                            // lift name sat indented while every other record stayed flush left.
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, Space.s)
                        .accessibilityElement(children: .combine)

                        if pr.id != top.last?.id {
                            Divider().overlay(Color.primary.opacity(0.06))
                        }
                    }
                }
            }
        }
        .padding(Space.gutter).elosCard()
    }

    private func emptyState(_ message: String, minHeight: CGFloat) -> some View {
        Text(message)
            .font(.elosCaption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
    }
}
