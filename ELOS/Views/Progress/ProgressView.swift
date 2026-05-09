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

    private var startDate: Date { Calendar.current.date(byAdding: .day, value: -range.days, to: .now) ?? .now }
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

                    HStack(spacing: 10) {
                        StatTile(label: "Sessions", value: "\(sessionsInRange.count)")
                        StatTile(label: "Sets", value: "\(totalSets)")
                        StatTile(label: "Volume", value: formatVolume(totalVolume))
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, Theme.Space.md)

                    SectionLabel(title: "Volume")
                    volumeChart.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "By Muscle")
                    muscleChart.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Streak")
                    streakCard.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Personal Records")
                    prList.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Body Weight", actionTitle: "Log") { showAddBodyMetric = true }
                    bodyWeightCard.padding(.horizontal, Theme.Space.md)

                    Spacer(minLength: 100)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.obsidian.ignoresSafeArea())
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddBodyMetric) { LogBodyMetricSheet() }
        }
    }

    // MARK: Range picker — segment with underline

    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { r in
                Button {
                    withAnimation(Theme.Motion.silk) { range = r }
                    Haptic.selection()
                } label: {
                    VStack(spacing: 0) {
                        Text(r.rawValue)
                            .font(Theme.Font.label)
                            .kerning(1.0)
                            .foregroundStyle(range == r ? Color.pearl : Color.shadowTxt)
                            .padding(.vertical, 10)
                        Rectangle()
                            .fill(range == r ? Color.pearl : Color.clear)
                            .frame(height: 1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func formatVolume(_ kg: Double) -> String {
        let v = appState.units.from(kg: kg)
        if v >= 10000 { return String(format: "%.0fK", v / 1000) }
        if v >= 1000  { return String(format: "%.1fK", v / 1000) }
        return String(format: "%.0f", v)
    }

    // MARK: Volume chart

    private var volumeChart: some View {
        Group {
            if sessionsInRange.isEmpty {
                emptyChart(icon: "chart.bar.xaxis", text: "No sessions in this range")
            } else {
                Chart(sessionsInRange.sorted(by: { $0.date < $1.date })) { session in
                    BarMark(
                        x: .value("Date", session.date, unit: barUnit),
                        y: .value("Volume", appState.units.from(kg: session.totalVolumeKg))
                    )
                    .foregroundStyle(Color.pearl.opacity(0.8))
                    .cornerRadius(2)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.mist.opacity(0.4))
                        AxisValueLabel().font(Theme.Font.label).foregroundStyle(Color.silver)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(Theme.Font.label).foregroundStyle(Color.silver)
                    }
                }
                .padding(Theme.Space.md)
            }
        }
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
    }

    private var barUnit: Calendar.Component {
        switch range {
        case .week, .month: return .day
        case .threeMonth: return .weekOfYear
        case .year, .all: return .month
        }
    }

    // MARK: Muscle chart

    private var muscleByVolume: [(group: String, volumeKg: Double)] {
        Dictionary(grouping: setsInRange, by: \.exerciseMuscleGroup)
            .map { (group: $0.key, volumeKg: $0.value.reduce(0) { $0 + $1.weightKg * Double($1.reps) }) }
            .sorted { $0.volumeKg > $1.volumeKg }
            .prefix(8).map { $0 }
    }

    private var muscleChart: some View {
        Group {
            if muscleByVolume.isEmpty {
                emptyChart(icon: "figure.run", text: "Log sessions to see muscle volume")
            } else {
                Chart(muscleByVolume, id: \.group) { item in
                    BarMark(
                        x: .value("Volume", appState.units.from(kg: item.volumeKg)),
                        y: .value("Muscle", item.group)
                    )
                    .foregroundStyle(Color.pearl.opacity(0.7))
                    .cornerRadius(2)
                }
                .frame(height: max(160, CGFloat(muscleByVolume.count) * 28))
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Color.mist.opacity(0.4))
                        AxisValueLabel().font(Theme.Font.label).foregroundStyle(Color.silver)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(Theme.Font.label).foregroundStyle(Color.silver)
                    }
                }
                .padding(Theme.Space.md)
            }
        }
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
    }

    private func emptyChart(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .thin))
                .foregroundStyle(.shadowTxt)
            Text(text)
                .font(Theme.Font.body(13))
                .foregroundStyle(.silver)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    // MARK: Streak card

    private var streakCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current".uppercased())
                    .font(Theme.Font.label)
                    .kerning(1.4)
                    .foregroundStyle(.silver)
                Text("\(appState.currentStreak)")
                    .font(Theme.Font.display(56))
                    .foregroundStyle(.pearl)
                Text(appState.currentStreak == 0 ? "Start today" : "day streak")
                    .font(Theme.Font.body(13))
                    .foregroundStyle(.silver)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Hairline()
                .frame(width: 0.5, height: 80)
                .padding(.horizontal, Theme.Space.md)

            VStack(alignment: .leading, spacing: 6) {
                Text("Best".uppercased())
                    .font(Theme.Font.label)
                    .kerning(1.4)
                    .foregroundStyle(.silver)
                Text("\(appState.longestStreak)")
                    .font(Theme.Font.display(56))
                    .foregroundStyle(.pearl.opacity(0.5))
                Text("days")
                    .font(Theme.Font.body(13))
                    .foregroundStyle(.shadowTxt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Space.md)
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
    }

    // MARK: PR list

    private var prList: some View {
        Group {
            if prs.isEmpty {
                EmptyStateCard(icon: "rosette",
                               title: "No records yet",
                               subtitle: "Your personal records will appear here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(prs.prefix(6).enumerated()), id: \.element.id) { i, pr in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pr.exerciseName)
                                    .font(Theme.Font.heading(14))
                                    .foregroundStyle(.pearl)
                                    .lineLimit(1)
                                Text("\(pr.reps) rep\(pr.reps == 1 ? "" : "s") · \(pr.dateAchieved.shortDate)")
                                    .font(Theme.Font.body(12))
                                    .foregroundStyle(.silver)
                            }
                            Spacer()
                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text(appState.units.from(kg: pr.weightKg).prettyWeight)
                                    .font(Theme.Font.mono(18, .regular))
                                    .foregroundStyle(.pearl)
                                Text(appState.units.label)
                                    .font(Theme.Font.label)
                                    .foregroundStyle(.silver)
                            }
                        }
                        .padding(.horizontal, Theme.Space.md).padding(.vertical, 14)
                        if i < min(prs.count, 6) - 1 {
                            Hairline().padding(.horizontal, Theme.Space.md)
                        }
                    }
                }
                .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .edgeHighlight(radius: Theme.Radius.md)
            }
        }
    }

    // MARK: Body weight

    private var bodyWeightCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if bodyLogs.isEmpty {
                emptyChart(icon: "figure.stand", text: "Log your weight to track trends")
                    .padding(.vertical, Theme.Space.md)
            } else {
                HStack(alignment: .lastTextBaseline) {
                    Text("Latest".uppercased())
                        .font(Theme.Font.label)
                        .kerning(1.4)
                        .foregroundStyle(.silver)
                    Spacer()
                    if let latest = bodyLogs.first {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(appState.units.from(kg: latest.weightKg).prettyWeight)
                                .font(Theme.Font.mono(28, .regular))
                                .foregroundStyle(.pearl)
                            Text(appState.units.label)
                                .font(Theme.Font.body(12))
                                .foregroundStyle(.silver)
                        }
                    }
                }
                .padding(Theme.Space.md)

                Chart(bodyLogs.sorted(by: { $0.date < $1.date })) { log in
                    LineMark(
                        x: .value("Date", log.date),
                        y: .value("Weight", appState.units.from(kg: log.weightKg))
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .foregroundStyle(Color.pearl)
                }
                .frame(height: 100)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel().font(Theme.Font.label).foregroundStyle(Color.silver)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(Theme.Font.label).foregroundStyle(Color.silver)
                    }
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, Theme.Space.md)
            }
        }
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
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
                            .font(Theme.Font.mono(22, .regular))
                        Text(appState.units.label.uppercased())
                            .font(Theme.Font.label)
                            .foregroundStyle(.silver)
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
            .background(Color.obsidian)
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(Double(weight) == nil)
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
