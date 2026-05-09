import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var ctx

    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WorkoutSet.completedAt, order: .reverse) private var allSets: [WorkoutSet]
    @Query(sort: \PersonalRecord.dateAchieved, order: .reverse) private var prs: [PersonalRecord]
    @Query(sort: \BodyMetric.date, order: .reverse) private var bodyLogs: [BodyMetric]

    @State private var range: TimeRange = .month
    @State private var showAddBodyMetric = false

    enum TimeRange: String, CaseIterable {
        case week = "1W", month = "1M", threeMonth = "3M", year = "1Y", all = "All"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonth: return 90
            case .year: return 365
            case .all: return 9999
            }
        }
    }

    private var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -range.days, to: .now) ?? .now
    }

    private var sessionsInRange: [WorkoutSession] {
        sessions.filter { $0.date >= startDate }
    }

    private var setsInRange: [WorkoutSet] {
        allSets.filter { $0.completedAt >= startDate }
    }

    private var totalVolume: Double {
        sessionsInRange.reduce(0) { $0 + $1.totalVolumeKg }
    }

    private var totalSets: Int {
        sessionsInRange.reduce(0) { $0 + $1.sets.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    rangePicker
                        .padding(.horizontal, 14)
                        .padding(.top, 4)

                    statRow
                        .padding(.horizontal, 14)
                        .padding(.top, 12)

                    SectionLabel(title: "Volume Over Time")
                    volumeChart.padding(.horizontal, 14)

                    SectionLabel(title: "Volume by Muscle")
                    muscleChart.padding(.horizontal, 14)

                    SectionLabel(title: "Streaks")
                    streakCard.padding(.horizontal, 14)

                    SectionLabel(title: "Personal Records",
                                 actionTitle: prs.count > 6 ? "All" : nil) {}
                    prList.padding(.horizontal, 14)

                    SectionLabel(title: "Body Weight",
                                 actionTitle: "Log") { showAddBodyMetric = true }
                    bodyWeightCard.padding(.horizontal, 14)

                    Spacer(minLength: 60)
                }
            }
            .background(Color.surfaceBG.ignoresSafeArea())
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddBodyMetric) {
                LogBodyMetricSheet()
            }
        }
    }

    // MARK: Range picker

    private var rangePicker: some View {
        HStack(spacing: 6) {
            ForEach(TimeRange.allCases, id: \.self) { r in
                Button {
                    withAnimation(Theme.Motion.snappy) { range = r }
                    Haptic.selection()
                } label: {
                    Text(r.rawValue)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(range == r ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(range == r ? Color.brand : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.surfaceRaised, in: Capsule())
    }

    // MARK: Headline stats

    private var statRow: some View {
        HStack(spacing: 10) {
            StatTile(label: "Workouts", value: "\(sessionsInRange.count)",
                     icon: "checkmark.circle.fill", accent: .brand)
            StatTile(label: "Sets",     value: "\(totalSets)",
                     icon: "list.number", accent: .brandInfo)
            StatTile(label: "Volume",   value: formatVolume(totalVolume),
                     icon: "scalemass.fill", accent: .brandTrophy)
        }
    }

    private func formatVolume(_ kg: Double) -> String {
        let v = appState.units.from(kg: kg)
        if v >= 10000 { return String(format: "%.0fk", v/1000) }
        if v >= 1000  { return String(format: "%.1fk", v/1000) }
        return String(format: "%.0f", v)
    }

    // MARK: Volume over time chart

    private var volumeChart: some View {
        SolidCard {
            if sessionsInRange.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("No workouts in this range")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart(sessionsInRange.sorted(by: { $0.date < $1.date })) { session in
                    BarMark(
                        x: .value("Date", session.date, unit: barUnit),
                        y: .value("Volume", appState.units.from(kg: session.totalVolumeKg))
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [Color.brand, Color.brand.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.hairline)
                        AxisValueLabel().font(.system(size: 10))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.system(size: 10))
                    }
                }
            }
        }
    }

    private var barUnit: Calendar.Component {
        switch range {
        case .week, .month: return .day
        case .threeMonth: return .weekOfYear
        case .year, .all: return .month
        }
    }

    // MARK: Muscle volume chart

    private var muscleByVolume: [(group: String, volumeKg: Double)] {
        let dict = Dictionary(grouping: setsInRange, by: \.exerciseMuscleGroup)
        return dict.map { (group: $0.key, volumeKg: $0.value.reduce(0) { $0 + $1.weightKg * Double($1.reps) }) }
            .sorted { $0.volumeKg > $1.volumeKg }
            .prefix(10).map { $0 }
    }

    private var muscleChart: some View {
        SolidCard {
            if muscleByVolume.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "figure.run").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text("Log workouts to see muscle volume")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart(muscleByVolume, id: \.group) { item in
                    BarMark(
                        x: .value("Volume", appState.units.from(kg: item.volumeKg)),
                        y: .value("Muscle", item.group)
                    )
                    .foregroundStyle(colorFor(item.group))
                    .cornerRadius(4)
                }
                .frame(height: max(180, CGFloat(muscleByVolume.count) * 28))
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.hairline)
                        AxisValueLabel().font(.system(size: 10))
                    }
                }
            }
        }
    }

    private func colorFor(_ muscle: String) -> Color {
        ExerciseDefinition.library.first { $0.muscleGroup == muscle }?.color ?? .brand
    }

    // MARK: Streak card

    private var streakCard: some View {
        SolidCard {
            HStack(alignment: .center, spacing: 16) {
                StreakFlame(count: appState.currentStreak, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT STREAK")
                        .font(.system(size: 10, weight: .heavy)).kerning(0.6)
                        .foregroundStyle(.secondary)
                    Text(appState.currentStreak == 0 ? "Start one today" : "Don't lose it")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("LONGEST")
                        .font(.system(size: 10, weight: .heavy)).kerning(0.6)
                        .foregroundStyle(.secondary)
                    Text("\(appState.longestStreak)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                }
            }
        }
    }

    // MARK: PR list

    private var prList: some View {
        SolidCard(padding: 4) {
            if prs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("No PRs yet — get after it.")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(prs.prefix(6).enumerated()), id: \.element.id) { i, pr in
                        ProgressPRRow(pr: pr, units: appState.units)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                        if i < min(prs.count, 6) - 1 { Hairline(inset: 12) }
                    }
                }
            }
        }
    }

    // MARK: Body weight chart

    private var bodyWeightCard: some View {
        SolidCard {
            if bodyLogs.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "figure.stand").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text("Log your weight to track trends")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Latest")
                            .font(.system(size: 10, weight: .heavy)).kerning(0.6)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let latest = bodyLogs.first {
                            Text("\(appState.units.from(kg: latest.weightKg).prettyWeight) \(appState.units.label)")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                        }
                    }
                    Chart(bodyLogs.sorted(by: { $0.date < $1.date })) { log in
                        LineMark(
                            x: .value("Date", log.date),
                            y: .value("Weight", appState.units.from(kg: log.weightKg))
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(Color.brandInfo)
                        AreaMark(
                            x: .value("Date", log.date),
                            y: .value("Weight", appState.units.from(kg: log.weightKg))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(
                            colors: [Color.brandInfo.opacity(0.4), Color.brandInfo.opacity(0)],
                            startPoint: .top, endPoint: .bottom)
                        )
                    }
                    .frame(height: 140)
                }
            }
        }
    }
}

