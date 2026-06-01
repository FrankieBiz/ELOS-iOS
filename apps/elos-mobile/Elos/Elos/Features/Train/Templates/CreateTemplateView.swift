import SwiftUI
import SwiftData

// MARK: - TemplateExerciseEntry

struct TemplateExerciseEntry: Identifiable, Equatable {
    let id = UUID()
    var exerciseID: String?
    var exerciseName: String
    var equipmentId: String?        = nil
    var equipmentDedupeKey: String? = nil
    var equipmentBrandName: String? = nil
    var targetSets: Int    = 3
    var targetReps: String = "8-10"
    var targetRPE: Double  = 0
    var restSeconds: Int   = 90
    var notes: String      = ""

    static func == (lhs: TemplateExerciseEntry, rhs: TemplateExerciseEntry) -> Bool {
        lhs.exerciseName == rhs.exerciseName &&
        lhs.targetSets   == rhs.targetSets   &&
        lhs.targetReps   == rhs.targetReps   &&
        lhs.restSeconds  == rhs.restSeconds  &&
        lhs.notes        == rhs.notes
    }
}

// MARK: - Muscle group mapping + heuristic (internal — used module-wide)

let muscleKeyToLabel: [String: String] = [
    "chest": "Chest", "upper_chest": "Chest", "lower_chest": "Chest",
    "back": "Back", "lats": "Back", "rhomboids": "Back", "traps": "Back", "lower_traps": "Back",
    "shoulders": "Shoulders", "front_delts": "Shoulders", "side_delts": "Shoulders", "rear_delts": "Shoulders",
    "biceps": "Biceps", "brachialis": "Biceps",
    "triceps": "Triceps",
    "quads": "Quads",
    "hamstrings": "Hamstrings",
    "glutes": "Glutes", "adductors": "Glutes", "hip_abductors": "Glutes",
    "core": "Core", "obliques": "Core", "hip_flexors": "Core",
    "calves": "Calves"
]

let muscleDisplayOrder = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Core", "Calves"]

func resolveMuscleLabelHeuristic(for name: String) -> String? {
    let n = name.lowercased()
    let key: String
    if n.contains("bench") || n.contains("fly") || (n.contains("push") && !n.contains("pushdown")) { key = "chest" }
    else if n.contains("squat") || n.contains("leg press") || n.contains("lunge") || n.contains("extension") { key = "quads" }
    else if n.contains("deadlift") || n.contains("rdl") || (n.contains("curl") && n.contains("leg")) { key = "hamstrings" }
    else if n.contains("hip thrust") || n.contains("glute") { key = "glutes" }
    else if n.contains("pull") || n.contains("row") || n.contains("lat") { key = "lats" }
    else if n.contains("curl") && !n.contains("leg") { key = "biceps" }
    else if n.contains("tricep") || n.contains("pushdown") || n.contains("skull") { key = "triceps" }
    else if n.contains("overhead") || (n.contains("press") && n.contains("shoulder")) { key = "front_delts" }
    else if n.contains("lateral") || n.contains("side delt") { key = "side_delts" }
    else if n.contains("face pull") || n.contains("rear delt") { key = "rear_delts" }
    else if n.contains("calf") { key = "calves" }
    else if n.contains("plank") || n.contains("core") || n.contains("ab") { key = "core" }
    else { return nil }
    return muscleKeyToLabel[key]
}

func muscleGroupColor(for label: String) -> Color {
    switch label {
    case "Chest":      return Color.bad
    case "Back":       return Color(hex: "007AFF")
    case "Shoulders":  return Color.warn
    case "Biceps":     return Color(hex: "AF52DE")
    case "Triceps":    return Color(hex: "BF5AF2")
    case "Quads":      return Color(hex: "FFD60A")
    case "Hamstrings": return Color(hex: "FF9F0A")
    case "Glutes":     return Color(hex: "FF6369")
    case "Core":       return Color(hex: "32ADE6")
    case "Calves":     return Color.good
    default:           return Color.secondary
    }
}

// MARK: - MuscleGroupPanel

struct MuscleGroupPanel: View {
    let entries: [TemplateExerciseEntry]
    @Environment(\.modelContext) private var modelContext

    private var muscleSets: [(label: String, sets: Int)] {
        var counts: [String: Int] = [:]
        for entry in entries {
            guard let label = resolvedLabel(for: entry) else { continue }
            counts[label, default: 0] += entry.targetSets
        }
        return muscleDisplayOrder.compactMap { label in
            counts[label].map { (label, $0) }
        }
    }

