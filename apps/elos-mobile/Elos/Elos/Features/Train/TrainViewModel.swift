import SwiftUI
import SwiftData
import Combine

// MARK: - API request/response types
private struct CreateSessionRequest: Encodable {
    let started_at: String
}

private struct UpdateSessionRequest: Encodable {
    let finished_at: String
    let session_rpe: Int
    let total_volume: Double
}

private struct CreateSetRequest: Encodable {
    let exercise_name: String
    let set_index: Int
    let weight_kg: Double
    let reps: Int
    let rpe: Double?
    let completed_at: String
}

private struct SessionResponse: Decodable { let id: String }
private struct SetResponse: Decodable { let id: String }

@MainActor
class TrainViewModel: ObservableObject {
    private let context: ModelContext
    private let iso = ISO8601DateFormatter()

    @Published var currentSession: WorkoutSessionRecord?
    @Published var sessionSets: [ExerciseSetRecord] = []
    @Published var newPRExerciseName: String?
    @Published var prsHitThisSession: [String] = []
    @Published var showSessionRPEPrompt = false
    @Published var showDeloadSuggestion = false

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Session lifecycle

    func startSession(ownerID: String) {
        guard currentSession == nil else { return }
        let session = WorkoutSessionRecord(ownerID: ownerID, startedAt: Date())
        context.insert(session)
        try? context.save()
        currentSession = session
        sessionSets = []
        prsHitThisSession = []

        Task {
            let body = CreateSessionRequest(started_at: iso.string(from: session.startedAt))
            _ = try? await ApiClient.shared.post("/sessions", body: body) as SessionResponse
        }
    }

    func logCompletedSet(
        exerciseName: String,
        setIndex: Int,
        weightKg: Double,
        reps: Int,
        rpe: Double,
        ownerID: String
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
            completedAt: now
        )
        context.insert(record)
        sessionSets.append(record)
        session.totalVolume += weightKg * Double(max(reps, 0))
        try? context.save()

        checkAndUpdatePR(exerciseName: exerciseName, weightKg: weightKg, reps: reps,
                         sessionID: session.id, ownerID: ownerID)

        let sessionID = session.id
        Task {
            let body = CreateSetRequest(
                exercise_name: exerciseName,
                set_index: setIndex,
                weight_kg: weightKg,
                reps: reps,
                rpe: rpe > 0 ? rpe : nil,
                completed_at: iso.string(from: now)
            )
            _ = try? await ApiClient.shared.post("/sessions/\(sessionID)/sets", body: body) as SetResponse
        }
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
        for record in records {
            session.totalVolume -= record.weightKg * Double(max(record.reps, 0))
            context.delete(record)
        }
        sessionSets.removeAll { $0.exerciseName == exerciseName && $0.setIndex == setIndex && $0.sessionID == sid }
        try? context.save()
    }

    func finishSession(sessionRPE: Int, ownerID: String) {
        guard let session = currentSession else { return }
        let now = Date()
        session.finishedAt = now
        session.sessionRPE = sessionRPE
        try? context.save()

        checkDeloadNeeded(ownerID: ownerID)

        let sessionID = session.id
        let volume = session.totalVolume
        Task {
            let body = UpdateSessionRequest(
                finished_at: iso.string(from: now),
                session_rpe: sessionRPE,
                total_volume: volume
            )
            _ = try? await ApiClient.shared.patch("/sessions/\(sessionID)", body: body) as SessionResponse
        }

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

    // MARK: - Previous set lookup for pre-filling

    func previousSets(for exerciseName: String, ownerID: String) -> [ExerciseSetRecord] {
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.exerciseName == exerciseName && $0.isDone == true }
        )
        let all = (try? context.fetch(desc)) ?? []
        guard !all.isEmpty else { return [] }

        let currentID = currentSession?.id ?? ""
        let prior = all.filter { $0.sessionID != currentID }
        guard let latestID = prior
            .max(by: { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) })?
            .sessionID
        else { return [] }

        return prior.filter { $0.sessionID == latestID }.sorted { $0.setIndex < $1.setIndex }
    }

    // Returns a human-readable suggestion string, or nil if no suggestion
    func overloadSuggestion(for exerciseName: String, ownerID: String) -> String? {
        let prev = previousSets(for: exerciseName, ownerID: ownerID)
        guard !prev.isEmpty else { return nil }
        let validRPE = prev.filter { $0.rpe > 0 }
        let avgRPE = validRPE.isEmpty ? 0.0 :
            validRPE.map(\.rpe).reduce(0, +) / Double(validRPE.count)
        let lastWeight = prev.last?.weightKg ?? 0
        if avgRPE > 0 && avgRPE <= 8.0 {
            return String(format: "Try +2.5 kg → %.1f", lastWeight + 2.5)
        } else if avgRPE >= 9.5 {
            return String(format: "Consider %.1f kg (high RPE last time)", max(0, lastWeight - 2.5))
        }
        return nil
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
        sessionID: String, ownerID: String
    ) {
        guard reps > 0, reps <= 30, weightKg > 0 else { return }
        let newE1RM = weightKg * (1.0 + Double(reps) / 30.0)

        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.exerciseName == exerciseName && $0.isDone == true }
        )
        let all = (try? context.fetch(desc)) ?? []
        let historical = all.filter { $0.sessionID != sessionID && $0.reps > 0 && $0.reps <= 30 && $0.weightKg > 0 }
        let maxPrior = historical.map { $0.weightKg * (1.0 + Double($0.reps) / 30.0) }.max() ?? 0

        guard newE1RM > maxPrior else { return }

        withAnimation(.spring(duration: 0.3)) {
            newPRExerciseName = exerciseName
        }
        if !prsHitThisSession.contains(exerciseName) {
            prsHitThisSession.append(exerciseName)
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            withAnimation {
                if self.newPRExerciseName == exerciseName {
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
        if finished.prefix(3).filter({ $0.sessionRPE >= 9 }).count >= 3 {
            showDeloadSuggestion = true
        }
    }

    // MARK: - Muscle group heuristic

    func muscleGroup(for exerciseName: String) -> String {
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
