import SwiftUI
import SwiftData

/// Thin wrapper around `ExercisePickerView` for the in-session "swap exercise" use case.
///
/// Binds the whole `Exercise`, not just its name. Assigning the name alone left the swapped-in lift
/// wearing the old one's identity — its machine (which drives PR detection, previous-sets and the
/// progressive-overload target), its muscles, and its weight semantics. See `Exercise.adopt(_:in:)`.
struct ExerciseSwapSheet: View {
    @Binding var exercise: Exercise
    /// Names of every *other* exercise already in this session/template — swapping into one of
    /// these would collide, since logged sets are keyed by exercise name, not instance id.
    var existingNames: [String] = []
    @Environment(\.modelContext) private var modelContext
    @State private var duplicateName: String?

    @Query(sort: \ExerciseDefinitionRecord.name) private var dbExercises: [ExerciseDefinitionRecord]
    @Query private var profiles: [UserProfileRecord]

    private var equipmentPreference: EquipmentPreference { profiles.first?.equipmentPreference ?? .fullGym }

    private var suggestions: [SubstitutionSuggestion] {
        let candidates = dbExercises.map(ExerciseCandidate.init(record:))
        guard let source = ExerciseSubstitutionEngine.resolveSource(name: exercise.name, candidates: candidates) else {
            return []
        }
        return ExerciseSubstitutionEngine.suggest(for: source, candidates: candidates, equipment: equipmentPreference)
    }

    private func adopt(_ suggestion: SubstitutionSuggestion) {
        if existingNames.contains(suggestion.name) {
            duplicateName = suggestion.name
            return
        }
        exercise.adopt(PickedExercise(id: suggestion.id, name: suggestion.name), in: modelContext)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Suggested for you")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        EvidenceBadge(topic: .exerciseSubstitution)
                    }
                    ForEach(suggestions) { suggestion in
                        Button {
                            adopt(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.name)
                                    .font(.body.weight(.medium))
                                Text(suggestion.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    Text("Or choose manually")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
            }

            ExercisePickerView(onPickSingle: { picked in
                if existingNames.contains(picked.name) {
                    duplicateName = picked.name
                    return
                }
                exercise.adopt(picked, in: modelContext)
            })
        }
        .alert("Already in this workout", isPresented: Binding(
            get: { duplicateName != nil },
            set: { if !$0 { duplicateName = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(duplicateName ?? "That exercise") is already part of this session.")
        }
    }
}
