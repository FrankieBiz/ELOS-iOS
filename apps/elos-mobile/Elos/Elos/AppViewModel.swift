import SwiftUI
import Combine
import SwiftData

// MARK: - User Profile Snapshot
struct UserProfileSnapshot {
    var firstName: String
    var lastName:  String
    var email:     String
    var schoolName: String
    var schoolYear: String
}

class AppViewModel: ObservableObject {
    private let context: ModelContext

    // MARK: - Navigation / Sheet state
    @Published var selectedTab: AppTab = .today
    @Published var showingSession    = false
    @Published var showingLogSleep   = false
    @Published var showingAddHabit   = false

    // MARK: - Theme
    @Published var forceDark: Bool? = nil

    // MARK: - Global error banner
    @Published var errorBanner: String?
    private var errorBannerTask: Task<Void, Never>?

    func showError(_ message: String, autoHideAfter seconds: TimeInterval = 4) {
        errorBanner = message
        errorBannerTask?.cancel()
        errorBannerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.errorBanner = nil
        }
    }

    func dismissError() {
        errorBannerTask?.cancel()
        errorBanner = nil
    }

    // MARK: - User
    @Published var displayName: String = "there"
    @Published var currentUserID: String = ""
    @Published var userProfile: UserProfileSnapshot?

    // MARK: - Habits
    @Published var habits: [Habit] = []

    // MARK: - Assignments
    @Published var assignments: [Assignment] = []
    private var assignmentRecordIDs: [Int: String] = [:]

    // MARK: - Exams
    @Published var exams: [Exam] = []

    // MARK: - Sleep
    @Published var sleepLog: [SleepEntry] = []

    // MARK: - Hydration
    @Published var hydration: Int = 0
    let hydGoal = 128

    // MARK: - Training
    @Published var exercises: [Exercise] = []
    @Published var muscleVolume: [MuscleVolume] = []
    @Published var personalRecords: [PersonalRecord] = []
    @Published var todayReadiness: ReadinessCheckInRecord? = nil

    // MARK: - Active Split
    @Published var activeSplit: UserSplitRecord?
    @Published var activeSplitDays: [UserSplitDayRecord] = []

    // MARK: - Canvas sync state
    @Published var canvasSyncing = false
    @Published var canvasLastSynced: Date? = nil

    // MARK: - Favorites
    @Published var favoriteSplitKeys: Set<String> = []

    // MARK: - Init
    init(context: ModelContext) {
        self.context = context
        let stored = UserDefaults.standard.stringArray(forKey: "elos.favoriteSplitKeys") ?? []
        favoriteSplitKeys = Set(stored)
    }

    var modelContext: ModelContext { context }

    // MARK: - Computed Properties
    var doneHabits: Int { habits.filter { $0.done }.count }

    var sessionVolume: Double {
        let doneSets = exercises.flatMap(\.sets).filter(\.done)
        return doneSets.reduce(0.0) { sum, s in
            (Double(s.weight) ?? 0) * (Double(s.reps) ?? 0) + sum
        }
    }
    var doneSetsCount: Int  { exercises.flatMap(\.sets).filter(\.done).count }
    var totalSetsCount: Int { exercises.flatMap(\.sets).count }

    var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let name = displayName == "there" ? "there" : displayName
        switch h {
        case 0...4:   return "Good evening, \(name)."
        case 5...11:  return "Good morning, \(name)."
        case 12...16: return "Good afternoon, \(name)."
        default:      return "Good evening, \(name)."
        }
    }

    var todayDateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: Date())
    }

    // MARK: - Load / Clear
    func loadForUser(id: String) {
        currentUserID = id
        let uid = id
        let today = Calendar.current.startOfDay(for: Date())

        // Load profile
        let profileDesc = FetchDescriptor<UserProfileRecord>(
            predicate: #Predicate { $0.ownerID == uid }
        )
        if let profile = try? context.fetch(profileDesc).first {
            displayName  = profile.firstName.isEmpty ? "there" : profile.firstName
            userProfile  = UserProfileSnapshot(
                firstName:  profile.firstName,
                lastName:   profile.lastName,
                email:      profile.email,
                schoolName: profile.schoolName,
                schoolYear: profile.schoolYear
            )
        }

        // Load hydration (today)
        let hydDesc = FetchDescriptor<HydrationRecord>(
            predicate: #Predicate { $0.ownerID == uid }
        )
        let allHyd = (try? context.fetch(hydDesc)) ?? []
        let todayHyd = allHyd.filter { Calendar.current.isDateInToday($0.logDate) }
        hydration = todayHyd.first?.ouncesConsumed ?? 0

        // Load habits
        let habitDesc = FetchDescriptor<HabitRecord>(
            predicate: #Predicate { $0.ownerID == uid }
        )
        let habitRecords = (try? context.fetch(habitDesc)) ?? []
        habits = habitRecords.map { r in
            // Reset isDone if it was set on a previous day
            if !Calendar.current.isDateInToday(r.lastResetDate) {
                r.isDone = false
                r.lastResetDate = today
                try? context.save()
            }
            return Habit(id: r.id, label: r.label, category: r.category, streak: r.streak, done: r.isDone)
        }

        // Load sleep entries
        var sleepDesc = FetchDescriptor<SleepRecord>(
            predicate: #Predicate { $0.ownerID == uid }
        )
        sleepDesc.sortBy = [SortDescriptor(\.logDate, order: .reverse)]
        let sleepRecords = (try? context.fetch(sleepDesc)) ?? []
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "MMM d"
        sleepLog = sleepRecords.map { r in
            SleepEntry(date: dateFmt.string(from: r.logDate), bed: r.bedString, wake: r.wakeString, duration: r.duration, quality: r.quality)
        }

        // Load assignments
        let assignDesc = FetchDescriptor<AssignmentRecord>(
            predicate: #Predicate { $0.ownerID == uid }
        )
        let assignRecords = (try? context.fetch(assignDesc)) ?? []
        assignmentRecordIDs = [:]
        assignments = assignRecords.enumerated().map { idx, r in
            let intID = idx + 1
            assignmentRecordIDs[intID] = r.id
            return Assignment(id: intID, name: r.name, subject: r.subject, due: r.dueString, urgent: r.isUrgent, done: r.isDone)
        }

        // Load exams
        let examDesc = FetchDescriptor<ExamRecord>(
            predicate: #Predicate { $0.ownerID == uid }
        )
        let examRecords = (try? context.fetch(examDesc)) ?? []
        exams = examRecords.enumerated().map { idx, r in
            Exam(id: idx + 1, subject: r.subject, title: r.title, date: r.dateString, daysAway: r.daysAway)
        }

        loadTodayReadiness()
        loadActiveSplit()
        Task { await syncCanvasIfConfigured() }
        Task { await syncSplitsFromServer() }
    }

    func clearData() {
        habits           = []
        assignments      = []
        exams            = []
        sleepLog         = []
        hydration        = 0
        exercises        = []
        muscleVolume     = []
        personalRecords  = []
        userProfile      = nil
        displayName      = "there"
        currentUserID    = ""
        assignmentRecordIDs = [:]
        activeSplit      = nil
        activeSplitDays  = []
        wipeSwiftData()
    }

    func toggleFavorite(_ id: String) {
        if favoriteSplitKeys.contains(id) {
            favoriteSplitKeys.remove(id)
        } else {
            favoriteSplitKeys.insert(id)
        }
        UserDefaults.standard.set(Array(favoriteSplitKeys), forKey: "elos.favoriteSplitKeys")
    }

    private func wipeSwiftData() {
        try? context.delete(model: HabitRecord.self)
        try? context.delete(model: MealEntryRecord.self)
        try? context.delete(model: SleepRecord.self)
        try? context.delete(model: HydrationRecord.self)
        try? context.delete(model: AssignmentRecord.self)
        try? context.delete(model: ExamRecord.self)
        try? context.delete(model: UserProfileRecord.self)
        try? context.delete(model: WorkoutSessionRecord.self)
        try? context.delete(model: ExerciseSetRecord.self)
        try? context.delete(model: ExerciseDefinitionRecord.self)
        try? context.delete(model: WorkoutTemplateRecord.self)
        try? context.delete(model: TemplateExerciseRecord.self)
        try? context.delete(model: ReadinessCheckInRecord.self)
        try? context.delete(model: SavedLibraryWorkoutRecord.self)
        try? context.delete(model: FriendRecord.self)
        try? context.delete(model: LeaderboardEntryRecord.self)
        try? context.delete(model: UserSplitRecord.self)
        try? context.delete(model: UserSplitDayRecord.self)
        try? context.delete(model: ScheduleEventRecord.self)
        try? context.delete(model: CourseRecord.self)
        try? context.save()
    }

    func signOut(authStore: AuthStore) {
        clearData()
        Task { await authStore.logout() }
    }

    // MARK: - Mutations
    func toggleHabit(id: String) {
        guard let i = habits.firstIndex(where: { $0.id == id }) else { return }
        let wasDone = habits[i].done
        habits[i].done.toggle()
        habits[i].streak = wasDone ? max(0, habits[i].streak - 1) : habits[i].streak + 1
        // Write-through
        let uid = currentUserID
        let desc = FetchDescriptor<HabitRecord>(predicate: #Predicate { $0.id == id && $0.ownerID == uid })
        if let record = try? context.fetch(desc).first {
            record.isDone        = habits[i].done
            record.streak        = habits[i].streak
            record.lastResetDate = Calendar.current.startOfDay(for: Date())
            try? context.save()
        }
    }

    func addHabit(_ habit: Habit) {
        habits.append(habit)
        guard !currentUserID.isEmpty else { return }
        let record = HabitRecord(
            id: habit.id, ownerID: currentUserID,
            label: habit.label, category: habit.category,
            streak: habit.streak, isDone: habit.done
        )
        context.insert(record)
        try? context.save()
    }

    func toggleAssignment(id: Int) {
        guard let i = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[i].done.toggle()
        guard let recordID = assignmentRecordIDs[id] else { return }
        let uid = currentUserID
        let desc = FetchDescriptor<AssignmentRecord>(predicate: #Predicate { $0.id == recordID && $0.ownerID == uid })
        if let record = try? context.fetch(desc).first {
            record.isDone = assignments[i].done
            try? context.save()
        }
    }

    func addAssignment(name: String, subject: String, due: String) {
        guard !currentUserID.isEmpty else { return }
        let newIntID = (assignments.map(\.id).max() ?? 0) + 1
        let record = AssignmentRecord(
            ownerID: currentUserID,
            name: name, subject: subject, dueString: due,
            isUrgent: false, isDone: false
        )
        context.insert(record)
        try? context.save()
        assignmentRecordIDs[newIntID] = record.id
        assignments.append(Assignment(id: newIntID, name: name, subject: subject, due: due, urgent: false, done: false))
    }

    func addHydration(oz: Int) {
        hydration = min(hydGoal, hydration + oz)
        guard !currentUserID.isEmpty else { return }
        let uid = currentUserID
        let desc = FetchDescriptor<HydrationRecord>(predicate: #Predicate { $0.ownerID == uid })
        let allRecs = (try? context.fetch(desc)) ?? []
        if let existing = allRecs.first(where: { Calendar.current.isDateInToday($0.logDate) }) {
            existing.ouncesConsumed = hydration
        } else {
            context.insert(HydrationRecord(ownerID: uid, logDate: Date(), ouncesConsumed: hydration))
        }
        try? context.save()
    }

    func logSleep(_ entry: SleepEntry) {
        sleepLog.insert(entry, at: 0)
        guard !currentUserID.isEmpty else { return }
        let record = SleepRecord(
            id: entry.id.uuidString,
            ownerID: currentUserID,
            logDate: Date(),
            bedString: entry.bed,
            wakeString: entry.wake,
            duration: entry.duration,
            quality: entry.quality
        )
        context.insert(record)
        try? context.save()
    }

    func toggleSet(exerciseIndex eIdx: Int, setIndex sIdx: Int) {
        guard eIdx < exercises.count, sIdx < exercises[eIdx].sets.count else { return }
        exercises[eIdx].sets[sIdx].done.toggle()
    }

    // MARK: - Active Split

    func loadActiveSplit() {
        guard !currentUserID.isEmpty else { return }
        let uid = currentUserID

        // 1. Promote any pending splits whose scheduled start has arrived
        let pendingDesc = FetchDescriptor<UserSplitRecord>(
            predicate: #Predicate { $0.ownerID == uid && $0.isActive == false && $0.scheduledStartAt != nil }
        )
        let pending = (try? context.fetch(pendingDesc)) ?? []
        let now = Date()
        for record in pending {
            if let startAt = record.scheduledStartAt, startAt <= now {
                record.isActive    = true
                record.activatedAt = Calendar.current.startOfDay(for: startAt)
                record.scheduledStartAt = nil
            }
        }
        if !pending.isEmpty { try? context.save() }

        // 2. Fetch active split
        let splitDesc = FetchDescriptor<UserSplitRecord>(
            predicate: #Predicate { $0.ownerID == uid && $0.isActive == true }
        )
        guard let split = try? context.fetch(splitDesc).first else {
            activeSplit = nil
            activeSplitDays = []
            return
        }
        activeSplit = split
        let splitID = split.id
        let daysDesc = FetchDescriptor<UserSplitDayRecord>(
            predicate: #Predicate { $0.splitID == splitID }
        )
        activeSplitDays = ((try? context.fetch(daysDesc)) ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    func setActiveSplit(_ split: UserSplitRecord) {
        // Deactivate any existing active split
        let uid = currentUserID
        let allDesc = FetchDescriptor<UserSplitRecord>(
            predicate: #Predicate { $0.ownerID == uid && $0.isActive == true }
        )
        let existing = (try? context.fetch(allDesc)) ?? []
        for s in existing { s.isActive = false }
        // Activate the new split
        split.isActive    = true
        split.activatedAt = Calendar.current.startOfDay(for: Date())
        split.skippedDatesJSON = "[]"
        try? context.save()
        loadActiveSplit()
    }

    func skipToday() {
        guard let split = activeSplit else { return }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        split.addSkip(dateString: fmt.string(from: Date()))
        try? context.save()
        loadActiveSplit()
    }

    func loadTodayReadiness() {
        guard !currentUserID.isEmpty else { return }
        let uid = currentUserID
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let todayStr = fmt.string(from: Date())
        let desc = FetchDescriptor<ReadinessCheckInRecord>(
            predicate: #Predicate { $0.ownerID == uid }
        )
        let all = (try? context.fetch(desc)) ?? []
        todayReadiness = all.first { $0.logDate == todayStr }
    }

    struct DailyBriefResult {
        let text: String
        let mood: String  // "positive" | "cautious" | "alert"
    }

    var dailyBrief: DailyBriefResult {
        let score = todayReadiness.map { Double($0.overallScore) } ?? 0
        let hasExamToday  = exams.contains { $0.daysAway == 0 }
        let hasUrgent     = assignments.contains { $0.urgent }
        let hasExamSoon   = exams.contains { $0.daysAway <= 1 }
        let splitDayName  = activeSplitDays.indices.contains(currentSplitDayIndex)
            ? activeSplitDays[currentSplitDayIndex].dayName : nil

        // Mood
        let mood: String
        if todayReadiness != nil && score <= 1 || hasExamToday {
            mood = "alert"
        } else if todayReadiness != nil && score >= 4 && !hasUrgent && !hasExamSoon {
            mood = "positive"
        } else {
            mood = "cautious"
        }

        // Sentence 1: physical readiness + training
        let trainingLabel = splitDayName.map { "\($0) session" } ?? "today's session"
        let s1: String
        if todayReadiness == nil {
            s1 = "Log your check-in to get a personalised read on \(trainingLabel)."
        } else if score >= 4 {
            s1 = "You're well-rested — solid day to push your \(trainingLabel)."
        } else if score >= 2 {
            s1 = "Moderate energy today — keep \(trainingLabel) manageable and watch your volume."
        } else {
            s1 = "Recovery takes priority — scale back \(trainingLabel) if fatigue builds."
        }

        // Sentence 2: academic pressure
        let s2: String
        if hasExamToday {
            let sub = exams.first(where: { $0.daysAway == 0 })?.subject ?? "your exam"
            s2 = "You have a \(sub) exam today — save mental energy and keep training brief."
        } else if hasExamSoon {
            let sub = exams.first(where: { $0.daysAway <= 1 })?.subject ?? "an exam"
            s2 = "\(sub.capitalized) exam tomorrow — protect review time tonight."
        } else if hasUrgent {
            s2 = "Urgent deadline(s) ahead — carve out focus blocks between sessions."
        } else {
            s2 = "No pressing deadlines — good day to give training your full attention."
        }

        return DailyBriefResult(text: "\(s1) \(s2)", mood: mood)
    }

    var currentSplitDayIndex: Int {
        guard let split = activeSplit, let activatedAt = split.activatedAt,
              !activeSplitDays.isEmpty else { return 0 }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.startOfDay(for: activatedAt)
        let daysSince = cal.dateComponents([.day], from: start, to: today).day ?? 0
        guard daysSince > 0 else { return 0 }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let skipped = split.skippedDates
        var skipsToDate = 0
        for i in 0..<daysSince {
            if let d = cal.date(byAdding: .day, value: i, to: start) {
                if skipped.contains(fmt.string(from: d)) { skipsToDate += 1 }
            }
        }
        return (daysSince - skipsToDate) % activeSplitDays.count
    }

    var currentSplitDay: UserSplitDayRecord? {
        guard !activeSplitDays.isEmpty else { return nil }
        return activeSplitDays[currentSplitDayIndex]
    }

    // Loads exercises from a split day (direct exercises or template) into vm.exercises.
    // Call this before presenting the workout session.
    func prepareExercises(for day: UserSplitDayRecord) {
        guard !day.isRest else { return }

        // 1. Directly-added exercises take priority
        if let data = day.exercisesJSON.data(using: .utf8),
           let infos = try? JSONDecoder().decode([DayExercise].self, from: data),
           !infos.isEmpty {
            exercises = infos.map { info in
                Exercise(name: info.name, primaryMuscle: "", secondaryMuscles: [],
                         setsLabel: "3×10", lastBest: "",
                         sets: (0..<3).map { _ in WorkSet(weight: "", reps: "10", rpe: "") })
            }
            return
        }

        // 2. Fall back to template if one is assigned
        guard !day.templateID.isEmpty else { return }
        let tmplID = day.templateID
        var eDesc = FetchDescriptor<TemplateExerciseRecord>(
            predicate: #Predicate { $0.templateID == tmplID }
        )
        eDesc.sortBy = [SortDescriptor(\.orderIndex)]
        let tmplExercises = (try? context.fetch(eDesc)) ?? []
        guard !tmplExercises.isEmpty else { return }
        exercises = tmplExercises.map { ex in
            Exercise(name: ex.exerciseName, primaryMuscle: "", secondaryMuscles: [],
                     setsLabel: "\(ex.targetSets)×\(ex.targetReps)", lastBest: "",
                     sets: (0..<ex.targetSets).map { _ in
                         WorkSet(weight: "", reps: ex.targetReps.components(separatedBy: "-").first ?? "10",
                                 rpe: ex.targetRPE > 0 ? String(Int(ex.targetRPE)) : "")
                     })
        }
    }

    func prepareExercisesForToday() {
        guard let day = currentSplitDay else { return }
        prepareExercises(for: day)
    }

    // Returns whether today is already marked as skipped
    var isTodaySkipped: Bool {
        guard let split = activeSplit else { return false }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return split.skippedDates.contains(fmt.string(from: Date()))
    }

    // MARK: - Schedule Builder

    struct ScheduleRow: Identifiable {
        let id = UUID()
        let time: String
        let title: String
        let moduleType: String
        let durationMinutes: Int
        var isDone: Bool
    }

    func buildScheduleRows(for date: Date) -> [ScheduleRow] {
        guard !currentUserID.isEmpty else { return [] }
        let uid = currentUserID
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let dateStr = fmt.string(from: date)

        // 1. Canvas class/event rows for this date
        let evDesc = FetchDescriptor<ScheduleEventRecord>(
            predicate: #Predicate { $0.ownerID == uid && $0.date == dateStr }
        )
        let events = (try? context.fetch(evDesc)) ?? []
        var rows = events.map { ev in
            ScheduleRow(time: ev.startTime, title: ev.title, moduleType: ev.moduleType,
                        durationMinutes: ev.durationMinutes, isDone: ev.isDone)
        }

        // 2. Exams on this date
        let examFmt = DateFormatter(); examFmt.dateFormat = "yyyy-MM-dd"
        let examDesc = FetchDescriptor<ExamRecord>(predicate: #Predicate { $0.ownerID == uid })
        let allExams = (try? context.fetch(examDesc)) ?? []
        for exam in allExams where exam.dateString == dateStr {
            rows.append(ScheduleRow(time: "—", title: "\(exam.title) (Exam)",
                                    moduleType: "exam", durationMinutes: 0, isDone: false))
        }

        // 3. Assignments due on this date
        let assignDesc = FetchDescriptor<AssignmentRecord>(predicate: #Predicate { $0.ownerID == uid })
        let allAssigns = (try? context.fetch(assignDesc)) ?? []
        for a in allAssigns where a.dueString == dateStr && !a.isDone {
            rows.append(ScheduleRow(time: "—", title: "\(a.name) due",
                                    moduleType: "assignment", durationMinutes: 0, isDone: a.isDone))
        }

        // 4. Gym day: determine if this calendar date has a gym day (accounting for skips + exam pushes)
        if let gymDay = gymDay(for: date), !gymDay.isRest {
            let gymTitle = gymDay.dayName.isEmpty ? "Workout" : gymDay.dayName
            rows.append(ScheduleRow(time: "15:30", title: gymTitle,
                                    moduleType: "gym", durationMinutes: 60, isDone: false))
        }

        return rows.sorted {
            let t0 = $0.time == "—" ? "99:99" : $0.time
            let t1 = $1.time == "—" ? "99:99" : $1.time
            return t0 < t1
        }
    }

    // Returns which split day (if any) falls on a given calendar date, applying skips + exam pushes
    func gymDay(for date: Date) -> UserSplitDayRecord? {
        guard let split = activeSplit, !activeSplitDays.isEmpty else { return nil }
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)

        // Weekday-pinned path (Split Finder splits)
        if let pinned = split.pinnedWeekdays {
            let weekday = cal.component(.weekday, from: target)
            let nonRestDays = activeSplitDays.filter { !$0.isRest }
            guard let idx = pinned.firstIndex(of: weekday), idx < nonRestDays.count else { return nil }
            return nonRestDays[idx]
        }

        // Ordinal rotation path (existing splits)
        guard let activatedAt = split.activatedAt else { return nil }
        let start = cal.startOfDay(for: activatedAt)
        guard target >= start else { return nil }

        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let skipped = split.skippedDates
        let uid = currentUserID
        let examDesc = FetchDescriptor<ExamRecord>(predicate: #Predicate { $0.ownerID == uid })
        let examDateStrings: Set<String> = Set(((try? context.fetch(examDesc)) ?? []).map(\.dateString))

        var splitIndex = 0
        var d = start
        while d < target {
            let dStr = fmt.string(from: d)
            if !skipped.contains(dStr) {
                let dayRecord = activeSplitDays[splitIndex % activeSplitDays.count]
                // Exam push: if this is a gym day and there's an exam on this date, don't advance split
                if !dayRecord.isRest && examDateStrings.contains(dStr) {
                    // push forward — don't consume split slot
                } else {
                    splitIndex += 1
                }
            }
            d = cal.date(byAdding: .day, value: 1, to: d) ?? target
        }

        // Determine what falls on the target date
        let dStr = fmt.string(from: target)
        if skipped.contains(dStr) { return nil }
        let dayRecord = activeSplitDays[splitIndex % activeSplitDays.count]
        // If exam on this gym day → pushed (return nil)
        if !dayRecord.isRest && examDateStrings.contains(dStr) { return nil }
        return dayRecord
    }

    // Maps upcoming calendar dates to their load type: "gym", "rest", "exam", "skip"
    func weekLoadMap(daysAhead: Int = 7) -> [(date: Date, loadType: String)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let uid = currentUserID
        let examDates: Set<String> = {
            let desc = FetchDescriptor<ExamRecord>(predicate: #Predicate { $0.ownerID == uid })
            return Set(((try? context.fetch(desc)) ?? []).map(\.dateString))
        }()
        let skipped = activeSplit?.skippedDates ?? []

        return (0..<daysAhead).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let dStr = fmt.string(from: date)
            if skipped.contains(dStr) { return (date, "skip") }
            if let day = gymDay(for: date) {
                return (date, day.isRest ? "rest" : "gym")
            }
            if examDates.contains(dStr) { return (date, "exam") }
            return (date, "rest")
        }
    }

    // MARK: - Splits Sync

    private struct CreateSplitDayRequest: Encodable {
        let order_index: Int
        let day_label: String
        let day_name: String
        let template_id: String
        let is_rest: Bool
        let exercises_json: String
    }

    private struct CreateSplitRequest: Encodable {
        let name: String
        let library_key: String
        let days: [CreateSplitDayRequest]
    }

    private struct ActivateSplitRequest: Encodable {}

    func pushSplitToServer(_ record: UserSplitRecord) async {
        let splitID = record.id   // extract before #Predicate capture
        let days = (try? context.fetch(
            FetchDescriptor<UserSplitDayRecord>(
                predicate: #Predicate { $0.splitID == splitID },
                sortBy: [SortDescriptor(\.orderIndex)]
            )
        )) ?? []

        let body = CreateSplitRequest(
            name: record.name,
            library_key: record.libraryKey,
            days: days.map {
                CreateSplitDayRequest(
                    order_index: $0.orderIndex,
                    day_label: $0.dayLabel,
                    day_name: $0.dayName,
                    template_id: $0.templateID,
                    is_rest: $0.isRest,
                    exercises_json: $0.exercisesJSON
                )
            }
        )

        do {
            let response: UserSplitResponse = try await ApiClient.shared.post("/splits", body: body)
            await MainActor.run {
                record.serverID = response.id
                record.syncPending = false
                try? context.save()
            }
        } catch ApiError.httpError(409, _) {
            // Duplicate library split — fetch existing ID from server and reconcile
            if let existing: [UserSplitResponse] = try? await ApiClient.shared.get("/splits"),
               let match = existing.first(where: { $0.library_key == record.libraryKey }) {
                await MainActor.run {
                    record.serverID = match.id
                    record.syncPending = false
                    try? context.save()
                }
            }
        } catch {
            // Network failure — leave syncPending = true for retry on next launch
        }
    }

    func deleteSplitOnServer(serverID: String) async {
        guard !serverID.isEmpty else { return }
        try? await ApiClient.shared.deleteNoContent("/splits/\(serverID)")
    }

    func activateSplitOnServer(serverID: String) async {
        guard !serverID.isEmpty else { return }
        let _: UserSplitResponse? = try? await ApiClient.shared.patch("/splits/\(serverID)/activate", body: ActivateSplitRequest())
    }

    func syncSplitsFromServer() async {
        guard !currentUserID.isEmpty else { return }

        do {
            let remoteSplits: [UserSplitResponse] = try await ApiClient.shared.get("/splits")
            let localSplits = (try? context.fetch(FetchDescriptor<UserSplitRecord>())) ?? []
            let localDays = (try? context.fetch(FetchDescriptor<UserSplitDayRecord>())) ?? []

            for remote in remoteSplits {
                let match = localSplits.first { $0.serverID == remote.id }
                         ?? localSplits.first { !$0.libraryKey.isEmpty && $0.libraryKey == remote.library_key }

                if let existing = match {
                    await MainActor.run {
                        existing.name = remote.name
                        existing.isActive = remote.is_active
                        existing.serverID = remote.id
                        existing.syncPending = false
                    }
                    let existingDays = localDays.filter { $0.splitID == existing.id }
                    for remoteDay in remote.days {
                        if let localDay = existingDays.first(where: { $0.orderIndex == remoteDay.order_index }) {
                            if localDay.exercisesJSON != remoteDay.exercises_json {
                                await MainActor.run {
                                    localDay.dayName = remoteDay.day_name
                                    localDay.dayLabel = remoteDay.day_label
                                    localDay.isRest = remoteDay.is_rest
                                    localDay.templateID = remoteDay.template_id
                                    localDay.exercisesJSON = remoteDay.exercises_json
                                }
                            }
                        } else {
                            let newDay = UserSplitDayRecord(
                                splitID: existing.id,
                                orderIndex: remoteDay.order_index,
                                dayLabel: remoteDay.day_label,
                                dayName: remoteDay.day_name,
                                templateID: remoteDay.template_id,
                                isRest: remoteDay.is_rest,
                                exercisesJSON: remoteDay.exercises_json
                            )
                            await MainActor.run { context.insert(newDay) }
                        }
                    }
                } else {
                    let newSplit = UserSplitRecord(
                        ownerID: currentUserID,
                        name: remote.name,
                        isActive: remote.is_active,
                        libraryKey: remote.library_key,
                        serverID: remote.id,
                        syncPending: false
                    )
                    await MainActor.run { context.insert(newSplit) }
                    for remoteDay in remote.days {
                        let newDay = UserSplitDayRecord(
                            splitID: newSplit.id,
                            orderIndex: remoteDay.order_index,
                            dayLabel: remoteDay.day_label,
                            dayName: remoteDay.day_name,
                            templateID: remoteDay.template_id,
                            isRest: remoteDay.is_rest,
                            exercisesJSON: remoteDay.exercises_json
                        )
                        await MainActor.run { context.insert(newDay) }
                    }
                }
            }

            await MainActor.run {
                try? context.save()
                loadActiveSplit()
            }

            // Push locally-created splits not yet on the server
            let allLocal = (try? context.fetch(FetchDescriptor<UserSplitRecord>())) ?? []
            for record in allLocal where record.syncPending && record.serverID.isEmpty {
                await pushSplitToServer(record)
            }

        } catch {
            // Offline — local state is authoritative
        }
    }

    // MARK: - Canvas Sync

    func syncCanvasIfConfigured() async {
        let url = UserDefaults.standard.string(forKey: "canvasBaseURL") ?? ""
        let token = UserDefaults.standard.string(forKey: "canvasToken") ?? ""
        guard !url.isEmpty, !token.isEmpty, !currentUserID.isEmpty else { return }
        await syncCanvas(baseURL: url, token: token)
    }

    func syncCanvas(baseURL: String, token: String) async {
        let uid = currentUserID
        guard !uid.isEmpty else { return }
        await MainActor.run { canvasSyncing = true }
        do {
            try await CanvasService.shared.sync(baseURL: baseURL, token: token, ownerID: uid, context: context)
            await MainActor.run {
                canvasLastSynced = Date()
                canvasSyncing    = false
                // Reload exams + assignments after sync
                let examDesc = FetchDescriptor<ExamRecord>(predicate: #Predicate { $0.ownerID == uid })
                let examRecords = (try? context.fetch(examDesc)) ?? []
                exams = examRecords.enumerated().map { idx, r in
                    Exam(id: idx + 1, subject: r.subject, title: r.title, date: r.dateString, daysAway: r.daysAway)
                }
                let assignDesc = FetchDescriptor<AssignmentRecord>(predicate: #Predicate { $0.ownerID == uid })
                let assignRecords = (try? context.fetch(assignDesc)) ?? []
                assignmentRecordIDs = [:]
                assignments = assignRecords.enumerated().map { idx, r in
                    let intID = idx + 1
                    assignmentRecordIDs[intID] = r.id
                    return Assignment(id: intID, name: r.name, subject: r.subject,
                                      due: r.dueString, urgent: r.isUrgent, done: r.isDone)
                }
            }
        } catch {
            await MainActor.run { canvasSyncing = false }
        }
    }
}
