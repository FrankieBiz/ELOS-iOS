import SwiftUI
import SwiftData
import Combine

// MARK: - Response types

struct CreatorResponse: Decodable {
    let id: String
    let name: String
    let slug: String
    let bio: String?
    let category: String
    let training_style: String?
    let goals: [String]
    let split_types: [String]
    let difficulty: String
    let image_url: String?
    let is_verified: Bool
    let source_urls: [String]
    let workout_count: Int?
}

private struct CreatorsResponse: Decodable { let creators: [CreatorResponse] }

struct WorkoutSummaryResponse: Decodable {
    let id: String
    let creator_id: String?
    let creator_name: String?
    let creator_slug: String?
    let title: String
    let program_type: String
    let days_per_week: Int?
    let goal: String?
    let difficulty: String
    let duration_weeks: Int?
    let est_session_mins: Int?
    let equipment: [String]
    let muscle_groups: [String]
    let tags: [String]
    let disclaimer: String?
    let confidence_level: String?
}

private struct WorkoutsResponse: Decodable { let workouts: [WorkoutSummaryResponse] }

struct MachineResponse: Decodable {
    let id: String
    let name: String
    let slug: String
    let alternate_names: [String]?
    let category: String
    let equipment_type: String
    let primary_muscles: [String]
    let secondary_muscles: [String]?
    let movement_pattern: String?
    let description: String?
    let image_url: String?
    let tags: [String]?
}

private struct MachinesResponse: Decodable { let machines: [MachineResponse] }

private struct SearchResultsResponse: Decodable {
    let creators: [CreatorResponse]?
    let workouts: [WorkoutSummaryResponse]?
    let machines: [MachineResponse]?
}

// MARK: - ViewModel

@MainActor
class DiscoverViewModel: ObservableObject {
    @Published var featuredCreators: [CreatorRecord] = []
    @Published var featuredMachines: [MachineRecord] = []
    @Published var isLoading = false
    @Published var searchResults: SearchResults = SearchResults()

    struct SearchResults {
        var creators: [CreatorResponse] = []
        var workouts: [WorkoutSummaryResponse] = []
        var machines: [MachineResponse] = []
        var isEmpty: Bool { creators.isEmpty && workouts.isEmpty && machines.isEmpty }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func load() {
        let cDesc = FetchDescriptor<CreatorRecord>(sortBy: [SortDescriptor(\.name)])
        featuredCreators = (try? context.fetch(cDesc)) ?? []

        let mDesc = FetchDescriptor<MachineRecord>(sortBy: [SortDescriptor(\.name)])
        featuredMachines = (try? context.fetch(mDesc)) ?? []

        Task {
            isLoading = true
            defer { isLoading = false }
            await syncCreators()
            await syncMachines()
        }
    }

    func search(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = SearchResults()
            return
        }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        Task {
            if let response = try? await ApiClient.shared.get("/library/search?q=\(encoded)") as SearchResultsResponse {
                searchResults = SearchResults(
                    creators: response.creators ?? [],
                    workouts: response.workouts ?? [],
                    machines: response.machines ?? []
                )
            }
        }
    }

    private func syncCreators() async {
        guard let response = try? await ApiClient.shared.get("/library/creators") as CreatorsResponse else { return }
        let existing = Set(featuredCreators.map(\.id))
        for c in response.creators where !existing.contains(c.id) {
            let record = CreatorRecord(
                id: c.id, name: c.name, slug: c.slug,
                bio: c.bio ?? "",
                category: c.category,
                trainingStyle: c.training_style ?? "",
                goalsJSON: (try? String(data: JSONEncoder().encode(c.goals), encoding: .utf8)) ?? "[]",
                splitTypesJSON: (try? String(data: JSONEncoder().encode(c.split_types), encoding: .utf8)) ?? "[]",
                difficulty: c.difficulty,
                imageURL: c.image_url ?? "",
                isVerified: c.is_verified
            )
            context.insert(record)
        }
        try? context.save()
        featuredCreators = (try? context.fetch(FetchDescriptor<CreatorRecord>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private func syncMachines() async {
        guard let response = try? await ApiClient.shared.get("/machines") as MachinesResponse else { return }
        let existing = Set(featuredMachines.map(\.id))
        for m in response.machines where !existing.contains(m.id) {
            let record = MachineRecord(
                id: m.id, name: m.name, slug: m.slug,
                category: m.category,
                equipmentType: m.equipment_type,
                primaryMusclesJSON: (try? String(data: JSONEncoder().encode(m.primary_muscles), encoding: .utf8)) ?? "[]",
                secondaryMusclesJSON: (try? String(data: JSONEncoder().encode(m.secondary_muscles ?? []), encoding: .utf8)) ?? "[]",
                descriptionText: m.description ?? "",
                imageURL: m.image_url ?? "",
                tagsJSON: (try? String(data: JSONEncoder().encode(m.tags ?? []), encoding: .utf8)) ?? "[]"
            )
            context.insert(record)
        }
        try? context.save()
        featuredMachines = (try? context.fetch(FetchDescriptor<MachineRecord>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }
}
