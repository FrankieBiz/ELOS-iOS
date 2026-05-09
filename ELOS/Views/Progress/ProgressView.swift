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
        case week = "1W", month = "1M", threeMonth = "3M", year = "1Y", all = "ALL"
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
    private var sessionsInRange: [WorkoutSession] { sessions.filter { $0.date >= startDate } }
    private var setsInRange: [WorkoutSet] { allSets.filter { $0.completedAt >= startDate } }
    private var totalVolume: Double { sessionsInRange.reduce(0) { $0 + $1.totalVolumeKg } }
    private var totalSets: Int { sessionsInRange.reduce(0) { $0 + $1.sets.count } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    rangePicker
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.sm)

                    statRow
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.md)

                    SectionLabel(title: "Volume")
                    volumeChart.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Volume by Muscle")
                    muscleChart.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Streak")
                    streakCard.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Personal Records",
                                 actionTitle: prs.count > 6 ? "All" : nil) {}
                    prList.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Body Weight",
                                 actionTitle: "Log") { showAddBodyMetric = true }
                    bodyWeightCard.padding(.horizontal, Theme.Space.md)

                    Spacer(minLength: 80)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vBG.ignoresSafeArea())
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddBodyMetric) { LogBodyMetricSheet() }
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { r in
                Button {
                    withAnimation(Theme.Motion.snappy) { range = r }
                    Haptic.selection()
                } label: {
                    Text(r.rawValue)
                        .font(.system(size: 11, weight: .black))
                        .kerning(1.0)
                        .foregroundStyle(range == r ? Color.vBG : Color.vLabelMute)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(range == r ? Color.vSignal : Color.vSurfaceHigh)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xs))
    }

    private var statRow: some View {
        HStack(spacing: 8) {
            StatTile(label: "Workouts", value: "\(sessionsInRange.count)", icon: "checkmark")
            StatTile(label: "Sets",     value: "\(totalSets)", icon: "list.number")
            StatTile(label: "Volume",   value: formatVolume(totalVolume), icon: "scalemass")
        }
    }

    private func formatVolume(_ kg: Double) -> String {
        let v = appState.units.from(kg: kg)
        if v >= 10000 { return String(format: "%.0fK", v/1000) }
        if v >= 1000  { return String(format: "%.1fK", v/1000) }
        return String(format: "%.0f", v)
    }

    // MARK: Volume chart

    private var volumeChart: some View {
        VStack {
            if sessionsInRange.isEmpty {
                emptyChart(icon: "chart.bar.xaxis", text: "No workouts in this range")
            } else {
                Chart(sessionsInRange.sorted(by: { $0.date < $1.date })) { session in
                    BarMark(
                        x: .value("Date", session.date, unit: barUnit),
                        y: .value("Volume", appState.units.from(kg: session.totalVolumeKg))
                    )
                    .foregroundStyle(Color.vSignal)
                    .cornerRadius(0)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.vLine)
                        AxisValueLabel().font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color.vLabelMute)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color.vLabelMute)
                    }
                }
                .padding(Theme.Space.md)
            }
        }
        .background(Color.vSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    private var barUnit: Calendar.Component {
        switch range {
        case .week, .month: return .day
        case .threeMonth: return .weekOfYear
        case .year, .all: return .month
        }
    }

    // MARK: Muscle volume

    private var muscleByVolume: [(group: String, volumeKg: Double)] {
        let dict = Dictionary(grouping: setsInRange, by: \.exerciseMuscleGroup)
        return dict.map { (group: $0.key, volumeKg: $0.value.reduce(0) { $0 + $1.weightKg * Double($1.reps) }) }
            .sorted { $0.volumeKg > $1.volumeKg }
            .prefix(10).map { $0 }
    }

    private var muscleChart: some View {
        VStack {
            if muscleByVolume.isEmpty {
                emptyChart(icon: "figure.run", text: "Log workouts to see muscle volume")
            } else {
                Chart(muscleByVolume, id: \.group) { item in
                    BarMark(
                        x: .value("Volume", appState.units.from(kg: item.volumeKg)),
                        y: .value("Muscle", item.group)
                    )
                    .foregroundStyle(Color.vSignal)
                    .cornerRadius(0)
                }
                .frame(height: max(180, CGFloat(muscleByVolume.count) * 26))
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.vLine)
                        AxisValueLabel().font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color.vLabelMute)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color.vLabelMute)
                    }
                }
                .padding(Theme.Space.md)
            }
        }
        .background(Color.vSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    private func emptyChart(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.vLabelFaint)
            Text(text.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .kerning(1.0)
                .foregroundStyle(.vLabelMute)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    // MARK: Streak card

    private var streakCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CURRENT")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(1.4)
                    .foregroundStyle(.vLabelMute)
                Text("\(appState.currentStreak)")
                    .font(Theme.Font.mono(40, .black))
                    .foregroundStyle(.vSignal)
                Text(appState.currentStreak == 0 ? "START TODAY" : "DAY STREAK")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(1.0)
                    .foregroundStyle(.vLabelMute)
            }
            Rectangle().fill(Color.vLine).frame(width: 0.5)
            VStack(alignment: .leading, spacing: 2) {
                Text("LONGEST")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(1.4)
                    .foregroundStyle(.vLabelMute)
                Text("\(appState.longestStreak)")
                    .font(Theme.Font.mono(40, .black))
                    .foregroundStyle(.vLabel)
                Text("DAYS")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(1.0)
                    .foregroundStyle(.vLabelMute)
            }
            Spacer()
        }
        .padding(Theme.Space.md)
        .background(Color.vSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    // MARK: PR list

    private var prList: some View {
        VStack(spacing: 0) {
            if prs.isEmpty {
                EmptyStateCard(icon: "rosette",
                               title: "No PRs Yet",
                               subtitle: "Get after it.")
            } else {
                ForEach(Array(prs.prefix(6).enumerated()), id: \.element.id) { i, pr in
                    HStack(spacing: 10) {
                        IndexBadge(n: i + 1, active: false, size: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pr.exerciseName.uppercased())
                                .font(.system(size: 12, weight: .black))
                                .kerning(0.4)
                                .foregroundStyle(.vLabel)
                                .lineLimit(1)
                            Text("\(pr.reps) REP\(pr.reps == 1 ? "" : "S") · \(pr.dateAchieved.shortDate.uppercased())")
                                .font(.system(size: 9, weight: .heavy))
                                .kerning(0.6)
                                .foregroundStyle(.vLabelMute)
                        }
                        Spacer()
                        Text(appState.units.from(kg: pr.weightKg).prettyWeight)
                            .font(Theme.Font.mono(18, .black))
                            .foregroundStyle(.vSignal)
                        Text(appState.units.label.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.vLabelMute)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 10)
                    if i < min(prs.count, 6) - 1 { Hairline().padding(.leading, 40) }
                }
            }
        }
        .background(Color.vSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    // MARK: Body weight

    private var bodyWeightCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if bodyLogs.isEmpty {
                emptyChart(icon: "figure.stand", text: "Log your weight to track trends")
                    .padding(.vertical, 14)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("LATEST")
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(1.4)
                        .foregroundStyle(.vLabelMute)
                    Spacer()
                    if let latest = bodyLogs.first {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(appState.units.from(kg: latest.weightKg).prettyWeight)")
                                .font(Theme.Font.mono(28, .black))
                                .foregroundStyle(.vLabel)
                            Text(appState.units.label.uppercased())
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.vLabelMute)
                        }
                    }
                }
                .padding(Theme.Space.md)
                Chart(bodyLogs.sorted(by: { $0.date < $1.date })) { log in
                    LineMark(
                        x: .value("Date", log.date),
                        y: .value("Weight", appState.units.from(kg: log.weightKg))
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .butt))
                    .foregroundStyle(Color.vSignal)
                }
                .frame(height: 120)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel().font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color.vLabelMute)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color.vLabelMute)
                    }
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, Theme.Space.md)
            }
        }
        .background(Color.vSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
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
                            .font(Theme.Font.mono(22, .black))
                        Text(appState.units.label.uppercased())
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.vLabelMute)
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
            .scrollContentBackground(.hidden)
            .background(Color.vBG)
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