    private func resolvedLabel(for entry: TemplateExerciseEntry) -> String? {
        if let exID = entry.exerciseID,
           let def = try? modelContext.fetch(
               FetchDescriptor<ExerciseDefinitionRecord>(predicate: #Predicate { $0.id == exID })
           ).first {
            return muscleKeyToLabel[def.primaryMuscle]
        }
        return resolveMuscleLabelHeuristic(for: entry.exerciseName)
    }

    var body: some View {
        if !muscleSets.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(muscleSets, id: \.label) { item in
                        let color = muscleGroupColor(for: item.label)
                        HStack(spacing: 5) {
                            Circle().fill(color).frame(width: 6, height: 6)
                            Text("\(item.label)  \(item.sets)×")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(color)
                        }
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(color.opacity(0.12))
                        .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 2).padding(.vertical, 2)
            }
        }
    }
}

// MARK: - MuscleGroupPanelWeekly

struct MuscleGroupPanelWeekly: View {
    let dayTemplateIDs: [String]
    let dayIsRest: [Bool]
    let dayExerciseNames: [[String]]
    @Environment(\.modelContext) private var modelContext

    private var muscleSets: [(label: String, sets: Int)] {
        var counts: [String: Int] = [:]
        for i in 0..<min(7, dayTemplateIDs.count) {
            guard !dayIsRest[i] else { continue }
            if !dayTemplateIDs[i].isEmpty {
                let tid = dayTemplateIDs[i]
                let desc = FetchDescriptor<TemplateExerciseRecord>(
                    predicate: #Predicate { $0.templateID == tid },
                    sortBy: [SortDescriptor(\.orderIndex)]
                )
                let exs = (try? modelContext.fetch(desc)) ?? []
                for ex in exs {
                    if let label = resolvedLabelFromRecord(ex) {
                        counts[label, default: 0] += ex.targetSets
                    }
                }
            }
            for name in dayExerciseNames[i] {
                if let label = resolveMuscleLabelHeuristic(for: name) {
                    counts[label, default: 0] += 3
                }
            }
        }
        return muscleDisplayOrder.compactMap { label in
            counts[label].map { (label, $0) }
        }
    }

    private func resolvedLabelFromRecord(_ ex: TemplateExerciseRecord) -> String? {
        if let exID = ex.exerciseID,
           let def = try? modelContext.fetch(
               FetchDescriptor<ExerciseDefinitionRecord>(predicate: #Predicate { $0.id == exID })
           ).first {
            return muscleKeyToLabel[def.primaryMuscle]
        }
        return resolveMuscleLabelHeuristic(for: ex.exerciseName)
    }

    var body: some View {
        if !muscleSets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("WEEKLY COVERAGE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(muscleSets, id: \.label) { item in
                            let color = muscleGroupColor(for: item.label)
                            HStack(spacing: 5) {
                                Circle().fill(color).frame(width: 6, height: 6)
                                Text("\(item.label)  \(item.sets)×")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(color)
                            }
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(color.opacity(0.12))
                            .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}

// MARK: - TemplateBuilderView

struct TemplateBuilderView: View {
    let initialName: String
    let initialEntries: [TemplateExerciseEntry]
    let isEditMode: Bool
    let onSave: (String, [TemplateExerciseEntry]) -> Void

    init(initialName: String = "",
         initialEntries: [TemplateExerciseEntry] = [],
         isEditMode: Bool = false,
         onSave: @escaping (String, [TemplateExerciseEntry]) -> Void) {
        self.initialName    = initialName
        self.initialEntries = initialEntries
        self.isEditMode     = isEditMode
        self.onSave         = onSave
    }

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var exercises: [TemplateExerciseEntry] = []
    @State private var showAddExercise = false
    @State private var showDiscardAlert = false
    @State private var isDirty = false
    @State private var snapshotName = ""
    @State private var snapshotExercises: [TemplateExerciseEntry] = []

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
    }

    private var estimatedMinutes: Int {
        exercises.reduce(0) { $0 + ($1.targetSets * ($1.restSeconds + 45)) } / 60
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    // Name + duration header
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField(isEditMode ? "Template name" : "Name your template", text: $name)
                                .font(.system(size: 26, weight: .bold))
                                .submitLabel(.done)

                            if !exercises.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("~\(estimatedMinutes) min")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 12, leading: 20, bottom: 4, trailing: 20))
                    }

                    // Muscle panel
                    if !exercises.isEmpty {
                        Section {
                            MuscleGroupPanel(entries: exercises)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(.init(top: 4, leading: 20, bottom: 8, trailing: 20))
                        }
                    }

