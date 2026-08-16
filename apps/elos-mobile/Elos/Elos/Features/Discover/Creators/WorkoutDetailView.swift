import SwiftUI
import SwiftData
import Combine

// MARK: - Response types

struct WorkoutDetailAPIResponse: Decodable {
    let id: String
    let creator_id: String
    let creator_name: String
    let creator_slug: String
    let title: String
    let description: String?
    let program_type: String
    let days_per_week: Int?
    let goal: String?
    let difficulty: String
    let duration_weeks: Int?
    let est_session_mins: Int?
    let equipment: [String]
    let muscle_groups: [String]
    let tags: [String]
    let source_url: String?
    let attribution: String?
    let disclaimer: String?
    let confidence_level: String
    let days: [WorkoutDayAPIResponse]
}

struct WorkoutDayAPIResponse: Decodable {
    let id: String
    let day_number: Int
    let name: String
    let focus: String?
    let notes: String?
    let order_index: Int
    let exercises: [WorkoutExerciseAPIResponse]
}

struct WorkoutExerciseAPIResponse: Decodable {
    let exercise_name: String
    let order_index: Int
    let sets: Int?
    let reps: String?
    let rest_seconds: Int?
    let rpe_guidance: String?
    let notes: String?
    let substitution_notes: String?
    let is_superset: Bool?
    let superset_group: Int?
}

// MARK: - View

struct WorkoutDetailView: View {
    let workoutId: String
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var detailVM = WorkoutDetailViewModel()

