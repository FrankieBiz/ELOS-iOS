import SwiftUI
import Combine

struct ActiveSessionView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var context: TrainingContext

    @State private var elapsed           = 0
    @State private var restSeconds       = 0
    @State private var restActive        = false
    @State private var restPaused        = false
    @State private var activeExerciseId: UUID?
    @State private var showFinishAlert   = false
    @State private var showRPEPrompt     = false
    @State private var pendingSessionRPE = 8
    @State private var showExercisePicker = false

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
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    if restActive { restTimerBanner }
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
        .onReceive(sessionTimer) { _ in
            elapsed += 1
            if restActive && !restPaused {
                if restSeconds > 0 { restSeconds -= 1 } else { restActive = false }
            }
        }
        .alert("Finish Workout?", isPresented: $showFinishAlert) {
            Button("Finish", role: .destructive) { showRPEPrompt = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(String(format: "Volume: %.0f kg", trainVM.currentSession?.totalVolume ?? vm.sessionVolume))
        }
        .sheet(isPresented: $showRPEPrompt) {
            SessionRPESheet(rpe: $pendingSessionRPE) {
                let splitDay = vm.currentSplitDay
                let summary = trainVM.buildSessionSummary(
                    splitDayTemplateID: splitDay?.templateID ?? "",
                    splitDayName: splitDay?.dayName ?? ""
                )
                trainVM.finishSession(sessionRPE: pendingSessionRPE, ownerID: vm.currentUserID)
                context.sessionDidEnd(summary: summary)
                showRPEPrompt = false
                Task { @MainActor in vm.showingSession = false }
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView(onPickSingle: { picked in
                let newEx = Exercise(
                    name: picked.name,
                    primaryMuscle: "",
                    secondaryMuscles: [],
                    setsLabel: "3×10",
                    lastBest: "",
                    sets: (0..<3).map { _ in WorkSet(weight: "", reps: "10", rpe: "") }
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
                Button("Skip") {
                    context.warmupPhaseComplete = true
                    context.phase = .active
                }
                .font(.caption).foregroundStyle(.secondary)
            }

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
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                context.warmupPhaseComplete = true
                context.phase = .active
            } label: {
                Text("Done with Warmup")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.tintSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
            Text(title).font(.system(size: 20, weight: .bold, design: .monospaced))
            Text(sub).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var elapsedFormatted: String {
        String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private var volumeFormatted: String {
        let vol = trainVM.currentSession?.totalVolume ?? vm.sessionVolume
        if vol >= 1000 { return String(format: "%.1fk", vol / 1000) }
        return String(format: "%.0f kg", vol)
    }

    // MARK: Rest Timer
    private var restTimerBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .foregroundStyle(restTimerColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Rest timer").font(.caption).foregroundStyle(.secondary)
                Text(restFormatted).font(.system(size: 22, weight: .bold, design: .monospaced))
            }

            Spacer()

            Button(restPaused ? "Resume" : "Pause") { restPaused.toggle() }
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)

            Button("Skip") {
                restActive = false
                restSeconds = 0
                restPaused = false
                NotificationManager.cancelRestTimer()
            }
                .font(.caption).fontWeight(.semibold).foregroundStyle(Color.tint)
        }
        .padding(14)
        .background(Color.mGym.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.tint.opacity(0.25), lineWidth: 1))
    }

    private var restFormatted: String { String(format: "%02d:%02d", restSeconds / 60, restSeconds % 60) }
    private var restTimerColor: Color { restSeconds > 45 ? .good : restSeconds > 15 ? .warn : .bad }

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
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
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
                    let suggestion = trainVM.overloadSuggestion(for: ex.name, ownerID: vm.currentUserID)

                    SessionExerciseCard(
                        exercise: $ex,
                        isDone: isDone,
                        isActive: isActive,
                        doneCount: doneSets,
                        overloadSuggestion: suggestion,
                        previousSets: trainVM.previousSets(for: ex.name, ownerID: vm.currentUserID),
                        onSelect: {
                            withAnimation { activeExerciseId = ex.id }
                        },
                        onSetToggle: { sIdx in
                            let wasDone = ex.sets[sIdx].done
                            let eIdx = vm.exercises.firstIndex(where: { $0.id == ex.id }) ?? 0
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                vm.toggleSet(exerciseIndex: eIdx, setIndex: sIdx)
                            }
                            if !wasDone {
                                HapticManager.impact(.medium)
                                NotificationManager.scheduleRestTimer(seconds: 90)
                                let weightKg = (Double(ex.sets[sIdx].weight) ?? 0) * 0.453592
                                let reps = Int(ex.sets[sIdx].reps) ?? 0
                                let rpe = Double(ex.sets[sIdx].rpe) ?? 0
                                trainVM.logCompletedSet(
                                    exerciseName: ex.name,
                                    setIndex: sIdx,
                                    weightKg: weightKg,
                                    reps: reps,
                                    rpe: rpe,
                                    ownerID: vm.currentUserID
                                )
                                restSeconds = 90
                                restActive  = true
                                restPaused  = false
                                activeExerciseId = ex.id
                            } else {
                                trainVM.unlogCompletedSet(
                                    exerciseName: ex.name,
                                    setIndex: sIdx,
                                    ownerID: vm.currentUserID
                                )
                            }
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
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session RPE Sheet

private struct SessionRPESheet: View {
    @Binding var rpe: Int
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Session RPE").font(.title2).fontWeight(.bold)
                Text("How hard was this workout overall?")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            Text("\(rpe)")
                .font(.system(size: 56, weight: .bold, design: .monospaced))
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
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer()
        }
        .presentationDetents([.fraction(0.45)])
    }
}

// MARK: - Session Exercise Card

private struct SessionExerciseCard: View {
    @Binding var exercise: Exercise
    let isDone: Bool
    let isActive: Bool
    let doneCount: Int
    let overloadSuggestion: String?
    let previousSets: [ExerciseSetRecord]
    let onSelect: () -> Void
    let onSetToggle: (Int) -> Void

    @State private var expanded = true
    @State private var showingSwap = false

    var body: some View {
        VStack(spacing: 0) {
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
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    // Muscle info + overload suggestion
                    HStack {
                        Text("Primary: \(exercise.primaryMuscle)" +
                             (exercise.secondaryMuscles.isEmpty ? "" : " · secondary: \(exercise.secondaryMuscles.prefix(2).joined(separator: ", "))"))
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)

                    if let suggestion = overloadSuggestion {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill").font(.caption).foregroundStyle(Color.good)
                            Text(suggestion).font(.caption).fontWeight(.semibold).foregroundStyle(Color.good)
                        }
                        .padding(.horizontal, 14)
                    }

                    Divider()
                    HStack {
                        Text("#").frame(width: 24)
                        Text("Weight (lb)").frame(maxWidth: .infinity)
                        Text("Reps").frame(width: 50)
                        Text("RPE").frame(width: 40)
                        Image(systemName: "checkmark").frame(width: 36)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 14)

                    ForEach(exercise.sets.indices, id: \.self) { i in
                        let s = exercise.sets[i]
                        let prevWeight: String = i < previousSets.count
                            ? String(format: "%.0f", previousSets[i].weightKg / 0.453592) : ""
                        HStack(spacing: 8) {
                            Text("\(i + 1)")
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                                .frame(width: 24)

                            TextField(prevWeight.isEmpty ? "lb" : prevWeight,
                                      text: $exercise.sets[i].weight)
                                .font(.system(size: 14, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .frame(maxWidth: .infinity)

                            let prevReps: String = i < previousSets.count ? "\(previousSets[i].reps)" : ""
                            TextField(prevReps.isEmpty ? "reps" : prevReps,
                                      text: $exercise.sets[i].reps)
                                .font(.system(size: 14, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .frame(width: 50)

                            TextField("—", text: $exercise.sets[i].rpe)
                                .font(.system(size: 13, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 6).padding(.vertical, 6)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .frame(width: 40)

                            Button { onSetToggle(i) } label: {
                                Image(systemName: s.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(s.done ? Color.good : Color.secondary.opacity(0.5))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: s.done)
                            }
                            .buttonStyle(.plain).frame(width: 36)
                        }
                        .padding(.horizontal, 14)
                        .opacity(s.done ? 0.55 : 1)
                    }

                    Divider()
                    HStack(spacing: 16) {
                        Button("+ Add set") {
                            exercise.sets.append(WorkSet(weight: "", reps: "", rpe: "", done: false))
                        }
                        .font(.caption).foregroundStyle(Color.tint)
                        Button("Swap") { showingSwap = true }
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.bottom, 10)
                }
            }
        }
        .elosCard()
        .sheet(isPresented: $showingSwap) {
            ExerciseSwapSheet(exerciseName: $exercise.name)
        }
    }
}

// MARK: - Exercise Swap Sheet

