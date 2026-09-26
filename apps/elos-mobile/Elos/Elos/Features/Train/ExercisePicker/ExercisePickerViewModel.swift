import SwiftUI
import SwiftData
import Combine

@MainActor
final class ExercisePickerViewModel: ObservableObject {
    struct ExerciseResponse: Decodable, Identifiable {
        let id: String
        let owner_id: String?
        let name: String
        let primary_muscle: String
        let secondary_muscles: [String]
        let equipment: String
        let movement_pattern: String
        let is_custom: Bool
        let instructions: [String]?
        let image_key: String?
    }

    struct BrandResponse: Decodable, Identifiable {
        let id: String
        let name: String
        let slug: String
    }

    private struct ListResponse: Decodable { let exercises: [ExerciseResponse] }
    private struct BrandsListResponse: Decodable { let brands: [BrandResponse] }
    private struct OkResponse: Decodable { let ok: Bool }

    @Published var recent: [ExerciseResponse] = []
    @Published var favorites: [ExerciseResponse] = []
    @Published var favoriteIDs: Set<String> = []
    @Published var brands: [BrandResponse] = []
    @Published var brandFilteredResults: [ExerciseResponse] = []
    @Published var isLoadingRecent = false
    @Published var isLoadingFavorites = false
    @Published var isLoadingBrandFilter = false

    func loadRecent() async {
        isLoadingRecent = true
        defer { isLoadingRecent = false }
        do {
            let response: ListResponse = try await ApiClient.shared.get("/exercises/recent?limit=15")
            recent = response.exercises
        } catch {
            // Offline-first: the picker's main list comes from local @Query;
            // these server enrichments are non-fatal if the network is down.
        }
    }

    func loadFavorites() async {
        isLoadingFavorites = true
        defer { isLoadingFavorites = false }
        do {
            let response: ListResponse = try await ApiClient.shared.get("/exercises/favorites")
            favorites = response.exercises
            favoriteIDs = Set(response.exercises.map(\.id))
        } catch {
            // Offline-first: the picker's main list comes from local @Query;
            // these server enrichments are non-fatal if the network is down.
        }
    }

    func loadBrands() async {
        do {
            let response: BrandsListResponse = try await ApiClient.shared.get("/machines/brands")
            brands = response.brands.sorted { $0.name < $1.name }
        } catch {
            // Offline-first: the picker's main list comes from local @Query;
            // these server enrichments are non-fatal if the network is down.
        }
    }

    func loadByBrand(_ brandSlug: String) async {
        isLoadingBrandFilter = true
        defer { isLoadingBrandFilter = false }
        do {
            let encoded = brandSlug.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? brandSlug
            let response: ListResponse = try await ApiClient.shared.get("/exercises?brand_slug=\(encoded)&limit=500")
            brandFilteredResults = response.exercises
        } catch {
            brandFilteredResults = []
        }
    }