// MARK: - PR row

private struct ProgressPRRow: View {
    let pr: PersonalRecord
    let units: WeightUnit

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.brandTrophy.opacity(0.18))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.brandTrophy)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exerciseName)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                Text("\(pr.reps) rep\(pr.reps == 1 ? "" : "s") · \(pr.dateAchieved.shortDate)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(units.from(kg: pr.weightKg).prettyWeight)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Text(units.label)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Log body metric sheet

struct LogBodyMetricSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var notes = ""
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    HStack {
                        TextField(appState.units.label, text: $weight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                        Text(appState.units.label.uppercased())
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.secondary)
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Body Fat % (optional)") {
                    TextField("e.g. 12.5", text: $bodyFat).keyboardType(.decimalPad)
                }
                Section("Notes (optional)") {
                    TextField("Hydration, time of day, etc.", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Log Body Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(Double(weight) == nil)
                }
            }
        }
    }

    private func save() {
        guard let val = Double(weight.replacingOccurrences(of: ",", with: ".")) else { return }
        let kg = appState.units.toKg(val)
        let bf = Double(bodyFat.replacingOccurrences(of: ",", with: "."))
        let m = BodyMetric(weightKg: kg, date: date, bodyFatPct: bf, notes: notes)
        ctx.insert(m)
        if appState.bodyweightKg < kg + 5, appState.bodyweightKg > kg - 5 || appState.bodyweightKg == 0 {
            appState.bodyweightKg = kg
        }
        Haptic.success()
        dismiss()
    }
}
