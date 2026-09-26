import SwiftUI

/// Lets the lifter say "I'm not training this muscle here" for one day/template — the coach never
/// nags about a gap that's intentional. Grouped by `MuscleGroup`, live-editing straight into the
/// bound `Set<FineMuscle>` (no separate Save step, same philosophy as `VolumeTargetsView`'s
/// `GroupTargetEditor`: edits apply immediately).
///
/// Button rows with a checkmark, deliberately not `Toggle` — mirrors `MuscleTargetSheet`, the proven
/// working pattern for "pick several muscles from a grouped list" in this codebase. A `Toggle` inside
/// a `List` in a very similar sheet context (`VolumeTargetsView.GroupTargetEditor`) has previously
/// failed to fire at all.
struct SkipMusclesSheet: View {
    @Binding var selection: Set<FineMuscle>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Muscles checked here are left out of this day's coverage checks and quality score — use it for muscles you're training on a different day, or not training at all on purpose.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    Section(group.displayName) {
                        ForEach(group.children, id: \.self) { muscle in
                            muscleRow(muscle)
                        }
                    }
                }
            }
            .navigationTitle("Skip Muscles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func muscleRow(_ m: FineMuscle) -> some View {
        let isOn = selection.contains(m)
        return Button {
            HapticManager.impact(.light)
            if isOn { selection.remove(m) } else { selection.insert(m) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.tint : Color.secondary)
                Text(m.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
