import SwiftUI
import Combine
import SwiftData

// MARK: - User Profile Snapshot
struct UserProfileSnapshot {
    var firstName: String
    var lastName:  String
    var username:  String
    var email:     String
    var schoolName: String
    var schoolYear: String
}

@MainActor
class AppViewModel: ObservableObject {
    private let context: ModelContext

    // MARK: - Navigation / Sheet state
    @Published var selectedTab: AppTab = .today
    @Published var showingSession    = false
    @Published var showingLogSleep   = false
    @Published var showingAddHabit   = false

    /// An unfinished workout session detected on launch/foreground, awaiting a
    /// Resume/Discard choice. Non-nil drives the "Workout in progress" prompt.
    @Published var recoverableSession: WorkoutSessionRecord?

    // MARK: - Theme
    @Published var forceDark: Bool? = nil

    // MARK: - Auth deep links
    /// Set when the app is opened from a password-recovery email link.
    @Published var pendingPasswordReset = false

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

    // MARK: - Deep link / invite
    @Published var pendingFriendInviteUserId: String?
    @Published var pendingTemplateShareCode: String?

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
    @Published var canvasError: String? = nil

    // MARK: - Apple Health
    @Published var healthKitEnabled: Bool = UserDefaults.standard.bool(forKey: "healthKitEnabled") {
        didSet { UserDefaults.standard.set(healthKitEnabled, forKey: "healthKitEnabled") }
    }
    @Published var healthSnapshot: HealthSnapshot = .empty

    // MARK: - Favorites
    @Published var favoriteSplitKeys: Set<String> = []

    // MARK: - Preferences
    /// User's chosen weight unit. Mirrors `UserProfileRecord.useImperial`
    /// (the persisted/synced flag); this is the typed projection views read.
    @Published var weightUnit: WeightUnit = .localeDefault

    /// The lifter's deviations from the science-derived volume targets. Every builder passes these
    /// into `TrainingProfile`, which is what makes them reach the bands, the bars and the score —
    /// `TrainingScience` itself never reads UserDefaults, so the engine stays a pure function.
    @Published var volumeOverrides: VolumeOverrides = .none {
        didSet { persistVolumeOverrides() }
    }

    private static let volumeOverridesKey = "elos.volumeOverrides"

    private func persistVolumeOverrides() {
        guard let data = try? JSONEncoder().encode(volumeOverrides) else { return }
        UserDefaults.standard.set(data, forKey: Self.volumeOverridesKey)
    }

