import SwiftUI

/// One exercise inside the active session, restructured around a **single active-set focus block**:
/// the current set gets large controls, a tap RPE ladder, and tap-to-fill chips; completed sets
/// collapse to compact locked summaries (edited in place, never via the destructive un-log path);
/// upcoming sets are dimmed. Muscle chrome is demoted behind an ⓘ toggle.
struct SessionExerciseCard: View {
    @Binding var exercise: Exercise
    let isDone: Bool
    let isActive: Bool
    let doneCount: Int
    let overloadSuggestion: String?
    let overloadTarget: (weightKg: Double, reps: Int)?
    let previousSets: [ExerciseSetRecord]
    let unit: WeightUnit
    let onSelect: () -> Void
    let onSetToggle: (Int) -> Void
    let onSetDelete: (Int) -> Void
    let onSetEdit: (Int, Double, Int, Double) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var expanded = true
    @State private var showingSwap = false
    @State private var showInfo = false
    @State private var howTo: ExerciseHowTo?
    @State private var showHowTo = false
    @State private var editingIndex: Int?
    @State private var editSnapshot: (weight: String, reps: String, rpe: String)?
    @State private var editError = false
    @FocusState private var focusedField: FocusableField?

    private enum FocusableField: Hashable { case weight, reps }

    /// First not-yet-logged set — the one in focus.
    private var activeIndex: Int? { exercise.sets.firstIndex { !$0.done } }

