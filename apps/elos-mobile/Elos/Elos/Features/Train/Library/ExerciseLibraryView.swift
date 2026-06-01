import SwiftUI
import SwiftData
import Combine

// MARK: - ViewModel

@MainActor
class ExerciseLibraryViewModel: ObservableObject {
    @Published var definitions: [ExerciseDefinitionRecord] = []
    @Published var searchText = ""
    @Published var isLoading  = false

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func load(ownerID: String) {
        // Load from local SwiftData first
        let desc = FetchDescriptor<ExerciseDefinitionRecord>(
            sortBy: [SortDescriptor(\.name)]
        )
        definitions = (try? context.fetch(desc)) ?? []

        // Then sync from API
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let response = try await ApiClient.shared.get("/exercises?limit=500") as ExercisesResponse
                for ex in response.exercises {
                    let existing = definitions.first(where: { $0.id == ex.id })
                    if existing == nil {
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
                }
                try? context.save()
                definitions = (try? context.fetch(desc)) ?? []
            } catch {
                // Cached data remains
            }
        }
    }

    func createExercise(name: String, primaryMuscle: String, equipment: String, movementPattern: String, ownerID: String) {
        Task {
            let body = CreateExerciseRequest(
                name: name, primary_muscle: primaryMuscle,
                equipment: equipment, movement_pattern: movementPattern
            )
            do {
                let response = try await ApiClient.shared.post("/exercises", body: body) as ExerciseDefinitionResponse
                let record = ExerciseDefinitionRecord(
                    id: response.id,
                    ownerID: ownerID,
                    name: response.name,
                    primaryMuscle: response.primary_muscle,
                    secondaryMusclesJSON: (try? String(data: JSONEncoder().encode(response.secondary_muscles), encoding: .utf8)) ?? "[]",
                    equipment: response.equipment,
                    movementPattern: response.movement_pattern,
                    isCustom: true
                )
                context.insert(record)
                try? context.save()
                definitions.append(record)
                definitions.sort { $0.name < $1.name }
            } catch {}
        }
    }

    var filtered: [ExerciseDefinitionRecord] {
        guard !searchText.isEmpty else { return definitions }
        return definitions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var grouped: [(key: String, exercises: [ExerciseDefinitionRecord])] {
        let dict = Dictionary(grouping: filtered, by: { $0.movementPattern.isEmpty ? "other" : $0.movementPattern })
        return dict.sorted { $0.key < $1.key }.map { (key: $0.key, exercises: $0.value.sorted { $0.name < $1.name }) }
    }
}

private struct ExercisesResponse: Decodable {
    let exercises: [ExerciseDefinitionResponse]
}

struct ExerciseDefinitionResponse: Decodable {
    let id: String
    let owner_id: String?
    let name: String
    let primary_muscle: String
    let secondary_muscles: [String]
    let equipment: String
    let movement_pattern: String
    let is_custom: Bool
}

private struct CreateExerciseRequest: Encodable {
    let name: String
    let primary_muscle: String
    let equipment: String
    let movement_pattern: String
}

// MARK: - Main View

struct ExerciseLibraryView: View {
    @EnvironmentObject var vm: AppViewModel
    @StateObject private var libVM: ExerciseLibraryViewModel

    @State private var showCreate = false
    @State private var showAdvancedPicker = false
    @State private var pickedDetail: ExerciseDefinitionRecord?

    init(modelContext: ModelContext) {
        _libVM = StateObject(wrappedValue: ExerciseLibraryViewModel(context: modelContext))
    }

    var body: some View {
        NavigationStack {
            Group {
                if libVM.isLoading && libVM.definitions.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(libVM.grouped, id: \.key) { group in
                            Section(header: Text(group.key.capitalized.replacingOccurrences(of: "_", with: " "))) {
                                ForEach(group.exercises) { ex in
                                    NavigationLink(destination: ExerciseDetailView(exercise: ex)) {
                                        ExerciseRow(exercise: ex)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $libVM.searchText, prompt: "Search exercises")
                }
            }
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button { showAdvancedPicker = true } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                        Button { showCreate = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateExerciseView { name, muscle, equipment, pattern in
                    libVM.createExercise(name: name, primaryMuscle: muscle,
                                         equipment: equipment, movementPattern: pattern,
                                         ownerID: vm.currentUserID)
                    showCreate = false
                }
            }
            .sheet(isPresented: $showAdvancedPicker) {
                ExercisePickerView(onPickSingle: { picked in
                    pickedDetail = libVM.definitions.first { $0.id == picked.id }
                    showAdvancedPicker = false
                })
            }
            .navigationDestination(item: $pickedDetail) { ex in
                ExerciseDetailView(exercise: ex)
            }
            .onAppear {
                libVM.load(ownerID: vm.currentUserID)
            }
        }
    }
}

private struct ExerciseRow: View {
    let exercise: ExerciseDefinitionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(exercise.name).font(.subheadline).fontWeight(.semibold)
                if exercise.isCustom {
                    Text("Custom")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.tint)
                        .clipShape(Capsule())
                }
            }
            Text([exercise.primaryMuscle, exercise.equipment]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
