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
        return trimmed.components(separatedBy: " ").first ?? (trimmed.isEmpty ? "Operator" : trimmed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    statusBar
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.xs)

                    Hairline().padding(.top, Theme.Space.sm)

                    missionCard
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.lg)

                    SectionLabel(title: "This Week")
                    weekStrip
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.xs)

                    statRow
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.md)

                    if !personalRecords.isEmpty {
                        SectionLabel(title: "Personal Records")
                        prList.padding(.horizontal, Theme.Space.md)
                    }

                    Spacer(minLength: 80)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vBG.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    // MARK: Status bar

    private var statusBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.prettyDay)
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(1.6)
                    .foregroundStyle(.vLabelMute)
                Text(elosGreeting + ", " + firstName.uppercased())
                    .font(Theme.Font.title(22))
                    .foregroundStyle(.vLabel)
                    .kerning(0.5)
            }
            Spacer()
            if appState.currentStreak > 0 {
                StreakBadge(count: appState.currentStreak, size: 28)
            }
        }
    }

    // MARK: Mission card (today's workout)

    private var missionCard: some View {
        let dayNumber = workoutDayNumber()
        return VStack(alignment: .leading, spacing: 0) {
            // Top row: program tag + day index
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        StatusDot(color: todayDay.isRest ? .vLabelMute : .vSignal)
                        Text(program.name.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .kerning(1.4)
                            .foregroundStyle(.vLabelMute)
                    }
                    Text(todayDay.isRest ? "REST" : todayDay.title.uppercased())
                        .font(Theme.Font.display(54))
                        .foregroundStyle(.vLabel)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .kerning(-0.5)
                    Text(todayDay.focus.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .kerning(1.2)
                        .foregroundStyle(.vLabelMute)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("DAY")
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(1.6)
                        .foregroundStyle(.vLabelFaint)
                    Text(String(format: "%02d", dayNumber))
                        .font(Theme.Font.mono(28, .black))
                        .foregroundStyle(.vSignal)
                }
            }

            // Stats sub-row
            if !todayDay.isRest {
                Hairline().padding(.vertical, Theme.Space.md)
                HStack(spacing: 0) {
                    metric(label: "Exercises", value: "\(todayExercises.count)")
                    Rectangle().fill(Color.vLine).frame(width: 0.5, height: 32)
                    metric(label: "Sets",      value: "\(todayExercises.count * 4)")
                    Rectangle().fill(Color.vLine).frame(width: 0.5, height: 32)
                    metric(label: "Min",       value: "~\(todayExercises.count * 11)")
                }
            } else {
                Hairline().padding(.vertical, Theme.Space.md)
                Text("Recovery is part of the protocol.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.vLabelMute)
            }

            // CTA
            Button {
                if todayDay.isRest { startEmptyWorkout() } else { startWorkout() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: todayDay.isRest ? "plus" : "play.fill")
                        .font(.system(size: 13, weight: .black))
                    Text(todayDay.isRest ? "FREE WORKOUT" : "BEGIN MISSION")
                        .font(.system(size: 13, weight: .black))
                        .kerning(1.6)
                }
                .foregroundStyle(.vBG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.vSignal, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            }
            .buttonStyle(.pressable(scale: 0.98, haptic: .heavy))
            .padding(.top, Theme.Space.md)
        }
        .padding(Theme.Space.md)
        .background(Color.vSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
    }

    private func metric(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Font.mono(20, .black))
                .foregroundStyle(.vLabel)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .kerning(1.2)
                .foregroundStyle(.vLabelMute)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Week strip

    private var weekStrip: some View {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0, to: weekStart)! }
        let trained: Set<String> = Set(thisWeekSessions.map { $0.date.dayKey })

        return HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                dayCell(day: day, trained: trained.contains(day.dayKey),
                        isToday: cal.isDateInToday(day))
            }
        }
    }

    private func dayCell(day: Date, trained: Bool, isToday: Bool) -> some View {
        let f = DateFormatter(); f.dateFormat = "EEE"
        let dn = DateFormatter(); dn.dateFormat = "d"
        return VStack(spacing: 4) {
            Text(f.string(from: day).uppercased())
                .font(.system(size: 9, weight: .heavy))
                .kerning(0.8)
                .foregroundStyle(isToday ? .vSignal : .vLabelFaint)
            Text(dn.string(from: day))
                .font(Theme.Font.mono(15, .black))
                .foregroundStyle(trained ? .vBG : (isToday ? .vSignal : .vLabel))
            Rectangle()
                .fill(trained ? Color.vSignal : Color.vLine)
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(trained ? Color.vSignal : Color.vSurface)
        .overlay(
            Rectangle().strokeBorder(isToday ? Color.vSignal : Color.vLine, lineWidth: isToday ? 1 : 0.5)
        )
    }

    // MARK: Stat row

    private var statRow: some View {
        HStack(spacing: 8) {
            StatTile(label: "Sets", value: "\(weeklySetCount)",
                     sub: "this week", icon: "list.number")
            StatTile(label: "Volume", value: displayVolume,
                     sub: "this week", icon: "scalemass")
            StatTile(label: "PRs", value: "\(personalRecords.count)",
                     sub: "all time", icon: "rosette")
        }
    }

    private var displayVolume: String {
        let v = appState.units.from(kg: weeklyVolumeKg)
        if v >= 10000 { return String(format: "%.0fK", v/1000) }
        if v >= 1000  { return String(format: "%.1fK", v/1000) }
        return String(format: "%.0f", v)
    }

    // MARK: PR list

    private var prList: some View {
        VStack(spacing: 0) {
            ForEach(Array(personalRecords.prefix(4).enumerated()), id: \.element.id) { i, pr in
                prRow(idx: i + 1, pr: pr)
                if i < min(personalRecords.count, 4) - 1 {
                    Hairline().padding(.leading, 38)
                }
            }
        }
        .background(Color.vSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
    }

    private func prRow(idx: Int, pr: PersonalRecord) -> some View {
        HStack(spacing: 10) {
            IndexBadge(n: idx, active: false, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exerciseName.uppercased())
                    .font(.system(size: 13, weight: .black))
                    .kerning(0.4)
                    .foregroundStyle(.vLabel)
                    .lineLimit(1)
                Text("\(pr.reps) REP\(pr.reps == 1 ? "" : "S") · \(pr.dateAchieved.shortDate.uppercased())")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
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
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    // MARK: Helpers

    private func workoutDayNumber() -> Int {
        let days = Calendar.current.dateComponents([.day], from: appState.programStartDate, to: .now).day ?? 0
        return max(1, days + 1)
    }

    private func startWorkout() {
        let drafts: [DraftExercise] = todayExercises.map { ex in
            DraftExercise(name: ex.name, muscleGroup: ex.muscleGroup, targetSets: 4, targetReps: 8)
        }
        appState.activeWorkout = ActiveWorkout(
            title: todayDay.title,
            subtitle: todayDay.focus,
            exercises: drafts
        )
        Haptic.heavy()
    }

    private func startEmptyWorkout() {
        appState.activeWorkout = ActiveWorkout(
            title: "Free Workout",
            subtitle: "Build as you go",
            exercises: []
        )
        Haptic.heavy()
    }
}