                    // Exercise cards
                    ForEach($exercises) { $ex in
                        ExerciseCard(entry: $ex) {
                            withAnimation(.spring(response: 0.3)) {
                                exercises.removeAll { $0.id == ex.id }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 5, leading: 16, bottom: 5, trailing: 16))
                    }
                    .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }

                    // Spacer so cards don't hide behind add button
                    Section {
                        Color.clear.frame(height: 90)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .environment(\.editMode, .constant(.active))

                // Floating Add Exercise button
                Button {
                    showAddExercise = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Add Exercise")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Color.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.tint.opacity(0.35), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle(exercises.isEmpty ? (isEditMode ? "Edit Template" : "New Template") : "")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isDirty)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if isDirty { showDiscardAlert = true } else { dismiss() }
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        guard canSave else { return }
                        onSave(name.trimmingCharacters(in: .whitespaces), exercises)
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(canSave ? .white : Color.secondary)
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(canSave ? Color.tint : Color(.tertiarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showAddExercise) {
                ExercisePickerView(onConfirmMulti: { picked in
                    withAnimation(.spring(response: 0.35)) {
                        for ex in picked {
                            if !exercises.contains(where: { $0.exerciseID == ex.id || $0.exerciseName == ex.name }) {
                                exercises.append(TemplateExerciseEntry(
                                    exerciseID:         ex.id,
                                    exerciseName:       ex.name,
                                    equipmentId:        ex.equipmentId,
                                    equipmentDedupeKey: ex.equipmentDedupeKey,
                                    equipmentBrandName: ex.equipmentBrandName
                                ))
                            }
                        }
                    }
                    showAddExercise = false
                })
            }
            .alert("Discard Changes?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your unsaved changes will be lost.")
            }
            .onAppear {
                name      = initialName
                exercises = initialEntries
                snapshotName      = initialName
                snapshotExercises = initialEntries
                isDirty = false
            }
            .onChange(of: name)      { _, _ in updateDirty() }
            .onChange(of: exercises) { _, _ in updateDirty() }
        }
    }

    private func updateDirty() {
        isDirty = name != snapshotName || exercises != snapshotExercises
    }
}

// MARK: - ExerciseCard

private struct ExerciseCard: View {
    @Binding var entry: TemplateExerciseEntry
    let onDelete: () -> Void

    @State private var showNoteField: Bool

    init(entry: Binding<TemplateExerciseEntry>, onDelete: @escaping () -> Void) {
        _entry = entry
        _showNoteField = State(initialValue: !entry.wrappedValue.notes.isEmpty)
        self.onDelete = onDelete
    }

    private var accentColor: Color {
        muscleGroupColor(for: resolveMuscleLabelHeuristic(for: entry.exerciseName) ?? "")
    }

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .padding(.vertical, 16)

            VStack(alignment: .leading, spacing: 14) {
                // Header: name + delete
                HStack(spacing: 10) {
                    Text(entry.exerciseName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                // Steppers row
                HStack(spacing: 0) {
                    numericStepper(
                        label: "SETS",
                        value: $entry.targetSets,
                        min: 1, max: 10, step: 1,
                        display: "\(entry.targetSets)"
                    )
                    Spacer()
                    repsControl
                    Spacer()
                    numericStepper(
                        label: "REST",
                        value: $entry.restSeconds,
                        min: 0, max: 600, step: 15,
                        display: formatRest(entry.restSeconds)
                    )
                }

                // Notes
                notesRow
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var repsControl: some View {
        VStack(spacing: 6) {
            Text("REPS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            TextField("8-10", text: $entry.targetReps)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .keyboardType(.numbersAndPunctuation)
                .frame(width: 72)
                .padding(.vertical, 9)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func numericStepper(label: String, value: Binding<Int>, min: Int, max: Int, step: Int, display: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            HStack(spacing: 10) {
                Button {
                    if value.wrappedValue - step >= min { value.wrappedValue -= step }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text(display)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .frame(minWidth: 44, alignment: .center)

                Button {
                    if value.wrappedValue + step <= max { value.wrappedValue += step }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.tint)
                        .frame(width: 30, height: 30)
                        .background(Color.tint.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var notesRow: some View {
        if showNoteField {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.tint)
                    .padding(.top, 2)
                TextField("e.g. Slow eccentric, touch chest…", text: $entry.notes, axis: .vertical)
                    .font(.system(size: 13))
                    .lineLimit(1...3)
                Button {
                    entry.notes = ""
                    showNoteField = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { showNoteField = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: entry.notes.isEmpty ? "text.bubble" : "text.bubble.fill")
                        .font(.system(size: 11))
                    Text(entry.notes.isEmpty ? "Add note" : entry.notes)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                .foregroundStyle(entry.notes.isEmpty ? Color.secondary : Color.tint)
            }
            .buttonStyle(.plain)
        }
    }

    private func formatRest(_ seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60)m\(seconds % 60 == 0 ? "" : "\(seconds % 60)s")" : "\(seconds)s"
    }
}
