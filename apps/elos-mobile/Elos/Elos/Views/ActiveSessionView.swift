import SwiftUI
import Combine
import AudioToolbox

struct ActiveSessionView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var context: TrainingContext

    @State private var now               = Date()
    @State private var restSeconds       = 0
    @State private var restTotalSeconds  = 0
    @State private var restActive        = false
    @State private var restPaused        = false
    @State private var activeExerciseId: UUID?
    @State private var showFinishAlert   = false
    @State private var showRPEPrompt     = false
    @State private var pendingSessionRPE = 8
    @State private var showExercisePicker = false
    @State private var undoInfo: UndoInfo?
    @State private var undoCounter       = 0

    private struct UndoInfo: Equatable {
        let id: Int
        let exerciseID: UUID       // resolve the live row by identity, not position
        let setID: UUID
        let loggedSetIndex: Int    // the record's setIndex at log time (for the DB un-log)
        let exerciseName: String
    }

    private let sessionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var sessionTitle: String {
        if let day = vm.currentSplitDay, !day.isRest {
            let name = day.dayName.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? "Today's Workout" : name
        }
        return vm.exercises.isEmpty ? "Free Workout" : "Active Workout"
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Divider()
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    statsRow
                    if context.phase == .warmup {
                        warmupPhaseSection
                    }
                    if let nudge = context.volumeNudge {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.warn)
                            Text(nudge).font(.caption).foregroundStyle(Color.warn)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.warn.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    if let prName = trainVM.newPRExerciseName {
                        prRibbon(exerciseName: prName)
                    }
                    exerciseList
                    finishButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onReceive(sessionTimer) { _ in
            now = Date()   // drives the wall-clock elapsed display (survives backgrounding)
            if restActive && !restPaused && restSeconds > 0 {
                restSeconds -= 1
                if restSeconds == 0 { restDidComplete() }
            }
        }
        .alert("Finish Workout?", isPresented: $showFinishAlert) {
            Button("Finish", role: .destructive) { showRPEPrompt = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Volume: \(vm.weightUnit.formatVolume(kg: trainVM.currentSession?.totalVolume ?? vm.sessionVolumeKg))")
        }
        .sheet(isPresented: $showRPEPrompt, onDismiss: {
            // Swiping the sheet away should still finalize the workout, not silently abandon it
            // and dump the user back into the (already-finished) session.
            finishWorkout(rpe: 0)
        }) {
            SessionRPESheet(
                rpe: $pendingSessionRPE,
                onConfirm: { showRPEPrompt = false; finishWorkout(rpe: pendingSessionRPE) },
                onSkip:    { showRPEPrompt = false; finishWorkout(rpe: 0) }
            )
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView(onPickSingle: { picked in
                let newEx = Exercise(
                    name: picked.name,
                    primaryMuscle: "",
                    secondaryMuscles: [],
                    setsLabel: "3×10",
                    lastBest: "",
                    sets: (0..<3).map { _ in WorkSet(weight: "", reps: "10", rpe: "") },
                    equipmentId: picked.equipmentId,
                    equipmentDedupeKey: picked.equipmentDedupeKey,
                    equipmentBrandName: picked.equipmentBrandName,
                    isGenericExercise: picked.isGenericExercise,
                    supportsAddedWeight: ExerciseCatalog.weightableBodyweightExercises.contains(picked.name)
                )
                vm.exercises.append(newEx)
                showExercisePicker = false
                withAnimation { activeExerciseId = newEx.id }
            })
        }
        .onAppear {
            activeExerciseId = vm.exercises.first?.id
            trainVM.startSession(ownerID: vm.currentUserID)
        }
        .onDisappear {
            // Leaving the session (finish or back) must clear any pending rest alert.
            NotificationManager.cancelRestTimer()
        }
    }

    /// Leave the warmup phase with a bit of feedback so the transition isn't silent.
    private func completeWarmup() {
        HapticManager.impact(.light)
        withAnimation {
            context.warmupPhaseComplete = true
            context.phase = .active
        }
    }

    /// Finalize the session exactly once (guards against the button + onDismiss both firing).
    private func finishWorkout(rpe: Int) {
        guard let session = trainVM.currentSession else { return }
        let splitDay = vm.currentSplitDay
        let summary = trainVM.buildSessionSummary(
            splitDayTemplateID: splitDay?.templateID ?? "",
            splitDayName: splitDay?.dayName ?? ""
        )
        trainVM.finishSession(sessionRPE: rpe, ownerID: vm.currentUserID)
        context.sessionDidEnd(summary: summary)
        // Push to Apple Health if connected (no-op otherwise); the session is finished by now.
        Task { @MainActor in await vm.exportSessionToHealth(session) }
        Task { @MainActor in vm.showingSession = false }
    }

    // MARK: Nav Bar
    private var navBar: some View {
        HStack {
            Button {
                let anyDone = vm.exercises.flatMap(\.sets).contains(where: \.done)
                if anyDone { showFinishAlert = true } else {
                    trainVM.finishSession(sessionRPE: 0, ownerID: vm.currentUserID)
                    vm.showingSession = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                    Text("Train")
                }
                .foregroundStyle(Color.tint)
            }
            .buttonStyle(.plain)

            Spacer()
            Text(sessionTitle).font(.headline).lineLimit(1)
            Spacer()

            Button { showFinishAlert = true } label: {
                Text("Finish").font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.bad)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: Warmup Phase
    private var warmupPhaseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Warmup", systemImage: "flame.fill")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(Color.tint)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                Text("Workout").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Skip") { completeWarmup() }
                .font(.caption).foregroundStyle(.secondary)
            }

            Text("A checklist to get you ready — warmups aren't logged.")
                .font(.caption2).foregroundStyle(.secondary)

            ForEach(context.warmupExercises) { ex in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name).font(.subheadline).fontWeight(.semibold)
                        Text(ex.duration).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Button {
                completeWarmup()
            } label: {
                Text("Done with Warmup")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.tintSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .elosCard()
    }

    // MARK: Stats Row
    private var statsRow: some View {
        HStack {
            statColumn(title: elapsedFormatted, sub: "Elapsed")
            Divider().frame(height: 40)
            statColumn(title: "\(vm.doneSetsCount)/\(vm.totalSetsCount)", sub: "Sets")
            Divider().frame(height: 40)
            statColumn(title: volumeFormatted, sub: "Volume")
        }
        .padding(16)
        .elosCard()
    }

    private func statColumn(title: String, sub: String) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
            Text(sub).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Wall-clock seconds since the session started — derived from the persisted
    /// `startedAt`, so it's correct immediately on resume and after backgrounding.
    private var elapsedSeconds: Int {
        guard let started = trainVM.currentSession?.startedAt else { return 0 }
        return max(0, Int(now.timeIntervalSince(started)))
    }

    private var elapsedFormatted: String {
        let s = elapsedSeconds
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private var volumeFormatted: String {
        vm.weightUnit.formatVolume(kg: trainVM.currentSession?.totalVolume ?? vm.sessionVolumeKg)
    }

    // MARK: Sticky bottom bar (rest timer + undo)

    @ViewBuilder private var bottomBar: some View {
        VStack(spacing: 8) {
            if undoInfo != nil {
                UndoSnackbar(message: "Set logged") { undoLastSet() }
            }
            if restActive {
                RestTimerBar(
                    seconds: restSeconds,
                    totalSeconds: restTotalSeconds,
                    paused: restPaused,
                    nextLabel: nextSetLabel,
                    onMinus: { adjustRest(-RestMath.step) },
                    onPlus:  { adjustRest(RestMath.step) },
                    onPauseToggle: { togglePause() },
                    onSkip: { skipRest() }
                )
            }
        }
    }

    private var nextSetLabel: String? {
        guard let exId = activeExerciseId,
              let ex = vm.exercises.first(where: { $0.id == exId }),
              let nextIdx = ex.sets.firstIndex(where: { !$0.done }) else { return nil }
        return "Set \(nextIdx + 1) · \(ex.name)"
    }

    private func adjustRest(_ delta: Int) {
        restSeconds = RestMath.adjust(restSeconds, by: delta)
        restTotalSeconds = max(restTotalSeconds, restSeconds)
        if restSeconds == 0 {
            skipRest()
        } else {
            NotificationManager.scheduleRestTimer(seconds: restSeconds)
        }
    }

    private func skipRest() {
        restActive = false
        restSeconds = 0
        restPaused = false
        NotificationManager.cancelRestTimer()
    }

    /// Pause must also halt the real OS alert, not just the on-screen bar.
    private func togglePause() {
        restPaused.toggle()
        if restPaused {
            NotificationManager.cancelRestTimer()
        } else if restSeconds > 0 {
            NotificationManager.scheduleRestTimer(seconds: restSeconds)
        }
    }

    /// Fired the instant the countdown reaches zero — the old banner just vanished silently.
    private func restDidComplete() {
        restActive = false
        HapticManager.success()
        AudioServicesPlaySystemSound(1057)   // "Tink" — a gentle in-app rest-done cue
    }

    private func undoLastSet() {
        guard let u = undoInfo else { return }
        // Resolve the live position by identity (indices may have shifted during the window);
        // un-mark the exact WorkSet, but un-log against the record's original setIndex.
        if let eIdx = vm.exercises.firstIndex(where: { $0.id == u.exerciseID }),
           let sIdx = vm.exercises[eIdx].sets.firstIndex(where: { $0.id == u.setID }),
           vm.exercises[eIdx].sets[sIdx].done {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                vm.toggleSet(exerciseIndex: eIdx, setIndex: sIdx)
            }
            trainVM.unlogCompletedSet(exerciseName: u.exerciseName, setIndex: u.loggedSetIndex, ownerID: vm.currentUserID)
        }
        skipRest()
        withAnimation { undoInfo = nil }
    }

    // MARK: PR Ribbon
    private func prRibbon(exerciseName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill").foregroundStyle(.yellow)
            Text("New PR — \(exerciseName)!")
                .font(.subheadline).fontWeight(.semibold)
            Spacer()
        }
        .padding(12)
        .background(Color.yellow.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Exercise List
    private var exerciseList: some View {
        VStack(spacing: 12) {
            if vm.exercises.isEmpty {
                emptyExercisesPrompt
            } else {
                ForEach($vm.exercises) { $ex in
                    let isDone = ex.sets.allSatisfy(\.done)
                    let isActive = activeExerciseId == ex.id
                    let doneSets = ex.sets.filter(\.done).count
                    let suggestion = trainVM.overloadSuggestion(for: ex.name, ownerID: vm.currentUserID, unit: vm.weightUnit, equipmentDedupeKey: ex.equipmentDedupeKey)

                    SessionExerciseCard(
                        exercise: $ex,
                        isDone: isDone,
                        isActive: isActive,
                        doneCount: doneSets,
                        overloadSuggestion: suggestion,
                        overloadTarget: trainVM.overloadTarget(for: ex.name, ownerID: vm.currentUserID, unit: vm.weightUnit, equipmentDedupeKey: ex.equipmentDedupeKey),
                        previousSets: trainVM.previousSets(for: ex.name, ownerID: vm.currentUserID, equipmentDedupeKey: ex.equipmentDedupeKey),
                        unit: vm.weightUnit,
                        onSelect: {
                            withAnimation { activeExerciseId = ex.id }
                        },
                        onSetToggle: { sIdx in
                            let wasDone = ex.sets[sIdx].done
                            let eIdx = vm.exercises.firstIndex(where: { $0.id == ex.id }) ?? 0

                            // Validate before logging so empty/garbage sets never persist.
                            if !wasDone {
                                let reps = Int(ex.sets[sIdx].reps) ?? 0
                                guard reps > 0 else {
                                    vm.showError("Enter reps before completing this set.")
                                    return
                                }
                                let weightVal = max(0, Double(ex.sets[sIdx].weight) ?? 0)
                                let weightKg = vm.weightUnit.toKg(weightVal)
                                let rpe = min(10, max(0, Double(ex.sets[sIdx].rpe) ?? 0))
                                let rest = ex.restSeconds > 0 ? ex.restSeconds : 90

                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    vm.toggleSet(exerciseIndex: eIdx, setIndex: sIdx)
                                }
                                HapticManager.impact(.medium)
                                NotificationManager.scheduleRestTimer(seconds: rest)
                                trainVM.logCompletedSet(
                                    exerciseName: ex.name,
                                    setIndex: sIdx,
                                    weightKg: weightKg,
                                    reps: reps,
                                    rpe: rpe,
                                    ownerID: vm.currentUserID,
                                    equipmentId: ex.equipmentId,
                                    equipmentDedupeKey: ex.equipmentDedupeKey,
                                    equipmentBrandName: ex.equipmentBrandName
                                )
                                restSeconds = rest
                                restTotalSeconds = rest
                                restActive  = true
                                restPaused  = false
                                activeExerciseId = ex.id

                                // Brief undo window for an accidental tap. Capture identities,
                                // not positions, so a mid-window edit can't misdirect the undo.
                                undoCounter += 1
                                let info = UndoInfo(
                                    id: undoCounter,
                                    exerciseID: ex.id,
                                    setID: ex.sets[sIdx].id,
                                    loggedSetIndex: sIdx,
                                    exerciseName: ex.name
                                )
                                withAnimation { undoInfo = info }
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                                    if undoInfo?.id == info.id { withAnimation { undoInfo = nil } }
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    vm.toggleSet(exerciseIndex: eIdx, setIndex: sIdx)
                                }
                                trainVM.unlogCompletedSet(
                                    exerciseName: ex.name,
                                    setIndex: sIdx,
                                    ownerID: vm.currentUserID
                                )
                            }
                        },
                        onSetDelete: { sIdx in
                            // Only offered for not-yet-logged sets, so there's no
                            // server record to remove — just drop the planned row.
                            let eIdx = vm.exercises.firstIndex(where: { $0.id == ex.id }) ?? 0
                            guard sIdx < vm.exercises[eIdx].sets.count,
                                  !vm.exercises[eIdx].sets[sIdx].done else { return }
                            withAnimation { _ = vm.exercises[eIdx].sets.remove(at: sIdx) }
                        },
                        onSetEdit: { sIdx, weightKg, reps, rpe in
                            // Non-destructive in-place edit of an already-logged set.
                            trainVM.updateLoggedSet(
                                exerciseName: ex.name,
                                setIndex: sIdx,
                                newWeightKg: weightKg,
                                newReps: reps,
                                newRPE: rpe,
                                ownerID: vm.currentUserID
                            )
                        }
                    )
                }
            }

            // Always-visible add button so users can add exercises mid-session
            Button {
                showExercisePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.tint)
                    Text("Add Exercise")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.tint)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.tintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyExercisesPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No exercises yet")
                .font(.headline)
            Text("Tap Add Exercise below to start logging sets.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Finish Button
    private var finishButton: some View {
        Button { showFinishAlert = true } label: {
            Label("Finish Workout", systemImage: "stop.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.bad)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session RPE Sheet

private struct SessionRPESheet: View {
    @Binding var rpe: Int
    let onConfirm: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Session RPE").font(.title2).fontWeight(.bold)
                Text("How hard was this workout overall?")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            Text("\(rpe)")
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.tint)

            Slider(value: Binding(get: { Double(rpe) }, set: { rpe = Int($0) }),
                   in: 1...10, step: 1)
                .tint(Color.tint)
                .padding(.horizontal, 32)

            HStack {
                Text("Easy").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Max effort").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 36)

            Button {
                onConfirm()
            } label: {
                Text("Save & Finish")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Button("Skip", action: onSkip)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .presentationDetents([.fraction(0.45)])
    }
}
