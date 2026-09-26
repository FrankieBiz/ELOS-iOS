import SwiftUI

/// Shared entry point for the priority-aware exercise sort (see `ExerciseOrderer.order(priority:)`).
/// Presents "Overall Best Growth" plus every `MuscleGroup`; both the template builder's per-workout
/// sort and the split builder's bulk "auto-order all days" action open this same menu so there's one
/// place that defines what a training priority *is*, not two menus that could drift apart.
struct PriorityMenu<Label: View>: View {
    let onSelect: (MuscleGroup?) -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Menu {
            Button("Overall Best Growth") { onSelect(nil) }
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                Button(group.displayName) { onSelect(group) }
            }
        } label: {
            label()
        }
    }
}
