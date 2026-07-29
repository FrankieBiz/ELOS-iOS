import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @EnvironmentObject var vm: AppViewModel
    @Query(sort: \WorkoutSessionRecord.startedAt, order: .reverse)
    private var allSessions: [WorkoutSessionRecord]
    @Query private var allHabits: [HabitRecord]
    @Query private var allSleep: [SleepRecord]

    @StateObject private var analyticsVM = AnalyticsViewModel()

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

    private var bestHabitStreak: Int {
        let myHabits = allHabits.filter { $0.ownerID == vm.currentUserID }
        return myHabits.map(\.streak).max() ?? 0
    }

    private var avgSleepHours: Double {
        let mySleep = allSleep.filter { $0.ownerID == vm.currentUserID }
        guard !mySleep.isEmpty else { return 0 }
        return mySleep.map(\.duration).reduce(0, +) / Double(mySleep.count)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.xl) {
                    summaryHeader
                    liftPicker
                    e1rmCard
                    volumeCard
                    prCard
                    if let err = analyticsVM.loadError {
                        Text(err).font(.elosCaption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                .padding(Space.gutter)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                analyticsVM.loadE1RM(liftName: analyticsVM.selectedLift)
                analyticsVM.loadVolume()
                analyticsVM.loadPRs()
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
                value: "\(bestHabitStreak)",
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
            HStack(spacing: Space.xs) {
                Image(systemName: icon)
                    .font(.elosCaption)
                    .foregroundStyle(color)
                    .frame(width: 14)
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
                    minHeight: 80
                )
            }
        }
        .padding(Space.gutter).elosCard()
    }

    // MARK: Volume Card

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Volume").font(.elosHeadline)
                Text("Sets by muscle").font(.elosCaption).foregroundStyle(.secondary)
            }
            if analyticsVM.volumeData.isEmpty {
                emptyState("Complete a few sets to see your volume trends.", minHeight: 80)
            } else {
                let data = Dictionary(grouping: analyticsVM.volumeData.prefix(20), by: { $0.muscle })
                    .mapValues { $0.map(\.sets).reduce(0, +) }
                    .sorted { $0.value > $1.value }.prefix(8)
                Chart(data, id: \.key) { item in
                    BarMark(
                        x: .value("Sets", item.value),
                        y: .value("Muscle", Self.muscleLabel(item.key))
                    )
                    // The server buckets any set whose exercise name it can't match into 'other'.
                    // Drawn in the same tint as real muscles it reads as a muscle group called
                    // "Other"; greyed out it reads as what it is — work that couldn't be attributed.
                    .foregroundStyle(
                        item.key == "other" ? AnyShapeStyle(Color.secondary.opacity(0.35))
                                            : AnyShapeStyle(Color.tint.gradient)
                    )
                    .cornerRadius(4)
                    .annotation(position: .trailing, spacing: 5) {
                        Text("\(item.value)")
                            .font(.elosNumeric(.caption2, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 200)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(preset: .aligned, position: .leading) { _ in
                        AxisValueLabel().font(.elosCaption)
                    }
                }
            }
        }
        .padding(Space.gutter).elosCard()
    }

    // MARK: PR Board

    private var prCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Personal Records").font(.elosHeadline)
            if analyticsVM.prs.isEmpty {
                emptyState("Log a few working sets to build your PR board.", minHeight: 60)
            } else {
                // Four competing columns in one row left the exercise name truncating at ~12 chars
                // while the e1RM badge hogged the trailing edge. Stacking the lift over its set gives
                // the name the full width and reads as one record instead of four scattered numbers.
                let top = Array(analyticsVM.prs.prefix(8))
                VStack(spacing: 0) {
                    ForEach(top) { pr in
                        HStack(spacing: Space.m) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pr.exerciseName)
                                    .font(.elosBody).lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(vm.weightUnit.formatWeight(kg: pr.weightKg))
                                        .font(.elosNumeric(.caption, weight: .semibold))
                                    Text("× \(pr.reps)")
                                        .font(.elosCaption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Text("e1RM \(vm.weightUnit.formatValue(kg: pr.e1rm, decimals: 0))")
                                .font(.elosNumeric(.caption2, weight: .semibold))
                                .foregroundStyle(Color.good)
                                .padding(.horizontal, Space.s).padding(.vertical, 3)
                                .background(Color.good.opacity(0.12), in: Capsule())
                                .fixedSize()
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

    private static func muscleLabel(_ key: String) -> String {
        key == "other"
            ? "Unmatched"
            : key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func emptyState(_ message: String, minHeight: CGFloat) -> some View {
        Text(message)
            .font(.elosCaption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
    }
}
