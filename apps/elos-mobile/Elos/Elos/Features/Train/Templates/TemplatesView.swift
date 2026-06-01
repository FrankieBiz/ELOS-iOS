import SwiftUI
import SwiftData
import Combine

// MARK: - ViewModel

@MainActor
class TemplatesViewModel: ObservableObject {
    @Published var templates: [WorkoutTemplateRecord] = []
    @Published var templateExercises: [String: [TemplateExerciseRecord]] = [:]
    @Published var isLoading = false

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func load(ownerID: String) {
        let tDesc = FetchDescriptor<WorkoutTemplateRecord>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        templates = (try? context.fetch(tDesc)) ?? []
        refreshExerciseMap()

        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let response = try await ApiClient.shared.get("/templates") as TemplatesResponse
                for tmpl in response.templates {
                    if templates.first(where: { $0.id == tmpl.id }) == nil {
                        let record = WorkoutTemplateRecord(
                            id: tmpl.id, ownerID: ownerID,
                            name: tmpl.name,
                            createdAt: ISO8601DateFormatter().date(from: tmpl.created_at) ?? Date(),
                            serverConfirmed: true
                        )
                        context.insert(record)
                        for ex in tmpl.exercises {
                            context.insert(TemplateExerciseRecord(
                                id: ex.id, ownerID: ownerID,
                                templateID: tmpl.id,
                                exerciseID: ex.exercise_id,
                                exerciseName: ex.exercise_name,
                                orderIndex: ex.order_index,
                                targetSets: ex.target_sets,
                                targetReps: ex.target_reps,
                                targetRPE: ex.target_rpe ?? 0,
                                restSeconds: ex.rest_seconds,
                                notes: ex.notes ?? ""
                            ))
                        }
                    }
                }
                try? context.save()
                templates = (try? context.fetch(tDesc)) ?? []
                refreshExerciseMap()
            } catch {}
        }
    }

    func createTemplate(name: String, exercises: [TemplateExerciseEntry], ownerID: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, !exercises.isEmpty else { return }

        let localID = UUID().uuidString
        let record = WorkoutTemplateRecord(id: localID, ownerID: ownerID, name: name, createdAt: Date(), serverConfirmed: false)
        context.insert(record)
        var exRecords: [TemplateExerciseRecord] = []
        for (idx, ex) in exercises.enumerated() {
            let exRecord = TemplateExerciseRecord(
                ownerID: ownerID, templateID: localID,
                exerciseID: ex.exerciseID, exerciseName: ex.exerciseName,
                orderIndex: idx,
                targetSets: ex.targetSets, targetReps: ex.targetReps,
                targetRPE: ex.targetRPE, restSeconds: ex.restSeconds,
                notes: ex.notes,
                equipmentId: ex.equipmentId, equipmentDedupeKey: ex.equipmentDedupeKey,
                equipmentBrandName: ex.equipmentBrandName
            )
            context.insert(exRecord)
            exRecords.append(exRecord)
        }
        try? context.save()
        templates.insert(record, at: 0)
        templateExercises[localID] = exRecords

        Task {
            let body = CreateTemplateRequest(
                name: name,
                exercises: exercises.enumerated().map { idx, ex in
                    TemplateExerciseRequest(
                        exercise_id: ex.exerciseID,
                        exercise_name: ex.exerciseName,
                        order_index: idx,
                        target_sets: ex.targetSets,
                        target_reps: ex.targetReps,
                        target_rpe: ex.targetRPE > 0 ? ex.targetRPE : nil,
                        rest_seconds: ex.restSeconds,
                        notes: ex.notes.isEmpty ? nil : ex.notes
                    )
                }
            )
            do {
                let response = try await ApiClient.shared.post("/templates", body: body) as TemplateDetailResponse
                let serverID = response.id
                record.serverConfirmed = true
                if localID != serverID {
                    record.id = serverID
                    for (idx, ex) in exRecords.enumerated() {
                        ex.templateID = serverID
                        if idx < response.exercises.count { ex.id = response.exercises[idx].id }
                    }
                    templateExercises.removeValue(forKey: localID)
                    templateExercises[serverID] = exRecords
                }
                try? context.save()
            } catch {}
        }
    }

    func editTemplate(id: String, name: String, exercises: [TemplateExerciseEntry], ownerID: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let tDesc = FetchDescriptor<WorkoutTemplateRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? context.fetch(tDesc).first else { return }

        record.name = name

        let eDesc = FetchDescriptor<TemplateExerciseRecord>(predicate: #Predicate { $0.templateID == id })
        let existing = (try? context.fetch(eDesc)) ?? []
        existing.forEach { context.delete($0) }

        var newRecords: [TemplateExerciseRecord] = []
        for (idx, ex) in exercises.enumerated() {
            let exRecord = TemplateExerciseRecord(
                ownerID: ownerID, templateID: id,
                exerciseID: ex.exerciseID, exerciseName: ex.exerciseName,
                orderIndex: idx,
                targetSets: ex.targetSets, targetReps: ex.targetReps,
                targetRPE: ex.targetRPE, restSeconds: ex.restSeconds,
                notes: ex.notes,
                equipmentId: ex.equipmentId, equipmentDedupeKey: ex.equipmentDedupeKey,
                equipmentBrandName: ex.equipmentBrandName
            )
            context.insert(exRecord)
            newRecords.append(exRecord)
        }
        try? context.save()
        templateExercises[id] = newRecords

        Task {
            guard record.serverConfirmed else { return }
            let body = UpdateTemplateRequest(
                name: name,
                exercises: exercises.enumerated().map { idx, ex in
                    TemplateExerciseRequest(
                        exercise_id: ex.exerciseID,
                        exercise_name: ex.exerciseName,
                        order_index: idx,
                        target_sets: ex.targetSets,
                        target_reps: ex.targetReps,
                        target_rpe: ex.targetRPE > 0 ? ex.targetRPE : nil,
                        rest_seconds: ex.restSeconds,
                        notes: ex.notes.isEmpty ? nil : ex.notes
                    )
                }
            )
            _ = try? await ApiClient.shared.patch("/templates/\(id)", body: body) as TemplateDetailResponse
        }
    }

    func deleteTemplate(id: String) {
        templates.removeAll { $0.id == id }
        templateExercises.removeValue(forKey: id)
        let desc = FetchDescriptor<WorkoutTemplateRecord>(predicate: #Predicate { $0.id == id })
        if let record = try? context.fetch(desc).first {
            context.delete(record)
            try? context.save()
        }
        Task { _ = try? await ApiClient.shared.delete("/templates/\(id)") as EmptyResponse }
    }

    private func refreshExerciseMap() {
        for tmpl in templates {
            let tmplID = tmpl.id
            let eDesc = FetchDescriptor<TemplateExerciseRecord>(
                predicate: #Predicate { $0.templateID == tmplID },
                sortBy: [SortDescriptor(\.orderIndex)]
            )
            templateExercises[tmpl.id] = (try? context.fetch(eDesc)) ?? []
        }
    }
}

// MARK: - API types

private struct TemplatesResponse: Decodable {
    let templates: [TemplateDetailResponse]
}

struct TemplateDetailResponse: Decodable {
    let id: String
    let user_id: String?
    let name: String
    let created_at: String
    let exercises: [TemplateExerciseResponse]
}

struct TemplateExerciseResponse: Decodable {
    let id: String
    let exercise_id: String?
    let exercise_name: String
    let order_index: Int
    let target_sets: Int
    let target_reps: String
    let target_rpe: Double?
    let rest_seconds: Int
    let notes: String?
}

private struct CreateTemplateRequest: Encodable {
    let name: String
    let exercises: [TemplateExerciseRequest]
}

private struct UpdateTemplateRequest: Encodable {
    let name: String
    let exercises: [TemplateExerciseRequest]
}

private struct TemplateExerciseRequest: Encodable {
    let exercise_id: String?
    let exercise_name: String
    let order_index: Int
    let target_sets: Int
    let target_reps: String
    let target_rpe: Double?
    let rest_seconds: Int
    let notes: String?
}

private struct EmptyResponse: Decodable {}

// MARK: - Main View

struct TemplatesView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @StateObject private var templVM: TemplatesViewModel

    @State private var showBuilder = false
    @State private var builderIsEditMode = false
    @State private var builderInitialName = ""
    @State private var builderInitialEntries: [TemplateExerciseEntry] = []
    @State private var editingTemplateID: String? = nil

    init(modelContext: ModelContext) {
        _templVM = StateObject(wrappedValue: TemplatesViewModel(context: modelContext))
    }

    var body: some View {
        NavigationView {
            Group {
                if templVM.templates.isEmpty && !templVM.isLoading {
                    emptyState
                } else {
                    List {
                        ForEach(templVM.templates) { tmpl in
                            TemplateRow(
                                template: tmpl,
                                exercises: templVM.templateExercises[tmpl.id] ?? [],
                                onStart: { startSession(from: tmpl) },
                                onEdit: {
                                    builderIsEditMode = true
                                    builderInitialName = tmpl.name
                                    builderInitialEntries = entries(for: tmpl.id)
                                    editingTemplateID = tmpl.id
                                    showBuilder = true
                                },
                                onDuplicate: {
                                    builderIsEditMode = false
                                    builderInitialName = "Copy of \(tmpl.name)"
                                    builderInitialEntries = entries(for: tmpl.id)
                                    editingTemplateID = nil
                                    showBuilder = true
                                },
                                onDelete: { templVM.deleteTemplate(id: tmpl.id) }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                        .onDelete { offsets in
                            for idx in offsets { templVM.deleteTemplate(id: templVM.templates[idx].id) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        builderIsEditMode = false
                        builderInitialName = ""
                        builderInitialEntries = []
                        editingTemplateID = nil
                        showBuilder = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.tint)
                    }
                }
            }
            .sheet(isPresented: $showBuilder) {
                let editID = editingTemplateID
                TemplateBuilderView(
                    initialName: builderInitialName,
                    initialEntries: builderInitialEntries,
                    isEditMode: builderIsEditMode
                ) { name, exs in
                    if let id = editID {
                        templVM.editTemplate(id: id, name: name, exercises: exs, ownerID: vm.currentUserID)
                    } else {
                        templVM.createTemplate(name: name, exercises: exs, ownerID: vm.currentUserID)
                    }
                }
            }
            .onAppear { templVM.load(ownerID: vm.currentUserID) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.tint.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.tint)
            }
            VStack(spacing: 6) {
                Text("No Templates Yet")
                    .font(.system(size: 20, weight: .bold))
                Text("Save your favourite workouts\nto start in one tap.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                builderIsEditMode = false
                builderInitialName = ""
                builderInitialEntries = []
                editingTemplateID = nil
                showBuilder = true
            } label: {
                Label("Create Template", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
            }
            .elosPrimaryButton()
            .frame(width: 200)
        }
        .padding(32)
    }

    private func entries(for templateID: String) -> [TemplateExerciseEntry] {
        (templVM.templateExercises[templateID] ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { ex in
                TemplateExerciseEntry(
                    exerciseID:         ex.exerciseID,
                    exerciseName:       ex.exerciseName,
                    equipmentId:        ex.equipmentId,
                    equipmentDedupeKey: ex.equipmentDedupeKey,
                    equipmentBrandName: ex.equipmentBrandName,
                    targetSets:         ex.targetSets,
                    targetReps:         ex.targetReps,
                    targetRPE:          ex.targetRPE,
                    restSeconds:        ex.restSeconds,
                    notes:              ex.notes
                )
            }
    }

    private func startSession(from template: WorkoutTemplateRecord) {
        let exercises = templVM.templateExercises[template.id] ?? []
        vm.exercises = exercises.sorted { $0.orderIndex < $1.orderIndex }.map { ex in
            Exercise(
                name: ex.exerciseName,
                primaryMuscle: "",
                secondaryMuscles: [],
                setsLabel: "\(ex.targetSets)×\(ex.targetReps)",
                lastBest: "",
                sets: (0..<ex.targetSets).map { _ in
                    WorkSet(weight: "", reps: ex.targetReps.components(separatedBy: "-").first ?? "",
                            rpe: ex.targetRPE > 0 ? String(Int(ex.targetRPE)) : "")
                }
            )
        }
        vm.showingSession = true
    }
}

// MARK: - TemplateRow

private struct TemplateRow: View {
    let template: WorkoutTemplateRecord
    let exercises: [TemplateExerciseRecord]
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    private var estimatedMinutes: Int {
        exercises.reduce(0) { $0 + ($1.targetSets * ($1.restSeconds + 45)) } / 60
    }

    private var topMuscles: [(label: String, color: Color)] {
        var counts: [String: Int] = [:]
        for ex in exercises {
            if let label = resolveMuscleLabelHeuristic(for: ex.exerciseName) {
                counts[label, default: 0] += ex.targetSets
            }
        }
        return counts.sorted { $0.value > $1.value }
            .prefix(4)
            .map { ($0.key, muscleGroupColor(for: $0.key)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: name + start button
            HStack(alignment: .top) {
                Text(template.name)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Button(action: onStart) {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill").font(.system(size: 11))
                        Text("Start").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13).padding(.vertical, 7)
                    .background(Color.tint)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Exercise preview
            if !exercises.isEmpty {
                Text(exercises.prefix(3).map { $0.exerciseName }.joined(separator: "  ·  ") +
                     (exercises.count > 3 ? "  +\(exercises.count - 3) more" : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Muscle dots + stats
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(topMuscles, id: \.label) { m in
                        Circle().fill(m.color).frame(width: 8, height: 8)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 10))
                    Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)

                if !exercises.isEmpty {
                    Text("·").foregroundStyle(.secondary).font(.system(size: 12))
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 10))
                        Text("~\(estimatedMinutes) min").font(.system(size: 12))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button { onDuplicate() } label: { Label("Duplicate", systemImage: "doc.on.doc") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
