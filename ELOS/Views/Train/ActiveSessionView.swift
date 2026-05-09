import SwiftUI
import SwiftData

// MARK: - Active workout — fullscreen flow.
// File renamed in spirit to ActiveWorkoutView. Type alias kept for back-compat.

typealias ActiveSessionView = ActiveWorkoutView

struct ActiveWorkoutView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WorkoutSet.completedAt, order: .reverse) private var allSets: [WorkoutSet]
    @Query(sort: \PersonalRecord.dateAchieved, order: .reverse) private var allPRs: [PersonalRecord]

    @State private var elapsed: Int = 0
    @State private var restTotal: Int = 90
    @State private var restRemaining: Int = 0
    @State private var showAddExercise = false
    @State private var confettiTrigger = 0
    @State private var showDiscardConfirm = false
    @State private var showFinishConfirm = false
    @State private var completionData: WorkoutCompleteData? = nil
    @State private var newPRsThisSession: Set<String> = []
    @State private var prToastTitle: String? = nil

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var workout: ActiveWorkout {
        appState.activeWorkout ?? ActiveWorkout(title: "", subtitle: "", exercises: [])
    }

    private var isResting: Bool { restRemaining > 0 }

    private var totalCompletedSets: Int {
        workout.exercises.flatMap(\.sets).filter(\.completed).count
    }

    private var totalPlannedSets: Int {
        workout.exercises.flatMap(\.sets).count
    }

    private var lastWeightByExercise: [String: Double] {
        var out: [String: Double] = [:]
        for s in allSets where !s.isWarmup && s.weightKg > 0 && out[s.exerciseName] == nil {
            out[s.exerciseName] = s.weightKg
        }
        return out
    }

    private var lastRepsByExercise: [String: Int] {
        var out: [String: Int] = [:]
        for s in allSets where !s.isWarmup && s.reps > 0 && out[s.exerciseName] == nil {
            out[s.exerciseName] = s.reps
        }
        return out
    }

    private var bestEstimated1RMByExercise: [String: Double] {
        var out: [String: Double] = [:]
        for s in allSets where !s.isWarmup {
            if let e1rm = s.estimated1RMKg {
                out[s.exerciseName] = max(out[s.exerciseName] ?? 0, e1rm)
            }
        }
        for pr in allPRs {
            out[pr.exerciseName] = max(out[pr.exerciseName] ?? 0, pr.estimated1RMKg)
        }
        return out
    }

    var body: some View {
        ZStack {
            Color.surfaceBG.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if isResting {
                    RestBanner(
                        total: restTotal,
                        remaining: $restRemaining,
                        onAdd: { restRemaining = max(0, restRemaining + $0) },
                        onSkip: { restRemaining = 0 }
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                exerciseList
            }

            if let title = prToastTitle {
                VStack {
                    PRToast(title: title)
                        .padding(.top, 70)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .ignoresSafeArea()
            }

            ConfettiOverlay(trigger: confettiTrigger)
                .ignoresSafeArea()
        }
        .onReceive(ticker) { _ in elapsed += 1 }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet { ex in
                addExercise(ex)
            }
        }
        .alert("Discard workout?",
               isPresented: $showDiscardConfirm) {
            Button("Discard", role: .destructive) {
                appState.activeWorkout = nil
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Your sets won't be saved.")
        }
        .alert("Finish workout?", isPresented: $showFinishConfirm) {
            Button("Finish", role: .none) { finishWorkout() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("\(totalCompletedSets) of \(totalPlannedSets) sets completed.")
        }
        .fullScreenCover(item: $completionData) { data in
            WorkoutCompleteView(data: data, units: appState.units) {
                completionData = nil
                appState.activeWorkout = nil
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    Haptic.light(); showDiscardConfirm = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.primary)
                        .frame(width: 38, height: 38)
                        .background(Color.surfaceRaised, in: Circle())
                }
                .buttonStyle(.pressable(scale: 0.92, haptic: .none))

                Spacer()

                VStack(spacing: 1) {
                    Text(formatElapsed(elapsed))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text(workout.title.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(0.5)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Haptic.medium()
                    showFinishConfirm = true
                } label: {
                    Text("Finish")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Color.brand, in: Capsule())
                }
                .buttonStyle(.pressable(scale: 0.94, haptic: .none))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.surfaceInset).frame(height: 4)
                    Capsule().fill(Color.brand)
                        .frame(width: geo.size.width * progressFraction, height: 4)
                        .animation(Theme.Motion.snappy, value: progressFraction)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var progressFraction: Double {
        guard totalPlannedSets > 0 else { return 0 }
        return Double(totalCompletedSets) / Double(totalPlannedSets)
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        ScrollView {
            VStack(spacing: 14) {
                if workout.exercises.isEmpty {
                    EmptyStateCard(
                        icon: "plus.app.fill",
                        title: "Empty Workout",
                        subtitle: "Add your first exercise to start logging sets.",
                        actionTitle: "Add Exercise"
                    ) { showAddExercise = true }
                    .padding(.top, 30)
                }

                ForEach(workout.exercises.indices, id: \.self) { idx in
                    let exercise = workout.exercises[idx]
                    ActiveExerciseCard(
                        exercise: bindingFor(idx: idx),
                        units: appState.units,
                        lastWeightKg: lastWeightByExercise[exercise.name],
                        lastReps: lastRepsByExercise[exercise.name],
                        recommendedKg: appState.recommendedWeightsKg[exercise.name],
                        bar: appState.barWeightKg,
                        plates: appState.availablePlatesKg,
                        bestE1RMKg: bestEstimated1RMByExercise[exercise.name],
                        onSetCompleted: { setBeatsPR in
                            startRest(seconds: appState.defaultRestSeconds)
                            if setBeatsPR { celebratePR(for: exercise.name) }
                        },
                        onDelete: { removeExercise(at: idx) }
                    )
                    .padding(.horizontal, 14)
                }

                Button {
                    showAddExercise = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 18, weight: .black))
                        Text("Add Exercise").font(.system(size: 15, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.pressable(scale: 0.97, haptic: .light))
                .padding(.horizontal, 14)
                .padding(.top, 4)

                Spacer(minLength: 60)
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Bindings (translate index <-> AppState's optional active workout)

    private func bindingFor(idx: Int) -> Binding<DraftExercise> {
        Binding(
            get: { appState.activeWorkout?.exercises[idx] ?? workout.exercises[idx] },
            set: { newValue in
                guard var w = appState.activeWorkout else { return }
                guard idx < w.exercises.count else { return }
                w.exercises[idx] = newValue
                appState.activeWorkout = w
            }
        )
    }

    private func removeExercise(at idx: Int) {
        guard var w = appState.activeWorkout else { return }
        guard idx < w.exercises.count else { return }
        w.exercises.remove(at: idx)
        appState.activeWorkout = w
        Haptic.warning()
    }

    private func addExercise(_ ex: ExerciseDefinition) {
        guard var w = appState.activeWorkout else { return }
        w.exercises.append(
            DraftExercise(name: ex.name, muscleGroup: ex.muscleGroup, targetSets: 4, targetReps: 8)
        )
        appState.activeWorkout = w
        Haptic.success()
    }

    // MARK: - Rest timer

    private func startRest(seconds: Int) {
        restTotal = seconds
        restRemaining = seconds
        withAnimation(Theme.Motion.snappy) {}
    }

    // MARK: - PR celebration

    private func celebratePR(for exerciseName: String) {
        confettiTrigger += 1
        Haptic.success()
        newPRsThisSession.insert(exerciseName)
        prToastTitle = "New PR · \(exerciseName)"
        withAnimation(Theme.Motion.snappy) {}
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(.easeOut(duration: 0.4)) { prToastTitle = nil }
        }
    }

    // MARK: - Finish

    private func finishWorkout() {
        guard let w = appState.activeWorkout else { return }

        let session = WorkoutSession(name: w.title, date: .now, programDay: w.subtitle)
        session.startedAt = w.startedAt
        session.endedAt = .now
        session.durationMinutes = max(1, elapsed / 60)

        var totalKg = 0.0
        var orderIdx = 0
        var prsCreated: [String] = []

        for ex in w.exercises {
            for (i, draftSet) in ex.sets.enumerated() where draftSet.completed {
                let kg = appState.units.toKg(draftSet.weight ?? 0)
                let reps = draftSet.reps ?? 0
                let model = WorkoutSet(
                    exerciseName: ex.name,
                    muscleGroup: ex.muscleGroup,
                    setNumber: i + 1,
                    reps: reps,
                    weightKg: kg,
                    rpe: draftSet.rpe,
                    isWarmup: draftSet.isWarmup
                )
                model.orderIndex = orderIdx; orderIdx += 1
                model.session = session
                ctx.insert(model)
                session.sets.append(model)
                totalKg += kg * Double(reps)

                // PR detection: best estimated 1RM exceeded?
                if !draftSet.isWarmup, let e1rm = model.estimated1RMKg {
                    let prior = bestEstimated1RMByExercise[ex.name] ?? 0
                    if e1rm > prior + 0.001 {
                        let pr = PersonalRecord(
                            exerciseName: ex.name,
                            weightKg: kg, reps: reps, estimated1RMKg: e1rm
                        )
                        ctx.insert(pr)
                        if !prsCreated.contains(ex.name) { prsCreated.append(ex.name) }
                    }
                }

                // Smart-load: if user rated difficulty, save recommended next weight
                if let d = draftSet.difficulty {
                    appState.recordDifficulty(d, exerciseName: ex.name, lastWeightKg: kg)
                }
            }
        }

        session.totalVolumeKg = totalKg
        ctx.insert(session)
        try? ctx.save()

        appState.registerCompletedWorkout()

        completionData = WorkoutCompleteData(
            title: w.title,
            subtitle: w.subtitle,
            durationMinutes: session.durationMinutes,
            totalSets: totalCompletedSets,
            totalVolumeKg: totalKg,
            exerciseCount: w.exercises.count,
            newPRs: prsCreated.isEmpty ? Array(newPRsThisSession) : prsCreated
        )

        Haptic.success()
    }

    // MARK: - Helpers

    private func formatElapsed(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - Active exercise card

private struct ActiveExerciseCard: View {
    @Binding var exercise: DraftExercise
    let units: WeightUnit
    let lastWeightKg: Double?
    let lastReps: Int?
    let recommendedKg: Double?
    let bar: Double
    let plates: [Double]
    let bestE1RMKg: Double?
    let onSetCompleted: (Bool) -> Void
    let onDelete: () -> Void

    @State private var showPlates = false
    @State private var showActions = false

    private var muscleColor: Color {
        ExerciseDefinition.find(name: exercise.name)?.color ?? .brand
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let hint = overloadHint {
                hintBanner(hint)
            }
            if let last = lastSummary {
                lastBanner(last)
            }
            sets
            controls
            if showPlates, let first = exercise.sets.first, let weight = first.weight {
                PlateCalculatorView(
                    targetWeightKg: units.toKg(weight),
                    barWeightKg: bar,
                    availablePlatesKg: plates,
                    units: units
                )
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
        }
        .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Color.hairline.opacity(0.4), lineWidth: 0.5)
        )
        .confirmationDialog("Exercise actions",
                            isPresented: $showActions, titleVisibility: .hidden) {
            Button("Add warm-up set") { addSet(warmup: true) }
            Button("Add working set") { addSet(warmup: false) }
            Button("Remove exercise", role: .destructive) { onDelete() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(muscleColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Text(exercise.muscleGroup)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { showActions = true } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: Hint banners

    private var overloadHint: String? {
        guard let lastKg = lastWeightKg else { return nil }
        let suggestKg = recommendedKg ?? (lastKg + 2.5)
        guard suggestKg > lastKg + 0.01 else { return nil }
        let v = units.from(kg: suggestKg)
        let lastV = units.from(kg: lastKg)
        return "Try \(v.prettyWeight) \(units.label) — up from \(lastV.prettyWeight)"
    }

    @ViewBuilder
    private func hintBanner(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.brandSuccess)
            Text(text)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.brandSuccess)
            Spacer()
            Text("OVERLOAD")
                .font(.system(size: 9, weight: .heavy))
                .kerning(0.6)
                .foregroundStyle(.brandSuccess.opacity(0.65))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.brandSuccess.opacity(0.08))
    }

    private var lastSummary: String? {
        guard let kg = lastWeightKg, let reps = lastReps else { return nil }
        let v = units.from(kg: kg)
        return "Last: \(v.prettyWeight) \(units.label) × \(reps)"
    }

    @ViewBuilder
    private func lastBanner(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
    }

    // MARK: Sets

    private var sets: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("SET")
                    .frame(width: 36, alignment: .leading)
                Text("WEIGHT")
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("REPS")
                    .frame(width: 70, alignment: .center)
                Text("")
                    .frame(width: 38)
            }
            .font(.system(size: 9, weight: .heavy))
            .kerning(0.6)
            .foregroundStyle(.secondary)

            if exercise.sets.isEmpty {
                Text("No sets yet — tap + below")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.surfaceInset, in: RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(exercise.sets.indices, id: \.self) { i in
                    SetInputRow(
                        index: i,
                        set: setBinding(i),
                        units: units,
                        suggestKg: i == 0 ? (recommendedKg ?? lastWeightKg) : nil,
                        onComplete: { handleSetComplete(at: i) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func setBinding(_ i: Int) -> Binding<DraftSet> {
        Binding(
            get: { exercise.sets[i] },
            set: { exercise.sets[i] = $0 }
        )
    }

    // MARK: Bottom controls

    private var controls: some View {
        HStack(spacing: 8) {
            Button { addSet(warmup: false) } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.pressable(scale: 0.96, haptic: .soft))

            Button {
                withAnimation(Theme.Motion.snappy) { showPlates.toggle() }
            } label: {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(showPlates ? Color.white : Color.brand)
                    .frame(width: 44, height: 40)
                    .background(showPlates ? Color.brand : Color.brand.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.pressable(scale: 0.94, haptic: .light))
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
    }

    // MARK: Actions

    private func addSet(warmup: Bool) {
        var s = DraftSet(isWarmup: warmup)
        // Pre-fill from previous set or recommendation
        if let last = exercise.sets.last(where: { $0.weight != nil }) {
            s.weight = last.weight
            s.reps = exercise.targetReps
        } else if let rec = recommendedKg {
            s.weight = units.from(kg: rec)
            s.reps = exercise.targetReps
        } else if let last = lastWeightKg {
            s.weight = units.from(kg: last)
            s.reps = lastReps ?? exercise.targetReps
        } else {
            s.reps = exercise.targetReps
        }
        withAnimation(Theme.Motion.snappy) {
            exercise.sets.append(s)
        }
        Haptic.light()
    }

    private func handleSetComplete(at i: Int) {
        guard i < exercise.sets.count else { return }
        var set = exercise.sets[i]
        set.completed = true
        set.completedAt = .now
        exercise.sets[i] = set

        var beatsPR = false
        if let kg = set.weight.map(units.toKg), let reps = set.reps, !set.isWarmup, reps > 0, kg > 0 {
            let e1rm = reps == 1 ? kg : kg * (1 + Double(reps) / 30.0)
            if e1rm > (bestE1RMKg ?? 0) + 0.001 { beatsPR = true }
        }
        Haptic.success()
        onSetCompleted(beatsPR)
    }
}

// MARK: - Single set row

private struct SetInputRow: View {
    let index: Int
    @Binding var set: DraftSet
    let units: WeightUnit
    let suggestKg: Double?
    let onComplete: () -> Void

    @State private var weightStr: String = ""
    @State private var repsStr: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Text(set.isWarmup ? "W" : "\(index + 1)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(set.isWarmup ? .brandWarn : (set.completed ? .brandSuccess : .secondary))
                .frame(width: 36, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill((set.completed ? Color.brandSuccess : Color.brand).opacity(set.completed ? 0.18 : 0.06))
                )

            // Weight field
            TextField(weightPlaceholder, text: $weightStr)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.surfaceInset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10).strokeBorder(
                        set.completed ? Color.brandSuccess.opacity(0.4) : .clear, lineWidth: 1
                    )
                )
                .onChange(of: weightStr) { _, new in
                    set.weight = Double(new.replacingOccurrences(of: ",", with: "."))
                }
                .onAppear {
                    if let w = set.weight {
                        weightStr = w.prettyWeight
                    } else if let s = suggestKg {
                        let v = units.from(kg: s)
                        weightStr = v.prettyWeight
                        set.weight = v
                    }
                }

            // Reps field
            TextField("0", text: $repsStr)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .padding(.vertical, 10)
                .frame(width: 70)
                .background(Color.surfaceInset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10).strokeBorder(
                        set.completed ? Color.brandSuccess.opacity(0.4) : .clear, lineWidth: 1
                    )
                )
                .onChange(of: repsStr) { _, new in
                    set.reps = Int(new)
                }
                .onAppear {
                    if let r = set.reps { repsStr = "\(r)" }
                }

            // Complete button
            Button {
                guard !set.completed else {
                    set.completed = false
                    Haptic.warning()
                    return
                }
                onComplete()
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(set.completed ? .brandSuccess : .secondary)
            }
            .buttonStyle(.pressable(scale: 0.85, haptic: .none))
            .frame(width: 38)
        }
    }

    private var weightPlaceholder: String {
        if let s = suggestKg {
            return units.from(kg: s).prettyWeight
        }
        return units.label
    }
}

// MARK: - PR Toast (animated banner)

private struct PRToast: View {
    let title: String
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.brandTrophy)
                .scaleEffect(bounce ? 1.15 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.5).repeatCount(2), value: bounce)
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(Color.brandTrophy.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .brandTrophy.opacity(0.3), radius: 16, x: 0, y: 8)
        .onAppear { bounce = true }
    }
}

// MARK: - Add Exercise Sheet

private struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var muscleFilter: String? = nil

    let onPick: (ExerciseDefinition) -> Void

    private var filtered: [ExerciseDefinition] {
        var r = ExerciseDefinition.search(search)
        if let m = muscleFilter { r = r.filter { $0.muscleGroup == m } }
        return r
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "All", selected: muscleFilter == nil) { muscleFilter = nil }
                        ForEach(ExerciseDefinition.muscleGroups, id: \.self) { m in
                            FilterChip(label: m, selected: muscleFilter == m) {
                                muscleFilter = muscleFilter == m ? nil : m
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }

                List(filtered) { ex in
                    Button {
                        onPick(ex); Haptic.success(); dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(ex.color.opacity(0.15))
                                Image(systemName: ex.icon)
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(ex.color)
                            }
                            .frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name).font(.system(size: 15, weight: .heavy, design: .rounded))
                                Text("\(ex.muscleGroup) · \(ex.equipment)")
                                    .font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if ex.isCompound {
                                Chip(text: "Compound", color: .brand)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .searchable(text: $search, prompt: "Search exercises")
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { Haptic.selection(); action() }) {
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(selected ? Color.brand : Color.surfaceRaised, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.hairline.opacity(selected ? 0 : 0.4), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout complete data (consumed by WorkoutCompleteView)

struct WorkoutCompleteData: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let durationMinutes: Int
    let totalSets: Int
    let totalVolumeKg: Double
    let exerciseCount: Int
    let newPRs: [String]
}
