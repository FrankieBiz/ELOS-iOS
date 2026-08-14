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
    @Environment(\.dismiss) private var dismiss
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

    /// Shared by the suggestion-tap path and the manual picker's `onPickSingle` — same duplicate
    /// check, same adopt call, same dismiss-on-success. Adopting used to silently no-op from the
    /// suggestions list because nothing ever dismissed the sheet; unifying here means both paths
    /// behave identically instead of drifting.
    private func tryAdopt(_ picked: PickedExercise) {
        if existingNames.contains(picked.name) {
            duplicateName = picked.name
            return
        }
        exercise.adopt(picked, in: modelContext)
        dismiss()
    }

    /// Suggestion panel content, or nothing when there's nothing to suggest. Built as `AnyView` to
    /// match `ExercisePickerView.topContent`'s erased signature.
    private func suggestionsPanel(_ suggestions: [SubstitutionSuggestion]) -> AnyView {
        guard !suggestions.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Suggested for you")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    EvidenceBadge(topic: .exerciseSubstitution)
                }
                ForEach(suggestions) { suggestion in
                    Button {
                        tryAdopt(PickedExercise(id: suggestion.id, name: suggestion.name))
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
        )
    }

    var body: some View {
        // Evaluated once per body pass rather than once for the emptiness check and again inside
        // the panel builder.
        let suggestions = suggestions
        ExercisePickerView(
            onPickSingle: { picked in tryAdopt(picked) },
            topContent: { suggestionsPanel(suggestions) }
        )
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
