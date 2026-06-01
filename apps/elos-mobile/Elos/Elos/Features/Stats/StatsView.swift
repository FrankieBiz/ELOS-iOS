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

    private let commonLifts = [
        "Barbell Back Squat", "Barbell Bench Press", "Conventional Deadlift",
        "Barbell Overhead Press", "Barbell Row",
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
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    summaryHeader
                    liftPicker
                    e1rmCard
                    volumeCard
                    prCard
                    if let err = analyticsVM.loadError {
                        Text(err).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            summaryCell(
                value: "\(mySessions.count)",
                unit: "total",
                label: "Workouts",
                icon: "dumbbell.fill",
                color: Color.tint
            )
            summaryCell(
                value: totalVolumeKg >= 1000
                    ? String(format: "%.0fk", totalVolumeKg / 1000)
                    : String(format: "%.0f", totalVolumeKg),
                unit: "kg",
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Lift Picker

    private var liftPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(commonLifts, id: \.self) { lift in
                    let sel = lift == analyticsVM.selectedLift
                    Button(lift.components(separatedBy: " ").last ?? lift) {
                        analyticsVM.selectedLift = lift
                        analyticsVM.loadE1RM(liftName: lift)
                    }
                    .font(.caption).fontWeight(sel ? .semibold : .regular)
                    .foregroundStyle(sel ? .white : Color.primary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(sel ? Color.tint : Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: e1RM Card

    private var e1rmCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated 1RM").font(.subheadline).fontWeight(.semibold)
                    Text(analyticsVM.selectedLift).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if analyticsVM.isLoading { ProgressView().scaleEffect(0.7) }
                if let last = analyticsVM.e1rmHistory.last {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f kg", last.e1rm))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                        Text("current").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if analyticsVM.e1rmHistory.count >= 2 {
                Chart(analyticsVM.e1rmHistory) { p in
                    LineMark(x: .value("Day", p.day), y: .value("e1RM", p.e1rm))
                        .foregroundStyle(Color.tint).interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Day", p.day), y: .value("e1RM", p.e1rm))
                        .foregroundStyle(Color.tint.opacity(0.12)).interpolationMethod(.catmullRom)
                }
                .frame(height: 160).chartXAxis(.hidden).chartYAxisLabel("kg")
            } else {
                Text("Log a few sessions to see your e1RM trend.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            }
        }
        .padding(16).elosCard()
    }

    // MARK: Volume Card

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Volume (Sets by Muscle)").font(.subheadline).fontWeight(.semibold)
            if analyticsVM.volumeData.isEmpty {
                Text("No completed sets in the last 8 weeks yet.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                let data = Dictionary(grouping: analyticsVM.volumeData.prefix(20), by: { $0.muscle })
                    .mapValues { $0.map(\.sets).reduce(0, +) }
                    .sorted { $0.value > $1.value }.prefix(8)
                Chart(data, id: \.key) { item in
                    BarMark(
                        x: .value("Sets", item.value),
                        y: .value("Muscle", item.key.capitalized.replacingOccurrences(of: "_", with: " "))
                    )
                    .foregroundStyle(Color.tint.gradient)
                    .annotation(position: .trailing) {
                        Text("\(item.value)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 200).chartXAxis(.hidden)
            }
        }
        .padding(16).elosCard()
    }

    // MARK: PR Board

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Personal Records").font(.subheadline).fontWeight(.semibold)
            if analyticsVM.prs.isEmpty {
                Text("Log a few working sets to build your PR board.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                ForEach(analyticsVM.prs.prefix(8)) { pr in
                    HStack {
                        Text(pr.exerciseName).font(.subheadline).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.1f kg", pr.weightKg)).font(.system(size: 15, weight: .bold, design: .monospaced))
                        Text("×\(pr.reps)").font(.caption).foregroundStyle(.secondary).frame(width: 30)
                        Text(String(format: "e1RM %.0f", pr.e1rm)).font(.caption2).foregroundStyle(Color.good)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.good.opacity(0.12)).clipShape(Capsule())
                    }
                    if pr.id != analyticsVM.prs.prefix(8).last?.id { Divider() }
                }
            }
        }
        .padding(16).elosCard()
    }
}
