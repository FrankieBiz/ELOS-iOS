import SwiftUI
import SwiftData
import Combine

// MARK: - ViewModel

@MainActor
class TemplatesViewModel: ObservableObject {
    @Published var templates: [WorkoutTemplateRecord] = []
    @Published var templateExercises: [String: [TemplateExerciseRecord]] = [:]
    @Published var isLoading = false
    /// Set when a create/edit fails to reach the server (the template is saved locally but unsynced).
    @Published var syncError: String? = nil

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
                                notes: ex.notes ?? "",
                                equipmentId: ex.equipment_id,
                                equipmentDedupeKey: ex.equipment_dedupe_key,
                                equipmentBrandName: ex.equipment_brand_name
                            ))
                        }
                    }
                }
                try? context.save()
                templates = (try? context.fetch(tDesc)) ?? []
                refreshExerciseMap()
                // Now that the server's templates are merged in, re-push any
                // local ones whose original upload never landed.
                await reconcileUnconfirmed(ownerID: ownerID)
                templates = (try? context.fetch(tDesc)) ?? []
                refreshExerciseMap()
            } catch {}
        }
    }

    /// Push templates created while the server was unreachable
    /// (serverConfirmed == false means the create-time POST never succeeded).
    /// Runs on every load, so a template can never be stranded on-device.
    private func reconcileUnconfirmed(ownerID: String) async {
        let desc = FetchDescriptor<WorkoutTemplateRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.serverConfirmed == false }
        )
        let pending = (try? context.fetch(desc)) ?? []
        for record in pending {
            // If a confirmed template with the same name came down in the pull,
            // the original push actually landed and this is a stale duplicate —
            // adopt the server copy instead of uploading a second one.
            if templates.contains(where: { $0.serverConfirmed && $0.name == record.name && $0.id != record.id }) {
                for ex in exerciseRecords(for: record.id) { context.delete(ex) }
                context.delete(record)
                continue
            }

            let exs = exerciseRecords(for: record.id)
            let body = CreateTemplateRequest(
                name: record.name,
                exercises: exs.enumerated().map { idx, ex in
                    TemplateExerciseRequest(
                        exercise_id: ex.exerciseID,
                        exercise_name: ex.exerciseName,
                        order_index: idx,
                        target_sets: ex.targetSets,
                        target_reps: ex.targetReps,
                        target_rpe: ex.targetRPE > 0 ? ex.targetRPE : nil,
                        rest_seconds: ex.restSeconds,
                        notes: ex.notes.isEmpty ? nil : ex.notes,
                        equipment_id: ex.equipmentId,
                        equipment_dedupe_key: ex.equipmentDedupeKey,
                        equipment_brand_name: ex.equipmentBrandName
                    )
                }
            )
            do {
                let response = try await ApiClient.shared.post("/templates", body: body) as TemplateDetailResponse
                let oldID = record.id
                record.serverConfirmed = true
                if oldID != response.id {
                    record.id = response.id
                    for (idx, ex) in exs.enumerated() {
                        ex.templateID = response.id
                        if idx < response.exercises.count { ex.id = response.exercises[idx].id }
                    }
                    templateExercises.removeValue(forKey: oldID)
                    templateExercises[response.id] = exs

                    TemplateIDRepointing.repointDays(from: oldID, to: response.id, context: context)
                }
            } catch {
                // Still safe locally; retried on the next load.
            }
        }
        try? context.save()
    }

    private func exerciseRecords(for templateID: String) -> [TemplateExerciseRecord] {
        let desc = FetchDescriptor<TemplateExerciseRecord>(
            predicate: #Predicate { $0.templateID == templateID },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return (try? context.fetch(desc)) ?? []
    }

    func createTemplate(name: String, exercises: [TemplateExerciseEntry], ownerID: String,
                        intent: TrainingIntent? = nil) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, !exercises.isEmpty else { return }

        let localID = UUID().uuidString
        let record = WorkoutTemplateRecord(id: localID, ownerID: ownerID, name: name, createdAt: Date(), serverConfirmed: false)
        record.intent = intent
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
                equipmentBrandName: ex.equipmentBrandName,
                muscleTargetsJSON: ex.muscleTargets?.jsonString ?? ""
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
                        notes: ex.notes.isEmpty ? nil : ex.notes,
                        equipment_id: ex.equipmentId,
                        equipment_dedupe_key: ex.equipmentDedupeKey,
                        equipment_brand_name: ex.equipmentBrandName
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
            } catch {
                syncError = "Couldn't save \"\(name)\" to the cloud. It's saved on this device — reopen it to retry syncing."
            }
        }
    }

    func editTemplate(id: String, name: String, exercises: [TemplateExerciseEntry], ownerID: String,
                      intent: TrainingIntent? = nil) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let tDesc = FetchDescriptor<WorkoutTemplateRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? context.fetch(tDesc).first else { return }

        record.name = name
        record.intent = intent

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
                equipmentBrandName: ex.equipmentBrandName,
                muscleTargetsJSON: ex.muscleTargets?.jsonString ?? ""
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
                        notes: ex.notes.isEmpty ? nil : ex.notes,
                        equipment_id: ex.equipmentId,
                        equipment_dedupe_key: ex.equipmentDedupeKey,
                        equipment_brand_name: ex.equipmentBrandName
                    )
                }
            )
            do {
                _ = try await ApiClient.shared.patch("/templates/\(id)", body: body) as TemplateDetailResponse
            } catch {
                syncError = "Couldn't save your changes to \"\(name)\" to the cloud. They're saved on this device."
            }
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
    let equipment_id: String?
    let equipment_dedupe_key: String?
    let equipment_brand_name: String?
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
    let equipment_id: String?
    let equipment_dedupe_key: String?
    let equipment_brand_name: String?
}

