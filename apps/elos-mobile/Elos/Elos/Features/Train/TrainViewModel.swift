import SwiftUI
import SwiftData
import Combine

@MainActor
class TrainViewModel: ObservableObject {
    private let context: ModelContext

    @Published var currentSession: WorkoutSessionRecord?
    @Published var sessionSets: [ExerciseSetRecord] = []
    @Published var newPRExerciseName: String?
    @Published var prsHitThisSession: [String] = []
    @Published var showSessionRPEPrompt = false
    @Published var showDeloadSuggestion = false
    @Published var deloadMessage = "Recent sessions have been very hard. Consider reducing volume this week to recover."
    @Published var recentExercises: [ExercisePickerViewModel.ExerciseResponse] = []

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Recent exercises

    func loadRecentExercises() async {
        struct ListResponse: Decodable { let exercises: [ExercisePickerViewModel.ExerciseResponse] }
        do {
            let r: ListResponse = try await ApiClient.shared.get("/exercises/recent?limit=8")
            recentExercises = r.exercises
        } catch {
            // Offline-first: recent-exercise hints are a non-fatal enrichment.
        }
    }

    // MARK: - Session lifecycle

    func startSession(ownerID: String) {
        guard currentSession == nil else { return }
        let session = WorkoutSessionRecord(ownerID: ownerID, startedAt: Date(), syncPending: true)
        context.insert(session)
        try? context.save()
        currentSession = session
        sessionSets = []
        prsHitThisSession = []

        Task { await WorkoutSyncService.shared.pushSessionCreate(session, context: context) }
    }

