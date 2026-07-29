import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var vm: AppViewModel
    @Query(sort: \ExerciseDefinitionRecord.name) private var exerciseDefs: [ExerciseDefinitionRecord]

    let session: WorkoutSessionRecord

    @State private var sets: [ExerciseSetRecord] = []
    @State private var showSaveAsTemplate = false

    private var durationText: String {
        guard let finished = session.finishedAt else { return "—" }
        let mins = Int(finished.timeIntervalSince(session.startedAt) / 60)
        return "\(mins) min"
    }

    private var grouped: [(exercise: String, sets: [ExerciseSetRecord])] {
        let dict = Dictionary(grouping: sets, by: { $0.exerciseName })
        return dict.sorted { $0.key < $1.key }
            .map { (exercise: $0.key, sets: $0.value.sorted { $0.setIndex < $1.setIndex }) }
    }

    // MARK: - Save as Template

    /// Only genuinely completed sets count toward a template — a session can carry a stray
    /// unfinished row (e.g. an abandoned last exercise) that shouldn't shape the target scheme.
    private var doneSets: [ExerciseSetRecord] { sets.filter { $0.isDone } }

    /// Exercises in the order they were first performed. `grouped` sorts alphabetically for
    /// display, but a template should read like the workout did.
    ///
    /// Ordering by `setIndex` (as fetched) doesn't work here: it restarts at 0 for every
    /// exercise, so every exercise's first set ties at the same value and a plain sort produces
    /// an effectively arbitrary interleaving rather than performed order. `completedAt` is set on
    /// every set the moment it's logged (`TrainViewModel.swift`) and is the real chronological
    /// signal — sort exercises by the earliest `completedAt` among their sets.
    private var performedOrder: [String] {
        let byExercise = Dictionary(grouping: doneSets, by: \.exerciseName)
        return byExercise.keys.sorted {
            let a = byExercise[$0]!.compactMap(\.completedAt).min() ?? .distantFuture
            let b = byExercise[$1]!.compactMap(\.completedAt).min() ?? .distantFuture
            return a < b
        }
    }

    private var templateEntries: [TemplateExerciseEntry] {
        let byNormalizedName = Dictionary(exerciseDefs.map { (MuscleTaxonomy.normalize($0.name), $0) },
                                          uniquingKeysWith: { a, _ in a })

        return performedOrder.compactMap { name -> TemplateExerciseEntry? in
            let exSets = doneSets.filter { $0.exerciseName == name }.sorted { $0.setIndex < $1.setIndex }
            guard let first = exSets.first else { return nil }

            let reps = exSets.map(\.reps)
            let minReps = reps.min() ?? 0
            let maxReps = reps.max() ?? 0
            // No reps logged at all (unlikely, but possible for a weight-only custom entry) —
            // fall back to the same default a fresh template row starts with.
            let repsText: String = maxReps <= 0 ? "8-10"
                : minReps == maxReps ? "\(minReps)" : "\(minReps)-\(maxReps)"

            let loggedRPEs = exSets.compactMap { $0.rpe > 0 ? $0.rpe : nil }
            let avgRPE = loggedRPEs.isEmpty ? 0
                : ((loggedRPEs.reduce(0, +) / Double(loggedRPEs.count)) * 2).rounded() / 2

            let def = byNormalizedName[MuscleTaxonomy.normalize(name)]

            return TemplateExerciseEntry(
                exerciseID: def?.id,
                exerciseName: name,
                equipmentId: first.equipmentId,
                equipmentDedupeKey: first.equipmentDedupeKey,
                equipmentBrandName: first.equipmentBrandName,
                targetSets: exSets.count,
                targetReps: repsText,
                targetRPE: avgRPE
            )
        }
    }

    private var suggestedTemplateName: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: session.startedAt)) Workout"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsCard
                ForEach(grouped, id: \.exercise) { group in
                    exerciseCard(group)
                }
            }
            .padding(16).padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSaveAsTemplate = true
                } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .disabled(doneSets.isEmpty)
                .accessibilityLabel("Save as Template")
            }
        }
        .sheet(isPresented: $showSaveAsTemplate) {
            TemplateBuilderView(
                initialName: suggestedTemplateName,
                initialEntries: templateEntries
            ) { name, entries, intent in
                let templatesVM = TemplatesViewModel(context: modelContext)
                templatesVM.createTemplate(name: name, exercises: entries,
                                           ownerID: vm.currentUserID, intent: intent)
            }
        }
        .onAppear { loadSets() }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(value: durationText, label: "Duration")
            Divider().frame(height: 40)
            statItem(value: vm.weightUnit.formatVolume(kg: session.totalVolume), label: "Volume")
            Divider().frame(height: 40)
            statItem(value: session.sessionRPE > 0 ? "\(session.sessionRPE)" : "—", label: "Session RPE")
        }
        .padding(16)
        .elosCard()
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseCard(_ group: (exercise: String, sets: [ExerciseSetRecord])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.exercise)
                .font(.subheadline).fontWeight(.semibold)
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            Divider()
            HStack {
                Text("#").frame(width: 24)
                Text("Weight (\(vm.weightUnit.label))").frame(maxWidth: .infinity)
                Text("Reps").frame(width: 50)
                Text("RPE").frame(width: 40)
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.vertical, 6)

            ForEach(group.sets) { s in
                HStack {
                    Text("\(s.setIndex + 1)").font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 24)
                    Text(vm.weightUnit.formatValue(kg: s.weightKg)).font(.system(size: 14, design: .monospaced)).frame(maxWidth: .infinity)
                    Text("\(s.reps)").font(.system(size: 14, design: .monospaced)).frame(width: 50)
                    Text(s.rpe > 0 ? String(format: "%.1f", s.rpe) : "—")
                        .font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 40)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                Divider().padding(.leading, 14)
            }
        }
        .elosCard()
    }

    private func loadSets() {
        let sessionID = session.id
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.setIndex)]
        )
        sets = (try? modelContext.fetch(desc)) ?? []
    }
}
