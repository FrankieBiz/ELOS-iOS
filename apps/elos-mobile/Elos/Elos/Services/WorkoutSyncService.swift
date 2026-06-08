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
        let equipment_id: String?
        let equipment_dedupe_key: String?
        let equipment_brand_name: String?
    }
    private struct IDResponse: Decodable { let id: String }

    // MARK: - Down-sync response shapes (GET /sessions, GET /sessions/:id/sets)

    private struct SessionListResponse: Decodable { let sessions: [SessionResponse] }
    private struct SessionResponse: Decodable {
        let id: String
        let started_at: String?
        let finished_at: String?
        let session_rpe: Int?
        let notes: String?
        let template_id: String?
        let total_volume: Double?
    }
    private struct SetListResponse: Decodable { let sets: [SetResponse] }
    private struct SetResponse: Decodable {
        let id: String
        let exercise_name: String
        let set_index: Int
        let weight_kg: Double
        let reps: Int
        let rpe: Double?
        let completed_at: String?
        let equipment_id: String?
        let equipment_dedupe_key: String?
        let equipment_brand_name: String?
    }

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

    /// DELETE a previously-synced set server-side (when the user un-checks/removes it).
    func deleteSet(serverSessionID: String, setServerID: String) async {
        guard !serverSessionID.isEmpty, !setServerID.isEmpty else { return }
        try? await ApiClient.shared.deleteNoContent("/sessions/\(serverSessionID)/sets/\(setServerID)")
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

        // After pushing anything local, pull server history to fill gaps
        // (fresh install / new device). Self-bounding: only sessions missing
        // locally trigger a per-session sets fetch.
        await hydrateFromServer(ownerID: ownerID, context: context)
    }

    // MARK: - Down-sync (restore history on reinstall / new device)

    /// Pull recent sessions + their sets from the server and insert any that are
    /// missing locally (matched by `serverID`). Without this, a reinstall loses
    /// all logged history and every PR / overload baseline resets.
    func hydrateFromServer(ownerID: String, context: ModelContext) async {
        guard !ownerID.isEmpty else { return }
        let remote: SessionListResponse
        do {
            remote = try await ApiClient.shared.get("/sessions?limit=100")
        } catch {
            return  // offline — local state stands
        }

        // Server ids already present locally → skip (dedup).
        let existing = (try? context.fetch(FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == ownerID }
        ))) ?? []
        let knownServerIDs = Set(existing.map(\.serverID).filter { !$0.isEmpty })

        for s in remote.sessions where !knownServerIDs.contains(s.id) {
            let session = WorkoutSessionRecord(
                ownerID: ownerID,
                startedAt: ServerDate.parse(s.started_at) ?? Date(),
                finishedAt: ServerDate.parse(s.finished_at),
                sessionRPE: s.session_rpe ?? 0,
                notes: s.notes ?? "",
                templateID: s.template_id ?? "",
                totalVolume: s.total_volume ?? 0,
                serverID: s.id,
                syncPending: false
            )
            context.insert(session)

            // Pull this session's sets (only runs for genuinely missing sessions).
            if let setList: SetListResponse = try? await ApiClient.shared.get("/sessions/\(s.id)/sets") {
                for set in setList.sets {
                    context.insert(ExerciseSetRecord(
                        ownerID: ownerID,
                        sessionID: session.id,
                        exerciseName: set.exercise_name,
                        setIndex: set.set_index,
                        weightKg: set.weight_kg,
                        reps: set.reps,
                        rpe: set.rpe ?? 0,
                        isDone: true,
                        completedAt: ServerDate.parse(set.completed_at),
                        equipmentId: set.equipment_id,
                        equipmentDedupeKey: set.equipment_dedupe_key,
                        equipmentBrandName: set.equipment_brand_name,
                        serverID: set.id,
                        syncPending: false
                    ))
                }
            }
            try? context.save()
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
                completed_at: iso.string(from: set.completedAt ?? Date()),
                equipment_id: set.equipmentId,
                equipment_dedupe_key: set.equipmentDedupeKey,
                equipment_brand_name: set.equipmentBrandName
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
