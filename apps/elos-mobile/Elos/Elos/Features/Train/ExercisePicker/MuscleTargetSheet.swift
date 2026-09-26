import SwiftUI

/// Lets the lifter say what a movement actually trains.
///
/// Two jobs. The obvious one is correcting a wrong guess — a back-extension machine that reported no
/// lower-back work. The subtler one is machines that genuinely do more than one thing: a Pec/Rear Delt
/// station is a chest fly *or* a reverse fly, and only the person who sat in it knows which. Those
/// arrive with a Movement row so the whole answer is one tap.
struct MuscleTargetSheet: View {
    let title: String
    /// Preset movements this machine supports. Shown as one-tap choices when there's more than one.
    let movements: [MachineMovement]
    /// Muscles worth showing without expanding the full list — from the machine's spec and name.
    let suggested: [FineMuscle]
    /// What's being credited right now, however that was arrived at.
    let initial: MuscleTargets
    /// `nil` means "go back to working it out automatically".
    let onSave: (MuscleTargets?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var targets: MuscleTargets = MuscleTargets()
    @State private var showAllMuscles = false

    /// Build for a machine-backed exercise: presets and options come from the equipment database.
    init(title: String, record: EquipmentRecord?, initial: MuscleTargets,
         onSave: @escaping (MuscleTargets?) -> Void) {
        self.title = title
        self.movements = record.map { EquipmentMuscleMap.movements(for: $0) } ?? []
        // Whatever is already credited stays visible even if the machine's spec never mentioned it,
        // so a saved choice can always be un-ticked.
        let fromRecord = record.map { EquipmentMuscleMap.options(for: $0) } ?? []
        let pool = Set(fromRecord).union(initial.all)
        self.suggested = FineMuscle.allCases.filter { pool.contains($0) }
        self.initial = initial
        self.onSave = onSave
    }

    private var shownMuscles: [FineMuscle] {
        showAllMuscles || suggested.isEmpty ? FineMuscle.allCases : suggested
    }

    private var hasPresets: Bool { movements.count > 1 }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Sets count in full for muscles you mark as worked directly, and half for the ones you mark as assisting. This is what the coverage bars read.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                if hasPresets {
                    Section {
                        ForEach(movements) { m in
                            Button {
                                HapticManager.impact(.light)
                                withAnimation(.elosEmphasis) { targets = m.targets }
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(m.label)
                                            .font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                        Text(m.targets.summary)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if targets == m.targets {
                                        Image(systemName: "checkmark")
                                            .font(.system(.footnote, weight: .bold))
                                            .foregroundStyle(Color.tint)
                                    }
                                }
                                // Without this the row only responds on the text itself — a plain
                                // button's label doesn't hit-test its own empty Spacer.
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Which movement did you do?")
                    } footer: {
                        Text("This machine works more than one muscle group. Pick the movement, or set the muscles yourself below.")
                    }
                }

                Section {
                    ForEach(shownMuscles, id: \.self) { m in
                        muscleRow(m)
                    }
                } header: {
                    HStack {
                        Text("Muscles worked")
                        Spacer()
                        if !suggested.isEmpty {
                            Button(showAllMuscles ? "Suggested only" : "Show all") {
                                withAnimation { showAllMuscles.toggle() }
                            }
                            .font(.caption2)
                            .textCase(nil)
                        }
                    }
                } footer: {
                    // With nothing ticked, Done sends no override — which means "work it out
                    // automatically", not "trains nothing". The previous wording claimed the latter,
                    // so the sheet contradicted what saving it actually did.
                    Text(targets.isEmpty
                         ? "Nothing ticked — the muscles will be worked out automatically."
                         : "Direct: \(labelList(targets.primary))\(targets.secondary.isEmpty ? "" : "  ·  Assisting: \(labelList(targets.secondary))")")
                }

                Section {
                    // Not red: in iOS red means destructive and hard to undo. Reverting to automatic
                    // discards nothing you can't re-tick in a second.
                    Button("Reset to automatic") {
                        onSave(nil)
                        dismiss()
                    }
                    .foregroundStyle(Color.tint)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(targets.isEmpty ? nil : targets)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { targets = initial }
        }
    }

    /// One muscle, with its two independent states. Separate controls rather than a cycling tap:
    /// "does this train my lower back, and how much" is two questions, and a tri-state toggle makes
    /// the second one invisible.
    private func muscleRow(_ m: FineMuscle) -> some View {
        let isPrimary = targets.primary.contains(m)
        let isSecondary = targets.secondary.contains(m)
        return HStack(spacing: 10) {
            Button {
                HapticManager.impact(.light)
                targets = targets.togglingPrimary(m)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isPrimary ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isPrimary ? Color.tint : Color.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text(m.group.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                // Whole row left of "Assists" toggles direct — see the note on the preset rows.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                HapticManager.impact(.light)
                targets = targets.togglingSecondary(m)
            } label: {
                Text("Assists")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(isSecondary ? .white : Color.secondary)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(isSecondary ? Color.tint : Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(m.displayName) assists")
            .accessibilityAddTraits(isSecondary ? [.isSelected] : [])
        }
        .padding(.vertical, 2)
    }

    private func labelList(_ ms: [FineMuscle]) -> String {
        ms.isEmpty ? "none" : ms.map(\.displayName).joined(separator: ", ")
    }
}
