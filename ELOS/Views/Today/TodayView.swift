import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.skin) private var skin
    @Environment(\.modelContext) private var ctx

    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \PersonalRecord.dateAchieved, order: .reverse) private var personalRecords: [PersonalRecord]

    private var program: Program {
        Program.find(id: appState.activeProgramId)
    }

    private var todayDay: ProgramDay {
        Program.todayDay(for: program, startDate: appState.programStartDate)
    }

    private var todayExercises: [ExerciseDefinition] {
        todayDay.exerciseIds.compactMap { ExerciseDefinition.find(id: $0) }
    }

    private var thisWeekSessions: [WorkoutSession] {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return sessions.filter { $0.date >= weekStart }
    }

    private var weeklyVolumeKg: Double {
        thisWeekSessions.reduce(0) { $0 + $1.totalVolumeKg }
    }

    private var weeklySetCount: Int {
        thisWeekSessions.reduce(0) { $0 + $1.sets.count }
    }

    private var lastSession: WorkoutSession? { sessions.first }

    private var firstName: String {
        let trimmed = appState.displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.components(separatedBy: " ").first ?? (trimmed.isEmpty ? "Athlete" : trimmed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, Theme.Space.lg)
                        .padding(.top, Theme.Space.xs)
                        .padding(.bottom, Theme.Space.md)

                    sessionCard
                        .padding(.horizontal, Theme.Space.md)

                    quickStats
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.md)

                    SectionLabel(title: "This Week")
                    weeklyOverview
                        .padding(.horizontal, Theme.Space.md)

                    if !personalRecords.isEmpty {
                        SectionLabel(title: "Recent PRs", actionTitle: "All", action: {})
                        recentPRs
                            .padding(.horizontal, Theme.Space.md)
                    }

                    Spacer(minLength: 60)
                }
            }
            .scrollContentBackground(.hidden)
            .background(skin.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Header (greeting + streak)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.prettyDay)
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                Text(elosGreeting + ",")
                    .font(Theme.Font.title(28))
                Text(firstName + ".")
                    .font(Theme.Font.title(28))
                    .foregroundStyle(.brand)
            }
            Spacer()
            if appState.currentStreak > 0 {
                StreakBadge(count: appState.currentStreak)
            }
        }
    }

    // MARK: Today's Session card

    private var sessionCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [program.accent, program.accent.opacity(0.65), program.accent.opacity(0.35)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            // Decorative glow circles
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 220, height: 220)
                .offset(x: 180, y: -80)
            Circle()
                .fill(Color.black.opacity(0.18))
                .frame(width: 140, height: 140)
                .offset(x: -40, y: 120)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: program.icon)
                        .font(.system(size: 12, weight: .heavy))
                    Text(program.name.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .kerning(0.7)
                }
                .foregroundStyle(.white.opacity(0.85))

                if todayDay.isRest {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rest day")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(todayDay.focus)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(todayDay.title)
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(todayDay.focus)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                if !todayDay.isRest {
                    HStack(spacing: 14) {
                        SmallStat(value: "\(todayExercises.count)", label: "Exercises")
                        SmallStat(value: "\(todayExercises.count * 4)", label: "Sets")
                        SmallStat(value: estimatedDuration, label: "Min")
                    }
                    .padding(.top, 2)

                    Button {
                        startWorkout()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill").font(.system(size: 16, weight: .black))
                            Text("Start Workout")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(program.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.pressable(scale: 0.97, haptic: .heavy))
                    .padding(.top, 4)
                } else {
                    Button {
                        startEmptyWorkout()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 16, weight: .black))
                            Text("Start Empty Workout")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.pressable(scale: 0.97, haptic: .medium))
                }
            }
            .padding(20)
        }
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .shadow(color: program.accent.opacity(0.3), radius: 22, x: 0, y: 14)
    }

    private var estimatedDuration: String {
        let mins = todayExercises.count * 11
        return "\(mins)"
    }

    // MARK: Quick stats

    private var quickStats: some View {
        HStack(spacing: 10) {
            StatTile(
                label: "Streak",
                value: "\(appState.currentStreak)",
                sub: appState.currentStreak == 1 ? "day" : "days",
                icon: "flame.fill",
                accent: .brand
            )
            StatTile(
                label: "This Week",
                value: weeklySetCount > 0 ? "\(weeklySetCount)" : "0",
                sub: weeklySetCount == 1 ? "set" : "sets",
                icon: "list.bullet.rectangle.fill",
                accent: .brandInfo
            )
            StatTile(
                label: "PRs",
                value: "\(personalRecords.count)",
                sub: "all-time",
                icon: "trophy.fill",
                accent: .brandTrophy
            )
        }
    }

    // MARK: Weekly overview

    private var weeklyOverview: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VOLUME")
                            .font(.system(size: 10, weight: .heavy))
                            .kerning(0.6)
                            .foregroundStyle(.secondary)
                        Text(displayVolume)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("SESSIONS")
                            .font(.system(size: 10, weight: .heavy))
                            .kerning(0.6)
                            .foregroundStyle(.secondary)
                        Text("\(thisWeekSessions.count)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                    }
                }

                weekDayDots
            }
        }
    }

    private var displayVolume: String {
        let v = appState.units.from(kg: weeklyVolumeKg)
        if v >= 10000 { return String(format: "%.1fk %@", v/1000, appState.units.label) }
        if v >= 1000  { return String(format: "%.1fk %@", v/1000, appState.units.label) }
        return String(format: "%.0f %@", v, appState.units.label)
    }

    private var weekDayDots: some View {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0, to: weekStart)! }
        let didTrain: Set<String> = Set(thisWeekSessions.map { $0.date.dayKey })

        return HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let trained = didTrain.contains(day.dayKey)
                let isToday = cal.isDateInToday(day)
                VStack(spacing: 4) {
                    Text(weekdayLetter(day))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(trained ? Color.brand : Color.surfaceInset)
                        .overlay(
                            Circle().strokeBorder(isToday ? Color.brand : .clear, lineWidth: 2)
                        )
                        .frame(width: 22, height: 22)
                        .overlay(
                            trained
                                ? Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.white)
                                : nil
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdayLetter(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: d)
    }

    // MARK: Recent PRs

    private var recentPRs: some View {
        SolidCard(padding: 4) {
            VStack(spacing: 0) {
                ForEach(Array(personalRecords.prefix(4).enumerated()), id: \.element.id) { i, pr in
                    PRRow(pr: pr, units: appState.units)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                    if i < min(personalRecords.count, 4) - 1 { Hairline(inset: 12) }
                }
            }
        }
    }

    // MARK: Actions

    private func startWorkout() {
        let drafts: [DraftExercise] = todayExercises.map { ex in
            DraftExercise(name: ex.name, muscleGroup: ex.muscleGroup, targetSets: 4, targetReps: 8)
        }
        let workout = ActiveWorkout(
            title: todayDay.title,
            subtitle: todayDay.focus,
            exercises: drafts
        )
        appState.activeWorkout = workout
        Haptic.heavy()
    }

    private func startEmptyWorkout() {
        let workout = ActiveWorkout(
            title: "Free Workout",
            subtitle: "Build as you go",
            exercises: []
        )
        appState.activeWorkout = workout
        Haptic.heavy()
    }
}

// MARK: - Helper subviews

private struct SmallStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .kerning(0.7)
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}


private struct PRRow: View {
    let pr: PersonalRecord
    let units: WeightUnit

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.brandTrophy.opacity(0.18))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.brandTrophy)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exerciseName)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                Text("\(pr.reps) rep\(pr.reps == 1 ? "" : "s") · \(pr.dateAchieved.shortDate)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(units.from(kg: pr.weightKg).prettyWeight)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Text(units.label)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
