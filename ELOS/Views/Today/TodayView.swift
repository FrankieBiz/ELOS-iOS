import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var ctx

    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \PersonalRecord.dateAchieved, order: .reverse) private var personalRecords: [PersonalRecord]

    private var program: Program { Program.find(id: appState.activeProgramId) }
    private var todayDay: ProgramDay { Program.todayDay(for: program, startDate: appState.programStartDate) }
    private var todayExercises: [ExerciseDefinition] {
        todayDay.exerciseIds.compactMap { ExerciseDefinition.find(id: $0) }
    }

    private var thisWeekSessions: [WorkoutSession] {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return sessions.filter { $0.date >= weekStart }
    }

    private var weeklyVolumeKg: Double { thisWeekSessions.reduce(0) { $0 + $1.totalVolumeKg } }
    private var weeklySetCount: Int    { thisWeekSessions.reduce(0) { $0 + $1.sets.count } }

    private var firstName: String {
        let trimmed = appState.displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.components(separatedBy: " ").first ?? (trimmed.isEmpty ? "there" : trimmed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text(elosGreeting + ", " + firstName)
                            .font(Theme.Font.display(34))
                            .foregroundStyle(.pearl)

                        HStack(spacing: 10) {
                            Rectangle()
                                .fill(Color.pearl.opacity(0.18))
                                .frame(width: 16, height: 1)
                            Text(Date.now.prettyDay.uppercased())
                                .font(Theme.Font.label)
                                .kerning(1.4)
                                .foregroundStyle(.silver)
                            Spacer()
                            if appState.currentStreak > 0 {
                                StreakBadge(count: appState.currentStreak, size: 26)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, Theme.Space.md)

                    // Session card
                    sessionCard
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.lg)

                    // Week strip
                    SectionLabel(title: "This Week")
                    weekStrip
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.xs)

                    // Stats
                    HStack(spacing: 10) {
                        StatTile(label: "Sets", value: "\(weeklySetCount)", sub: "this week")
                        StatTile(label: "Volume", value: displayVolume, sub: "this week")
                        StatTile(label: "PRs", value: "\(personalRecords.count)", sub: "all time")
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, Theme.Space.md)

                    // PRs
                    if !personalRecords.isEmpty {
                        SectionLabel(title: "Personal Records")
                        prList.padding(.horizontal, Theme.Space.md)
                    }

                    Spacer(minLength: 100)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.obsidian.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    // MARK: Session card

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Program label
            HStack(spacing: 6) {
                StatusDot(color: todayDay.isRest ? .silver : .pearl, size: 5)
                Text(program.name.uppercased())
                    .font(Theme.Font.label)
                    .kerning(1.4)
                    .foregroundStyle(.silver)
                Spacer()
                Text("Day \(workoutDayNumber())")
                    .font(Theme.Font.mono(11, .regular))
                    .foregroundStyle(.shadowTxt)
            }

            Spacer().frame(height: 14)

            // Session title
            Text(todayDay.isRest ? "Rest day" : todayDay.title)
                .font(Theme.Font.display(44))
                .foregroundStyle(.pearl)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(todayDay.isRest ? "Recovery is part of the work." : todayDay.focus)
                .font(Theme.Font.body(14))
                .foregroundStyle(.silver)
                .padding(.top, 4)

            // Metrics
            if !todayDay.isRest {
                Hairline()
                    .padding(.vertical, Theme.Space.md)

                HStack(spacing: 0) {
                    metricCell(label: "Exercises", value: "\(todayExercises.count)")
                    metricDivider()
                    metricCell(label: "Sets",      value: "\(todayExercises.count * 4)")
                    metricDivider()
                    metricCell(label: "Min",       value: "~\(todayExercises.count * 11)")
                }
            }

            // CTA
            Button {
                if todayDay.isRest { startEmptyWorkout() } else { startWorkout() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: todayDay.isRest ? "plus" : "arrow.right")
                        .font(.system(size: 14, weight: .thin))
                    Text(todayDay.isRest ? "Free session" : "Begin session")
                        .font(Theme.Font.title(17))
                }
                .foregroundStyle(.obsidian)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(colors: [Color.pearl.opacity(0.97), .pearl], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                )
                .breathGlow(minIntensity: 0.10, maxIntensity: 0.28, radius: 16)
            }
            .buttonStyle(.pressable(scale: 0.985, haptic: .heavy, glow: true, glowRadius: 20))
            .padding(.top, Theme.Space.md)
        }
        .padding(Theme.Space.md)
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.lg)
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Theme.Font.mono(22, .regular))
                .foregroundStyle(.pearl)
            Text(label.uppercased())
                .font(Theme.Font.label)
                .kerning(1.0)
                .foregroundStyle(.silver)
        }
        .frame(maxWidth: .infinity)
    }

    private func metricDivider() -> some View {
        Rectangle()
            .fill(Color.mist.opacity(0.6))
            .frame(width: 0.5, height: 34)
    }

    // MARK: Week strip

    private var weekStrip: some View {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0, to: weekStart)! }
        let trained: Set<String> = Set(thisWeekSessions.map { $0.date.dayKey })

        return HStack(spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                dayBar(day: day,
                       trained: trained.contains(day.dayKey),
                       isToday: cal.isDateInToday(day))
            }
        }
    }

    private func dayBar(day: Date, trained: Bool, isToday: Bool) -> some View {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return VStack(spacing: 6) {
            // Vertical bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(trained ? Color.pearl : (isToday ? Color.pearl.opacity(0.3) : Color.mist))
                .frame(height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(isToday && !trained ? Color.pearl.opacity(0.5) : Color.clear, lineWidth: 0.75)
                )
                .glow(active: trained, radius: 8, intensity: 0.3)

            Text(f.string(from: day).prefix(1))
                .font(Theme.Font.label)
                .kerning(0.5)
                .foregroundStyle(isToday ? Color.pearl : Color.shadowTxt)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: PR list

    private var prList: some View {
        VStack(spacing: 0) {
            ForEach(Array(personalRecords.prefix(5).enumerated()), id: \.element.id) { i, pr in
                prRow(pr)
                if i < min(personalRecords.count, 5) - 1 {
                    Hairline().padding(.horizontal, Theme.Space.md)
                }
            }
        }
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
    }

    private func prRow(_ pr: PersonalRecord) -> some View {
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
                    .font(Theme.Font.mono(18, .medium))
                    .foregroundStyle(.pearl)
                Text(appState.units.label)
                    .font(Theme.Font.label)
                    .foregroundStyle(.silver)
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, 14)
    }

    // MARK: Helpers

    private var displayVolume: String {
        let v = appState.units.from(kg: weeklyVolumeKg)
        if v >= 10000 { return String(format: "%.0fK", v / 1000) }
        if v >= 1000  { return String(format: "%.1fK", v / 1000) }
        return String(format: "%.0f", v)
    }

    private func workoutDayNumber() -> Int {
        max(1, (Calendar.current.dateComponents([.day], from: appState.programStartDate, to: .now).day ?? 0) + 1)
    }

    private func startWorkout() {
        let drafts: [DraftExercise] = todayExercises.map {
            DraftExercise(name: $0.name, muscleGroup: $0.muscleGroup, targetSets: 4, targetReps: 8)
        }
        appState.activeWorkout = ActiveWorkout(title: todayDay.title, subtitle: todayDay.focus, exercises: drafts)
        Haptic.heavy()
    }

    private func startEmptyWorkout() {
        appState.activeWorkout = ActiveWorkout(title: "Free Session", subtitle: "Build as you go", exercises: [])
        Haptic.heavy()
    }
}
