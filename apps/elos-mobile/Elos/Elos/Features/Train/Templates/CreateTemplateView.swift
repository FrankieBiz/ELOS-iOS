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
    /// The lifter's muscle check-off, when they've corrected what this trains.
    var muscleTargets: MuscleTargets? = nil

    static func == (lhs: TemplateExerciseEntry, rhs: TemplateExerciseEntry) -> Bool {
        lhs.exerciseName  == rhs.exerciseName &&
        lhs.targetSets    == rhs.targetSets   &&
        lhs.targetReps    == rhs.targetReps   &&
        lhs.restSeconds   == rhs.restSeconds  &&
        lhs.notes         == rhs.notes        &&
        lhs.muscleTargets == rhs.muscleTargets
    }

    /// What this entry trains, fully resolved — the same precedence coverage uses, so the muscles
    /// shown on the card are exactly the ones being credited.
    var resolvedTargets: MuscleTargets {
        ResolvedExercise(exercise: scored, candidate: nil).targets
    }

    var scored: ScoredExercise {
        ScoredExercise(id: exerciseID ?? "", name: exerciseName,
                       sets: targetSets, repsText: targetReps, restSeconds: restSeconds,
                       equipmentId: equipmentId, muscleTargets: muscleTargets)
    }

    /// The gym machine behind this entry, when there is one — the source of the muscle options offered
    /// in the check-off sheet.
    var equipmentRecord: EquipmentRecord? {
        equipmentId.flatMap { EquipmentDatabase.find(equipmentId: $0) }
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

/// Resolve any builder row to what it trains, via the one shared precedence chain
/// (`ResolvedExercise.targets`): lifter override → catalog → machine → name.
///
/// The muscle strips used to answer this themselves, with a second keyword ladder that lived in this
/// file, and got it badly wrong: `muscleKeyToLabel` has no `lower_back` key, so even the catalog's own
/// Hyperextension fell through to the name guess, where `contains("extension")` labelled it **Quads**.
/// That ladder is deleted — `MovementLexicon` is the only name-based resolution in the app now.
func resolvedMuscleTargets(exerciseID: String?, name: String,
                           equipmentId: String? = nil,
                           override: MuscleTargets? = nil,
                           candidate: ExerciseCandidate? = nil) -> MuscleTargets {
    ResolvedExercise(
        exercise: ScoredExercise(id: exerciseID ?? "", name: name, sets: 1, repsText: "",
                                 equipmentId: equipmentId, muscleTargets: override),
        candidate: candidate
    ).targets
}

/// The palette label for what a row trains, or nil when nothing is known about it.
func muscleLabel(for targets: MuscleTargets) -> String? {
    targets.primary.first.map(muscleGroupLabel(for:))
}

/// Look up one catalog entry by id, as the `ExerciseCandidate` the resolver wants.
func candidate(forID id: String?, in context: ModelContext) -> ExerciseCandidate? {
    guard let id else { return nil }
    let def = try? context.fetch(
        FetchDescriptor<ExerciseDefinitionRecord>(predicate: #Predicate { $0.id == id })
    ).first
    return def.map { ExerciseCandidate(record: $0) }
}

/// `FineMuscle` → the label vocabulary `muscleGroupColor` and `MuscleGroupPanel` already use.
/// `MuscleGroup.displayName` can't be used directly: it yields "Arms" and "Legs", which the palette
/// splits into Biceps/Triceps and Quads/Hamstrings/Calves.
func muscleGroupLabel(for fine: FineMuscle) -> String {
    switch fine {
    case .chest:                                        return "Chest"
    case .lats, .upperBack, .lowerBack:                 return "Back"
    case .rearDelts, .frontDelts, .sideDelts, .rotatorCuff: return "Shoulders"
    case .biceps, .forearms:                            return "Biceps"
    case .triceps:                                      return "Triceps"
    case .quads:                                        return "Quads"
    case .hamstrings:                                   return "Hamstrings"
    case .calves:                                       return "Calves"
    case .glutes:                                       return "Glutes"
    case .abs:                                          return "Core"
    }
}

func muscleGroupColor(for label: String) -> Color {
    switch label {
    case "Chest":      return Color.bad
    case "Back":       return Color.mBack
    case "Shoulders":  return Color.warn
    case "Biceps":     return Color.mBiceps
    case "Triceps":    return Color.mTriceps
    case "Quads":      return Color.mQuads
    case "Hamstrings": return Color.mHamstrings
    case "Glutes":     return Color.mGlutes
    case "Core":       return Color.mCore
    case "Calves":     return Color.good
    default:           return Color.secondary
    }
}

// MARK: - MuscleGroupPanelWeekly

struct MuscleGroupPanelWeekly: View {
    let dayTemplateIDs: [String]
    let dayIsRest: [Bool]
    /// Full `DayExercise` values, not just names. Both call sites already decode these and were
    /// discarding everything but `name` — which threw away the machine and the lifter's muscle
    /// check-off, so the weekly strip understated exactly the machine work the coverage bars credit.
    let dayExercises: [[DayExercise]]
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
            for ex in dayExercises[i] {
                let targets = resolvedMuscleTargets(
                    exerciseID: ex.id, name: ex.name,
                    equipmentId: ex.equipmentId, override: ex.muscleTargets,
                    candidate: candidate(forID: ex.id, in: modelContext))
                if let label = muscleLabel(for: targets) {
                    counts[label, default: 0] += ex.sets
                }
            }
        }
        return muscleDisplayOrder.compactMap { label in
            counts[label].map { (label, $0) }
        }
    }

    private func resolvedLabelFromRecord(_ ex: TemplateExerciseRecord) -> String? {
        muscleLabel(for: resolvedMuscleTargets(
            exerciseID: ex.exerciseID, name: ex.exerciseName,
            equipmentId: ex.equipmentId, override: ex.muscleTargets,
            candidate: candidate(forID: ex.exerciseID, in: modelContext)))
    }

    var body: some View {
        if !muscleSets.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("WEEKLY COVERAGE")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(muscleSets, id: \.label) { item in
                            let color = muscleGroupColor(for: item.label)
                            HStack(spacing: 5) {
                                Circle().fill(color).frame(width: 6, height: 6)
                                Text("\(item.label)  \(item.sets)×")
                                    .font(.system(.caption, weight: .semibold))
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
    /// The template's saved focus + goal, when editing one. `nil` = seed from the profile.
    let initialIntent: TrainingIntent?
    let onSave: (String, [TemplateExerciseEntry], TrainingIntent) -> Void

    init(initialName: String = "",
         initialEntries: [TemplateExerciseEntry] = [],
         isEditMode: Bool = false,
         initialIntent: TrainingIntent? = nil,
         onSave: @escaping (String, [TemplateExerciseEntry], TrainingIntent) -> Void) {
        self.initialName    = initialName
        self.initialEntries = initialEntries
        self.isEditMode     = isEditMode
        self.initialIntent  = initialIntent
        self.onSave         = onSave
    }

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExerciseDefinitionRecord.name) private var exerciseDefs: [ExerciseDefinitionRecord]
    /// Both presenters of this sheet (TemplatesView, SessionDetailView) already hold `vm`, and a sheet
    /// inherits the presenter's environment — needed here so the lifter's volume overrides reach the
    /// score instead of being silently dropped.
    @EnvironmentObject private var vm: AppViewModel
    @Query private var profiles: [UserProfileRecord]
    @State private var name = ""
    @State private var exercises: [TemplateExerciseEntry] = []
    @State private var showAddExercise = false
    @State private var showDiscardAlert = false
    @State private var isDirty = false
    @State private var snapshotName = ""
    @State private var snapshotExercises: [TemplateExerciseEntry] = []
    /// What the lifter says they're building. Seeded from their profile goal; `focus` stays nil
    /// (= inferred from the name) until they pick one.
    @State private var intent = TrainingIntent.default
    /// Muscle bias handed to the picker when a suggestion says "add hamstrings".
    @State private var pickerBias: DayContext = .empty

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
    }

    private var estimatedMinutes: Int {
        exercises.reduce(0) { $0 + ($1.targetSets * ($1.restSeconds + 45)) } / 60
    }

    // MARK: - Quality coach

    private var exerciseCatalog: [ExerciseCandidate] { exerciseDefs.map { ExerciseCandidate(record: $0) } }
    private var trainingProfile: TrainingProfile {
        TrainingProfile(record: profiles.first, volumeOverrides: vm.volumeOverrides)
    }
    private var guidanceLevel: GuidanceLevel {
        GuidanceLevel(trainingExperience: profiles.first?.trainingExperience ?? "")
    }

    private var qualityReport: QualityReport {
        let scored = exercises.map(\.scored)
        return TemplateQualityEngine.score(days: [scored], dayNames: [name],
                                           scope: .singleSession,
                                           profile: scoringProfile, catalog: exerciseCatalog,
                                           intent: intent)
    }

    /// The goal chip has to actually change the targets, so the *selected* goal overrides the saved
    /// profile's when scoring. Experience still comes from the profile — that's not a per-template
    /// choice.
    private var scoringProfile: TrainingProfile {
        // `volumeOverrides` must be carried across explicitly. Rebuilding the profile from goal +
        // experience alone silently dropped them, so a lifter's own volume targets changed the numbers
        // on the Volume Targets screen and nowhere else — the coverage bars and score here kept using
        // the science defaults.
        TrainingProfile(goal: intent.goal,
                        experience: trainingProfile.experience,
                        volumeOverrides: vm.volumeOverrides)
    }

    /// What the focus chip shows as its "Automatic" reading, from the template name.
    private var inferredFocus: SplitArchetype? { MuscleTaxonomy.archetype(forDayName: name) }

    // MARK: - Suggestion actions
    //
    // Previously every tip tap just opened a blank picker, throwing the tip's action away.

    private func handle(tip: QualityTip) {
        switch tip.action {
        case .addMuscle(let payload):
            openPicker(biasedToMuscles: MuscleTaxonomy.targetMuscles(forPayload: payload))
        case .addPattern(let pattern):
            // No pattern filter on the picker, so bias by the muscles that pattern trains.
            openPicker(biasedToMuscles: MuscleTaxonomy.targetMuscles(forPayload: pattern))
        case .reorder:
            reorderCompoundsFirst()
        case .noAction:
            break
        }
    }

    private func openPicker(biasedToMuscles muscles: [String]) {
        // `addedTargets` is what the picker's coverage strip counts, so it has to carry the resolved
        // muscles for what's already in the template — otherwise every chip reads as uncovered.
        pickerBias = DayContext(dayName: name, archetype: inferredFocus ?? intent.focus,
                               targetMuscles: Set(muscles),
                               addedPrimaryMuscles: [],
                               addedExerciseIDs: Set(exercises.compactMap { $0.exerciseID }),
                               addedExerciseNames: Set(exercises.map { MuscleTaxonomy.normalize($0.exerciseName) }),
                               addedTargets: exercises.map { $0.resolvedTargets })
        showAddExercise = true
    }

    /// Re-sorts `exercises` via `ExerciseOrderer`, preserving each entry's settings. Shared by the
    /// "poor order" tip's fix action (no priority) and the new priority menu below, so the
    /// name-matching re-map logic exists in exactly one place.
    private func reorder(priority: MuscleGroup?) {
        let asDays = exercises.map {
            DayExercise(id: $0.exerciseID ?? "", name: $0.exerciseName,
                        sets: $0.targetSets, reps: $0.targetReps)
        }
        let ordered = ExerciseOrderer.order(asDays, catalog: exerciseCatalog, priority: priority)
        // Re-sort the real entries to match the ordered names, keeping any unmatched ones at the end.
        var remaining = exercises
        var result: [TemplateExerciseEntry] = []
        for d in ordered {
            let key = MuscleTaxonomy.normalize(d.name)
            if let i = remaining.firstIndex(where: { MuscleTaxonomy.normalize($0.exerciseName) == key }) {
                result.append(remaining.remove(at: i))
            }
        }
        result.append(contentsOf: remaining)
        withAnimation(.elosEmphasis) { exercises = result }
    }

    /// Apply `ExerciseOrderer` (compound-first, no priority) — the "poor order" tip's fix action has no
    /// context on which muscle the user cares about, so it always uses the default sort.
    private func reorderCompoundsFirst() {
        reorder(priority: nil)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                List {
                    // Name + duration header
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField(isEditMode ? "Template name" : "Name your template", text: $name)
                                .font(.system(.title, weight: .bold))
                                .submitLabel(.done)

                            if !exercises.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .font(.system(.caption, weight: .medium))
                                    Text("~\(estimatedMinutes) min")
                                        .font(.system(.footnote, weight: .semibold))
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

                    // Intent — what are you building? Drives every target below it.
                    Section {
                        TrainingIntentRow(intent: $intent, inferredFocus: inferredFocus)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 0, leading: 20, bottom: 8, trailing: 20))
                    }

                    // Quality coach — score + dimension bars + actionable tips, then the muscle bars.
                    // Computed once here and passed down; the engine is pure but resolving the
                    // catalog per row would be wasteful.
                    if !exercises.isEmpty {
                        let report = qualityReport
                        Section {
                            VStack(spacing: 12) {
                                if vm.showQualityRater, report.isScored {
                                    TemplateQualityPanel(report: report, guidance: guidanceLevel,
                                                         title: "Template Quality",
                                                         scope: .singleSession,
                                                         onTapTip: { handle(tip: $0) })
                                }
                                MuscleCoverageBars(
                                    report: report.volume,
                                    title: "MUSCLE COVERAGE",
                                    hidesUnexpected: true,
                                    showsLegend: true,
                                    onTapMuscle: { bar in
                                        let payload = bar.fine?.rawValue ?? bar.group.rawValue
                                        openPicker(biasedToMuscles: MuscleTaxonomy.targetMuscles(forPayload: payload))
                                    })
                                .padding(Space.card)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .elosCard()
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 4, leading: 16, bottom: 8, trailing: 16))
                        }
                    }

                    // Priority sort — only useful with 2+ exercises to actually reorder.
                    if exercises.count > 1 {
                        HStack {
                            Text("Sort").elosSectionLabel()
                            Spacer()
                            PriorityMenu(onSelect: { reorder(priority: $0) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.caption2)
                                    Text("Sort by priority")
                                        .font(.caption2)
                                }
                                .foregroundStyle(Color.tint)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.tint.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    // Exercise cards
                    ForEach($exercises) { $ex in
                        ExerciseCard(entry: $ex) {
                            withAnimation(.elosEmphasis) {
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
                            .font(.system(.callout, weight: .semibold))
                        Text("Add Exercise")
                            .font(.system(.callout, weight: .semibold))
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
                        onSave(name.trimmingCharacters(in: .whitespaces), exercises, intent)
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(canSave ? .white : Color.secondary)
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(canSave ? Color.tint : Color(.tertiarySystemGroupedBackground))
                            .clipShape(Capsule())
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showAddExercise, onDismiss: { pickerBias = .empty }) {
                ExercisePickerView(onConfirmMulti: { picked in
                    withAnimation(.elosEmphasis) {
                        for ex in picked {
                            if !exercises.contains(where: { $0.exerciseID == ex.id || $0.exerciseName == ex.name }) {
                                exercises.append(TemplateExerciseEntry(
                                    exerciseID:         ex.id,
                                    exerciseName:       ex.name,
                                    equipmentId:        ex.equipmentId,
                                    equipmentDedupeKey: ex.equipmentDedupeKey,
                                    equipmentBrandName: ex.equipmentBrandName,
                                    muscleTargets:      ex.muscleTargets
                                ))
                            }
                        }
                    }
                    showAddExercise = false
                }, dayContext: pickerBias)
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
                // The template's own saved intent wins; otherwise seed the goal from the profile
                // so the chip is never a blank chore.
                intent = initialIntent ?? TrainingIntent(profile: trainingProfile)
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
    @State private var showMuscleSheet = false

    // Three numeric controls sit side by side in one row, so their chrome has to grow with the text or
    // the digits outgrow their wells. `elosDenseLayout` on the row caps how far that goes.
    @ScaledMetric(relativeTo: .title3) private var stepperButton: CGFloat = 30
    @ScaledMetric(relativeTo: .title3) private var stepperValueWidth: CGFloat = 44
    @ScaledMetric(relativeTo: .title3) private var repsFieldWidth: CGFloat = 72

    init(entry: Binding<TemplateExerciseEntry>, onDelete: @escaping () -> Void) {
        _entry = entry
        _showNoteField = State(initialValue: !entry.wrappedValue.notes.isEmpty)
        self.onDelete = onDelete
    }

    private var accentColor: Color {
        // Drive the accent off the resolved targets rather than a name guess, so the stripe matches
        // the muscle the coverage bars are crediting. No secondary fallback ladder: the resolution
        // chain already ends in the movement lexicon, so an empty result means nothing is known —
        // and the neutral stripe is the honest answer for that.
        let targets = entry.resolvedTargets
        guard let fine = targets.primary.first ?? targets.secondary.first else {
            return muscleGroupColor(for: "")
        }
        return muscleGroupColor(for: muscleGroupLabel(for: fine))
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
                        .font(.system(.subheadline, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                muscleTargetRow

                // Steppers row — three numeric controls in one line. They scale now, but the row can't
                // reflow, so cap the growth rather than let SETS/REPS/REST overflow the card.
                HStack(spacing: 0) {
                    numericStepper(
                        label: "SETS",
                        value: $entry.targetSets,
                        min: 1, max: 10, step: 1,
                        display: "\(entry.targetSets)"
                    )
                    Spacer(minLength: Space.xs)
                    repsControl
                    Spacer(minLength: Space.xs)
                    numericStepper(
                        label: "REST",
                        value: $entry.restSeconds,
                        min: 0, max: 600, step: 15,
                        display: formatRest(entry.restSeconds)
                    )
                }
                .elosDenseLayout()

                // Notes
                notesRow
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showMuscleSheet) {
            MuscleTargetSheet(
                title: entry.exerciseName,
                record: entry.equipmentRecord,
                initial: entry.resolvedTargets
            ) { chosen in
                entry.muscleTargets = chosen
            }
        }
    }

    /// What this exercise is credited to, and the way in to change it. Always present — the muscles a
    /// movement trains shouldn't be a thing you can only fix if you happen to notice it's wrong.
    private var muscleTargetRow: some View {
        let targets = entry.resolvedTargets
        let isEdited = entry.muscleTargets != nil
        return Button {
            HapticManager.impact(.light)
            showMuscleSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: targets.isEmpty ? "exclamationmark.triangle.fill" : "figure.strengthtraining.traditional")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(targets.isEmpty ? Color.warn : .secondary)
                Text(targets.isEmpty ? "Set muscles worked" : targets.summary)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(targets.isEmpty ? Color.warn : .secondary)
                    .lineLimit(1)
                if isEdited {
                    Text("EDITED")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(Color.tint)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.tint.opacity(0.12))
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var repsControl: some View {
        VStack(spacing: 6) {
            Text("REPS")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            TextField("8-10", text: $entry.targetReps)
                .font(.elosNumeric(.title3))
                .multilineTextAlignment(.center)
                .keyboardType(.numbersAndPunctuation)
                .frame(width: repsFieldWidth)
                .padding(.vertical, 9)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func numericStepper(label: String, value: Binding<Int>, min: Int, max: Int, step: Int, display: String) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            HStack(spacing: Space.s) {
                Button {
                    if value.wrappedValue - step >= min { value.wrappedValue -= step }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: stepperButton, height: stepperButton)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease \(label.lowercased())")

                Text(display)
                    .font(.elosNumeric(.title3))
                    // A 5-character rest value ("1m30s") wrapped to two lines inside the three-up
                    // stepper row, splitting as "1m3 / 0s" and pushing the card taller. The number
                    // must stay on one line; shrink it instead.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(minWidth: stepperValueWidth, alignment: .center)

                Button {
                    if value.wrappedValue + step <= max { value.wrappedValue += step }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(.caption, weight: .bold))
                        .foregroundStyle(Color.tint)
                        .frame(width: stepperButton, height: stepperButton)
                        .background(Color.tint.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase \(label.lowercased())")
            }
        }
    }

    @ViewBuilder
    private var notesRow: some View {
        if showNoteField {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.elosCaption)
                    .foregroundStyle(Color.tint)
                    .padding(.top, 2)
                TextField("e.g. Slow eccentric, touch chest", text: $entry.notes, axis: .vertical)
                    .font(.elosBody)
                    .lineLimit(1...3)
                Button {
                    entry.notes = ""
                    showNoteField = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear note")
            }
        } else {
            Button {
                withAnimation(.elosQuick) { showNoteField = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: entry.notes.isEmpty ? "text.bubble" : "text.bubble.fill")
                        .font(.caption)
                    Text(entry.notes.isEmpty ? "Add note" : entry.notes)
                        .font(.caption)
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
