import SwiftUI
import SwiftData

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
    @State private var showDiscardConfirm = false
    @State private var showFinishConfirm = false
    @State private var completionData: WorkoutCompleteData? = nil
    @State private var newPRsThisSession: Set<String> = []
    @State private var prToastTitle: String? = nil
    @State private var flashTrigger = 0

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
            Color.vBG.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if isResting {
                    restBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                exerciseList
            }

            if let title = prToastTitle {
                VStack {
                    prToast(title)
                        .padding(.top, 90)
                    Spacer()
                }
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(ticker) { _ in
            elapsed += 1
            if isResting { restRemaining = max(0, restRemaining - 1) }
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet { ex in addExercise(ex) }
        }
        .alert("Discard workout?", isPresented: $showDiscardConfirm) {
            Button("Discard", role: .destructive) { appState.activeWorkout = nil }
            Button("Keep going", role: .cancel) {}
        } message: { Text("Your sets won't be saved.") }
        .alert("Finish workout?", isPresented: $showFinishConfirm) {
            Button("Finish", role: .none) { finishWorkout() }
            Button("Keep going", role: .cancel) {}
        } message: { Text("\(totalCompletedSets) of \(totalPlannedSets) sets completed.") }
        .fullScreenCover(item: $completionData) { data in
            WorkoutCompleteView(data: data, units: appState.units) {
                completionData = nil
                appState.activeWorkout = nil
            }
        }
    }

    // MARK: Top bar (HUD)

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    Haptic.light(); showDiscardConfirm = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.vLabel)
                        .frame(width: 32, height: 32)
                        .background(Color.vSurfaceHigh)
                        .overlay(Rectangle().strokeBorder(Color.vLine, lineWidth: 0.5))
                }
                .buttonStyle(.pressable(scale: 0.9, haptic: .none))

                VStack(alignment: .leading, spacing: 1) {
                    Text("MISSION TIME")
                        .font(.system(size: 8, weight: .heavy))
                        .kerning(1.4)
                        .foregroundStyle(.vLabelFaint)
                    Text(formatElapsed(elapsed))
                        .font(Theme.Font.mono(20, .black))
                        .foregroundStyle(.vLabel)
                }

                Spacer()

                Button {
                    Haptic.medium(); showFinishConfirm = true
                } label: {
                    Text("FINISH")
                        .font(.system(size: 11, weight: .black))
                        .kerning(1.4)
                        .foregroundStyle(.vBG)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.vSignal)
                }
                .buttonStyle(.pressable(scale: 0.95, haptic: .none))
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, 6)

            // Title + progress
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.title.uppercased())
                        .font(.system(size: 14, weight: .black))
                        .kerning(0.6)
                        .foregroundStyle(.vLabel)
                        .lineLimit(1)
                    Text("\(totalCompletedSets) / \(totalPlannedSets) SETS COMPLETE")
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(1.0)
                        .foregroundStyle(.vLabelMute)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, 10)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.vSurfaceHigh).frame(height: 3)
                    Rectangle()
                        .fill(Color.vSignal)
                        .frame(width: geo.size.width * progressFraction, height: 3)
                        .animation(Theme.Motion.snappy, value: progressFraction)
                }
            }
            .frame(height: 3)
            .padding(.top, 10)

            Hairline()
        }
    }

    private var progressFraction: Double {
        guard totalPlannedSets > 0 else { return 0 }
        return Double(totalCompletedSets) / Double(totalPlannedSets)
    }

    // MARK: Rest banner

    private var restBanner: some View {
        HStack(spacing: 12) {
            Text(formatRest(restRemaining))
                .font(Theme.Font.mono(28, .black))
                .foregroundStyle(.vSignal)
            VStack(alignment: .leading, spacing: 1) {
                Text("REST")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(1.4)
                    .foregroundStyle(.vLabelMute)
                Text("Recovery in progress")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.vLabel)
            }
            Spacer()
            Button { restRemaining = max(0, restRemaining + 15); Haptic.light() } label: {
                Text("+15s")
                    .font(.system(size: 10, weight: .black))
                    .kerning(0.6)
                    .foregroundStyle(.vLabel)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .overlay(Rectangle().strokeBorder(Color.vLineHigh, lineWidth: 0.5))
            }
            .buttonStyle(.pressable(scale: 0.94, haptic: .none))
            Button { restRemaining = 0; Haptic.medium() } label: {
                Text("SKIP")
                    .font(.system(size: 10, weight: .black))
                    .kerning(1.0)
                    .foregroundStyle(.vBG)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.vSignal)
            }
            .buttonStyle(.pressable(scale: 0.94, haptic: .none))
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, 10)
        .background(Color.vSurface)
        .overlay(Rectangle().fill(Color.vLine).frame(height: 0.5), alignment: .bottom)
    }

    // MARK: Exercise list

    private var exerciseList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if workout.exercises.isEmpty {
                    EmptyStateCard(
                        icon: "plus.app",
                        title: "Empty Roster",
                        subtitle: "Add your first exercise to begin logging.",
                        actionTitle: "Add Exercise"
                    ) { showAddExercise = true }
                    .padding(.top, 40)
                }

                ForEach(workout.exercises.indices, id: \.self) { idx in
                    let exercise = workout.exercises[idx]
                    ActiveExerciseCard(
                        index: idx + 1,
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
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, idx == 0 ? Theme.Space.md : Theme.Space.sm)
                    .prFlash(trigger: flashTrigger)
                }

                Button { showAddExercise = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .black))
                        Text("ADD EXERCISE")
                            .font(.system(size: 12, weight: .black))
                            .kerning(1.4)
                    }
                    .foregroundStyle(.vSignal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .strokeBorder(Color.vSignal, lineWidth: 1)
                    )
                }
                .buttonStyle(.pressable(scale: 0.97, haptic: .light))
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.md)

                Spacer(minLength: 80)
            }
        }
    }

    // MARK: PR toast

    private func prToast(_ title: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.vSignal).frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("NEW RECORD")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(1.4)
                    .foregroundStyle(.vBG.opacity(0.6))
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .black))
                    .kerning(0.6)
                    .foregroundStyle(.vBG)
            }
            Spacer()
            Image(systemName: "rosette")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.vBG)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.vSignal)
        .padding(.horizontal, Theme.Space.md)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Bindings

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

    private func startRest(seconds: Int) {
        restTotal = seconds
        withAnimation(Theme.Motion.snappy) { restRemaining = seconds }
    }

    private func celebratePR(for exerciseName: String) {
        flashTrigger += 1
        Haptic.success()
        newPRsThisSession.insert(exerciseName)
        withAnimation(Theme.Motion.snappy) { prToastTitle = exerciseName }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(.easeOut(duration: 0.4)) { prToastTitle = nil }
        }
    }

    // MARK: Finish

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

    // MARK: Helpers

    private func formatElapsed(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }

    private func formatRest(_ s: Int) -> String {
        let m = s / 60, sec = s % 60
        return String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Active exercise card

private struct ActiveExerciseCard: View {
    let index: Int
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

    @State private var showActions = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                IndexBadge(n: index, active: true, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(exercise.name.uppercased())
                        .font(.system(size: 13, weight: .black))
                        .kerning(0.6)
                        .foregroundStyle(.vLabel)
                        .lineLimit(1)
                    Text(exercise.muscleGroup.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(1.2)
                        .foregroundStyle(.vLabelMute)
                }
                Spacer()
                Button { showActions = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.vLabelMute)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            if let hint = overloadHint {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .black))
                    Text(hint.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(0.8)
                    Spacer()
                    Text("OVERLOAD")
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(1.2)
                        .foregroundStyle(.vSuccess.opacity(0.7))
                }
                .foregroundStyle(.vSuccess)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.vSuccess.opacity(0.06))
            } else if let last = lastSummary {
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.system(size: 9, weight: .heavy))
                    Text(last.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(0.8)
                    Spacer()
                }
                .foregroundStyle(.vLabelMute)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.vSurfaceHigh.opacity(0.5))
            }

            Hairline()

            // Column headers
            HStack(spacing: 0) {
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
            .kerning(1.2)
            .foregroundStyle(.vLabelFaint)
            .padding(.horizontal, 12).padding(.vertical, 8)

            // Sets
            if exercise.sets.isEmpty {
                Text("No sets yet — tap below to add one.")
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.4)
                    .foregroundStyle(.vLabelMute)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(Color.vBG)
            } else {
                VStack(spacing: 0) {
                    ForEach(exercise.sets.indices, id: \.self) { i in
                        if i > 0 { Hairline() }
                        SetInputRow(
                            index: i,
                            set: setBinding(i),
                            units: units,
                            suggestKg: i == 0 ? (recommendedKg ?? lastWeightKg) : nil,
                            onComplete: { handleSetComplete(at: i) }
                        )
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
            }

            Hairline()

            // Add set
            Button { addSet(warmup: false) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .black))
                    Text("ADD SET")
                        .font(.system(size: 11, weight: .black))
                        .kerning(1.2)
                }
                .foregroundStyle(.vLabelMute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .buttonStyle(.pressable(scale: 0.98, haptic: .soft))
        }
        .background(Color.vSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .confirmationDialog("Exercise actions",
                            isPresented: $showActions, titleVisibility: .hidden) {
            Button("Add warm-up set") { addSet(warmup: true) }
            Button("Add working set") { addSet(warmup: false) }
            Button("Remove exercise", role: .destructive) { onDelete() }
        }
    }

    private var overloadHint: String? {
        guard let lastKg = lastWeightKg else { return nil }
        let suggestKg = recommendedKg ?? (lastKg + 2.5)
        guard suggestKg > lastKg + 0.01 else { return nil }
        let v = units.from(kg: suggestKg)
        let lastV = units.from(kg: lastKg)
        return "Try \(v.prettyWeight) \(units.label) (was \(lastV.prettyWeight))"
    }

    private var lastSummary: String? {
        guard let kg = lastWeightKg, let reps = lastReps else { return nil }
        let v = units.from(kg: kg)
        return "Last: \(v.prettyWeight) \(units.label) × \(reps)"
    }

    private func setBinding(_ i: Int) -> Binding<DraftSet> {
        Binding(get: { exercise.sets[i] }, set: { exercise.sets[i] = $0 })
    }

    private func addSet(warmup: Bool) {
        var s = DraftSet(isWarmup: warmup)
        if let last = exercise.sets.last(where: { $0.weight != nil }) {
            s.weight = last.weight
            s.reps = exercise.targetReps
        } else if let rec = recommendedKg {
            s.weight = units.from(kg: rec); s.reps = exercise.targetReps
        } else if let last = lastWeightKg {
            s.weight = units.from(kg: last); s.reps = lastReps ?? exercise.targetReps
        } else {
            s.reps = exercise.targetReps
        }
        withAnimation(Theme.Motion.snappy) { exercise.sets.append(s) }
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

// MARK: - Set input row

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
            // Set index / W marker
            ZStack {
                Rectangle()
                    .fill(set.completed ? Color.vSignal : (set.isWarmup ? Color.vWarn.opacity(0.18) : Color.vSurfaceHigh))
                Text(set.isWarmup ? "W" : "\(index + 1)")
                    .font(Theme.Font.mono(11, .black))
                    .foregroundStyle(set.completed ? Color.vBG : (set.isWarmup ? Color.vWarn : Color.vLabelMute))
            }
            .frame(width: 36, height: 38)

            TextField(weightPlaceholder, text: $weightStr)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(Theme.Font.mono(15, .black))
                .foregroundStyle(.vLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(set.completed ? Color.vSignal.opacity(0.08) : Color.vInset)
                .overlay(Rectangle().strokeBorder(set.completed ? Color.vSignal.opacity(0.4) : Color.vLine, lineWidth: 0.5))
                .onChange(of: weightStr) { _, new in
                    set.weight = Double(new.replacingOccurrences(of: ",", with: "."))
                }
                .onAppear {
                    if let w = set.weight { weightStr = w.prettyWeight }
                    else if let s = suggestKg {
                        let v = units.from(kg: s)
                        weightStr = v.prettyWeight
                        set.weight = v
                    }
                }

            TextField("0", text: $repsStr)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(Theme.Font.mono(15, .black))
                .foregroundStyle(.vLabel)
                .padding(.vertical, 10)
                .frame(width: 70)
                .background(set.completed ? Color.vSignal.opacity(0.08) : Color.vInset)
                .overlay(Rectangle().strokeBorder(set.completed ? Color.vSignal.opacity(0.4) : Color.vLine, lineWidth: 0.5))
                .onChange(of: repsStr) { _, new in
                    set.reps = Int(new)
                }
                .onAppear {
                    if let r = set.reps { repsStr = "\(r)" }
                }

            Button {
                guard !set.completed else {
                    set.completed = false; Haptic.warning(); return
                }
                onComplete()
            } label: {
                Image(systemName: set.completed ? "checkmark" : "circle")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(set.completed ? Color.vBG : Color.vLabelMute)
                    .frame(width: 38, height: 38)
                    .background(set.completed ? Color.vSignal : Color.vSurfaceHigh)
                    .overlay(Rectangle().strokeBorder(set.completed ? Color.clear : Color.vLine, lineWidth: 0.5))
            }
            .buttonStyle(.pressable(scale: 0.88, haptic: .none))
        }
    }

    private var weightPlaceholder: String {
        if let s = suggestKg { return units.from(kg: s).prettyWeight }
        return units.label
    }
}

