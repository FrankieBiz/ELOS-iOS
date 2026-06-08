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
                    Text("Could not load workout.").foregroundStyle(.secondary).padding(.top, 40)
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

            Button { detailVM.addToMyPlan() } label: {
                Label("Add to Plan", systemImage: "plus.rectangle.on.rectangle")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - ViewModel

@MainActor
final class WorkoutDetailViewModel: ObservableObject {
    @Published var workout: WorkoutDetailAPIResponse?
    @Published var isSaved = false
    @Published var isLoading = false

    private struct SaveWorkoutBody: Encodable { let workoutId: String }
    private struct EmptySaveResponse: Decodable { let ok: Bool? }
    private struct CreateTemplateForkRequest: Encodable {
        let name: String
        let exercises: [TemplateExForkRequest]
    }
    private struct TemplateExForkRequest: Encodable {
        let exercise_name: String
        let order_index: Int
        let target_sets: Int
        let target_reps: String
        let target_rpe: Double?
        let rest_seconds: Int
    }
    private struct ForkTemplateResponse: Decodable { let id: String }

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

    func addToMyPlan() {
        guard let w = workout, let firstDay = w.days.first else { return }
        let exercises = firstDay.exercises.map { ex in
            TemplateExForkRequest(
                exercise_name: ex.exercise_name,
                order_index: ex.order_index,
                target_sets: ex.sets ?? 3,
                target_reps: ex.reps ?? "8-10",
                target_rpe: nil,
                rest_seconds: ex.rest_seconds ?? 90
            )
        }
        Task {
            _ = try? await ApiClient.shared.post(
                "/templates",
                body: CreateTemplateForkRequest(name: "\(w.creator_name): \(firstDay.name)", exercises: exercises)
            ) as ForkTemplateResponse
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
                    Text("\(day.exercises.count) exercises")
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