    @State private var expandedDay: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if detailVM.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if let w = detailVM.workout {
                    headerCard(w)
                    if !w.equipment.isEmpty { equipmentRow(w.equipment) }
                    ForEach(w.days, id: \.id) { day in
                        WorkoutDaySectionView(
                            day: day,
                            isExpanded: expandedDay == day.id
                        ) {
                            expandedDay = expandedDay == day.id ? nil : day.id
                        }
                    }
                    if let disclaimer = w.disclaimer {
                        disclaimerCard(disclaimer, attribution: w.attribution)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Could not load workout.").foregroundStyle(.secondary)
                        Button("Retry") { Task { await detailVM.load(workoutId: workoutId, context: modelContext) } }
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.tint)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(detailVM.workout?.title ?? "Program")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await detailVM.load(workoutId: workoutId, context: modelContext)
            expandedDay = detailVM.workout?.days.first?.id
        }
        .safeAreaInset(edge: .bottom) {
            if detailVM.workout != nil { bottomBar }
        }
    }

    // MARK: Header Card

    private func headerCard(_ w: WorkoutDetailAPIResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(w.title).font(.title3).fontWeight(.bold)
            Text(w.creator_name).font(.subheadline).foregroundStyle(Color.tint)
            if let desc = w.description, !desc.isEmpty {
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                if let days = w.days_per_week { metaChip(icon: "calendar", text: "\(days)d/wk") }
                if let dur = w.duration_weeks  { metaChip(icon: "clock",    text: "\(dur) wks")  }
                if let mins = w.est_session_mins { metaChip(icon: "timer",   text: "~\(mins)min") }
                DifficultyBadge(difficulty: w.difficulty)
            }
        }
        .padding(16)
        .elosCard()
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
    }

    private func equipmentRow(_ equipment: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Equipment").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(equipment, id: \.self) { item in
                    Text(item.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func disclaimerCard(_ disclaimer: String, attribution: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Attribution", systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
            if let attr = attribution, !attr.isEmpty {
                Text(attr).font(.caption).foregroundStyle(.secondary).italic()
            }
            Text(disclaimer).font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { detailVM.toggleSave(ownerID: appVM.currentUserID, context: modelContext) } label: {
                Label(detailVM.isSaved ? "Saved" : "Save",
                      systemImage: detailVM.isSaved ? "bookmark.fill" : "bookmark")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(detailVM.isSaved ? Color.tint : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(detailVM.isSaved ? Color.tint.opacity(0.12) : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button { detailVM.addToMyPlan(ownerID: appVM.currentUserID, context: modelContext, vm: appVM) } label: {
                Group {
                    if detailVM.isAddingToPlan {
                        ProgressView().tint(.white)
                    } else {
                        Label(detailVM.addedToPlan ? "Added to Plan" : "Add to Plan",
                              systemImage: detailVM.addedToPlan ? "checkmark.circle.fill" : "plus.rectangle.on.rectangle")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(detailVM.addedToPlan ? Color.good : Color.tint)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(detailVM.isAddingToPlan || detailVM.addedToPlan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .alert("Couldn't Add to Plan", isPresented: Binding(
            get: { detailVM.addError != nil },
            set: { if !$0 { detailVM.addError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(detailVM.addError ?? "")
        }
    }
}

// MARK: - ViewModel

@MainActor
final class WorkoutDetailViewModel: ObservableObject {
    @Published var workout: WorkoutDetailAPIResponse?
    @Published var isSaved = false
    @Published var isLoading = false
    @Published var isAddingToPlan = false
    @Published var addedToPlan = false
    @Published var addError: String? = nil

    private struct SaveWorkoutBody: Encodable { let workoutId: String }
    private struct EmptySaveResponse: Decodable { let ok: Bool? }

    func load(workoutId: String, context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }
        workout = try? await ApiClient.shared.get("/library/workouts/\(workoutId)") as WorkoutDetailAPIResponse
        checkSaved(workoutId: workoutId, context: context)
    }

    func checkSaved(workoutId: String, context: ModelContext) {
        let id = workoutId
        let desc = FetchDescriptor<SavedLibraryWorkoutRecord>(predicate: #Predicate { $0.workoutID == id })
        isSaved = (try? context.fetch(desc))?.isEmpty == false
    }

    func toggleSave(ownerID: String, context: ModelContext) {
        guard let w = workout else { return }
        if isSaved {
            isSaved = false
            let id = w.id
            let desc = FetchDescriptor<SavedLibraryWorkoutRecord>(predicate: #Predicate { $0.workoutID == id })
            if let record = try? context.fetch(desc).first {
                context.delete(record)
                try? context.save()
            }
            Task { _ = try? await ApiClient.shared.delete("/library/saved/\(w.id)") as EmptySaveResponse }
        } else {
            isSaved = true
            let record = SavedLibraryWorkoutRecord(ownerID: ownerID, workoutID: w.id)
            context.insert(record)
            try? context.save()
            Task { _ = try? await ApiClient.shared.post("/library/saved", body: SaveWorkoutBody(workoutId: w.id)) as EmptySaveResponse }
        }
    }

    /// Builds the local split + one template per program day (up to 7 — `SplitDayPersistence`'s
    /// shape is a fixed 7-slot week). Network-free and synchronous so it's directly testable;
    /// `addToMyPlan` below is the thin async wrapper that calls this then pushes.
    ///
    /// Reuses `SplitDayPersistence.upsertDays` (the same day-persistence the split builder already
    /// uses) rather than a third split-construction path. Templates are created locally
    /// (`serverConfirmed: false`, the default) and left for `TemplatesView.reconcileUnconfirmed` —
    /// which already "runs on every load, so a template can never be stranded on-device" — to push;
    /// if the server assigns a different id, `TemplateIDRepointing` (built for exactly this) already
    /// re-points this split's day `templateID`s automatically. Not activated by default, matching
    /// the existing "blank Create Split just adds to My Splits, unactivated" convention — the lifter
    /// can hit Set as Active from My Splits once they've looked it over.
    @discardableResult
    func buildLocalSplit(ownerID: String, context: ModelContext) -> UserSplitRecord? {
        guard let w = workout, !w.days.isEmpty else { return nil }

        let dayLabels = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        var dayNames = Array(repeating: "", count: 7)
        var dayTemplateIDs = Array(repeating: "", count: 7)
        var dayIsRest = Array(repeating: true, count: 7)

        let orderedDays = w.days.sorted { $0.order_index < $1.order_index }
        for (i, day) in orderedDays.prefix(7).enumerated() {
            let template = WorkoutTemplateRecord(ownerID: ownerID, name: "\(w.creator_name): \(day.name)")
            context.insert(template)
            for ex in day.exercises {
                context.insert(TemplateExerciseRecord(
                    ownerID: ownerID, templateID: template.id, exerciseName: ex.exercise_name,
                    orderIndex: ex.order_index, targetSets: ex.sets ?? 3, targetReps: ex.reps ?? "8-10",
                    restSeconds: ex.rest_seconds ?? 90))
            }
            dayNames[i] = day.name
            dayTemplateIDs[i] = template.id
            dayIsRest[i] = false
        }

        let split = UserSplitRecord(ownerID: ownerID, name: w.title)
        context.insert(split)
        let indexToWeekday = [2, 3, 4, 5, 6, 7, 1]   // same convention as CreateSplitView.saveSplit()
        split.pinnedWeekdays = (0..<7).filter { !dayIsRest[$0] }.map { indexToWeekday[$0] }
        SplitDayPersistence.upsertDays(
            splitID: split.id, dayLabels: dayLabels, dayNames: dayNames,
            dayTemplateIDs: dayTemplateIDs, dayIsRest: dayIsRest,
            dayExercises: Array(repeating: [], count: 7),   // ad-hoc unused — every day is template-backed
            dayExcludedMuscles: Array(repeating: [], count: 7),
            existing: [], modelContext: context)
        try? context.save()
        return split
    }

    func addToMyPlan(ownerID: String, context: ModelContext, vm: AppViewModel) {
        guard let split = buildLocalSplit(ownerID: ownerID, context: context) else { return }
        isAddingToPlan = true
        Task {
            defer { isAddingToPlan = false }
            await vm.pushSplitToServer(split)
            addedToPlan = true
        }
    }
}

// MARK: - Workout Day Section

struct WorkoutDaySectionView: View {
    let day: WorkoutDayAPIResponse
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day \(day.day_number): \(day.name)")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        if let focus = day.focus, !focus.isEmpty {
                            Text(focus).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(day.exercises.count.pluralized("exercise"))
                        .font(.caption2).foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                ForEach(Array(day.exercises.enumerated()), id: \.offset) { i, ex in
                    ExerciseRowDetailView(exercise: ex)
                    if i < day.exercises.count - 1 { Divider().padding(.leading, 14) }
                }
                if let notes = day.notes, !notes.isEmpty {
                    Divider()
                    Text(notes)
                        .font(.caption).foregroundStyle(.secondary).italic()
                        .padding(.horizontal, 14).padding(.vertical, 8)
                }
            }
        }
        .elosCard()
    }
}

struct ExerciseRowDetailView: View {
    let exercise: WorkoutExerciseAPIResponse

    var body: some View {
        HStack(spacing: 10) {
            if let group = exercise.superset_group, exercise.is_superset == true {
                Text("\(group)")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.tint)
                    .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exercise_name).font(.subheadline)
                HStack(spacing: 6) {
                    if let sets = exercise.sets, let reps = exercise.reps {
                        Text("\(sets)×\(reps)").font(.caption2).foregroundStyle(.secondary)
                    }
                    if let rest = exercise.rest_seconds {
                        Text("· \(rest)s rest").font(.caption2).foregroundStyle(.secondary)
                    }
                    if let rpe = exercise.rpe_guidance, !rpe.isEmpty {
                        Text("· \(rpe)").font(.caption2).foregroundStyle(Color.tint)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}