    /// Global on/off for the 0–100 quality score + tips layer (`TemplateQualityPanel` and everything
    /// it opens). Coverage bars stay visible either way — this only hides the *rating*, not the
    /// underlying muscle-coverage data. Defaults to `true`; `UserDefaults.bool(forKey:)` alone would
    /// default a never-set key to `false`, which is backwards from the intended default, so this
    /// reads `.object(forKey:)` first to tell "never set" apart from "explicitly turned off".
    @Published var showQualityRater: Bool = (UserDefaults.standard.object(forKey: "elos.showQualityRater") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showQualityRater, forKey: "elos.showQualityRater") }
    }

    // MARK: - Init
    init(context: ModelContext) {
        self.context = context
        let stored = UserDefaults.standard.stringArray(forKey: "elos.favoriteSplitKeys") ?? []
        favoriteSplitKeys = Set(stored)
        if let data = UserDefaults.standard.data(forKey: Self.volumeOverridesKey),
           let decoded = try? JSONDecoder().decode(VolumeOverrides.self, from: data) {
            volumeOverrides = decoded
        }
    }

    var modelContext: ModelContext { context }

    // MARK: - Computed Properties
    var doneHabits: Int { habits.filter { $0.done }.count }

    /// In-progress session volume in KILOGRAMS (matches `WorkoutSessionRecord.totalVolume`).
    /// Typed set weights are in the user's display unit, so convert to kg here.
    var sessionVolumeKg: Double {
        let doneSets = exercises.flatMap(\.sets).filter(\.done)
        return doneSets.reduce(0.0) { sum, s in
            sum + weightUnit.toKg(Double(s.weight) ?? 0) * (Double(s.reps) ?? 0)
        }
    }
    var doneSetsCount: Int  { exercises.flatMap(\.sets).filter(\.done).count }
    var totalSetsCount: Int { exercises.flatMap(\.sets).count }

    /// Volume logged **today** in kilograms: every session finished today, plus whatever is in the live
    /// draft right now.
    ///
    /// The Today tab used to show `sessionVolumeKg`, which only counts the *in-progress* draft — so the
    /// moment you finished a workout the tile dropped to "0" and its subtitle read "tap to train", on the
    /// one day it should have had something to show. A tile on a screen called Today should mean today.
    var todayVolumeKg: Double {
        guard !currentUserID.isEmpty else { return sessionVolumeKg }
        let uid = currentUserID
        let desc = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == uid && $0.finishedAt != nil }
        )
        let finishedToday = ((try? context.fetch(desc)) ?? [])
            .filter { Calendar.current.isDateInToday($0.finishedAt ?? .distantPast) }
            .reduce(0.0) { $0 + $1.totalVolume }
        return finishedToday + sessionVolumeKg
    }

    /// Short by design. "Good afternoon, Frankie." wrapped to two lines as a large title and pushed
    /// every piece of actual content a quarter of the way down the screen — a lot of real estate for
    /// a phrase that carries no information. Dropping "Good" and the full stop fits one line.
    var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let name = displayName == "there" ? "there" : displayName
        switch h {
        case 5...11:  return "Morning, \(name)"
        case 12...16: return "Afternoon, \(name)"
        default:      return "Evening, \(name)"
        }
    }

    /// Cached formatter: this is the Today header, so a computed property that built a
    /// `DateFormatter` each time it was read did so on every render.
    var todayDateString: String { Formatters.weekdayMonthDay.string(from: Date()) }

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
            weightUnit   = WeightUnit(useImperial: profile.useImperial)
            userProfile  = UserProfileSnapshot(
                firstName:  profile.firstName,
                lastName:   profile.lastName,
                username:   profile.username,
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
        // Reset any habit whose done-flag is left over from a previous day (single save).
        var didResetHabit = false
        for r in habitRecords where !Calendar.current.isDateInToday(r.lastResetDate) {
            r.isDone = false
            r.lastResetDate = today
            didResetHabit = true
        }
        if didResetHabit { try? context.save() }
        habits = habitRecords.map { r in
            Habit(id: r.id, label: r.label, category: r.category, streak: r.streak, done: r.isDone)
        }

        // Load sleep entries
        var sleepDesc = FetchDescriptor<SleepRecord>(
            predicate: #Predicate { $0.ownerID == uid }
        )
        sleepDesc.sortBy = [SortDescriptor(\.logDate, order: .reverse)]
        let sleepRecords = (try? context.fetch(sleepDesc)) ?? []
        sleepLog = sleepRecords.map { r in
            SleepEntry(date: Formatters.monthDay.string(from: r.logDate), bed: r.bedString, wake: r.wakeString, duration: r.duration, quality: r.quality, notes: r.notes)
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
            Exam(id: idx + 1, subject: r.subject, title: r.title, date: r.dateString, daysAway: Formatters.daysFromToday(toISODay: r.dateString))
        }

        loadTodayReadiness()
        loadActiveSplit()
        recoverActiveSession()
        Task { await syncCanvasIfConfigured() }
        Task { await syncSplitsFromServer() }
        Task { await syncProfileFromServer() }
        Task { await WorkoutSyncService.shared.reconcile(ownerID: uid, context: context) }
    }

    /// Change the user's weight unit. Persists to `UserProfileRecord.useImperial`
    /// (the synced flag) and pushes to the server, reusing the profile sync path.
    func setWeightUnit(_ unit: WeightUnit) {
        guard unit != weightUnit else { return }
        weightUnit = unit
        let uid = currentUserID
        guard !uid.isEmpty else { return }
        let desc = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.ownerID == uid })
        guard let profile = try? context.fetch(desc).first else { return }
        profile.useImperial = unit.useImperial
        profile.syncPending = true
        try? context.save()
        Task { await pushProfileToServer(profile) }
    }

    /// Response shape for `GET /analytics/prs` (weights in kg, computed server-side).
    /// Only the fields the Train tab renders are decoded; extra keys are ignored.
    private struct PersonalRecordsAPIResponse: Decodable {
        let prs: [Entry]
        struct Entry: Decodable {
            let exercise_name: String
            let weight_kg: Double
            let reps: Int
        }
    }

    /// Load the user's personal records from the API into `personalRecords`.
    /// This is the single place the Train tab's PR card and the XP/rank PR bonus
    /// get their data. Weight is rendered through `weightUnit` so it honors the
    /// kg/lb preference. Failures are non-blocking — the guarded card simply stays
    /// hidden until a later refresh, consistent with the app's local-first stance.
    func loadPersonalRecords() async {
        guard !currentUserID.isEmpty else { return }
        do {
            let response: PersonalRecordsAPIResponse = try await ApiClient.shared.get("/analytics/prs")
            personalRecords = response.prs.map { pr in
                PersonalRecord(
                    lift:   pr.exercise_name,
                    weight: weightUnit.formatWeight(kg: pr.weight_kg),
                    reps:   "×\(pr.reps)"
                )
            }
        } catch {
            // Local-first / non-blocking: keep any existing PRs on failure.
        }
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
        recoverableSession = nil
        // NOTE: deliberately does NOT touch SwiftData. Local records are the
        // user's only copy until sync confirms — wiping them on sign-out
        // destroyed real data. Records are keyed by ownerID, so another
        // account signing in on this device can't see them anyway.
    }

    /// Full local erase — only for account deletion, never for sign-out.
    func eraseAllLocalData() {
        clearData()
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
        // Mirror the Canvas-sync threshold (daysUntil <= 3) so a manually-added assignment due soon
        // gets the same "Due soon" treatment a synced one would — `due` is an ISO day string here
        // (or the "—" sentinel for "no date set"), never a real date, so parseability guards the flag.
        let isUrgent = Formatters.isoDay.date(from: due) != nil && Formatters.daysFromToday(toISODay: due) <= 3
        let record = AssignmentRecord(
            ownerID: currentUserID,
            name: name, subject: subject, dueString: due,
            isUrgent: isUrgent, isDone: false
        )
        context.insert(record)
        try? context.save()
        assignmentRecordIDs[newIntID] = record.id
        assignments.append(Assignment(id: newIntID, name: name, subject: subject, due: due, urgent: isUrgent, done: false))
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

    func removeHydration(oz: Int) {
        hydration = max(0, hydration - oz)
        guard !currentUserID.isEmpty else { return }
        let uid = currentUserID
        let desc = FetchDescriptor<HydrationRecord>(predicate: #Predicate { $0.ownerID == uid })
        let allRecs = (try? context.fetch(desc)) ?? []
        if let existing = allRecs.first(where: { Calendar.current.isDateInToday($0.logDate) }) {
            existing.ouncesConsumed = hydration
            try? context.save()
        }
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
            quality: entry.quality,
            notes: entry.notes
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
        let dueForPromotion = pending.filter { ($0.scheduledStartAt ?? .distantFuture) <= now }
        // If more than one is somehow simultaneously due (e.g. two "start next Monday" splits left
        // unopened for weeks), promote only the one scheduled latest — never activate two at once.
        if let toPromote = dueForPromotion.max(by: { ($0.scheduledStartAt ?? .distantPast) < ($1.scheduledStartAt ?? .distantPast) }) {
            // Deactivate whatever's currently active first — otherwise the promoted split lands
            // alongside the old one, and two records end up with isActive == true at once.
            let activeDesc = FetchDescriptor<UserSplitRecord>(
                predicate: #Predicate { $0.ownerID == uid && $0.isActive == true }
            )
            for s in (try? context.fetch(activeDesc)) ?? [] { s.isActive = false }
            let promotedStartAt = toPromote.scheduledStartAt ?? now
            toPromote.isActive    = true
            toPromote.activatedAt = Calendar.current.startOfDay(for: promotedStartAt)
            toPromote.scheduledStartAt = nil
            try? context.save()
            // Keep the server's notion of "active" in sync too — otherwise a later
            // syncSplitsFromServer() overwrites isActive from the stale pre-promotion value.
            let serverID = toPromote.serverID
            Task { await activateSplitOnServer(serverID: serverID) }
        }

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
                split.addSkip(dateString: Formatters.isoDay.string(from: Date()))
        try? context.save()
        loadActiveSplit()
    }

    func loadTodayReadiness() {
        guard !currentUserID.isEmpty else { return }
        let uid = currentUserID
                let todayStr = Formatters.isoDay.string(from: Date())
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
                let skipped = split.skippedDates
        var skipsToDate = 0
        for i in 0..<daysSince {
            if let d = cal.date(byAdding: .day, value: i, to: start) {
                if skipped.contains(Formatters.isoDay.string(from: d)) { skipsToDate += 1 }
            }
        }
        return (daysSince - skipsToDate) % activeSplitDays.count
    }

    var currentSplitDay: UserSplitDayRecord? {
        guard !activeSplitDays.isEmpty else { return nil }
        return activeSplitDays[currentSplitDayIndex]
    }

    /// Builds the next `count` days of split info for dynamic notification scheduling.
    func upcomingNotificationDays(count: Int = 60) -> [NotificationManager.DayInfo] {
        let cal      = Calendar.current
        let hasSplit = activeSplit != nil
        return (0..<count).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: Date()) else { return nil }
            let record = gymDay(for: date)
            let name: String
            if let r = record, !r.isRest {
                name = r.dayName.isEmpty ? r.dayLabel : r.dayName
            } else {
                name = ""   // rest day or off day for this split
            }
            return NotificationManager.DayInfo(date: date, dayName: name, hasSplit: hasSplit)
        }
    }

    // Loads exercises from a split day (direct exercises or template) into vm.exercises.
    // Call this before presenting the workout session.
    func prepareExercises(for day: UserSplitDayRecord) {
        guard !day.isRest else { return }

        // 1. Directly-added exercises take priority
        if let data = day.exercisesJSON.data(using: .utf8),
           let infos = try? JSONDecoder().decode([DayExercise].self, from: data),
           !infos.isEmpty {
            let catalog = exerciseCatalogForResolution()
            exercises = infos.map { info in
                // Use the lower bound of any rep range (e.g. "6–10" → "6", "8-12" → "8")
                let baseReps = info.reps
                    .components(separatedBy: CharacterSet(charactersIn: "-–"))
                    .first?
                    .trimmingCharacters(in: .whitespaces) ?? "10"
                let targets = resolveTargets(exerciseID: info.id, name: info.name,
                                             equipmentId: info.equipmentId,
                                             override: info.muscleTargets, catalog: catalog)
                return Exercise(name: info.name,
                                primaryMuscle: targets.catalogPrimary ?? "",
                                secondaryMuscles: targets.catalogSecondaries,
                                setsLabel: "\(info.sets)×\(info.reps)", lastBest: "",
                                sets: (0..<info.sets).map { _ in WorkSet(weight: "", reps: baseReps, rpe: "") },
                                equipmentId: info.equipmentId,
                                equipmentDedupeKey: info.equipmentDedupeKey,
                                equipmentBrandName: info.equipmentBrandName,
                                isGenericExercise: (info.equipmentDedupeKey ?? "").isEmpty,
                                supportsAddedWeight: ExerciseCatalog.weightableBodyweightExercises.contains(info.name),
                                muscleTargets: targets.isEmpty ? nil : targets)
            }
            return
        }

        // 2. Fall back to template if one is assigned
        guard !day.templateID.isEmpty else { return }
        let tmplExercises = fetchTemplateExercises(templateID: day.templateID)
        guard !tmplExercises.isEmpty else { return }
        exercises = self.exercises(fromTemplateExercises: tmplExercises)
    }

    func fetchTemplateExercises(templateID: String) -> [TemplateExerciseRecord] {
        var eDesc = FetchDescriptor<TemplateExerciseRecord>(
            predicate: #Predicate { $0.templateID == templateID }
        )
        eDesc.sortBy = [SortDescriptor(\.orderIndex)]
        return (try? context.fetch(eDesc)) ?? []
    }

    /// Builds live-session `Exercise`s from a template's saved exercises — the one place this mapping
    /// happens, so starting a session from a split day's assigned template and starting one directly
    /// from the Templates tab both carry equipment/rest/muscle-target data instead of one of them
    /// quietly reverting to `isGenericExercise` and a flat 90s rest.
    func exercises(fromTemplateExercises tmplExercises: [TemplateExerciseRecord]) -> [Exercise] {
        let catalog = exerciseCatalogForResolution()
        return tmplExercises.map { ex in
            let targets = resolveTargets(exerciseID: ex.exerciseID, name: ex.exerciseName,
                                         equipmentId: ex.equipmentId,
                                         override: ex.muscleTargets, catalog: catalog)
            return Exercise(name: ex.exerciseName,
                     primaryMuscle: targets.catalogPrimary ?? "",
                     secondaryMuscles: targets.catalogSecondaries,
                     setsLabel: "\(ex.targetSets)×\(ex.targetReps)", lastBest: "",
                     sets: (0..<ex.targetSets).map { _ in
                         WorkSet(weight: "", reps: ex.targetReps.components(separatedBy: "-").first ?? "10",
                                 rpe: ex.targetRPE > 0 ? String(Int(ex.targetRPE)) : "")
                     },
                     equipmentId: ex.equipmentId,
                     equipmentDedupeKey: ex.equipmentDedupeKey,
                     equipmentBrandName: ex.equipmentBrandName,
                     isGenericExercise: (ex.equipmentDedupeKey ?? "").isEmpty,
                     supportsAddedWeight: ExerciseCatalog.weightableBodyweightExercises.contains(ex.exerciseName),
                     restSeconds: ex.restSeconds > 0 ? ex.restSeconds : 90,
                     muscleTargets: targets.isEmpty ? nil : targets)
        }
    }

    /// Resolve what an exercise trains as the session is built, through the one shared precedence
    /// chain (lifter override → catalog → machine → name). Every `Exercise` in a live session used to
    /// be constructed with `primaryMuscle: ""`, which pushed the whole post-workout muscle breakdown
    /// onto a name heuristic.
    func resolveTargets(exerciseID: String?, name: String,
                        equipmentId: String?, override: MuscleTargets?,
                        catalog: [ExerciseCandidate]? = nil) -> MuscleTargets {
        let pool = catalog ?? exerciseCatalogForResolution()
        // Split days store a UUID as the exercise id when the row came from a scaffold, so match by id
        // then by name, the way `ExerciseResolver` does.
        let candidate = pool.first { !($0.id.isEmpty) && $0.id == exerciseID }
            ?? pool.first { MuscleTaxonomy.normalize($0.name) == MuscleTaxonomy.normalize(name) }
        return ResolvedExercise(
            exercise: ScoredExercise(id: exerciseID ?? "", name: name, sets: 1, repsText: "",
                                     equipmentId: equipmentId, muscleTargets: override),
            candidate: candidate
        ).targets
    }

    /// The exercise catalog as resolution candidates. Fetched once per session build — resolving each
    /// exercise against its own fetch would scan the whole catalog per row.
    func exerciseCatalogForResolution() -> [ExerciseCandidate] {
        ((try? context.fetch(FetchDescriptor<ExerciseDefinitionRecord>())) ?? [])
            .map { ExerciseCandidate(record: $0) }
    }

    func prepareExercisesForToday() {
        guard let day = currentSplitDay else { return }
        prepareExercises(for: day)
    }

    // MARK: - Active Session Recovery

    /// Sessions older than this are not offered for resume (auto-finalized if they
    /// hold logged data, otherwise discarded).
    static let resumeCutoff: TimeInterval = 12 * 60 * 60

    /// Count of logged (done) sets persisted for a session.
    func loggedSetCount(for session: WorkoutSessionRecord) -> Int {
        let sid = session.id
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.sessionID == sid && $0.isDone == true }
        )
        return (try? context.fetchCount(desc)) ?? 0
    }

    /// Detect an unfinished session on launch/foreground and decide whether to
    /// surface a Resume prompt. Reads local SwiftData only; safe to call eagerly.
    func recoverActiveSession() {
        guard !currentUserID.isEmpty else { return }
        repairImplausibleSessionDurations()
        // A session already live in the UI needs no recovery (e.g. mere suspend).
        guard !showingSession, recoverableSession == nil else { return }
        let uid = currentUserID

        var desc = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == uid && $0.finishedAt == nil }
        )
        desc.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]
        let unfinished = (try? context.fetch(desc)) ?? []
        guard let candidate = unfinished.first else { return }

        // Clean up any older duplicate unfinished sessions (shouldn't normally exist).
        for stale in unfinished.dropFirst() { finalizeOrDiscard(stale) }

        let sets = loggedSetCount(for: candidate)
        let hasDraft = !candidate.draftJSON.isEmpty

        // Empty start (no sets, no draft) → drop silently, no prompt.
        if sets == 0 && !hasDraft {
            context.delete(candidate)
            try? context.save()
            return
        }

        // Too old to reasonably resume → preserve data as a completed workout, or discard.
        if Date().timeIntervalSince(candidate.startedAt) > Self.resumeCutoff {
            finalizeOrDiscard(candidate)
            return
        }

        recoverableSession = candidate
    }

    /// Finalize a session as completed if it has logged data; otherwise delete it.
    private func finalizeOrDiscard(_ session: WorkoutSessionRecord) {
        if loggedSetCount(for: session) > 0 {
            // End it when the lifter actually stopped — the last set they logged — not "now". Stamping
            // the current time on a session abandoned days ago produced workouts of 1,422 and 9,749
            // minutes in History, and fed those durations into every average built on top of them.
            session.finishedAt = lastSetCompletedAt(for: session) ?? session.startedAt
            session.syncPending = true
            try? context.save()
            Task { await WorkoutSyncService.shared.pushFinish(session, context: context) }
        } else {
            context.delete(session)
            try? context.save()
        }
    }

    /// The longest a single session can plausibly run. Beyond this it isn't a long workout, it's a
    /// session someone walked away from that got stamped when the app next noticed.
    static let maxPlausibleSessionHours: Double = 6

    /// Repair sessions already stamped with a bogus end time by the old `finalizeOrDiscard`, which used
    /// "now" instead of the last set. Idempotent: after a repair the duration is plausible, so the
    /// session no longer matches. Without this the fix only helps future workouts and History keeps
    /// showing the 9,749-minute ones already on disk.
    func repairImplausibleSessionDurations() {
        guard !currentUserID.isEmpty else { return }
        let uid = currentUserID
        let desc = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == uid && $0.finishedAt != nil }
        )
        var repaired = 0
        for session in (try? context.fetch(desc)) ?? [] {
            guard let finished = session.finishedAt else { continue }
            let hours = finished.timeIntervalSince(session.startedAt) / 3600
            guard hours > Self.maxPlausibleSessionHours,
                  let lastSet = lastSetCompletedAt(for: session),
                  lastSet < finished
            else { continue }
            session.finishedAt = lastSet
            repaired += 1
        }
        if repaired > 0 { try? context.save() }
    }

    /// When the lifter last logged a set in this session — the honest end time for one they walked
    /// away from without finishing.
    private func lastSetCompletedAt(for session: WorkoutSessionRecord) -> Date? {
        let sid = session.id
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.sessionID == sid && $0.isDone == true }
        )
        return ((try? context.fetch(desc)) ?? []).compactMap(\.completedAt).max()
    }

    /// Resume the recovered session: re-attach it to TrainViewModel, rebuild the
    /// in-progress exercise list, and reopen the session UI.
    func resumeRecoveredSession(trainVM: TrainViewModel, context trainingContext: TrainingContext) {
        guard let session = recoverableSession else { return }
        // Re-attach BEFORE showing UI so ActiveSessionView.onAppear's startSession() no-ops.
        trainVM.adoptRecoveredSession(session)

        if let draft = decodeDraft(session.draftJSON), !draft.isEmpty {
            exercises = draft
        } else {
            exercises = rebuildExercises(from: session)
        }

        trainingContext.phase = .active
        recoverableSession = nil
        showingSession = true
    }

    /// Discard the recovered session from the prompt. Preserves logged data by
    /// finalizing it as a (short) completed workout; deletes it if empty.
    func discardRecoveredSession(trainVM: TrainViewModel) {
        guard let session = recoverableSession else { return }
        finalizeOrDiscard(session)
        trainVM.currentSession = nil
        recoverableSession = nil
    }

    /// Snapshot the in-progress draft to the session record. Called when the app
    /// backgrounds so a hard kill loses nothing (incl. typed-but-uncommitted values).
    func captureSessionDraft(trainVM: TrainViewModel) {
        guard let session = trainVM.currentSession, session.finishedAt == nil else { return }
        session.draftJSON = encodeDraft(exercises)
        try? context.save()
    }

    private func encodeDraft(_ list: [Exercise]) -> String {
        guard let data = try? JSONEncoder().encode(list),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }

    private func decodeDraft(_ json: String) -> [Exercise]? {
        guard !json.isEmpty, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([Exercise].self, from: data)
    }

    /// Fallback when no draft is present: reconstruct exercises from persisted sets
    /// so all logged work is visible and resumable.
    private func rebuildExercises(from session: WorkoutSessionRecord) -> [Exercise] {
        let sid = session.id
        var desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.sessionID == sid }
        )
        desc.sortBy = [SortDescriptor(\.setIndex)]
        let records = (try? context.fetch(desc)) ?? []
        guard !records.isEmpty else { return [] }

        // Group by exercise, preserving first-seen order.
        var order: [String] = []
        var byName: [String: [ExerciseSetRecord]] = [:]
        for r in records {
            if byName[r.exerciseName] == nil { order.append(r.exerciseName) }
            byName[r.exerciseName, default: []].append(r)
        }

        let catalog = exerciseCatalogForResolution()
        return order.map { name in
            let sets = (byName[name] ?? []).sorted { $0.setIndex < $1.setIndex }
            let workSets = sets.map { rec in
                WorkSet(
                    weight: rec.weightKg > 0 ? weightUnit.formatValue(kg: rec.weightKg) : "",
                    reps:   rec.reps > 0 ? "\(rec.reps)" : "",
                    rpe:    rec.rpe > 0 ? String(Int(rec.rpe)) : "",
                    done:   rec.isDone
                )
            }
            let first = sets.first
            // Sets record what they trained, so a resumed session keeps the lifter's own check-off
            // instead of falling back to a guess from the exercise name.
            let targets = resolveTargets(exerciseID: nil, name: name,
                                         equipmentId: first?.equipmentId,
                                         override: first?.muscleTargets, catalog: catalog)
            return Exercise(
                name: name,
                primaryMuscle: targets.catalogPrimary ?? "",
                secondaryMuscles: targets.catalogSecondaries,
                setsLabel: "\(workSets.count)×", lastBest: "",
                sets: workSets,
                equipmentId: first?.equipmentId,
                equipmentDedupeKey: first?.equipmentDedupeKey,
                equipmentBrandName: first?.equipmentBrandName,
                isGenericExercise: (first?.equipmentDedupeKey ?? "").isEmpty,
                muscleTargets: targets.isEmpty ? nil : targets
            )
        }
    }

    // Returns whether today is already marked as skipped
    var isTodaySkipped: Bool {
        guard let split = activeSplit else { return false }
                return split.skippedDates.contains(Formatters.isoDay.string(from: Date()))
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
                let dateStr = Formatters.isoDay.string(from: date)

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

    /// The split day that would land on this date if nothing were scheduled against it — no exam
    /// check applied. Only meaningful for the two weekday-fixed paths (pinned / 7-day backward-compat);
    /// the ordinal-rotation path has no independent "ignoring exam" answer, since its exam-push
    /// bookkeeping *is* what determines the mapping from date to day (a past exam shifts every date
    /// after it) — that path returns `nil` here and must be special-cased by callers that need to know
    /// "was this a gym day at all" for copy purposes (see `isOrdinalRotationSplit`).
    func scheduledGymDayIgnoringExam(for date: Date) -> UserSplitDayRecord? {
        guard let split = activeSplit, !activeSplitDays.isEmpty else { return nil }
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)

        if let pinned = split.pinnedWeekdays {
            let weekday = cal.component(.weekday, from: target)
            let nonRestDays = activeSplitDays.filter { !$0.isRest }
            guard let idx = pinned.firstIndex(of: weekday), idx < nonRestDays.count else { return nil }
            return nonRestDays[idx]
        }

        if activeSplitDays.count == 7 {
            let weekday = cal.component(.weekday, from: target)
            let indexToWeekday = [2, 3, 4, 5, 6, 7, 1]
            guard let dayIndex = indexToWeekday.firstIndex(of: weekday) else { return nil }
            let day = activeSplitDays[dayIndex]
            return day.isRest ? nil : day
        }

        return nil
    }

    /// True only for splits using the ordinal-rotation scheduling path (no fixed weekdays) — the one
    /// path where an exam genuinely pushes that day's workout to a later date rather than just
    /// clearing it, since the rotation index itself can be held back.
    var isOrdinalRotationSplit: Bool {
        guard let split = activeSplit, !activeSplitDays.isEmpty else { return false }
        return split.pinnedWeekdays == nil && activeSplitDays.count != 7
    }

    // Returns which split day (if any) falls on a given calendar date, applying skips + exam pushes
    func gymDay(for date: Date) -> UserSplitDayRecord? {
        guard let split = activeSplit, !activeSplitDays.isEmpty else { return nil }
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        let uid = currentUserID
        let examDesc = FetchDescriptor<ExamRecord>(predicate: #Predicate { $0.ownerID == uid })
        let examDateStrings: Set<String> = Set(((try? context.fetch(examDesc)) ?? []).map(\.dateString))
        let targetStr = Formatters.isoDay.string(from: target)

        // Weekday-pinned path (Split Finder splits and new CreateSplitView splits). A fixed weekday
        // has no "next available day" to push into, so an exam here clears the day rather than
        // rescheduling it — see `scheduledGymDayIgnoringExam` for the pre-exam answer.
        if let pinned = split.pinnedWeekdays {
            let weekday = cal.component(.weekday, from: target)
            let nonRestDays = activeSplitDays.filter { !$0.isRest }
            guard let idx = pinned.firstIndex(of: weekday), idx < nonRestDays.count else { return nil }
            let day = nonRestDays[idx]
            if examDateStrings.contains(targetStr) { return nil }
            return day
        }

        // Backward-compat path: 7-day CreateSplitView splits saved before pinnedWeekdays was set.
        // orderIndex 0–6 maps directly to Mon–Sun, so look up today's weekday directly.
        if activeSplitDays.count == 7 {
            let weekday = cal.component(.weekday, from: target) // 1=Sun,2=Mon,...,7=Sat
            let indexToWeekday = [2, 3, 4, 5, 6, 7, 1]         // orderIndex 0–6 → Calendar weekday
            guard let dayIndex = indexToWeekday.firstIndex(of: weekday) else { return nil }
            let day = activeSplitDays[dayIndex]                  // sorted by orderIndex
            if day.isRest { return nil }
            if examDateStrings.contains(targetStr) { return nil }
            return day
        }

        // Ordinal rotation path (existing splits)
        guard let activatedAt = split.activatedAt else { return nil }
        let start = cal.startOfDay(for: activatedAt)
        guard target >= start else { return nil }

                let skipped = split.skippedDates

        var splitIndex = 0
        var d = start
        while d < target {
            let dStr = Formatters.isoDay.string(from: d)
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
        let dStr = Formatters.isoDay.string(from: target)
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
                let uid = currentUserID
        let examDates: Set<String> = {
            let desc = FetchDescriptor<ExamRecord>(predicate: #Predicate { $0.ownerID == uid })
            return Set(((try? context.fetch(desc)) ?? []).map(\.dateString))
        }()
        let skipped = activeSplit?.skippedDates ?? []

        return (0..<daysAhead).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let dStr = Formatters.isoDay.string(from: date)
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
        let pinned_weekdays_json: String
        let days: [CreateSplitDayRequest]
    }

    private struct UpdateSplitRequest: Encodable {
        let name: String
        let pinned_weekdays_json: String
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
            pinned_weekdays_json: record.pinnedWeekdaysJSON ?? "",
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

    func updateSplitOnServer(serverID: String, record: UserSplitRecord) async {
        let splitID = record.id
        let days = (try? context.fetch(
            FetchDescriptor<UserSplitDayRecord>(
                predicate: #Predicate { $0.splitID == splitID },
                sortBy: [SortDescriptor(\.orderIndex)]
            )
        )) ?? []
        let body = UpdateSplitRequest(
            name: record.name,
            pinned_weekdays_json: record.pinnedWeekdaysJSON ?? "",
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
            let _: UserSplitResponse = try await ApiClient.shared.put("/splits/\(serverID)", body: body)
            await MainActor.run {
                record.syncPending = false
                try? context.save()
            }
        } catch {
            // Network failure — syncPending stays true for retry on next launch
        }
    }

    func syncSplitsFromServer() async {
        guard !currentUserID.isEmpty else { return }

        let uid = currentUserID
        do {
            let remoteSplits: [UserSplitResponse] = try await ApiClient.shared.get("/splits")
            // Scope to the current user — never consider another account's local rows.
            let localSplits = (try? context.fetch(
                FetchDescriptor<UserSplitRecord>(predicate: #Predicate { $0.ownerID == uid })
            )) ?? []
            let localSplitIDs = Set(localSplits.map(\.id))
            let localDays = ((try? context.fetch(FetchDescriptor<UserSplitDayRecord>())) ?? [])
                .filter { localSplitIDs.contains($0.splitID) }

            for remote in remoteSplits {
                let match = localSplits.first { $0.serverID == remote.id }
                         ?? localSplits.first { !$0.libraryKey.isEmpty && $0.libraryKey == remote.library_key }

                if let existing = match {
                    await MainActor.run {
                        existing.name = remote.name
                        existing.isActive = remote.is_active
                        existing.serverID = remote.id
                        existing.syncPending = false
                        if !remote.pinned_weekdays_json.isEmpty {
                            existing.pinnedWeekdaysJSON = remote.pinned_weekdays_json
                        }
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
                    if !remote.pinned_weekdays_json.isEmpty {
                        newSplit.pinnedWeekdaysJSON = remote.pinned_weekdays_json
                    }
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

            // Push locally-created splits (this user's) not yet on the server
            let allLocal = (try? context.fetch(
                FetchDescriptor<UserSplitRecord>(predicate: #Predicate { $0.ownerID == uid })
            )) ?? []
            for record in allLocal where record.syncPending && record.serverID.isEmpty {
                await pushSplitToServer(record)
            }

        } catch {
            // Local state remains authoritative, but tell the user their data
            // may be stale when this wasn't plain airplane-mode offline.
            reportSyncFailure(error)
        }
    }

    // MARK: - Profile Sync

    func syncProfileFromServer() async {
        guard !currentUserID.isEmpty else { return }
        let uid = currentUserID

        // Push any locally-pending profile to server first
        let allProfiles = (try? context.fetch(FetchDescriptor<UserProfileRecord>())) ?? []
        if let pending = allProfiles.first(where: { $0.ownerID == uid && $0.syncPending }) {
            await pushProfileToServer(pending)
        }

        // Fetch from server (server is source of truth on login)
        do {
            let remote: ProfileResponse = try await ApiClient.shared.get("/profile")

            await MainActor.run {
                let desc = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.ownerID == uid })
                if let existing = try? context.fetch(desc).first {
                    existing.firstName          = remote.first_name ?? existing.firstName
                    existing.lastName           = remote.last_name ?? existing.lastName
                    existing.username           = remote.username ?? existing.username
                    existing.heightCm           = remote.height_cm ?? existing.heightCm
                    existing.weightKg           = remote.weight_kg ?? existing.weightKg
                    existing.ageYears           = remote.age_years ?? existing.ageYears
                    existing.trainingExperience = remote.training_experience ?? existing.trainingExperience
                    existing.trainingGoal       = remote.training_goal ?? existing.trainingGoal
                    existing.schoolName         = remote.school_name ?? existing.schoolName
                    existing.schoolYear         = remote.school_year ?? existing.schoolYear
                    existing.calGoal            = remote.cal_goal ?? existing.calGoal
                    existing.proteinGoal        = remote.protein_goal ?? existing.proteinGoal
                    existing.carbGoal           = remote.carb_goal ?? existing.carbGoal
                    existing.fatGoal            = remote.fat_goal ?? existing.fatGoal
                    existing.useImperial        = remote.use_imperial ?? existing.useImperial
                    existing.email              = remote.email ?? existing.email
                    existing.syncPending        = false
                } else {
                    let record = UserProfileRecord(
                        id: uid, ownerID: uid, email: remote.email ?? "",
                        firstName:          remote.first_name ?? "",
                        lastName:           remote.last_name ?? "",
                        username:           remote.username ?? "",
                        heightCm:           remote.height_cm ?? 0,
                        weightKg:           remote.weight_kg ?? 0,
                        ageYears:           remote.age_years ?? 0,
                        trainingExperience: remote.training_experience ?? "beginner",
                        trainingGoal:       remote.training_goal ?? "hypertrophy",
                        schoolName:         remote.school_name ?? "",
                        schoolYear:         remote.school_year ?? "sophomore",
                        calGoal:            remote.cal_goal ?? 2500,
                        proteinGoal:        remote.protein_goal ?? 180,
                        carbGoal:           remote.carb_goal ?? 300,
                        fatGoal:            remote.fat_goal ?? 80,
                        onboardingComplete: remote.onboarding_complete ?? false,
                        syncPending:        false,
                        useImperial:        remote.use_imperial ?? true
                    )
                    context.insert(record)
                }
                try? context.save()

                // Refresh published UI state
                let fetchDesc = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.ownerID == uid })
                if let profile = try? context.fetch(fetchDesc).first {
                    displayName = profile.firstName.isEmpty ? "there" : profile.firstName
                    weightUnit  = WeightUnit(useImperial: profile.useImperial)
                    userProfile = UserProfileSnapshot(
                        firstName:  profile.firstName,
                        lastName:   profile.lastName,
                        username:   profile.username,
                        email:      profile.email,
                        schoolName: profile.schoolName,
                        schoolYear: profile.schoolYear
                    )
                }
            }
        } catch {
            // Local state stands; surface the failure unless we're plainly offline.
            reportSyncFailure(error)
        }
    }

    /// One banner per launch when server sync fails for a reason other than
    /// being offline (offline is a supported mode, not an error). Without this,
    /// auth/server failures render as silently empty screens.
    private var reportedSyncFailure = false
    private func reportSyncFailure(_ error: Error) {
        if case ApiError.networkError(let underlying) = error,
           (underlying as? URLError)?.code == .notConnectedToInternet {
            return
        }
        guard !reportedSyncFailure else { return }
        reportedSyncFailure = true
        showError("Couldn't load your latest data. Pull to refresh to try again.", autoHideAfter: 6)
    }

    private func pushProfileToServer(_ record: UserProfileRecord) async {
        let body = ProfileUpdateBody(
            first_name:          record.firstName.isEmpty ? nil : record.firstName,
            last_name:           record.lastName.isEmpty ? nil : record.lastName,
            username:            record.username.isEmpty ? nil : record.username,
            height_cm:           record.heightCm > 0 ? record.heightCm : nil,
            weight_kg:           record.weightKg > 0 ? record.weightKg : nil,
            age_years:           record.ageYears > 0 ? record.ageYears : nil,
            training_experience: record.trainingExperience.isEmpty ? nil : record.trainingExperience,
            training_goal:       record.trainingGoal.isEmpty ? nil : record.trainingGoal,
            school_name:         record.schoolName.isEmpty ? nil : record.schoolName,
            school_year:         record.schoolYear.isEmpty ? nil : record.schoolYear,
            cal_goal:            record.calGoal > 0 ? record.calGoal : nil,
            protein_goal:        record.proteinGoal,
            carb_goal:           record.carbGoal,
            fat_goal:            record.fatGoal,
            onboarding_complete: record.onboardingComplete ? true : nil,
            use_imperial:        record.useImperial
        )
        do {
            let _: ProfileResponse = try await ApiClient.shared.patch("/profile", body: body)
            await MainActor.run {
                record.syncPending = false
                try? context.save()
            }
        } catch {
            // Network failure — syncPending stays true for retry on next launch
        }
    }

    // MARK: - Canvas Sync

    func syncCanvasIfConfigured() async {
        let url = UserDefaults.standard.string(forKey: "canvasBaseURL") ?? ""
        let token = KeychainHelper.load(forKey: "canvasToken") ?? ""
        guard !url.isEmpty, !token.isEmpty, !currentUserID.isEmpty else { return }
        await syncCanvas(baseURL: url, token: token)
        // This runs in the background at launch; surface a failure once so it isn't invisible
        // (the Settings screen only shows canvasError if the user happens to open it).
        if let err = canvasError { showError(err) }
    }

    func syncCanvas(baseURL: String, token: String) async {
        let uid = currentUserID
        guard !uid.isEmpty else { return }
        await MainActor.run { canvasSyncing = true; canvasError = nil }
        do {
            try await CanvasService.shared.sync(baseURL: baseURL, token: token, ownerID: uid, context: context)
            await MainActor.run {
                canvasLastSynced = Date()
                canvasSyncing    = false
                canvasError      = nil
                // Reload exams + assignments after sync
                let examDesc = FetchDescriptor<ExamRecord>(predicate: #Predicate { $0.ownerID == uid })
                let examRecords = (try? context.fetch(examDesc)) ?? []
                exams = examRecords.enumerated().map { idx, r in
                    Exam(id: idx + 1, subject: r.subject, title: r.title, date: r.dateString, daysAway: Formatters.daysFromToday(toISODay: r.dateString))
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
            await MainActor.run {
                canvasSyncing = false
                canvasError = "Sync failed. Check your Canvas URL and access token, then try again."
            }
        }
    }

    // MARK: - Apple Health

    /// Connect (Settings toggle): request authorization, then persist the toggle and do an initial
    /// backfill + metric refresh. On failure, leave it off and surface why.
    func connectHealth() async {
        guard HealthKitService.shared.isAvailable else {
            showError("Apple Health isn't available on this device.")
            return
        }
        let granted = await HealthKitService.shared.requestAuthorization()
        guard granted else {
            healthKitEnabled = false
            showError("Couldn't connect to Apple Health. You can enable access in Settings → Privacy → Health.")
            return
        }
        healthKitEnabled = true
        await backfillHealth()
        await refreshHealthMetrics()
    }

    func disconnectHealth() {
        healthKitEnabled = false
        healthSnapshot = .empty
    }

    /// Read body weight / resting HR / steps; update the profile weight and the snapshot.
    func refreshHealthMetrics() async {
        guard healthKitEnabled, HealthKitService.shared.isAvailable else { return }
        let weight   = await HealthKitService.shared.latestBodyWeightKg()
        let rhr      = await HealthKitService.shared.restingHeartRate()
        let baseline = await HealthKitService.shared.restingHRBaseline()
        let steps    = await HealthKitService.shared.todaySteps()

        healthSnapshot = HealthSnapshot(bodyWeightKg: weight, restingHeartRate: rhr,
                                        restingHRBaseline: baseline, steps: steps)

        if let weight, weight > 0 { applyBodyWeightFromHealth(weight) }
    }

    private func applyBodyWeightFromHealth(_ kg: Double) {
        let uid = currentUserID
        guard !uid.isEmpty else { return }
        let desc = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.ownerID == uid })
        guard let profile = try? context.fetch(desc).first else { return }
        if abs(profile.weightKg - kg) > 0.05 {   // only write when meaningfully different
            profile.weightKg = kg
            try? context.save()
        }
    }

    /// Export finished sessions from the last 90 days that haven't been written to Health yet.
    func backfillHealth() async {
        guard healthKitEnabled, HealthKitService.shared.isAvailable, !currentUserID.isEmpty else { return }
        let uid = currentUserID
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        let desc = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == uid && $0.finishedAt != nil && $0.exportedToHealth == false }
        )
        let sessions = ((try? context.fetch(desc)) ?? []).filter { ($0.finishedAt ?? .distantPast) >= cutoff }
        for session in sessions { await exportSessionToHealth(session) }
    }

    /// Write one finished session to Health (once), marking it so it isn't duplicated.
    func exportSessionToHealth(_ session: WorkoutSessionRecord) async {
        guard healthKitEnabled, HealthKitService.shared.isAvailable,
              session.finishedAt != nil, !session.exportedToHealth else { return }
        if await HealthKitService.shared.export(session: session, bodyWeightKg: currentBodyWeightKg()) {
            session.exportedToHealth = true
            try? context.save()
        }
    }

    private func currentBodyWeightKg() -> Double {
        let uid = currentUserID
        let desc = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.ownerID == uid })
        return (try? context.fetch(desc).first)?.weightKg ?? 0
    }
}
