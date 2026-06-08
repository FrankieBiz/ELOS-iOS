import Foundation
import SwiftData

/// Pushes locally-recorded workout sessions/sets to the backend and reconciles
/// anything that failed to sync (offline, app killed mid-workout, etc.).
///
/// The backend generates its own session/set ids, so we capture the returned id
/// into `serverID` and address all follow-up calls (sets, finish) by it. Records
/// carry `syncPending` until confirmed, mirroring the splits/profile sync pattern.
@MainActor
final class WorkoutSyncService {
    static let shared = WorkoutSyncService()

    private let iso = ISO8601DateFormatter()

    private struct CreateSessionRequest: Encodable { let started_at: String }
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
    private struct IDResponse: Decodable { let id: String }

    // MARK: - Live push (called as the workout happens)

    /// Create the session server-side, capture its id, then flush any sets/finish
    /// that were recorded before the id arrived.
    func pushSessionCreate(_ session: WorkoutSessionRecord, context: ModelContext) async {
        guard session.serverID.isEmpty else { return }
        do {
            let body = CreateSessionRequest(started_at: iso.string(from: session.startedAt))
            let resp: IDResponse = try await ApiClient.shared.post("/sessions", body: body)
            session.serverID = resp.id
            try? context.save()
            await flushSets(for: session, context: context)
            if session.finishedAt != nil { await pushFinish(session, context: context) }
            session.syncPending = hasUnsyncedSets(session, context: context)
            try? context.save()
        } catch {
            session.syncPending = true
            try? context.save()
        }
    }

    /// POST a single set. No-op (left pending) if the session id isn't known yet —
    /// `reconcile` / `pushSessionCreate`'s flush will pick it up.
    func pushSet(_ set: ExerciseSetRecord, session: WorkoutSessionRecord, context: ModelContext) async {
        guard set.serverID.isEmpty else { return }
        guard !session.serverID.isEmpty else { set.syncPending = true; try? context.save(); return }
        await postSet(set, serverSessionID: session.serverID, context: context)
    }

    /// PATCH the session's finish payload. Left pending if the id isn't known yet.
    func pushFinish(_ session: WorkoutSessionRecord, context: ModelContext) async {
        guard let finishedAt = session.finishedAt else { return }
        guard !session.serverID.isEmpty else { session.syncPending = true; try? context.save(); return }
        do {
            let body = UpdateSessionRequest(
                finished_at: iso.string(from: finishedAt),
                session_rpe: session.sessionRPE,
                total_volume: session.totalVolume
            )
            let _: IDResponse = try await ApiClient.shared.patch("/sessions/\(session.serverID)", body: body)
            session.syncPending = hasUnsyncedSets(session, context: context)
            try? context.save()
        } catch {
            session.syncPending = true
            try? context.save()
        }
    }

    // MARK: - Reconcile (called on login / app launch)

    func reconcile(ownerID: String, context: ModelContext) async {
        guard !ownerID.isEmpty else { return }
        let desc = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.syncPending == true }
        )
        let pending = (try? context.fetch(desc)) ?? []
        for session in pending {
            if session.serverID.isEmpty {
                await pushSessionCreate(session, context: context)
                continue
            }
            await flushSets(for: session, context: context)
            if session.finishedAt != nil {
                await pushFinish(session, context: context)
            } else {
                session.syncPending = hasUnsyncedSets(session, context: context)
                try? context.save()
            }
        }
    }

    // MARK: - Helpers

    private func postSet(_ set: ExerciseSetRecord, serverSessionID: String, context: ModelContext) async {
        do {
            let body = CreateSetRequest(
                exercise_name: set.exerciseName,
                set_index: set.setIndex,
                weight_kg: set.weightKg,
                reps: set.reps,
                rpe: set.rpe > 0 ? set.rpe : nil,
                completed_at: iso.string(from: set.completedAt ?? Date())
            )
            let resp: IDResponse = try await ApiClient.shared.post("/sessions/\(serverSessionID)/sets", body: body)
            set.serverID = resp.id
            set.syncPending = false
            try? context.save()
        } catch {
            set.syncPending = true
            try? context.save()
        }
    }

    private func flushSets(for session: WorkoutSessionRecord, context: ModelContext) async {
        guard !session.serverID.isEmpty else { return }
        let sid = session.id
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.sessionID == sid && $0.serverID == "" }
        )
        let unsynced = (try? context.fetch(desc)) ?? []
        for set in unsynced {
            await postSet(set, serverSessionID: session.serverID, context: context)
        }
    }

    private func hasUnsyncedSets(_ session: WorkoutSessionRecord, context: ModelContext) -> Bool {
        let sid = session.id
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.sessionID == sid && $0.serverID == "" }
        )
        return !((try? context.fetch(desc)) ?? []).isEmpty
    }
}
