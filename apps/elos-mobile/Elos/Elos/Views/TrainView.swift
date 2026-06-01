import SwiftUI
import SwiftData

// MARK: - Week day data (dynamic — built from active split)
private struct WeekDay: Identifiable {
    let id = UUID()
    let letter: String
    let number: Int
    let title: String
    let sublabel: String
    let isToday: Bool
    let isPast: Bool
    let loadColor: Color
}

// MARK: - Main View
struct TrainView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @EnvironmentObject var socialVM: SocialViewModel
    @EnvironmentObject var context: TrainingContext
    @Environment(\.modelContext) private var modelContext

    @State private var expandedExercise: UUID?
    @State private var selectedMuscleName: String? = "chest"
    @State private var prsExpanded         = false
    @State private var waitingForReadiness = false
    @State private var recentExercises: [ExercisePickerViewModel.ExerciseResponse] = []
    @State private var userProgress: GamificationEngine.UserProgress?
    @State private var workoutStreak: Int = 0
    @State private var sessionCount: Int = 0

    private enum TrainState {
        case noSplit
        case restDay
        case gymDayNoReadiness
        case gymDayReady
    }

    private var trainState: TrainState {
        guard vm.activeSplit != nil else { return .noSplit }
        let isGymToday = vm.weekLoadMap(daysAhead: 1).first?.loadType == "gym"
        guard isGymToday else { return .restDay }
        guard vm.todayReadiness != nil else { return .gymDayNoReadiness }
        return .gymDayReady
    }

    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    if context.shouldSuggestDeload { deloadBanner }
                    if let progress = userProgress {
                        XPRankCard(
                            progress: progress,
                            workoutStreak: workoutStreak,
                            sessionCount: sessionCount,
                            prCount: vm.personalRecords.count
                        )
                    }
                    switch trainState {
                    case .noSplit:           noSplitHint
                    case .restDay:           restDayCard
                    case .gymDayNoReadiness: programHeader; readinessPromptCard
                    case .gymDayReady:       programHeader
                    }
                    weekStrip
                    leaderboardCard
                    quickActions
                    if !recentExercises.isEmpty { recentExercisesRow }
                    startButton
                    exercisesSection
                    muscleVolumePanel
                    weeklyRadarCard
                    personalRecordsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button { context.showHistory = true } label: {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(Color.tint)
                        }
                        Button { context.showAnalytics = true } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(Color.tint)
                        }
                    }
                }
            }
        }
        .onAppear {
            if expandedExercise == nil {
                expandedExercise = vm.exercises.first?.id
            }
            vm.loadActiveSplit()
            computeUserProgress()
            Task { await loadRecentExercises() }
            context.update(
                shouldDeload: trainVM.showDeloadSuggestion,
                readinessScore: vm.todayReadiness.map { Int($0.overallScore.rounded()) }
            )
        }
        .sheet(isPresented: $context.showSplitFinder) {
            SplitFinderView(dismissAll: { context.showSplitFinder = false })
                .environmentObject(vm)
        }
        .sheet(isPresented: $context.showAnalytics)        { AnalyticsView() }
        .sheet(isPresented: $context.showLibrary)          { ExerciseLibraryView(modelContext: vm.modelContext) }
        .sheet(isPresented: $context.showTemplates)        { TemplatesView(modelContext: vm.modelContext) }
        .sheet(isPresented: $context.showStretches)        { StretchRoutinesView() }
        .sheet(isPresented: $context.showSplitLibrary)     { ProgramsView().environmentObject(vm) }
        .sheet(isPresented: $context.showHistory)          { WorkoutHistoryView() }
        .sheet(isPresented: $context.showLeaderboard) {
            CrewView()
                .environmentObject(socialVM)
                .environmentObject(vm)
        }
        .sheet(isPresented: $context.showReadinessSheet) {
            ReadinessCheckInView(
                onDismiss: { context.showReadinessSheet = false },
                onComplete: { record in
                    context.readinessDidComplete(record)
                    vm.loadTodayReadiness()
                    waitingForReadiness = false
                    startSessionWithWarmup()
                }
            )
            .environmentObject(vm)
        }
        .sheet(isPresented: $context.showPostSummary) {
            if let summary = context.sessionSummary {
                PostSessionSummaryView(summary: summary)
                    .environmentObject(vm)
                    .environmentObject(trainVM)
                    .environmentObject(context)
            }
        }
        .task {
            let uid = vm.currentUserID
            if !uid.isEmpty {
                await socialVM.load(ownerID: uid)
            }
            await socialVM.loadStandings()
            await socialVM.loadBoard()
        }
        .onChange(of: vm.showingSession) { _, isShowing in
            if !isShowing { computeUserProgress() }
        }
        .onChange(of: vm.todayReadiness?.id) { _, _ in
            context.update(
                shouldDeload: trainVM.showDeloadSuggestion,
                readinessScore: vm.todayReadiness.map { Int($0.overallScore.rounded()) }
            )
        }
        .onChange(of: context.showReadinessSheet) { _, isShowing in
            if !isShowing && waitingForReadiness {
                waitingForReadiness = false
                startSessionWithWarmup()
            }
        }
        .onChange(of: context.showPostSummary) { _, isShowing in
            if !isShowing && context.pendingAnalytics {
                context.pendingAnalytics = false
                context.showAnalytics = true
            }
        }
    }

    private func startSessionWithWarmup() {
        if vm.activeSplit?.includeWarmups == true {
            let goal: TrainingGoal = vm.activeSplit?.name.lowercased().contains("athletic") == true
                ? .athletic : .hypertrophy
            context.warmupExercises = WarmupLibrary.block(goal: goal, style: .dynamic)
            context.warmupPhaseComplete = false
            context.phase = .warmup
        } else {
            context.phase = .active
        }
        vm.showingSession = true
    }

    // MARK: Context State Cards

    private var noSplitHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("No active split — tap Programs below to set one up.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var restDayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "moon.fill").foregroundStyle(Color.tint)
                Text("Rest Day").font(.system(size: 18, weight: .bold))
                Spacer()
            }
            if let next = vm.weekLoadMap(daysAhead: 7).first(where: { $0.loadType == "gym" }) {
                let cal = Calendar.current
                let daysAway = (cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                                   to: cal.startOfDay(for: next.date)).day ?? 0)
                let dayName = vm.gymDay(for: next.date)?.dayName ?? "Workout"
                Text("Next: \(dayName) in \(daysAway) day\(daysAway == 1 ? "" : "s")")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .elosCard()
    }

    private var readinessPromptCard: some View {
        Button { context.showReadinessSheet = true } label: {
            HStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill").foregroundStyle(.indigo)
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Image(systemName: "bolt.fill").foregroundStyle(.yellow)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick check-in before you train?")
                        .font(.subheadline).fontWeight(.semibold)
                    Text("Takes 10 seconds — helps us guide your session.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: Deload Banner
    private var deloadBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(Color.warn)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Deload Suggested")
                    .font(.subheadline).fontWeight(.semibold)
                Text("3 high-RPE sessions in a row. Consider reducing volume by 40% this week.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                withAnimation { trainVM.showDeloadSuggestion = false }
            } label: {
                Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.warn.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.warn.opacity(0.3), lineWidth: 1))
    }

    // MARK: Program Header
    private var programHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let split = vm.activeSplit {
                        let dayCount = vm.activeSplitDays.count
                        let dayIdx   = vm.currentSplitDayIndex
                        let dayName  = vm.currentSplitDay.map { $0.isRest ? "Rest" : ($0.dayName.isEmpty ? "Workout" : $0.dayName) } ?? "—"
                        Text("\(dayName) · Day \(dayIdx + 1) of \(dayCount)")
                            .font(.system(size: 20, weight: .bold))
                        Text(split.name)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No Active Split")
                            .font(.system(size: 20, weight: .bold))
                        Button("Pick a split in Programs") { context.showSplitLibrary = true }
                            .font(.system(size: 13))
                            .foregroundStyle(Color.tint)
                    }
                }
                Spacer()
                if let activatedAt = vm.activeSplit?.activatedAt {
                    let cal = Calendar.current
                    let weeksIn = max(1, (cal.dateComponents([.weekOfYear], from: activatedAt, to: Date()).weekOfYear ?? 0) + 1)
                    Text("Wk \(weeksIn)")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .elosCard()
    }

    private func computeUserProgress() {
        let ownerID = vm.currentUserID
        guard !ownerID.isEmpty else { return }
        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())) ?? []
        let sets     = (try? modelContext.fetch(FetchDescriptor<ExerciseSetRecord>())) ?? []
        let mySessions = sessions.filter { $0.ownerID == ownerID }
        let mySets     = sets.filter     { $0.ownerID == ownerID }
        let xp = GamificationEngine.totalXP(
            sessions: mySessions,
            sets: mySets,
            prCount: vm.personalRecords.count
        )
        userProgress   = GamificationEngine.progress(totalXP: xp)
        workoutStreak  = GamificationEngine.workoutStreak(sessions: mySessions)
        sessionCount   = mySessions.filter { $0.finishedAt != nil }.count
    }

    // MARK: Week Strip
    private var weekStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(buildWeekDays()) { day in WeekDayCard(day: day) }
            }
            .padding(.horizontal, 1)
        }
    }

    private func buildWeekDays() -> [WeekDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
        let loadMap = vm.weekLoadMap(daysAhead: 7)
        return loadMap.enumerated().map { _, entry in
            let date = entry.date
            let comps = cal.dateComponents([.weekday, .day], from: date)
            let letter = dayLetters[(comps.weekday ?? 1) - 1]
            let number = comps.day ?? 0
            let isToday = cal.isDateInToday(date)
            let isPast  = date < today

            switch entry.loadType {
            case "gym":
                let dayName = vm.gymDay(for: date).flatMap { $0.dayName.isEmpty ? nil : $0.dayName } ?? "Gym"
                return WeekDay(letter: letter, number: number, title: dayName,
                               sublabel: "Train", isToday: isToday, isPast: isPast, loadColor: .mGym)
            case "exam":
                return WeekDay(letter: letter, number: number, title: "Exam",
                               sublabel: "Study", isToday: isToday, isPast: isPast, loadColor: .mExams)
            case "skip":
                return WeekDay(letter: letter, number: number, title: "Skipped",
                               sublabel: "—", isToday: isToday, isPast: isPast, loadColor: .secondary)
            default:
                return WeekDay(letter: letter, number: number, title: "Rest",
                               sublabel: "Recover", isToday: isToday, isPast: isPast, loadColor: .secondary)
            }
        }
    }

    // MARK: Leaderboard Card
    private var leaderboardCard: some View {
        Button {
            context.showLeaderboard = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("This Week", systemImage: "trophy")
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text(weekRangeLabel())
                        .font(.caption2).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                if socialVM.friends.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(.secondary)
                        Text("Add friends to compete")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 0) {
                        ForEach(Array(socialVM.weeklyBoard.prefix(3).enumerated()), id: \.element.id) { idx, entry in
                            let medals = ["🥇","🥈","🥉"]
                            HStack(spacing: 6) {
                                Text(idx < medals.count ? medals[idx] : "#\(entry.rank)")
                                    .font(.caption)
                                AvatarCircle(initials: entry.initials, hex: entry.avatarHex, size: 24)
                                Text(entry.displayName.components(separatedBy: " ").first ?? entry.displayName)
                                    .font(.caption).fontWeight(entry.is_self ? .bold : .regular)
                                    .foregroundStyle(entry.is_self ? Color.tint : .primary)
                            }
                            if idx < 2 { Spacer() }
                        }
                        Spacer()
                    }
                    if let standings = socialVM.standings {
                        let rank = rankValue(for: socialVM.selectedMetric, standings: standings)
                        let val  = metricValue(for: socialVM.selectedMetric, standings: standings)
                        Text("You're #\(rank) · \(socialVM.formattedValue(val, metric: socialVM.selectedMetric))")
                            .font(.caption).foregroundStyle(Color.tint)
                    }
                }
            }
            .padding(14)
            .elosCard()
        }
        .buttonStyle(.plain)
    }

    private func weekRangeLabel() -> String {
        let now = Date()
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? now
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: start))–\(fmt.string(from: end))"
    }

    private func rankValue(for metric: String, standings: MyStandingsResponse) -> Int {
        switch metric {
        case "volume":   return standings.volume.rank
        case "sessions": return standings.sessions.rank
        case "streak":   return standings.streak.rank
        case "prs":      return standings.prs.rank
        default:         return standings.volume.rank
        }
    }

    private func metricValue(for metric: String, standings: MyStandingsResponse) -> Double {
        switch metric {
        case "volume":   return standings.volume.value
        case "sessions": return standings.sessions.value
        case "streak":   return standings.streak.value
        case "prs":      return standings.prs.value
        default:         return standings.volume.value
        }
    }

    // MARK: Quick Actions
    private var recentExercisesRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECENT")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Browse all") { context.showExercisePicker = true }
                    .font(.caption)
                    .foregroundStyle(Color.tint)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentExercises) { ex in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ex.name)
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(ex.primary_muscle.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(width: 140, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .sheet(isPresented: $context.showExercisePicker) {
            ExercisePickerView(onPickSingle: { _ in context.showExercisePicker = false })
        }
    }

    private func loadRecentExercises() async {
        struct ListResponse: Decodable { let exercises: [ExercisePickerViewModel.ExerciseResponse] }
        do {
            let r: ListResponse = try await ApiClient.shared.get("/exercises/recent?limit=8")
            recentExercises = r.exercises
        } catch {}
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            QuickActionButton(icon: "list.bullet.clipboard", label: "Templates") { context.showTemplates   = true }
            QuickActionButton(icon: "calendar.badge.plus",   label: "Programs")  { context.showSplitLibrary = true }
            QuickActionButton(icon: "figure.cooldown",        label: "Stretches") { context.showStretches    = true }
            QuickActionButton(icon: "dumbbell",               label: "Library")   { context.showLibrary      = true }
        }
    }

    // MARK: Start Button
    private var startButton: some View {
        VStack(spacing: 10) {
            Button {
                vm.prepareExercisesForToday()
                if vm.todayReadiness == nil {
                    waitingForReadiness = true
                    context.showReadinessSheet = true
                } else {
                    startSessionWithWarmup()
                }
            } label: {
                Label("Start Today's Workout", systemImage: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if let nudge = context.volumeNudge {
                Text(nudge)
                    .font(.caption)
                    .foregroundStyle(Color.warn)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if vm.activeSplit != nil && !vm.isTodaySkipped {
                Button {
                    vm.skipToday()
                } label: {
                    Label("Skip Today", systemImage: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Exercises
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S EXERCISES")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                Button {
                    context.showExercisePicker = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption).foregroundStyle(Color.tint)
                }
            }

            if vm.exercises.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No exercises planned")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("Add a split in Programs or start a free workout.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .elosCard()
            } else {
                ForEach($vm.exercises) { $exercise in
                    ExerciseCard(
                        exercise: $exercise,
                        isExpanded: expandedExercise == exercise.id,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedExercise = expandedExercise == exercise.id ? nil : exercise.id
                                selectedMuscleName = exercise.primaryMuscle
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: Muscle Volume Panel
    private var muscleVolumePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MUSCLE VOLUME · THIS WEEK")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(vm.muscleVolume.enumerated()), id: \.element.id) { idx, mv in
                    let isSelected = selectedMuscleName?.lowercased() == mv.muscle.lowercased()
                    Button {
                        withAnimation { selectedMuscleName = mv.muscle.lowercased() }
                    } label: {
                        MuscleVolumeRow(mv: mv, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    if idx < vm.muscleVolume.count - 1 { Divider().padding(.leading, 80) }
                }
            }
            .elosCard()
        }
    }

    // MARK: Personal Records
    private var personalRecordsCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { prsExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Color.good)
                    Text("Personal Records").font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Image(systemName: prsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if prsExpanded {
                Divider()
                ForEach(vm.personalRecords) { pr in
                    HStack {
                        Text(pr.lift).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        Text(pr.weight)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                        Text(pr.reps)
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    Divider().padding(.leading, 16)
                }
            }
        }
        .elosCard()
    }

    // MARK: Weekly Radar Card

    private var weeklyRadarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("THIS WEEK")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                Text(weekRangeLabel())
                    .font(.caption2).foregroundStyle(.secondary)
            }

            let axes = buildMuscleAxes()
            let current = currentMuscleStats()

            HStack {
                Spacer()
                WeeklyRadarChart(axes: axes, size: 200)
                Spacer()
            }

            HStack(spacing: 6) {
                Circle().fill(Color.tint).frame(width: 6, height: 6)
                Text("This week").font(.caption2).foregroundStyle(.secondary)
                Spacer().frame(width: 12)
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 12, height: 1.5)
                Text("Prior week").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    muscleChip("Chest",     sets: current.chest,     target: 12)
                    muscleChip("Back",      sets: current.back,      target: 14)
                    muscleChip("Legs",      sets: current.legs,      target: 14)
                    muscleChip("Shoulders", sets: current.shoulders, target: 10)
                    muscleChip("Arms",      sets: current.arms,      target: 10)
                    muscleChip("Core",      sets: current.core,      target: 8)
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(16)
        .elosCard()
    }

    private func muscleChip(_ label: String, sets: Int, target: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(sets)/\(target)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(sets >= target ? Color.good : Color.primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Muscle radar data

    private struct MuscleWeekStats {
        var chest: Int = 0
        var back: Int = 0
        var legs: Int = 0
        var shoulders: Int = 0
        var arms: Int = 0
        var core: Int = 0
    }

    private func isoWeekStart(weeksAgo: Int = 0) -> Date {
        let cal = Calendar(identifier: .iso8601)
        let now = Date()
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let thisMonday = cal.date(from: components) ?? now
        return cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisMonday) ?? thisMonday
    }

    private func muscleCounts(allSets: [ExerciseSetRecord], ownerID: String, weekStart: Date) -> MuscleWeekStats {
        let cal = Calendar.current
        let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
        let doneSets = allSets.filter {
            $0.ownerID == ownerID &&
            $0.isDone &&
            ($0.completedAt ?? .distantPast) >= weekStart &&
            ($0.completedAt ?? .distantPast) < weekEnd
        }
        var s = MuscleWeekStats()
        for set in doneSets {
            switch trainVM.muscleGroup(for: set.exerciseName) {
            case "chest":                                        s.chest += 1
            case "lats", "rear_delts":                           s.back += 1
            case "quads", "hamstrings", "glutes", "calves":      s.legs += 1
            case "front_delts", "side_delts":                    s.shoulders += 1
            case "biceps", "triceps":                            s.arms += 1
            case "core":                                         s.core += 1
            default: break
            }
        }
        return s
    }

    private func currentMuscleStats() -> MuscleWeekStats {
        let ownerID = vm.currentUserID
        guard !ownerID.isEmpty else { return MuscleWeekStats() }
        let allSets = (try? modelContext.fetch(FetchDescriptor<ExerciseSetRecord>())) ?? []
        return muscleCounts(allSets: allSets, ownerID: ownerID, weekStart: isoWeekStart(weeksAgo: 0))
    }

    private func buildMuscleAxes() -> [RadarAxis] {
        let ownerID = vm.currentUserID
        guard !ownerID.isEmpty else { return [] }
        let allSets = (try? modelContext.fetch(FetchDescriptor<ExerciseSetRecord>())) ?? []
        let current = muscleCounts(allSets: allSets, ownerID: ownerID, weekStart: isoWeekStart(weeksAgo: 0))
        let prior   = muscleCounts(allSets: allSets, ownerID: ownerID, weekStart: isoWeekStart(weeksAgo: 1))
        let t = (chest: 12.0, back: 14.0, legs: 14.0, shoulders: 10.0, arms: 10.0, core: 8.0)
        return [
            RadarAxis(label: "Chest",     current: min(1, Double(current.chest)     / t.chest),     prior: min(1, Double(prior.chest)     / t.chest)),
            RadarAxis(label: "Back",      current: min(1, Double(current.back)      / t.back),      prior: min(1, Double(prior.back)      / t.back)),
            RadarAxis(label: "Legs",      current: min(1, Double(current.legs)      / t.legs),      prior: min(1, Double(prior.legs)      / t.legs)),
            RadarAxis(label: "Shoulders", current: min(1, Double(current.shoulders) / t.shoulders), prior: min(1, Double(prior.shoulders) / t.shoulders)),
            RadarAxis(label: "Arms",      current: min(1, Double(current.arms)      / t.arms),      prior: min(1, Double(prior.arms)      / t.arms)),
            RadarAxis(label: "Core",      current: min(1, Double(current.core)      / t.core),      prior: min(1, Double(prior.core)      / t.core)),
        ]
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.vertical, 10)
            .foregroundStyle(Color.tint)
            .background(Color.tintSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Week Day Card
private struct WeekDayCard: View {
    let day: WeekDay

    var body: some View {
        VStack(spacing: 4) {
            Text(day.letter).font(.system(size: 10, weight: .medium))
            Text("\(day.number)").font(.system(size: 15, weight: .bold))
            Text(day.title).font(.system(size: 11, weight: .bold)).lineLimit(1)
            Text(day.sublabel).font(.system(size: 9)).lineLimit(1)
            if day.isPast {
                Circle().fill(Color.good).frame(width: 5, height: 5)
            } else {
                Circle().fill(Color.clear).frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .foregroundStyle(day.isToday ? Color.white : Color.primary)
        .background(day.isToday ? Color.tint : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            if !day.isToday && !day.isPast {
                RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

// MARK: - Exercise Card
private struct ExerciseCard: View {
    @Binding var exercise: Exercise
    let isExpanded: Bool
    let onSelect: () -> Void

    @State private var showingSwap = false

    private var doneCount: Int { exercise.sets.filter(\.done).count }
    private var allDone: Bool  { doneCount == exercise.sets.count }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(allDone ? Color.good : (isExpanded ? Color.tint : Color.secondary.opacity(0.3)))
                        .frame(width: 10, height: 10)
                    Text(exercise.name).font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(exercise.setsLabel)
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primary: \(exercise.primaryMuscle)" +
                         (exercise.secondaryMuscles.isEmpty ? "" : " · Last: \(exercise.lastBest)"))
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 14)

                    Divider()
                    HStack {
                        Text("#").frame(width: 20)
                        Text("Weight (lb)").frame(maxWidth: .infinity)
                        Text("Reps").frame(width: 50)
                        Text("RPE").frame(width: 40)
                        Image(systemName: "checkmark").frame(width: 30)
                    }
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14)

                    ForEach(exercise.sets.indices, id: \.self) { i in
                        HStack {
                            Text("\(i + 1)").font(.caption.monospaced()).frame(width: 20).foregroundStyle(.secondary)
                            Text(exercise.sets[i].weight.isEmpty ? "— lb" : "\(exercise.sets[i].weight) lb")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(exercise.sets[i].done ? .secondary : .primary)
                                .frame(maxWidth: .infinity)
                            Text(exercise.sets[i].reps.isEmpty ? "—" : exercise.sets[i].reps)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(exercise.sets[i].done ? .secondary : .primary)
                                .frame(width: 50)
                            Text(exercise.sets[i].rpe.isEmpty ? "—" : exercise.sets[i].rpe)
                                .font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 40)
                            Image(systemName: exercise.sets[i].done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(exercise.sets[i].done ? Color.good : Color.secondary)
                                .frame(width: 30)
                        }
                        .padding(.horizontal, 14)
                        .opacity(exercise.sets[i].done ? 0.55 : 1)
                    }

                    Divider()
                    HStack(spacing: 16) {
                        Button("+ Add set") {
                            exercise.sets.append(WorkSet(weight: "", reps: "", rpe: "", done: false))
                        }
                        .font(.caption).foregroundStyle(Color.tint)
                        Button("Swap") { showingSwap = true }
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.bottom, 10)
                }
            }
        }
        .elosCard()
        .sheet(isPresented: $showingSwap) {
            ExerciseSwapSheet(exerciseName: $exercise.name)
        }
    }
}

// MARK: - Exercise Swap Sheet

// MARK: - Muscle Volume Row
private struct MuscleVolumeRow: View {
    let mv: MuscleVolume
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(mv.muscle)
                .font(.subheadline).fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.tint : Color.primary)
                .frame(width: 72, alignment: .leading)
            ProgressBar(
                value: mv.target > 0 ? Double(mv.current) / Double(mv.target) : 0,
                color: mv.onTrack ? .mGym : .warn, height: 6
            )
            Text("\(mv.current)/\(mv.target)")
                .font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary).frame(width: 42)
            Text(mv.trend)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(mv.trendUp ? Color.good : Color.bad).frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(isSelected ? Color.tintSoft : Color.clear)
    }
}
