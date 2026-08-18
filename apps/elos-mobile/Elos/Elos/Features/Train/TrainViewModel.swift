import SwiftUI
import SwiftData
import Combine

@MainActor
class TrainViewModel: ObservableObject {
    private let context: ModelContext
    /// Per-record sync coalescing: `inFlight` holds records whose push is running; an edit that
    /// arrives mid-push marks the record `dirty` so the in-flight task re-pushes the latest state
    /// (instead of dropping it or double-posting).
    private var setSyncInFlight: Set<String> = []
    private var setSyncDirty: Set<String> = []

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

    func startSession(ownerID: String, gymID: String = "") {
        guard currentSession == nil else { return }
        let session = WorkoutSessionRecord(ownerID: ownerID, startedAt: Date(), syncPending: true, gymID: gymID)
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
        equipmentBrandName: String? = nil,
        muscleTargets: MuscleTargets? = nil
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
            syncPending: true,
            muscleTargetsJSON: muscleTargets?.jsonString ?? ""
        )
        context.insert(record)
        sessionSets.append(record)
        session.totalVolume += weightKg * Double(max(reps, 0))
        try? context.save()

        checkAndUpdatePR(exerciseName: exerciseName, weightKg: weightKg, reps: reps,
                         sessionID: session.id, ownerID: ownerID,
                         equipmentDedupeKey: equipmentDedupeKey,
                         equipmentBrandName: equipmentBrandName)

        syncSet(record, session: session, ownerID: ownerID)
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