    // Syncs the global exercise catalog into SwiftData so the @Query in
    // ExercisePickerView reflects the latest server data on every open.
    // Upserts by ID so equipment/name changes from backend migrations propagate.
    func syncExercises(into context: ModelContext) async {
        guard let response = try? await ApiClient.shared.get("/exercises?limit=500") as ListResponse else { return }
        let incoming = response.exercises
        guard !incoming.isEmpty else { return }

        let existing = (try? context.fetch(FetchDescriptor<ExerciseDefinitionRecord>())) ?? []
        // Tolerate duplicate ids in the local store — `uniqueKeysWithValues` would trap.
        let existingByID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Second lookup, keyed by identity rather than id, over the *locally seeded* rows only
        // (non-custom, no owner). `ExerciseCatalog.seedIfNeeded` inserts those with a fresh
        // `UUID()` — an id the server has never heard of — so matching purely on id meant every
        // server exercise looked new and got inserted alongside its seeded twin. That doubled the
        // entire catalog: the picker listed "Arnold Press", "Assisted Pull-Up" etc. twice, and
        // volume could be counted twice if both copies were added to a template.
        //
        // Matching on name + equipment lets the seeded row *adopt* the server id, converging the
        // two into one record. Mirrors the local-id-then-reconcile pattern used for sessions.
        func identityKey(_ name: String, _ equipment: String) -> String {
            "\(MuscleTaxonomy.normalize(name))|\(MuscleTaxonomy.normalize(equipment))"
        }
        //
        // This has to be a multimap. Once a sync has run, a lift can have *two* local rows that both
        // look "seeded" (non-custom, no owner): the original uppercase-`UUID()` twin and the
        // server-backed row adopted from a previous sync. A `[String: Record]` kept only the last one
        // per identity, so the other twin was invisible to both the adopt path (the server id already
        // existed, so it took the update branch) and the orphan sweep below — and survived every
        // subsequent sync. That is why the picker still listed 11 lifts twice.
        var seededByIdentity: [String: [ExerciseDefinitionRecord]] = [:]
        for r in existing where !r.isCustom && r.ownerID.isEmpty {
            seededByIdentity[identityKey(r.name, r.equipment), default: []].append(r)
        }

        for ex in incoming {
            let secondaryJSON = (try? String(data: JSONEncoder().encode(ex.secondary_muscles), encoding: .utf8)) ?? "[]"
            let instructionsJSON = (try? String(data: JSONEncoder().encode(ex.instructions ?? []), encoding: .utf8)) ?? "[]"
            let key = identityKey(ex.name, ex.equipment)
            // Adopt a seeded twin before falling through to "insert new".
            if existingByID[ex.id] == nil,
               let seeded = seededByIdentity[key]?.first {
                // This row is now the server-backed keeper for that identity; take it out of the
                // orphan pool so the sweep below can't delete the very record we just adopted.
                seededByIdentity[key]?.removeFirst()
                seeded.id = ex.id
                seeded.ownerID = ex.owner_id ?? ""
                seeded.name = ex.name
                seeded.equipment = ex.equipment
                seeded.primaryMuscle = ex.primary_muscle
                seeded.secondaryMusclesJSON = secondaryJSON
                seeded.movementPattern = ex.movement_pattern
                seeded.isCustom = ex.is_custom
                seeded.instructionsJSON = instructionsJSON
                seeded.imageKey = ex.image_key ?? ""
                continue
            }
            if let record = existingByID[ex.id] {
                // Same reasoning as the adopt branch: this row is the keeper for its identity, so it
                // must leave the orphan pool. Without this the sweep would delete the server-backed
                // row and leave the stale twin behind.
                seededByIdentity[key]?.removeAll { $0 === record }
                // Update mutable fields so backend corrections (e.g. equipment type) propagate
                record.name = ex.name
                record.equipment = ex.equipment
                record.primaryMuscle = ex.primary_muscle
                record.secondaryMusclesJSON = secondaryJSON
                record.movementPattern = ex.movement_pattern
                record.instructionsJSON = instructionsJSON
                record.imageKey = ex.image_key ?? ""
            } else {
                let record = ExerciseDefinitionRecord(
                    id: ex.id,
                    ownerID: ex.owner_id ?? "",
                    name: ex.name,
                    primaryMuscle: ex.primary_muscle,
                    secondaryMusclesJSON: secondaryJSON,
                    equipment: ex.equipment,
                    movementPattern: ex.movement_pattern,
                    isCustom: ex.is_custom,
                    instructionsJSON: instructionsJSON,
                    imageKey: ex.image_key ?? ""
                )
                context.insert(record)
            }
        }

        // Anything still in `seededByIdentity` that the server also sent under a different id is a
        // leftover twin from before the adopt-by-identity fix above — drop it, keeping the
        // server-backed row. Templates referencing a deleted id degrade gracefully: `ExerciseResolver`
        // already falls back to normalized-name matching when an id misses.
        let incomingIdentities = Set(incoming.map { identityKey($0.name, $0.equipment) })
        for (key, orphans) in seededByIdentity where incomingIdentities.contains(key) {
            orphans.forEach { context.delete($0) }
        }

        try? context.save()
    }

    func toggleFavorite(exerciseID: String) async {
        if favoriteIDs.contains(exerciseID) {
            // Optimistic remove, rolled back if the request fails so the star reflects reality.
            let removed = favorites.first { $0.id == exerciseID }
            favoriteIDs.remove(exerciseID)
            favorites.removeAll { $0.id == exerciseID }
            do {
                _ = try await ApiClient.shared.delete("/exercises/\(exerciseID)/favorite") as OkResponse
            } catch {
                favoriteIDs.insert(exerciseID)
                if let removed { favorites.append(removed) }
            }
        } else {
            favoriteIDs.insert(exerciseID)
            do {
                _ = try await ApiClient.shared.post("/exercises/\(exerciseID)/favorite", body: EmptyBody()) as OkResponse
                await loadFavorites()
            } catch {
                favoriteIDs.remove(exerciseID)
            }
        }
    }
}

private struct EmptyBody: Encodable {}
