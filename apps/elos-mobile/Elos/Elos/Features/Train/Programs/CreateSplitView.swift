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
    @State private var showFullReport = false
    /// Weekly scope carries a goal but no single focus — a week isn't one kind of day.
    @State private var intent = TrainingIntent.default
    /// Muscles a suggestion asked for, folded into the next picker's Smart Sort bias.
    @State private var pendingBiasMuscles: [String] = []
    /// Which exercise's muscle check-off is open, if any.
    @State private var muscleEdit: MuscleEdit? = nil

    private struct MuscleEdit: Identifiable {
        let dayIndex: Int
        let exerciseIndex: Int
        var id: String { "\(dayIndex)-\(exerciseIndex)" }
    }

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
                            dayExercises: dayExercises
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)

                        qualityPanel
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
                // A saved split's own goal wins; otherwise seed from the profile so the chip
                // starts on something sensible rather than blank.
                intent = editSplit?.intent ?? TrainingIntent(profile: TrainingProfile(record: profiles.first))
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
            .sheet(item: $activePicker, onDismiss: { pendingBiasMuscles = [] }) { picker in
                switch picker {
                case .template(let i):
                    TemplatePickerSheet(
                        templates: templates,
                        selectedID: dayTemplateIDs[i]
                    ) { templateID, templateName in
                        dayTemplateIDs[i] = templateID
                        if dayNames[i].isEmpty { dayNames[i] = templateName }
                        // A day's exercises come from either its template or its ad-hoc list, never
                        // both — `prepareExercises(for:)` silently prefers ad-hoc when both are set,
                        // so leaving stale exercises here would make this template pick a no-op.
                        dayExercises[i] = []
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
                                    equipmentBrandName: picked.equipmentBrandName,
                                    muscleTargets: picked.muscleTargets))
                                // Ad-hoc exercises take precedence over a template at save time —
                                // clear the template chip so the UI doesn't keep showing it as active
                                // for a day whose exercises it no longer actually determines.
                                dayTemplateIDs[i] = ""
                            }
                        },
                        dayContext: biasedContext(dayIndex: i)
                    )
                }
            }
            // Indices are resolved defensively on both sides. A sheet's content closure is re-evaluated
            // on state changes while it's presented, so a bare `dayExercises[i][j]` here is a crash
            // waiting for the day the row it points at goes away.
            .sheet(item: $muscleEdit) { edit in
                if let ex = exercise(at: edit) {
                    MuscleTargetSheet(
                        title: ex.name,
                        record: ex.equipmentId.flatMap { EquipmentDatabase.find(equipmentId: $0) },
                        initial: resolvedTargets(for: ex)
                    ) { chosen in
                        guard exercise(at: edit) != nil else { return }
                        dayExercises[edit.dayIndex][edit.exerciseIndex].muscleTargets = chosen
                    }
                }
            }
            .sheet(isPresented: $showFullReport) {
                SplitQualityReportView(
                    report: qualityReport,
                    days: daySummaries,
                    onTapTip: { tip in
                        showFullReport = false
                        handle(tip: tip)
                    },
                    onTapMuscle: { bar in
                        showFullReport = false
                        let payload = bar.fine?.rawValue ?? bar.group.rawValue
                        pendingBiasMuscles = MuscleTaxonomy.targetMuscles(forPayload: payload)
                        activePicker = .exercise(dayIndex: firstOpenDayIndex())
                    })
            }
            .confirmationDialog("Discard this split?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { onSave() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your changes won't be saved.")
            }
        }
    }

    // MARK: - Quality panel

    private var qualityReport: QualityReport {
        TemplateQualityEngine.score(days: dayExercises.map { $0.map(ScoredExercise.init(day:)) },
                                    dayNames: dayNames,
                                    scope: .weeklySplit,
                                    profile: scoringProfile,
                                    catalog: exerciseCatalog,
                                    intent: intent)
    }

    /// The selected goal overrides the saved profile's, so the goal chip actually moves the rep/rest
    /// targets. Experience stays profile-driven — it isn't a per-split choice.
    private var scoringProfile: TrainingProfile {
        TrainingProfile(goal: intent.goal,
                        experience: TrainingProfile(record: profiles.first).experience,
                        volumeOverrides: vm.volumeOverrides)
    }

    @ViewBuilder private var qualityPanel: some View {
        let populatedDays = dayExercises.filter { !$0.isEmpty }.count
        let report = qualityReport
        // Hold scoring until the split is meaningfully built — a half-finished week would flag
        // "low volume" on everything, which reads as nagging rather than coaching.
        if populatedDays >= 2 && report.isScored {
            VStack(alignment: .leading, spacing: 10) {
                // A week has no single focus, so only the goal chip appears here.
                TrainingIntentRow(intent: $intent, showsFocus: false, showsSkip: false)
                TemplateQualityPanel(report: report, guidance: guidanceLevel, title: "Split Quality",
                                     scope: .weeklySplit,
                                     onTapTip: { handle(tip: $0) },
                                     onSeeFullReport: { showFullReport = true })
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    /// Per-day headline numbers for the full report. Each day is scored on its own at session scope,
    /// which is what makes "Monday 82 / Friday 41" meaningful.
    private var daySummaries: [SplitDaySummary] {
        (0..<min(7, dayExercises.count)).compactMap { i in
            let day = dayExercises[i]
            guard !dayIsRest[i], !day.isEmpty else { return nil }
            let scored = day.map(ScoredExercise.init(day:))
            let r = TemplateQualityEngine.score(days: [scored], dayNames: [dayNames[i]],
                                                scope: .singleSession,
                                                profile: scoringProfile,
                                                catalog: exerciseCatalog)
            return SplitDaySummary(
                id: i,
                name: dayNames[i].isEmpty ? dayLabels[i] : dayNames[i],
                exerciseCount: day.count,
                sets: day.reduce(0) { $0 + $1.sets },
                score: r.isScored ? r.overall : nil)
        }
    }

    // MARK: - Suggestion actions

    private func handle(tip: QualityTip) {
        switch tip.action {
        case .addMuscle(let payload), .addPattern(let payload):
            // Open the emptiest non-rest day, biased toward the muscle the tip names.
            let target = firstOpenDayIndex()
            pendingBiasMuscles = MuscleTaxonomy.targetMuscles(forPayload: payload)
            activePicker = .exercise(dayIndex: target)
        case .reorder(let dayIndex):
            guard dayExercises.indices.contains(dayIndex) else { return }
            withAnimation(.elosEmphasis) {
                dayExercises[dayIndex] = ExerciseOrderer.order(dayExercises[dayIndex],
                                                              catalog: exerciseCatalog)
            }
        case .noAction:
            break
        }
    }

    /// The day most in need of another exercise — fewest exercises among non-rest days.
    private func firstOpenDayIndex() -> Int {
        let candidates = (0..<min(7, dayExercises.count)).filter { !dayIsRest[$0] }
        return candidates.min { dayExercises[$0].count < dayExercises[$1].count } ?? 0
    }

    /// The exercise a pending muscle-edit points at, or nil if the row has since gone.
    private func exercise(at edit: MuscleEdit) -> DayExercise? {
        guard dayExercises.indices.contains(edit.dayIndex),
              dayExercises[edit.dayIndex].indices.contains(edit.exerciseIndex)
        else { return nil }
        return dayExercises[edit.dayIndex][edit.exerciseIndex]
    }

    /// What one day-exercise is credited to, via the shared precedence chain.
    private func resolvedTargets(for ex: DayExercise) -> MuscleTargets {
        ExerciseResolver.resolve([[ScoredExercise(day: ex)]], catalog: exerciseCatalog)
            .first?.first?.targets ?? MuscleTargets()
    }

    /// The day's inferred context, plus any muscles a suggestion just asked for.
    private func biasedContext(dayIndex i: Int) -> DayContext {
        let base = DayContextInferrer.infer(dayName: dayNames[i], added: dayExercises[i],
                                            catalog: exerciseCatalog)
        guard !pendingBiasMuscles.isEmpty else { return base }
        return DayContext(dayName: base.dayName, archetype: base.archetype,
                          targetMuscles: base.targetMuscles.union(pendingBiasMuscles),
                          addedPrimaryMuscles: base.addedPrimaryMuscles,
                          addedExerciseIDs: base.addedExerciseIDs,
                          addedExerciseNames: base.addedExerciseNames,
                          addedTargets: base.addedTargets)
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
                                dayTemplateIDs[i] = ""
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
                                // Tapping the exercise opens its options — sets AND reorder live
                                // here (a chevron hints at the menu) so reordering is discoverable.
                                Menu {
                                    Section("Sets") {
                                        ForEach([2, 3, 4, 5], id: \.self) { s in
                                            Button("\(s) sets") { dayExercises[i][j].sets = s }
                                        }
                                    }
                                    if j > 0 { Button { withAnimation { dayExercises[i].swapAt(j, j - 1) } } label: { Label("Move left", systemImage: "arrow.left") } }
                                    if j < dayExercises[i].count - 1 { Button { withAnimation { dayExercises[i].swapAt(j, j + 1) } } label: { Label("Move right", systemImage: "arrow.right") } }
                                    Button {
                                        muscleEdit = MuscleEdit(dayIndex: i, exerciseIndex: j)
                                    } label: {
                                        Label("Muscles worked…", systemImage: "figure.strengthtraining.traditional")
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(ex.name)
                                            .font(.caption2)
                                            .lineLimit(1)
                                        Text("\(ex.sets)×")
                                            .font(.caption2).fontWeight(.semibold)
                                            .foregroundStyle(Color.tint.opacity(0.7))
                                        Image(systemName: "ellipsis.circle.fill")
                                            .font(.footnote)
                                            .foregroundStyle(Color.tint.opacity(0.8))
                                    }
                                }
                                Button {
                                    dayExercises[i].removeAll { $0.id == ex.id }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(.caption2, weight: .bold))
                                }
                                .accessibilityLabel("Remove exercise")
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

        // A day the lifter never touched — no exercises, no template, no name — is a rest day, not a
        // training day with nothing in it. `dayIsRest` starts all-false, so without this a 2-day
        // split saved seven *training* days and pinned all seven into the schedule: the split card
        // said "2 Days" while the week strip showed five more days labelled "Train", and "Start
        // Today's Workout" on one of them opened an empty session. A day that was given a name is
        // left alone — that's a deliberate placeholder the lifter still intends to fill.
        func isEffectivelyRest(_ i: Int) -> Bool {
            dayIsRest[i] || (dayExercises[i].isEmpty
                             && dayTemplateIDs[i].isEmpty
                             && dayNames[i].trimmingCharacters(in: .whitespaces).isEmpty)
        }

        func buildDays(for splitID: String) {
            for (i, label) in dayLabels.enumerated() {
                let exData = try? encoder.encode(dayExercises[i])
                let exJSON = exData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                let rest = isEffectivelyRest(i)
                modelContext.insert(UserSplitDayRecord(
                    splitID: splitID,
                    orderIndex: i,
                    dayLabel: label,
                    dayName: rest ? "Rest" : (dayNames[i].isEmpty ? label : dayNames[i]),
                    templateID: rest ? "" : dayTemplateIDs[i],
                    isRest: rest,
                    exercisesJSON: rest ? "[]" : exJSON
                ))
            }
        }

        if let existing = editSplit {
            // Edit mode — update in place then push to server
            existing.name = trimmed
            existing.pinnedWeekdays = (0..<7).filter { !isEffectivelyRest($0) }.map { indexToWeekday[$0] }
            existing.intent = intent
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
            split.pinnedWeekdays = (0..<7).filter { !isEffectivelyRest($0) }.map { indexToWeekday[$0] }
            split.intent = intent
            split.syncPending = true
            modelContext.insert(split)
            buildDays(for: split.id)
            try? modelContext.save()
            let record = split
            // Only "Customize & Subscribe" (entered with a `template`) implies replacing the active
            // split — the blank "Create Split" button elsewhere just adds to My Splits, unactivated,
            // same as any split the user browses in and hasn't tapped Activate on.
            let shouldActivate = template != nil
            if shouldActivate {
                vm.setActiveSplit(record)
            }
            Task.detached {
                await vm.pushSplitToServer(record)
                if shouldActivate {
                    await vm.activateSplitOnServer(serverID: record.serverID)
                }
            }
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
                        Image(systemName: "list.bullet.clipboard").font(.largeTitle).foregroundStyle(.secondary)
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