private struct EmptyResponse: Decodable {}

// MARK: - Main View

struct TemplatesView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @StateObject private var templVM: TemplatesViewModel

    /// Everything the builder sheet needs, in one value.
    ///
    /// This used to be six separate `@State` properties plus a `showBuilder` bool driving
    /// `.sheet(isPresented:)`. That races: SwiftUI evaluates the sheet's content in the same update
    /// that flips the bool, so the *first* presentation after launch was built from the default
    /// values — tapping Edit on a template opened a blank "New Template" with no name and no
    /// exercises, and because `editingTemplateID` was stale-nil, saving created a second template
    /// instead of editing the original. It appeared to work from the second open onward, which is
    /// what made it easy to miss. `.sheet(item:)` builds the sheet from the payload itself, so the
    /// values can't lag behind the presentation.
    private struct BuilderConfig: Identifiable {
        let id = UUID()
        let name: String
        let entries: [TemplateExerciseEntry]
        let intent: TrainingIntent?
        let isEditMode: Bool
        /// Non-nil = save edits back to this template; nil = create a new one.
        let editingTemplateID: String?
    }
    @State private var builderConfig: BuilderConfig? = nil
    @State private var sharingTemplateID: String? = nil
    @State private var shareURL: URL? = nil
    @State private var shareError: String? = nil
    @State private var templatePendingDelete: WorkoutTemplateRecord? = nil

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
                                isSharing: sharingTemplateID == tmpl.id,
                                onStart: { startSession(from: tmpl) },
                                onEdit: {
                                    builderConfig = BuilderConfig(
                                        name: tmpl.name,
                                        entries: entries(for: tmpl.id),
                                        intent: tmpl.intent,
                                        isEditMode: true,
                                        editingTemplateID: tmpl.id
                                    )
                                },
                                onDuplicate: {
                                    builderConfig = BuilderConfig(
                                        name: "Copy of \(tmpl.name)",
                                        entries: entries(for: tmpl.id),
                                        intent: tmpl.intent,
                                        isEditMode: false,
                                        editingTemplateID: nil
                                    )
                                },
                                onShare: { shareTemplate(tmpl) },
                                onDelete: { templatePendingDelete = tmpl }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                        .onDelete { offsets in
                            if let idx = offsets.first { templatePendingDelete = templVM.templates[idx] }
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
                        builderConfig = BuilderConfig(
                            name: "", entries: [], intent: nil,
                            isEditMode: false, editingTemplateID: nil
                        )
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.tint)
                    }
                    .accessibilityLabel("New template")
                }
            }
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } }
            )) {
                if let url = shareURL {
                    ShareSheet(items: [url as Any, "Check out my workout on Elos" as Any])
                        .presentationDetents([.medium, .large])
                }
            }
            .alert("Couldn't Share Template", isPresented: Binding(
                get: { shareError != nil },
                set: { if !$0 { shareError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(shareError ?? "")
            }
            .alert("Template Not Synced", isPresented: Binding(
                get: { templVM.syncError != nil },
                set: { if !$0 { templVM.syncError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(templVM.syncError ?? "")
            }
            .confirmationDialog(
                "Delete Template?",
                isPresented: Binding(
                    get: { templatePendingDelete != nil },
                    set: { if !$0 { templatePendingDelete = nil } }
                ),
                presenting: templatePendingDelete
            ) { tmpl in
                Button("Delete", role: .destructive) { templVM.deleteTemplate(id: tmpl.id) }
                Button("Cancel", role: .cancel) {}
            } message: { tmpl in
                Text("Delete \"\(tmpl.name)\"? This can't be undone.")
            }
            .sheet(item: $builderConfig) { config in
                TemplateBuilderView(
                    initialName: config.name,
                    initialEntries: config.entries,
                    isEditMode: config.isEditMode,
                    initialIntent: config.intent
                ) { name, exs, intent in
                    if let id = config.editingTemplateID {
                        templVM.editTemplate(id: id, name: name, exercises: exs, ownerID: vm.currentUserID, intent: intent)
                    } else {
                        templVM.createTemplate(name: name, exercises: exs, ownerID: vm.currentUserID, intent: intent)
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
                    .font(.system(.title, weight: .medium))
                    .foregroundStyle(Color.tint)
            }
            VStack(spacing: 6) {
                Text("No Templates Yet")
                    .font(.system(.title3, weight: .bold))
                Text("Save your favourite workouts\nto start in one tap.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                builderConfig = BuilderConfig(
                    name: "", entries: [], intent: nil,
                    isEditMode: false, editingTemplateID: nil
                )
            } label: {
                Label("Create Template", systemImage: "plus")
                    .font(.system(.subheadline, weight: .semibold))
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
                    notes:              ex.notes,
                    muscleTargets:      ex.muscleTargets
                )
            }
    }

    private func shareTemplate(_ template: WorkoutTemplateRecord) {
        guard sharingTemplateID == nil else { return }
        sharingTemplateID = template.id
        Task {
            defer { sharingTemplateID = nil }
            do {
                struct _Empty: Encodable {}
                struct _ShareResponse: Decodable { let shareCode: String }
                let response: _ShareResponse = try await ApiClient.shared.post(
                    "/templates/\(template.id)/share",
                    body: _Empty()
                )
                if let url = URL(string: "elos://template?code=\(response.shareCode)") {
                    shareURL = url
                }
            } catch {
                shareError = "Could not generate share link. Please try again."
            }
        }
    }

    private func startSession(from template: WorkoutTemplateRecord) {
        let exercises = (templVM.templateExercises[template.id] ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
        vm.exercises = vm.exercises(fromTemplateExercises: exercises)
        vm.showingSession = true
    }
}

// MARK: - TemplateRow

private struct TemplateRow: View {
    let template: WorkoutTemplateRecord
    let exercises: [TemplateExerciseRecord]
    var isSharing: Bool = false
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext

    private var estimatedMinutes: Int {
        exercises.reduce(0) { $0 + ($1.targetSets * ($1.restSeconds + 45)) } / 60
    }

    private var topMuscles: [(label: String, color: Color)] {
        var counts: [String: Int] = [:]
        for ex in exercises {
            // Same resolution the coverage bars use, so a template's card and its builder agree.
            let targets = resolvedMuscleTargets(
                exerciseID: ex.exerciseID, name: ex.exerciseName,
                equipmentId: ex.equipmentId, override: ex.muscleTargets,
                candidate: candidate(forID: ex.exerciseID, in: modelContext))
            if let label = muscleLabel(for: targets) {
                counts[label, default: 0] += ex.targetSets
            }
        }
        return counts.sorted { $0.value > $1.value }
            .prefix(4)
            .map { ($0.key, muscleGroupColor(for: $0.key)) }
    }

    private var templateName: some View {
        Text(template.name)
            .font(.system(.headline, weight: .bold))
            .lineLimit(2)
    }

    private var startButton: some View {
        Button(action: onStart) {
            // Explicit `titleAndIcon`: left to choose, SwiftUI collapsed this to icon-only inside the
            // card and the capsule rendered as a bare orange circle with no "Start" on it.
            Label("Start", systemImage: "play.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 13).padding(.vertical, 7)
                .background(Color.tint, in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    var body: some View {
        // Every size here was a fixed literal, so the card stayed at its default size while the
        // "Templates" title above it grew — the sheet looked like two different apps stacked.
        VStack(alignment: .leading, spacing: Space.s + 2) {
            // Top row: name + start button. Wraps rather than squeezing the name, since "Start" is
            // the one control on the card.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Space.s) {
                    templateName
                    Spacer(minLength: 0)
                    startButton
                }
                VStack(alignment: .leading, spacing: Space.s) {
                    templateName
                    startButton
                }
            }

            // Exercise preview
            if !exercises.isEmpty {
                Text(exercises.prefix(3).map { $0.exerciseName }.joined(separator: "  ·  ") +
                     (exercises.count > 3 ? "  +\(exercises.count - 3) more" : ""))
                    .font(.elosMicro)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Muscle dots + stats
            HStack(spacing: Space.s) {
                HStack(spacing: 4) {
                    ForEach(topMuscles, id: \.label) { m in
                        Circle().fill(m.color).frame(width: 8, height: 8)
                    }
                }
                Spacer(minLength: 0)
                Label("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")",
                      systemImage: "dumbbell.fill")
                    .font(.elosMicro)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)

                if !exercises.isEmpty {
                    Label("~\(estimatedMinutes) min", systemImage: "clock")
                        .font(.elosMicro)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
            }
            // Dots-plus-two-stats in one row cannot reflow; cap the growth rather than overflow.
            .elosDenseLayout()
        }
        .padding(Space.card)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button { onDuplicate() } label: { Label("Duplicate", systemImage: "doc.on.doc") }
            Button { onShare() } label: { Label("Share", systemImage: "square.and.arrow.up") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onShare()
            } label: {
                if isSharing {
                    ProgressView()
                } else {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .tint(.blue)

            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
