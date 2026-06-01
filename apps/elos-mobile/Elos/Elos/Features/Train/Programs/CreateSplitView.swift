import SwiftUI
import SwiftData


struct CreateSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplateRecord.name) private var templates: [WorkoutTemplateRecord]
    @EnvironmentObject var vm: AppViewModel

    let onSave: () -> Void
    let template: WorkoutSplit?

    init(template: WorkoutSplit? = nil, onSave: @escaping () -> Void) {
        self.template = template
        self.onSave = onSave
    }

    @State private var splitName = ""
    @State private var dayNames: [String] = Array(repeating: "", count: 7)
    @State private var dayTemplateIDs: [String] = Array(repeating: "", count: 7)
    @State private var dayIsRest: [Bool] = Array(repeating: false, count: 7)
    @State private var dayExercises: [[DayExercise]] = Array(repeating: [], count: 7)
    @State private var pickingDayIndex: Int?
    @State private var pickingExerciseDayIndex: Int?

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
            .navigationTitle(template != nil ? "Customize Split" : "New Split")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard let t = template else { return }
                splitName = t.title
                for (i, day) in t.workouts.prefix(7).enumerated() {
                    dayNames[i] = day.focus
                    dayIsRest[i] = false
                    dayExercises[i] = day.exercises.map { DayExercise(id: UUID().uuidString, name: $0.name) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onSave() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveSplit() }
                        .fontWeight(.semibold)
                        .foregroundStyle(splitName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.tint)
                        .disabled(splitName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(item: Binding(
                get: { pickingDayIndex.map { PickerIndex(value: $0) } },
                set: { pickingDayIndex = $0?.value }
            )) { item in
                TemplatePickerSheet(
                    templates: templates,
                    selectedID: dayTemplateIDs[item.value]
                ) { templateID, templateName in
                    dayTemplateIDs[item.value] = templateID
                    if dayNames[item.value].isEmpty {
                        dayNames[item.value] = templateName
                    }
                    pickingDayIndex = nil
                }
            }
            .sheet(item: Binding(
                get: { pickingExerciseDayIndex.map { PickerIndex(value: $0) } },
                set: { pickingExerciseDayIndex = $0?.value }
            )) { item in
                ExercisePickerView(onPickSingle: { picked in
                    if !dayExercises[item.value].contains(where: { $0.id == picked.id }) {
                        dayExercises[item.value].append(DayExercise(id: picked.id, name: picked.name))
                    }
                    // Don't dismiss — user can keep picking then swipe to close
                })
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
                        pickingDayIndex = i
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.caption)
                            Text(dayTemplateIDs[i].isEmpty ? "Template" : templateName(for: dayTemplateIDs[i]))
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(dayTemplateIDs[i].isEmpty ? Color.tint : Color.good)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background((dayTemplateIDs[i].isEmpty ? Color.tint : Color.good).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                // Exercises for this day
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(dayExercises[i]) { ex in
                            HStack(spacing: 4) {
                                Text(ex.name)
                                    .font(.caption2)
                                    .lineLimit(1)
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
                            pickingExerciseDayIndex = i
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
        let split = UserSplitRecord(ownerID: vm.currentUserID, name: trimmed)
        modelContext.insert(split)
        let encoder = JSONEncoder()
        for (i, label) in dayLabels.enumerated() {
            let exData = try? encoder.encode(dayExercises[i])
            let exJSON = exData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let day = UserSplitDayRecord(
                splitID: split.id,
                orderIndex: i,
                dayLabel: label,
                dayName: dayIsRest[i] ? "Rest" : (dayNames[i].isEmpty ? label : dayNames[i]),
                templateID: dayIsRest[i] ? "" : dayTemplateIDs[i],
                isRest: dayIsRest[i],
                exercisesJSON: dayIsRest[i] ? "[]" : exJSON
            )
            modelContext.insert(day)
        }
        try? modelContext.save()
        onSave()
    }
}

private struct PickerIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

private struct TemplatePickerSheet: View {
    let templates: [WorkoutTemplateRecord]
    let selectedID: String
    let onSelect: (String, String) -> Void

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
                        Button {
                            onSelect(template.id, template.name)
                        } label: {
                            HStack {
                                Text(template.name).font(.subheadline)
                                Spacer()
                                if template.id == selectedID {
                                    Image(systemName: "checkmark").foregroundStyle(Color.tint).font(.caption)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("None") { onSelect("", "") }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