// MARK: - Add exercise sheet

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
                    HStack(spacing: 6) {
                        FilterChip(label: "All", selected: muscleFilter == nil) { muscleFilter = nil }
                        ForEach(ExerciseDefinition.muscleGroups, id: \.self) { m in
                            FilterChip(label: m, selected: muscleFilter == m) {
                                muscleFilter = muscleFilter == m ? nil : m
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }

                List(filtered) { ex in
                    Button {
                        onPick(ex); Haptic.success(); dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Rectangle().fill(ex.color).frame(width: 3, height: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name.uppercased())
                                    .font(.system(size: 12, weight: .black))
                                    .kerning(0.4)
                                    .foregroundStyle(.vLabel)
                                Text("\(ex.muscleGroup.uppercased()) · \(ex.equipment.uppercased())")
                                    .font(.system(size: 9, weight: .heavy))
                                    .kerning(0.8)
                                    .foregroundStyle(.vLabelMute)
                            }
                            Spacer()
                            if ex.isCompound {
                                Chip(text: "Compound", color: .vSignal)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.vBG)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.vBG)
                    .listRowSeparatorTint(Color.vLine)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.vBG)
                .searchable(text: $search, prompt: "Search exercises")
            }
            .background(Color.vBG.ignoresSafeArea())
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
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black))
                .kerning(1.0)
                .foregroundStyle(selected ? Color.vBG : Color.vLabelMute)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(selected ? Color.vSignal : Color.vSurfaceHigh)
                .overlay(Rectangle().strokeBorder(selected ? Color.clear : Color.vLine, lineWidth: 0.5))
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
