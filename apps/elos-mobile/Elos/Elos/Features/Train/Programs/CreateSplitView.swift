import SwiftUI
import SwiftData


struct CreateSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplateRecord.name) private var templates: [WorkoutTemplateRecord]
    @Query(sort: \ExerciseDefinitionRecord.name) private var exerciseDefs: [ExerciseDefinitionRecord]
    @Query private var profiles: [UserProfileRecord]
    private var exerciseCatalog: [ExerciseCandidate] { exerciseDefs.map(ExerciseCandidate.init(record:)) }
    private var equipmentPreference: EquipmentPreference { profiles.first?.equipmentPreference ?? .fullGym }
    private var guidanceLevel: GuidanceLevel { GuidanceLevel(trainingExperience: profiles.first?.trainingExperience ?? "") }
    @EnvironmentObject var vm: AppViewModel

    let onSave: () -> Void
    let template: WorkoutSplit?
    private let editSplit: UserSplitRecord?
    private let editDays: [UserSplitDayRecord]

    init(template: WorkoutSplit? = nil, onSave: @escaping () -> Void) {
        self.template = template
        self.editSplit = nil
        self.editDays = []
        self.onSave = onSave
    }

    init(editSplit: UserSplitRecord, editDays: [UserSplitDayRecord], onSave: @escaping () -> Void) {
        self.template = nil
        self.editSplit = editSplit
        self.editDays = editDays
        self.onSave = onSave
    }

    @State private var splitName = ""
    @State private var dayNames: [String] = Array(repeating: "", count: 7)
    @State private var dayTemplateIDs: [String] = Array(repeating: "", count: 7)
    @State private var dayIsRest: [Bool] = Array(repeating: false, count: 7)
    @State private var dayExercises: [[DayExercise]] = Array(repeating: [], count: 7)
    @State private var activePicker: ActivePicker? = nil
    @State private var showDiscardConfirm = false
    @State private var balanceExpanded = false

    private var hasUnsavedContent: Bool {
        !splitName.trimmingCharacters(in: .whitespaces).isEmpty
            || dayTemplateIDs.contains { !$0.isEmpty }
            || dayExercises.contains { !$0.isEmpty }
    }

    private enum ActivePicker: Identifiable {
        case template(dayIndex: Int)
        case exercise(dayIndex: Int)
        var id: String {
            switch self {
            case .template(let i): return "template-\(i)"
            case .exercise(let i): return "exercise-\(i)"
            }
        }
        var dayIndex: Int {
            switch self { case .template(let i): return i; case .exercise(let i): return i }
        }
    }

    private let dayLabels = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Split Name") {
                    TextField("e.g. My PPL, Push Pull Legs", text: $splitName)
                }

                let hasAnyDay = dayTemplateIDs.contains { !$0.isEmpty } || dayExercises.contains { !$0.isEmpty }
                if hasAnyDay {
                    Section {
                        MuscleGroupPanelWeekly(
                            dayTemplateIDs: dayTemplateIDs,
                            dayIsRest: dayIsRest,
                            dayExerciseNames: dayExercises.map { $0.map { $0.name } }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }

                Section("Weekly Schedule") {
                    ForEach(0..<7, id: \.self) { i in
                        dayRow(index: i)
                    }
                }
            }
            .navigationTitle(editSplit != nil ? "Edit Split" : (template != nil ? "Customize Split" : "New Split"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let t = template {
                    splitName = t.title
                    for (i, day) in t.workouts.prefix(7).enumerated() {
                        dayNames[i] = day.focus
                        dayIsRest[i] = false
                        dayExercises[i] = day.exercises.map { DayExercise.from(name: $0.name, prescription: $0.prescription) }
                    }
                } else if let s = editSplit {
                    splitName = s.name
                    for day in editDays {
                        let i = day.orderIndex
                        guard i < 7 else { continue }
                        dayIsRest[i] = day.isRest
                        dayNames[i] = day.isRest ? "" : (day.dayName == dayLabels[i] ? "" : day.dayName)
                        dayTemplateIDs[i] = day.templateID
                        if let data = day.exercisesJSON.data(using: .utf8),
                           let decoded = try? JSONDecoder().decode([DayExercise].self, from: data) {
                            dayExercises[i] = decoded
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedContent { showDiscardConfirm = true } else { onSave() }
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveSplit() }
                        .fontWeight(.semibold)
                        .foregroundStyle(splitName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.tint)
                        .disabled(splitName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(item: $activePicker) { picker in
                switch picker {
                case .template(let i):
                    TemplatePickerSheet(
                        templates: templates,
                        selectedID: dayTemplateIDs[i]
                    ) { templateID, templateName in
                        dayTemplateIDs[i] = templateID
                        if dayNames[i].isEmpty { dayNames[i] = templateName }
                    }
                case .exercise(let i):
                    ExercisePickerView(
                        onPickSingle: { picked in
                            if !dayExercises[i].contains(where: { $0.id == picked.id }) {
                                let pattern = exerciseCatalog.first { $0.id == picked.id }?.movementPattern ?? ""
                                let def = SetRepDefaults.defaults(forMovementPattern: pattern)
                                dayExercises[i].append(DayExercise(id: picked.id, name: picked.name,
                                    sets: def.sets, reps: def.reps,
                                    equipmentId: picked.equipmentId,
                                    equipmentDedupeKey: picked.equipmentDedupeKey,
                                    equipmentBrandName: picked.equipmentBrandName))
                            }
                        },
                        dayContext: DayContextInferrer.infer(dayName: dayNames[i], added: dayExercises[i], catalog: exerciseCatalog)
                    )
                }
            }
            .confirmationDialog("Discard this split?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { onSave() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your changes won't be saved.")
            }
        }
    }

    private func dayRow(index i: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dayLabels[i])
                    .font(.subheadline).fontWeight(.semibold)
                    .frame(width: 100, alignment: .leading)
                Spacer()
                Toggle("Rest", isOn: $dayIsRest[i])
                    .labelsHidden()
                    .onChange(of: dayIsRest[i]) { _, isRest in
                        if isRest {
                            dayTemplateIDs[i] = ""
                            dayNames[i] = ""
                        }
                    }
                Text("Rest")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !dayIsRest[i] {
                HStack(spacing: 8) {
                    TextField("Day name (e.g. Push Day)", text: $dayNames[i])
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)

                    Button {
                        activePicker = .template(dayIndex: i)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.caption)
                            Text(dayTemplateIDs[i].isEmpty ? "Template" : templateName(for: dayTemplateIDs[i]))
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(dayTemplateIDs[i].isEmpty ? Color.tint : Color.good)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background((dayTemplateIDs[i].isEmpty ? Color.tint : Color.good).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                if dayExercises[i].isEmpty, MuscleTaxonomy.archetype(forDayName: dayNames[i]) != nil {
                    Button {
                        if let arch = MuscleTaxonomy.archetype(forDayName: dayNames[i]) {
                            withAnimation {
                                dayExercises[i] = SplitScaffolds.recommend(
                                    archetype: arch, catalog: exerciseCatalog,
                                    personalization: PersonalizationProvider(signals: .init()),
                                    isEquipmentAvailable: { equipmentPreference.isAvailable(equipment: $0) })
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text("Auto-fill recommended")
                                .font(.caption2)
                        }
                        .foregroundStyle(Color.tint)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.tint.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Exercises for this day
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if dayExercises[i].count > 1 {
                            Button {
                                withAnimation { dayExercises[i] = ExerciseOrderer.order(dayExercises[i], catalog: exerciseCatalog) }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.caption2)
                                    Text("Sort")
                                        .font(.caption2)
                                }
                                .foregroundStyle(Color.tint)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.tint.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(Array(dayExercises[i].enumerated()), id: \.element.id) { j, ex in
                            HStack(spacing: 4) {
                                Text(ex.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Menu {
                                    ForEach([2, 3, 4, 5], id: \.self) { s in
                                        Button("\(s) sets") { dayExercises[i][j].sets = s }
                                    }
                                    if j > 0 { Button { withAnimation { dayExercises[i].swapAt(j, j - 1) } } label: { Label("Move left", systemImage: "arrow.left") } }
                                    if j < dayExercises[i].count - 1 { Button { withAnimation { dayExercises[i].swapAt(j, j + 1) } } label: { Label("Move right", systemImage: "arrow.right") } }
                                } label: {
                                    Text("\(ex.sets)×")
                                        .font(.caption2).fontWeight(.semibold)
                                        .foregroundStyle(Color.tint.opacity(0.7))
                                }
                                Button {
                                    dayExercises[i].removeAll { $0.id == ex.id }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                            }
                            .foregroundStyle(Color.tint)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.tint.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        Button {
                            activePicker = .exercise(dayIndex: i)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.caption2)
                                Text(dayExercises[i].isEmpty ? "Add exercises" : "Add more")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func templateName(for id: String) -> String {
        templates.first { $0.id == id }?.name ?? "Template"
    }

    private func saveSplit() {
        let trimmed = splitName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let encoder = JSONEncoder()
        let indexToWeekday = [2, 3, 4, 5, 6, 7, 1]

        func buildDays(for splitID: String) {
            for (i, label) in dayLabels.enumerated() {
                let exData = try? encoder.encode(dayExercises[i])
                let exJSON = exData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                modelContext.insert(UserSplitDayRecord(
                    splitID: splitID,
                    orderIndex: i,
                    dayLabel: label,
                    dayName: dayIsRest[i] ? "Rest" : (dayNames[i].isEmpty ? label : dayNames[i]),
                    templateID: dayIsRest[i] ? "" : dayTemplateIDs[i],
                    isRest: dayIsRest[i],
                    exercisesJSON: dayIsRest[i] ? "[]" : exJSON
                ))
            }
        }

        if let existing = editSplit {
            // Edit mode — update in place then push to server
            existing.name = trimmed
            existing.pinnedWeekdays = (0..<7).filter { !dayIsRest[$0] }.map { indexToWeekday[$0] }
            existing.syncPending = true
            for day in editDays { modelContext.delete(day) }
            buildDays(for: existing.id)
            try? modelContext.save()
            vm.loadActiveSplit()
            let record = existing
            Task.detached {
                if !record.serverID.isEmpty {
                    await vm.updateSplitOnServer(serverID: record.serverID, record: record)
                } else {
                    await vm.pushSplitToServer(record)
                }
            }
        } else {
            // Create mode — insert new record and push immediately
            let split = UserSplitRecord(ownerID: vm.currentUserID, name: trimmed)
            split.pinnedWeekdays = (0..<7).filter { !dayIsRest[$0] }.map { indexToWeekday[$0] }
            split.syncPending = true
            modelContext.insert(split)
            buildDays(for: split.id)
            try? modelContext.save()
            let record = split
            Task.detached { await vm.pushSplitToServer(record) }
        }
        onSave()
    }
}

private struct TemplatePickerSheet: View {
    let templates: [WorkoutTemplateRecord]
    let selectedID: String
    let onSelect: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.clipboard").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("No templates yet").font(.subheadline).foregroundStyle(.secondary)
                        Text("Create templates in the Templates tab to link them to split days.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(templates) { template in
                        HStack {
                            Text(template.name).font(.subheadline)
                            Spacer()
                            if template.id == selectedID {
                                Image(systemName: "checkmark").foregroundStyle(Color.tint).font(.caption)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(template.id, template.name)
                            dismiss()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("None") {
                        onSelect("", "")
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