        // Record each deletion durably, then drain it — a fire-and-forget DELETE is lost on
        // failure/offline, which would let the set resurrect on the next down-sync.
        if !serverSessionID.isEmpty, !deletedServerIDs.isEmpty {
            for setServerID in deletedServerIDs {
                context.insert(PendingSetDeletion(ownerID: ownerID, serverSessionID: serverSessionID, setServerID: setServerID))
            }
            try? context.save()
            Task { await WorkoutSyncService.shared.drainDeletions(ownerID: ownerID, context: context) }
        }
    }

    /// Coalesced, per-record set sync. Runs one push at a time per record; if another edit lands
    /// while a push is in flight, the in-flight task re-pushes the latest state. After a successful
    /// post, a pending newer edit tombstones the just-created (now-stale) row and re-posts, so the
    /// set converges to a single server row carrying the latest values. Used by both logging and
    /// editing so a log-then-edit (or rapid re-edit) can't double-post or drop the newest values.
    private func syncSet(_ record: ExerciseSetRecord, session: WorkoutSessionRecord, ownerID: String) {
        let rid = record.id
        if setSyncInFlight.contains(rid) { setSyncDirty.insert(rid); return }
        setSyncInFlight.insert(rid)
        Task { @MainActor in
            while true {
                setSyncDirty.remove(rid)
                await WorkoutSyncService.shared.pushSet(record, session: session, context: context)
                await WorkoutSyncService.shared.drainDeletions(ownerID: ownerID, context: context)
                if !setSyncDirty.contains(rid) { break }
                // A newer edit arrived during the push — the row we just created is stale, so
                // tombstone it and loop to repost the latest values.
                if !record.serverID.isEmpty && !session.serverID.isEmpty {
                    context.insert(PendingSetDeletion(ownerID: ownerID, serverSessionID: session.serverID, setServerID: record.serverID))
                    record.serverID = ""
                    record.syncPending = true
                    try? context.save()
                }
            }
            setSyncInFlight.remove(rid)
        }
    }

    /// Non-destructive edit of an already-logged set: mutate the record in place and adjust
    /// session volume by the delta. There's no set-PATCH endpoint, so if the record was already
    /// synced we tombstone the stale server copy and repost it as new — the lifter never re-types.
    func updateLoggedSet(
        exerciseName: String,
        setIndex: Int,
        newWeightKg: Double,
        newReps: Int,
        newRPE: Double,
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
                && $0.isDone == true
            }
        )
        guard let record = (try? context.fetch(desc))?.first else { return }

        let oldContribution = record.weightKg * Double(max(record.reps, 0))
        let newContribution = newWeightKg * Double(max(newReps, 0))
        session.totalVolume += (newContribution - oldContribution)

        let oldServerID = record.serverID
        record.weightKg = newWeightKg
        record.reps = newReps
        record.rpe = newRPE

        let serverSessionID = session.serverID
        // No single-set PATCH endpoint: if the set was already synced, durably tombstone the stale
        // server row (so the delete survives failure/offline) and repost the edit as a new row.
        if !oldServerID.isEmpty && !serverSessionID.isEmpty {
            context.insert(PendingSetDeletion(ownerID: ownerID, serverSessionID: serverSessionID, setServerID: oldServerID))
            record.serverID = ""
        }
        record.syncPending = true
        // Mark the session pending too so reconcile retries this repost if it can't complete now.
        session.syncPending = true
        try? context.save()

        // An edit can turn a conservative set into a PR — re-evaluate (history excludes this session).
        checkAndUpdatePR(exerciseName: exerciseName, weightKg: newWeightKg, reps: newReps,
                         sessionID: sid, ownerID: ownerID,
                         equipmentDedupeKey: record.equipmentDedupeKey,
                         equipmentBrandName: record.equipmentBrandName)

        // Repost via the coalesced per-record path; the durable tombstone retires the stale row.
        syncSet(record, session: session, ownerID: ownerID)
    }

    func finishSession(sessionRPE: Int, ownerID: String) {
        guard let session = currentSession else { return }
        let now = Date()
        session.finishedAt = now
        session.sessionRPE = sessionRPE

        // Recompute the total from the actual logged sets so a dropped set-sync (or an edit that
        // raced) can't ship a wrong volume — the incremental running total is for live display only.
        let sid = session.id
        let doneSets = (try? context.fetch(FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.sessionID == sid && $0.isDone == true }
        ))) ?? []
        session.totalVolume = SyncMath.totalVolume(doneSets.map { ($0.weightKg, $0.reps) })

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
            setsByMuscle[muscleGroup(for: set), default: 0] += 1
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
        StrengthMath.isSameLift(nameA: record.exerciseName, dedupeKeyA: record.equipmentDedupeKey,
                                nameB: exerciseName, dedupeKeyB: dedupeKey)
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

    /// Structured form of `overloadSuggestion` for tap-to-fill: the load (kg) and reps to put in
    /// the active set. Progresses the load only when the last session's effort justifies it
    /// (RPE ≤ 8 and logged); otherwise holds. Returns nil when there's no history.
    func overloadTarget(for exerciseName: String, ownerID: String, unit: WeightUnit, equipmentDedupeKey: String? = nil) -> (weightKg: Double, reps: Int)? {
        let sessions = recentSessionStats(for: exerciseName, ownerID: ownerID, equipmentDedupeKey: equipmentDedupeKey)
        guard let last = sessions.first, last.topWeightKg > 0 else { return nil }

        let lastDisplay = unit.fromKg(last.topWeightKg)
        let shouldProgress: Bool = {
            guard let rpe = last.avgRPE else { return false }   // no RPE → don't auto-bump load
            return rpe <= 8.0
        }()
        let targetDisplay = unit.round(shouldProgress ? lastDisplay + unit.increment : lastDisplay)

        let prev = previousSets(for: exerciseName, ownerID: ownerID, equipmentDedupeKey: equipmentDedupeKey)
        let topReps = prev.max(by: { $0.weightKg < $1.weightKg })?.reps ?? 8
        return (unit.toKg(targetDisplay), max(1, topReps))
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
            setCounts[muscleGroup(for: s), default: 0] += 1
        }

        return setCounts.sorted { $0.key < $1.key }.map { muscle, count in
            // Target comes from `TrainingScience`, the same volume landmarks the coverage bars and the
            // quality score use, instead of a second hand-maintained table that disagreed with them
            // and had no entry for half the vocabulary (lower back, traps, calves, forearms).
            let target = MuscleTaxonomy.fine(forMuscle: muscle).map {
                Int(TrainingScience.weeklyBand(for: $0, experience: .intermediate).targetLow)
            } ?? 10
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
        guard let newE1RM = StrengthMath.e1rm(weightKg: weightKg, reps: reps) else { return }

        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.exerciseName == exerciseName && $0.isDone == true }
        )
        let all = (try? context.fetch(desc)) ?? []
        // Only compare against history for the SAME machine (or generic) — per-machine PRs.
        let historical = all.filter {
            $0.sessionID != sessionID && $0.reps > 0 && $0.reps <= 30 && $0.weightKg > 0
            && sameLift($0, exerciseName: exerciseName, dedupeKey: equipmentDedupeKey)
        }
        let maxPrior = historical.compactMap { StrengthMath.e1rm(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0

        guard newE1RM > maxPrior else { return }

        // Label the PR with the brand for machine-specific lifts so two machines surface as distinct
        // PRs — but only when the name doesn't already carry it. Picking a machine straight from the
        // picker names the exercise "\(brandName) \(machineName)", so prepending unconditionally
        // produced "Atlantis Strength Atlantis Strength Pec / Rear Delt Fly Combo".
        let prLabel: String
        if let brand = equipmentBrandName, !brand.isEmpty,
           !exerciseName.localizedCaseInsensitiveContains(brand) {
            prLabel = "\(brand) \(exerciseName)"
        } else {
            prLabel = exerciseName
        }

        withAnimation(.elosEmphasis) {
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

    /// Resolve the trained muscle for a logged set.
    ///
    /// Prefers what the set itself recorded at log time — that's the only way to honour the lifter's
    /// own muscle check-off, and the only way a machine-backed set is attributed at all. Falls back to
    /// the synced catalog by name, then to the machine, then to the movement lexicon.
    func muscleGroup(for set: ExerciseSetRecord) -> String {
        if let recorded = set.muscleTargets?.catalogPrimary { return recorded }
        if let dbMuscle = dbPrimaryMuscle(for: set.exerciseName) { return dbMuscle }
        if let equipmentId = set.equipmentId,
           let record = EquipmentDatabase.find(equipmentId: equipmentId),
           let fromEquipment = EquipmentMuscleMap.targets(for: record)?.catalogPrimary {
            return fromEquipment
        }
        return MovementLexicon.targets(forExerciseName: set.exerciseName)?.catalogPrimary ?? "other"
    }

    /// Name-only resolution, for callers with no set record to hand (e.g. historical charts built from
    /// exercise names). Routed through the shared `MovementLexicon` rather than a private heuristic —
    /// the old copy read "Low Back Extension" as **quads**, because it tested `contains("extension")`.
    func muscleGroup(for exerciseName: String) -> String {
        if let dbMuscle = dbPrimaryMuscle(for: exerciseName) { return dbMuscle }
        return MovementLexicon.targets(forExerciseName: exerciseName)?.catalogPrimary ?? "other"
    }
}