    var body: some View {
        VStack(spacing: 0) {
            header
            if expanded {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    if showInfo { muscleCaption }
                    if let suggestion = overloadSuggestion {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill").font(.caption).foregroundStyle(Color.good)
                            Text(suggestion).font(.caption).fontWeight(.semibold).foregroundStyle(Color.good)
                        }
                    }
                    ForEach(exercise.sets.indices, id: \.self) { i in
                        rowContent(i)
                    }
                    footer
                }
                .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 12)
            }
        }
        .elosCard()
        .onAppear {
            if howTo == nil {
                howTo = ExerciseHowToLookup.find(name: exercise.name, in: modelContext)
            }
        }
        .sheet(isPresented: $showingSwap) {
            ExerciseSwapSheet(exerciseName: $exercise.name)
        }
        .sheet(isPresented: $showHowTo) {
            if let howTo { ExerciseHowToSheet(howTo: howTo) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(focusedField == .weight ? "Next" : "Done") {
                    if focusedField == .weight { focusedField = .reps } else { focusedField = nil }
                }
                .fontWeight(.semibold)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                onSelect()
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(isDone ? Color.good : isActive ? Color.tint : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                    Text(exercise.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(doneCount)/\(exercise.sets.count) sets")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
            .buttonStyle(.plain)

            Button {
                if howTo != nil {
                    HapticManager.impact(.light)
                    showHowTo = true
                } else {
                    withAnimation { showInfo.toggle() }
                }
            } label: {
                Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var muscleCaption: some View {
        Text("Primary: \(exercise.primaryMuscle)" +
             (exercise.secondaryMuscles.isEmpty ? "" : " · secondary: \(exercise.secondaryMuscles.prefix(2).joined(separator: ", "))"))
            .font(.caption).foregroundStyle(.secondary)
    }

    // MARK: Row dispatch

    @ViewBuilder private func rowContent(_ i: Int) -> some View {
        if editingIndex == i {
            entryBlock(i, mode: .edit)
        } else if exercise.sets[i].done {
            loggedRow(i)
        } else if i == activeIndex && editingIndex == nil {
            entryBlock(i, mode: .active)
        } else {
            upcomingRow(i)
        }
    }

    // MARK: Logged (locked) row

    private func loggedRow(_ i: Int) -> some View {
        let s = exercise.sets[i]
        let rpePart = RPEScale.parse(s.rpe).map { "  @\(RPEScale.label($0))" } ?? ""
        let weightPart = s.weight.isEmpty ? "—" : s.weight
        return HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundStyle(Color.good)
            Text("\(i + 1)").font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 16)
            Text("\(weightPart) \(unit.label) × \(s.reps.isEmpty ? "—" : s.reps)\(rpePart)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
            Spacer()
            Button {
                beginEditing(i)
            } label: {
                Image(systemName: "pencil").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.tint)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.good.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button { beginEditing(i) } label: { Label("Edit set", systemImage: "pencil") }
            Button(role: .destructive) { onSetToggle(i) } label: { Label("Uncomplete", systemImage: "arrow.uturn.backward") }
        }
    }

    // MARK: Upcoming (dim) row

    private func upcomingRow(_ i: Int) -> some View {
        let s = exercise.sets[i]
        let planned = (s.weight.isEmpty && s.reps.isEmpty) ? "— — —" : "\(s.weight.isEmpty ? "—" : s.weight) × \(s.reps.isEmpty ? "—" : s.reps)"
        return HStack(spacing: 10) {
            Text("\(i + 1)").font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 16)
            Text(planned).font(.system(size: 13, design: .rounded)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .opacity(0.5)
        .contextMenu {
            Button(role: .destructive) { onSetDelete(i) } label: { Label("Delete set", systemImage: "trash") }
        }
    }

    // MARK: Active / edit entry block

    private enum EntryMode { case active, edit }

    private func entryBlock(_ i: Int, mode: EntryMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SET \(i + 1) OF \(exercise.sets.count)")
                    .font(.caption2).fontWeight(.bold).foregroundStyle(Color.tint)
                Spacer()
                if mode == .edit {
                    Text("Editing").font(.caption2).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                fieldColumn(
                    label: exercise.supportsAddedWeight ? "+WT (\(unit.label))" : "WEIGHT (\(unit.label))",
                    placeholder: weightPlaceholder(i),
                    text: $exercise.sets[i].weight,
                    keyboard: .decimalPad,
                    field: .weight
                )
                fieldColumn(
                    label: "REPS",
                    placeholder: repsPlaceholder(i),
                    text: $exercise.sets[i].reps,
                    keyboard: .numberPad,
                    field: .reps,
                    width: 86
                )
            }

            RPEEffortLadder(rpe: $exercise.sets[i].rpe)

            if mode == .active {
                fillChips(i)
                Button {
                    focusedField = nil
                    onSetToggle(i)
                } label: {
                    Label("Complete set", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.good)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else {
                if editError {
                    Text("Enter reps before saving.").font(.caption2).foregroundStyle(Color.bad)
                }
                HStack(spacing: 10) {
                    Button { cancelEditing(i) } label: {
                        Text("Cancel").font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color(.tertiarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    Button { saveEditing(i) } label: {
                        Text("Save").font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.tint).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background((mode == .edit ? Color.tint : Color.tint).opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.tint.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            if mode == .active {
                Button(role: .destructive) { onSetDelete(i) } label: { Label("Delete set", systemImage: "trash") }
            }
        }
    }

    private func fieldColumn(label: String, placeholder: String, text: Binding<String>,
                             keyboard: UIKeyboardType, field: FocusableField, width: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            TextField(placeholder, text: text)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .keyboardType(keyboard)
                .focused($focusedField, equals: field)
                .padding(.vertical, 10)
                .frame(maxWidth: width == nil ? .infinity : nil)
                .frame(width: width)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: width == nil ? .infinity : nil)
    }

    // MARK: Tap-to-fill chips

    @ViewBuilder private func fillChips(_ i: Int) -> some View {
        HStack(spacing: 8) {
            if let pw = prevWeightDisplay(i), let pr = prevReps(i) {
                fillChip(icon: "arrow.counterclockwise", text: "\(pw)×\(pr)") {
                    exercise.sets[i].weight = pw
                    exercise.sets[i].reps = "\(pr)"
                    HapticManager.selection()
                }
            }
            if let target = overloadTarget {
                let tw = unit.formatValue(kg: target.weightKg)
                fillChip(icon: "arrow.up.forward", text: "\(unit.formatWeight(kg: target.weightKg))") {
                    exercise.sets[i].weight = tw
                    exercise.sets[i].reps = "\(target.reps)"
                    HapticManager.selection()
                }
            }
            Spacer()
        }
    }

    private func fillChip(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(text).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.tint)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.tintSoft)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                let last = exercise.sets.last
                exercise.sets.append(WorkSet(weight: last?.weight ?? "", reps: last?.reps ?? "", rpe: "", done: false))
            } label: {
                Label("Add set", systemImage: "plus").font(.caption).foregroundStyle(Color.tint)
            }
            .buttonStyle(.plain)

            if let a = activeIndex, hasCopyableTarget(a) {
                Button { copyToRemaining(from: a) } label: {
                    Label("Copy to remaining", systemImage: "arrow.down.doc").font(.caption).foregroundStyle(Color.tint)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button { showingSwap = true } label: {
                Label("Swap", systemImage: "arrow.left.arrow.right").font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    // MARK: Placeholders / previous-set lookups

    private func weightPlaceholder(_ i: Int) -> String {
        if let pw = prevWeightDisplay(i) { return pw }
        return exercise.supportsAddedWeight ? "+0" : unit.label
    }
    private func repsPlaceholder(_ i: Int) -> String {
        if let pr = prevReps(i) { return "\(pr)" }
        return "reps"
    }
    private func prevWeightDisplay(_ i: Int) -> String? {
        i < previousSets.count ? unit.formatValue(kg: previousSets[i].weightKg) : nil
    }
    private func prevReps(_ i: Int) -> Int? {
        i < previousSets.count ? previousSets[i].reps : nil
    }

    // MARK: Copy-down

    private func hasCopyableTarget(_ a: Int) -> Bool {
        guard !exercise.sets[a].weight.isEmpty || !exercise.sets[a].reps.isEmpty else { return false }
        return exercise.sets.indices.contains { $0 != a && !exercise.sets[$0].done }
    }
    private func copyToRemaining(from a: Int) {
        let w = exercise.sets[a].weight, r = exercise.sets[a].reps
        for j in exercise.sets.indices where j != a && !exercise.sets[j].done {
            exercise.sets[j].weight = w
            exercise.sets[j].reps = r
        }
        HapticManager.selection()
    }

    // MARK: Inline edit lifecycle

    private func beginEditing(_ i: Int) {
        editSnapshot = (exercise.sets[i].weight, exercise.sets[i].reps, exercise.sets[i].rpe)
        editError = false
        withAnimation { editingIndex = i }
    }
    private func cancelEditing(_ i: Int) {
        if let snap = editSnapshot {
            exercise.sets[i].weight = snap.weight
            exercise.sets[i].reps = snap.reps
            exercise.sets[i].rpe = snap.rpe
        }
        editSnapshot = nil
        editError = false
        focusedField = nil
        withAnimation { editingIndex = nil }
    }
    private func saveEditing(_ i: Int) {
        let weightVal = max(0, Double(exercise.sets[i].weight) ?? 0)
        let weightKg = unit.toKg(weightVal)
        let reps = Int(exercise.sets[i].reps) ?? 0
        // Mirror the completion guard — never save a zeroed-out set.
        guard reps > 0 else { editError = true; return }
        let rpe = min(10, max(0, Double(exercise.sets[i].rpe) ?? 0))
        // Normalize the WorkSet strings so the locked row matches the persisted/synced record.
        exercise.sets[i].weight = unit.formatValue(kg: weightKg)
        exercise.sets[i].reps = String(reps)
        exercise.sets[i].rpe = rpe > 0 ? RPEScale.label(rpe) : ""
        editSnapshot = nil
        editError = false
        focusedField = nil
        withAnimation { editingIndex = nil }
        onSetEdit(i, weightKg, reps, rpe)
    }
}
