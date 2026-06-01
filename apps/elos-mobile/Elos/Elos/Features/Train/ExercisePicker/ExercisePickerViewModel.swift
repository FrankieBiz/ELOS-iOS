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
        } catch {}
    }

    func loadFavorites() async {
        isLoadingFavorites = true
        defer { isLoadingFavorites = false }
        do {
            let response: ListResponse = try await ApiClient.shared.get("/exercises/favorites")
            favorites = response.exercises
            favoriteIDs = Set(response.exercises.map(\.id))
        } catch {}
    }

    func loadBrands() async {
        do {
            let response: BrandsListResponse = try await ApiClient.shared.get("/machines/brands")
            brands = response.brands.sorted { $0.name < $1.name }
        } catch {}
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
    func syncExercises(into context: ModelContext) async {
        guard let response = try? await ApiClient.shared.get("/exercises?limit=500") as ListResponse else { return }
        let incoming = response.exercises
        guard !incoming.isEmpty else { return }

        let existing = (try? context.fetch(FetchDescriptor<ExerciseDefinitionRecord>())) ?? []
        let existingIDs = Set(existing.map(\.id))

        for ex in incoming where !existingIDs.contains(ex.id) {
            let record = ExerciseDefinitionRecord(
                id: ex.id,
                ownerID: ex.owner_id ?? "",
                name: ex.name,
                primaryMuscle: ex.primary_muscle,
                secondaryMusclesJSON: (try? String(data: JSONEncoder().encode(ex.secondary_muscles), encoding: .utf8)) ?? "[]",
                equipment: ex.equipment,
                movementPattern: ex.movement_pattern,
                isCustom: ex.is_custom
            )
            context.insert(record)
        }
        try? context.save()
    }

    func toggleFavorite(exerciseID: String) async {
        if favoriteIDs.contains(exerciseID) {
            favoriteIDs.remove(exerciseID)
            favorites.removeAll { $0.id == exerciseID }
            _ = try? await ApiClient.shared.delete("/exercises/\(exerciseID)/favorite") as OkResponse
        } else {
            favoriteIDs.insert(exerciseID)
            _ = try? await ApiClient.shared.post("/exercises/\(exerciseID)/favorite", body: EmptyBody()) as OkResponse
            await loadFavorites()
        }
    }
}

private struct EmptyBody: Encodable {}
