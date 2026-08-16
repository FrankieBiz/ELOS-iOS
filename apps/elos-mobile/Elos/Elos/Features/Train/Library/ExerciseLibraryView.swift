import SwiftUI
import SwiftData
import Combine

// MARK: - ViewModel

@MainActor
class ExerciseLibraryViewModel: ObservableObject {
    @Published var definitions: [ExerciseDefinitionRecord] = []
    @Published var searchText = ""
    @Published var isLoading  = false
    @Published var createError: String? = nil

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
            } catch {
                createError = "Couldn't create \"\(name)\". Please check your connection and try again."
            }
        }
    }

    var filtered: [ExerciseDefinitionRecord] {
        let matching = searchText.isEmpty
            ? definitions
            : definitions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return Self.deduped(matching)
    }

    /// Collapse records that describe the same lift on the same equipment.
    ///
    /// The sync path already converges a locally seeded row with its server twin, but it can only do
    /// that when the *server* sent one row. When the server itself holds two rows for one lift under
    /// different ids, nothing upstream can merge them and the library listed the same exercise twice
    /// or three times. Deduping at the point of display means DB drift can never show the user
    /// triplicates, independent of whatever cleanup happens server-side.
    ///
    /// Custom (user-authored) exercises are deliberately exempt: someone may legitimately keep their
    /// own variant alongside the catalog entry, and silently hiding a row the user created is worse
    /// than showing two.
    static func deduped(_ records: [ExerciseDefinitionRecord]) -> [ExerciseDefinitionRecord] {
        var best: [String: ExerciseDefinitionRecord] = [:]
        var custom: [ExerciseDefinitionRecord] = []

        for r in records {
            guard !r.isCustom else { custom.append(r); continue }
            let key = "\(MuscleTaxonomy.normalize(r.name))|\(MuscleTaxonomy.normalize(r.equipment))"
            guard let incumbent = best[key] else { best[key] = r; continue }
            // Keep whichever copy carries more detail, so deduping never costs the user how-to
            // content or a demo image. Ids break ties so the choice is stable across launches.
            if richness(r) > richness(incumbent)
                || (richness(r) == richness(incumbent) && r.id < incumbent.id) {
                best[key] = r
            }
        }
        return best.values + custom
    }

    private static func richness(_ r: ExerciseDefinitionRecord) -> Int {
        var score = 0
        if r.instructionsJSON != "[]" && !r.instructionsJSON.isEmpty { score += 2 }
        if !r.imageKey.isEmpty { score += 1 }
        return score
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
    let instructions: [String]?
    let image_key: String?
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
                        .accessibilityLabel("Filter exercises")
                        Button { showCreate = true } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Create exercise")
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
            .alert("Couldn't Create Exercise", isPresented: Binding(
                get: { libVM.createError != nil },
                set: { if !$0 { libVM.createError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(libVM.createError ?? "")
            }
            .sheet(isPresented: $showAdvancedPicker) {
                ExercisePickerView(onPickSingle: { picked in
                    pickedDetail = libVM.definitions.first { $0.id == picked.id }
                    showAdvancedPicker = false
                    return true
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
                // Some catalog rows carry stray interior whitespace ("Dumbbell Turkish  Get-Up"),
                // which wrapped mid-name and rendered the second line visibly indented. Collapse it
                // for display rather than trusting the stored string to be clean.
                Text(exercise.name.split(whereSeparator: \.isWhitespace).joined(separator: " "))
                    .font(.system(.subheadline, weight: .semibold))
                if exercise.isCustom {
                    Text("Custom")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.tint)
                        .clipShape(Capsule())
                }
            }
            // These were raw database keys ("traps", "rear_delts", "ez_bar"). The picker was fixed to
            // use `muscleDisplayName` in 363ea90 but the library still showed users the schema.
            Text([exercise.primaryMuscle.muscleDisplayName,
                  exercise.equipment.muscleDisplayName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                .font(.elosCaption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