    /// Re-attach an unfinished session recovered after relaunch — WITHOUT creating
    /// a new one. Loads its persisted sets so volume/PR logic continues correctly.
    /// Setting `currentSession` here makes `startSession`'s guard a no-op when
    /// `ActiveSessionView.onAppear` fires.
    func adoptRecoveredSession(_ session: WorkoutSessionRecord) {
        currentSession = session
        let sid = session.id
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.sessionID == sid }
        )
        sessionSets = (try? context.fetch(desc)) ?? []
        prsHitThisSession = []
        newPRExerciseName = nil
    }

    func logCompletedSet(
        exerciseName: String,
        setIndex: Int,
        weightKg: Double,
        reps: Int,
        rpe: Double,
        ownerID: String,
        equipmentId: String? = nil,
        equipmentDedupeKey: String? = nil,
        equipmentBrandName: String? = nil
    ) {
        guard let session = currentSession else { return }
        let now = Date()

        let record = ExerciseSetRecord(
            ownerID: ownerID,
            sessionID: session.id,
            exerciseName: exerciseName,
            setIndex: setIndex,
            weightKg: weightKg,
            reps: reps,
            rpe: rpe,
            isDone: true,
            completedAt: now,
            equipmentId: equipmentId,
            equipmentDedupeKey: equipmentDedupeKey,
            equipmentBrandName: equipmentBrandName,
            syncPending: true
        )
        context.insert(record)
        sessionSets.append(record)
        session.totalVolume += weightKg * Double(max(reps, 0))
        try? context.save()

        checkAndUpdatePR(exerciseName: exerciseName, weightKg: weightKg, reps: reps,
                         sessionID: session.id, ownerID: ownerID,
                         equipmentDedupeKey: equipmentDedupeKey,
                         equipmentBrandName: equipmentBrandName)

        Task { await WorkoutSyncService.shared.pushSet(record, session: session, context: context) }
    }

    func unlogCompletedSet(
        exerciseName: String,
        setIndex: Int,
        ownerID: String
    ) {
        guard let session = currentSession else { return }
        let sid = session.id
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate {
                $0.ownerID == ownerID
                && $0.sessionID == sid
                && $0.exerciseName == exerciseName
                && $0.setIndex == setIndex
            }
        )
        guard let records = try? context.fetch(desc), !records.isEmpty else { return }
        let serverSessionID = session.serverID
        let deletedServerIDs = records.map(\.serverID).filter { !$0.isEmpty }
        for record in records {
            session.totalVolume -= record.weightKg * Double(max(record.reps, 0))
            context.delete(record)
        }
        sessionSets.removeAll { $0.exerciseName == exerciseName && $0.setIndex == setIndex && $0.sessionID == sid }
        try? context.save()

        // Propagate the deletion to the server so it doesn't resurrect on re-sync.
        if !serverSessionID.isEmpty {
            for setServerID in deletedServerIDs {
                Task { await WorkoutSyncService.shared.deleteSet(serverSessionID: serverSessionID, setServerID: setServerID) }
            }
        }
    }

    func finishSession(sessionRPE: Int, ownerID: String) {
        guard let session = currentSession else { return }
        let now = Date()
        session.finishedAt = now
        session.sessionRPE = sessionRPE
        session.syncPending = true
        try? context.save()

        checkDeloadNeeded(ownerID: ownerID)

        Task { await WorkoutSyncService.shared.pushFinish(session, context: context) }

        currentSession = nil
    }

    /// Pure function — call BEFORE finishSession() since currentSession is nil after.
    func buildSessionSummary(
        splitDayTemplateID: String = "",
        splitDayName: String = "",
        nextWorkoutDay: UserSplitDayRecord? = nil,
        nextWorkoutDate: Date? = nil
    ) -> SessionSummary {
        let session = currentSession
        let totalVol = session?.totalVolume ?? 0
        let startedAt = session?.startedAt ?? Date()

        let doneSets = sessionSets.filter(\.isDone)
        var setsByMuscle: [String: Int] = [:]
        for set in doneSets {
            let group = muscleGroup(for: set.exerciseName)
            setsByMuscle[group, default: 0] += 1
        }

        var comparisonPercent: Double? = nil
        var comparisonLabel: String? = nil
        let matchKey = splitDayTemplateID.isEmpty ? splitDayName : splitDayTemplateID
        if !matchKey.isEmpty, let curSession = session {
            let uid = curSession.ownerID
            var desc = FetchDescriptor<WorkoutSessionRecord>(
                predicate: #Predicate { $0.ownerID == uid && $0.finishedAt != nil }
            )
            desc.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]
            let allSessions = (try? context.fetch(desc)) ?? []
            let matching: WorkoutSessionRecord?
            if splitDayTemplateID.isEmpty {
                matching = allSessions.first { $0.id != curSession.id && $0.templateID.isEmpty }
            } else {
                matching = allSessions.first { $0.id != curSession.id && $0.templateID == splitDayTemplateID }
            }
            if let prior = matching, prior.totalVolume > 0 {
                let pct = (totalVol - prior.totalVolume) / prior.totalVolume
                comparisonPercent = pct
                let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
                let dayLabel = splitDayName.isEmpty ? "last session" : splitDayName
                comparisonLabel = "vs last \(dayLabel) (\(fmt.string(from: prior.startedAt)))"
            }
        }

        return SessionSummary(
            startedAt: startedAt,
            totalVolumeKg: totalVol,
            setsByMuscle: setsByMuscle,
            prsHit: prsHitThisSession,
            comparisonPercent: comparisonPercent,
            comparisonLabel: comparisonLabel,
            nextWorkoutDay: nextWorkoutDay,
            nextWorkoutDate: nextWorkoutDate
        )
    }

    // MARK: - Lift identity (per-machine progressive overload)

    /// Treat nil / empty dedupe keys as "generic".
    private func normalizedKey(_ key: String?) -> String? {
        guard let k = key, !k.isEmpty else { return nil }
        return k
    }

    /// Two sets are the "same lift" iff both have equal non-empty dedupe keys
    /// (machine-specific), or both are generic and the names match. This is what
    /// keeps progressive overload / PRs scoped to a specific machine.
    private func sameLift(_ record: ExerciseSetRecord, exerciseName: String, dedupeKey: String?) -> Bool {
        let target = normalizedKey(dedupeKey)
        let recordKey = normalizedKey(record.equipmentDedupeKey)
        if let target, let recordKey { return target == recordKey }
        if target == nil && recordKey == nil {
            return record.exerciseName.caseInsensitiveCompare(exerciseName) == .orderedSame
        }
        return false
    }

    // MARK: - Previous set lookup for pre-filling

    func previousSets(for exerciseName: String, ownerID: String, equipmentDedupeKey: String? = nil) -> [ExerciseSetRecord] {
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.exerciseName == exerciseName && $0.isDone == true }
        )
        let all = ((try? context.fetch(desc)) ?? [])
            .filter { sameLift($0, exerciseName: exerciseName, dedupeKey: equipmentDedupeKey) }
        guard !all.isEmpty else { return [] }

        let currentID = currentSession?.id ?? ""
        let prior = all.filter { $0.sessionID != currentID }
        guard let latestID = prior
            .max(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) })?
            .sessionID
        else { return [] }

        return prior.filter { $0.sessionID == latestID }.sorted { $0.setIndex < $1.setIndex }
    }

    /// Per-session average RPE (nil if none logged) + top weight, most-recent first.
    private func recentSessionStats(for exerciseName: String, ownerID: String, equipmentDedupeKey: String?)
        -> [(avgRPE: Double?, topWeightKg: Double, lastCompleted: Date)] {
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.exerciseName == exerciseName && $0.isDone == true }
        )
        let all = ((try? context.fetch(desc)) ?? [])
            .filter { sameLift($0, exerciseName: exerciseName, dedupeKey: equipmentDedupeKey) }
        let bySession = Dictionary(grouping: all, by: { $0.sessionID })
        return bySession.values.map { sets -> (Double?, Double, Date) in
            let rpes = sets.map(\.rpe).filter { $0 > 0 }
            let avg = rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count)
            let top = sets.map(\.weightKg).max() ?? 0
            let when = sets.compactMap(\.completedAt).max() ?? .distantPast
            return (avg, top, when)
        }
        .sorted { $0.2 > $1.2 }
    }

    // Returns a human-readable suggestion string (in the user's unit), or nil if no suggestion.
    // Fatigue-aware: weighs the RPE trend across recent sessions, not just the last one,
    // and avoids recommending progression when there's no RPE data to justify it.
    func overloadSuggestion(for exerciseName: String, ownerID: String, unit: WeightUnit, equipmentDedupeKey: String? = nil) -> String? {
        let sessions = recentSessionStats(for: exerciseName, ownerID: ownerID, equipmentDedupeKey: equipmentDedupeKey)
        guard let last = sessions.first else { return nil }

        let lastDisplay = unit.fromKg(last.topWeightKg)
        let inc = unit.increment
        let incStr = unit == .kg ? String(format: "%.1f", inc) : String(format: "%.0f", inc)
        func up() -> String { "Try +\(incStr) \(unit.label) → \(unit.formatWeight(kg: unit.toKg(unit.round(lastDisplay + inc))))" }
        func down() -> String { "Ease off to \(unit.formatWeight(kg: unit.toKg(max(0, unit.round(lastDisplay - inc))))) — RPE was high" }

        guard let lastRPE = last.avgRPE else {
            // No RPE logged — can't gauge effort; nudge toward a small progression via reps.
            return "Log RPE to tune suggestions — or add a rep this session"
        }

        // Fatigue check: RPE climbing across the last 2–3 sessions.
        let priorRPEs = sessions.dropFirst().prefix(2).compactMap(\.avgRPE)
        if let prevAvg = priorRPEs.first, lastRPE - prevAvg >= 1.5, lastRPE >= 8.5 {
            return "RPE climbing (\(String(format: "%.1f", prevAvg))→\(String(format: "%.1f", lastRPE))) — hold weight, watch fatigue"
        }

        if lastRPE >= 9.5 { return down() }
        if lastRPE <= 8.0 { return up() }
        return "Solid effort — add a rep before adding load"
    }

    // MARK: - Weekly volume (computed locally from SwiftData)

    func weeklyVolume(ownerID: String) -> [MuscleVolume] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.isDone == true }
        )
        let all = (try? context.fetch(desc)) ?? []
        let recent = all.filter { ($0.completedAt ?? .distantPast) >= weekAgo }

        var setCounts: [String: Int] = [:]
        for s in recent {
            let muscle = muscleGroup(for: s.exerciseName)
            setCounts[muscle, default: 0] += 1
        }

        let targets: [String: Int] = [
            "chest": 12, "lats": 14, "quads": 14, "hamstrings": 10,
            "glutes": 12, "front_delts": 10, "side_delts": 10,
            "rear_delts": 10, "biceps": 10, "triceps": 10, "core": 8,
        ]

        return setCounts.sorted { $0.key < $1.key }.map { muscle, count in
            let target = targets[muscle] ?? 10
            return MuscleVolume(
                muscle: muscle, current: count, target: target,
                trend: "+\(count)", trendUp: true, onTrack: count >= target
            )
        }
    }

    // MARK: - PR detection

    private func checkAndUpdatePR(
        exerciseName: String, weightKg: Double, reps: Int,
        sessionID: String, ownerID: String,
        equipmentDedupeKey: String? = nil,
        equipmentBrandName: String? = nil
    ) {
        guard reps > 0, reps <= 30, weightKg > 0 else { return }
        let newE1RM = weightKg * (1.0 + Double(reps) / 30.0)

        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.exerciseName == exerciseName && $0.isDone == true }
        )
        let all = (try? context.fetch(desc)) ?? []
        // Only compare against history for the SAME machine (or generic) — per-machine PRs.
        let historical = all.filter {
            $0.sessionID != sessionID && $0.reps > 0 && $0.reps <= 30 && $0.weightKg > 0
            && sameLift($0, exerciseName: exerciseName, dedupeKey: equipmentDedupeKey)
        }
        let maxPrior = historical.map { $0.weightKg * (1.0 + Double($0.reps) / 30.0) }.max() ?? 0

        guard newE1RM > maxPrior else { return }

        // Label the PR with the brand for machine-specific lifts so two machines
        // surface as distinct PRs.
        let prLabel: String
        if let brand = equipmentBrandName, !brand.isEmpty {
            prLabel = "\(brand) \(exerciseName)"
        } else {
            prLabel = exerciseName
        }

        withAnimation(.spring(duration: 0.3)) {
            newPRExerciseName = prLabel
        }
        if !prsHitThisSession.contains(prLabel) {
            prsHitThisSession.append(prLabel)
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            withAnimation {
                if self.newPRExerciseName == prLabel {
                    self.newPRExerciseName = nil
                }
            }
        }
    }

    // MARK: - Deload detection

    private func checkDeloadNeeded(ownerID: String) {
        var desc = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        desc.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]
        desc.fetchLimit = 4
        let recent = (try? context.fetch(desc)) ?? []
        let finished = recent.filter { $0.finishedAt != nil }
        guard finished.count >= 3 else { return }
        let lastThree = Array(finished.prefix(3))
        if lastThree.filter({ $0.sessionRPE >= 9 }).count >= 3 {
            let avg = lastThree.map { Double($0.sessionRPE) }.reduce(0, +) / Double(lastThree.count)
            deloadMessage = "Last 3 sessions averaged RPE \(String(format: "%.1f", avg)). Consider reducing volume ~40% this week to recover."
            showDeloadSuggestion = true
        }
    }

    // MARK: - Muscle group mapping

    /// Lazy name → primary-muscle map from the synced exercise catalog.
    private var dbMuscleByName: [String: String]?

    private func dbPrimaryMuscle(for exerciseName: String) -> String? {
        if dbMuscleByName == nil {
            let defs = (try? context.fetch(FetchDescriptor<ExerciseDefinitionRecord>())) ?? []
            var map: [String: String] = [:]
            for d in defs where !d.primaryMuscle.isEmpty {
                map[d.name.lowercased()] = d.primaryMuscle.lowercased()
            }
            dbMuscleByName = map
        }
        guard let m = dbMuscleByName?[exerciseName.lowercased()], !m.isEmpty else { return nil }
        return m
    }

    /// Resolve the trained muscle for an exercise. Prefer the canonical
    /// `ExerciseDefinitionRecord.primary_muscle` from the synced catalog; fall
    /// back to a name heuristic for custom/unmatched exercises.
    func muscleGroup(for exerciseName: String) -> String {
        if let dbMuscle = dbPrimaryMuscle(for: exerciseName) { return dbMuscle }
        let n = exerciseName.lowercased()
        if n.contains("bench") || n.contains("fly") || (n.contains("push") && !n.contains("pushdown")) { return "chest" }
        if n.contains("squat") || n.contains("leg press") || n.contains("lunge") || n.contains("extension") { return "quads" }
        if n.contains("deadlift") || n.contains("rdl") || (n.contains("curl") && n.contains("leg")) { return "hamstrings" }
        if n.contains("hip thrust") || n.contains("glute") { return "glutes" }
        if n.contains("pull") || n.contains("row") || n.contains("lat") { return "lats" }
        if n.contains("curl") && !n.contains("leg") { return "biceps" }
        if n.contains("tricep") || n.contains("pushdown") || n.contains("skull") { return "triceps" }
        if n.contains("overhead") || (n.contains("press") && n.contains("shoulder")) { return "front_delts" }
        if n.contains("lateral") || n.contains("side delt") { return "side_delts" }
        if n.contains("face pull") || n.contains("rear delt") { return "rear_delts" }
        if n.contains("calf") { return "calves" }
        if n.contains("plank") || n.contains("core") || n.contains("ab") { return "core" }
        return "other"
    }
}
