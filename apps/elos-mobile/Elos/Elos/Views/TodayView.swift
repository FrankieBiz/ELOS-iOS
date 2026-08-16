import SwiftUI
import SwiftData

// MARK: - Schedule data model (local to Today)
private struct ScheduleRow: Identifiable {
    let id = UUID()
    let time: String
    let label: String
    let subtitle: String?
    let moduleColor: Color
    let duration: String
    let done: Bool
    let isCTA: Bool
}


// MARK: - Main View
struct TodayView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainingContext: TrainingContext
    // Existence check only (not the switching logic itself, which GymSwitcherControl owns) — needed
    // so an empty gym list doesn't leave a blank padded card floating in the middle of the screen.
    @Query private var gyms: [GymRecord]

    /// Whether a widget has anything to show right now. Kept here rather than in the layout store
    /// because it's a fact about today's data, not a preference — and because only this screen knows
    /// that "gym switcher" needs both an active split *and* at least one saved gym.
    private func isAvailable(_ section: LayoutSection) -> Bool {
        switch section {
        case .todayRecovery:    return vm.healthSnapshot.recoveryHint != nil
        case .todayGymSwitcher: return vm.activeSplit != nil && !gyms.isEmpty
        case .todayNextWorkout: return vm.nextTrainingDay != nil
        case .todayLatestPR:    return !vm.personalRecords.isEmpty
        case .todayBodyWeight:  return (vm.healthSnapshot.bodyWeightKg ?? 0) > 0
        case .todayMuscleFocus: return vm.muscleVolume.contains { $0.current > 0 }
        default:                return true
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            // The whole screen is now assembled from the stored arrangement rather than a fixed
            // list — order, width and visibility all come from `LayoutStore`. What used to be the
            // hard-coded "quick stats" grid is three independent half/full-width widgets, which is
            // why sleep and volume can now be split up, swapped, or sent to the bottom.
            SectionStack(screen: .today, spacing: 24, isAvailable: isAvailable) { section in
                switch section {
                case .todayGreeting:    headerSection
                case .todayRecovery:    recoveryHintCard(vm.healthSnapshot.recoveryHint ?? "")
                case .todayGymSwitcher: gymSwitcherCard
                case .todayBrief:       DailyBriefCard()
                case .todayHabits:      habitsSection
                case .todaySchedule:    scheduleSection
                case .todayUpcoming:    upcomingDueSection
                case .todaySleep:       sleepCard
                case .todayGymVolume:   gymVolCard
                case .todayHydration:   hydrationCard

                case .todayStreak:            StreakWidget()
                case .todaySessionsThisWeek:  SessionsThisWeekWidget()
                case .todayWeeklyVolume:      WeeklyVolumeWidget()
                case .todayNextWorkout:       NextWorkoutWidget()
                case .todayLatestPR:          LatestPRWidget()
                case .todayReadiness:         ReadinessWidget()
                case .todayBodyWeight:        BodyWeightWidget()
                case .todayMuscleFocus:       MuscleFocusWidget()

                default: EmptyView()
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.xl)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .elosPageBackground()
        // This screen has a custom header instead of a navigation bar, so nothing was covering the
        // status bar: scrolled content ran straight into the clock and became unreadable. A blur
        // pinned over the top safe area lets content pass *behind* it, which is what the system
        // toolbar would have done.
        .overlay(alignment: .top) { statusBarScrim }
    }

    @ViewBuilder
    private var gymSwitcherCard: some View {
        // Reachable from the screen actually opened every day, instead of three taps deep into a
        // specific split's detail view — switching gyms changes what today's workout actually is,
        // and this used to be undiscoverable from here.
        if let split = vm.activeSplit {
            GymSwitcherControl(split: split)
                .padding(Space.card)
                .elosCard()
        }
    }

    private var statusBarScrim: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: proxy.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
    }

    // MARK: Recovery hint (from Apple Health resting HR vs baseline)
    private func recoveryHintCard(_ hint: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.text.square.fill").foregroundStyle(Color.warn)
            Text(hint).font(.subheadline).foregroundStyle(Color.primary.opacity(0.85))
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.warn.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Header
    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.todayDateString)
                    .elosSectionLabel()
                // largeTitle + a two-line greeting was the single biggest waste of space in the app.
                // One line, a step down the ramp, and it scales rather than wraps for long names.
                Text(vm.greeting)
                    .font(.title).fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: Space.s)

            // Today is the one screen with no navigation bar to hang a toolbar item off, so the
            // entry point rides in the header instead.
            CustomizeScreenButton(screen: .today)
        }
    }

    // MARK: Habits
    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                // With no habits yet this read "HABITS · 0/0" beside an empty ring stranded at the
                // far right — a progress gauge for nothing, and a count that looks like a failure
                // rather than an invitation. Both only appear once there's something to track.
                Text(vm.habits.isEmpty ? "HABITS" : "HABITS · \(vm.doneHabits)/\(vm.habits.count)")
                    .elosSectionLabel()
                Spacer()
                if !vm.habits.isEmpty {
                    ProgressRing(
                        progress: Double(vm.doneHabits) / Double(vm.habits.count),
                        color: .mHabits,
                        lineWidth: 3,
                        size: 28
                    )
                    .accessibilityLabel("\(vm.doneHabits) of \(vm.habits.count) habits done")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.habits) { habit in
                        HabitPillView(habit: habit) {
                            vm.toggleHabit(id: habit.id)
                        }
                    }
                    Button {
                        vm.showingAddHabit = true
                    } label: {
                        HStack(spacing: Space.xs + 2) {
                            Image(systemName: "plus")
                                .font(.system(.footnote, weight: .semibold))
                            Text(vm.habits.isEmpty ? "Add your first habit" : "Add")
                                .font(.system(.footnote, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Space.l)
                        .padding(.vertical, Space.m)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: Schedule

    private func moduleColor(for type: String) -> Color {
        switch type {
        case "gym":                    return .mGym
        case "exam":                   return .mExams
        case "assignment":             return .mExams
        case "class":                  return .mSched
        case "meal":                   return .mNutri
        case "sleep", "health":        return .mHealth
        default:                       return Color.secondary
        }
    }

    private var todaySchedule: [ScheduleRow] {
        let rows = vm.buildScheduleRows(for: Date())
        return rows.map { row in
            let isCTA = row.moduleType == "gym" && !row.isDone
            return ScheduleRow(
                time: row.time,
                label: row.title,
                subtitle: isCTA ? "Tap to start →" : nil,
                moduleColor: moduleColor(for: row.moduleType),
                duration: row.durationMinutes > 0 ? "\(row.durationMinutes)m" : "—",
                done: row.isDone,
                isCTA: isCTA
            )
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("TODAY'S SCHEDULE")
            let rows = todaySchedule
            if rows.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No events scheduled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Sync Canvas or set an active split in Training.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .elosCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                        ScheduleRowView(row: row) {
                            if row.isCTA {
                                vm.prepareExercisesForToday()
                                trainingContext.startSession(activeSplit: vm.activeSplit)
                                vm.showingSession = true
                            }
                        }
                        if idx < rows.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .elosCard()
            }
        }
    }

    // MARK: Upcoming Due
    private var upcomingDueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("UPCOMING DUE")
            VStack(spacing: 0) {
                let pending = vm.assignments.filter { !$0.done }.prefix(3)
                if pending.isEmpty {
                    // "All caught up! 🎉" — a party popper and an exclamation mark for the routine
                    // state of having no homework due. Stated plainly it reads as information
                    // rather than the app congratulating you.
                    Label("Nothing due", systemImage: "checkmark.circle")
                        .font(.elosBody)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(Space.gutter)
                } else {
                    ForEach(Array(pending.enumerated()), id: \.element.id) { idx, assign in
                        AssignmentRow(assign: assign) {
                            vm.toggleAssignment(id: assign.id)
                        }
                        if idx < pending.count - 1 { Divider().padding(.leading, 44) }
                    }
                }
                Divider()
                Button {
                    vm.selectedTab = .plan
                } label: {
                    HStack {
                        Text("View all assignments")
                            .font(.subheadline)
                            .foregroundStyle(Color.tint)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
            }
            .elosCard()
        }
    }

    // MARK: Quick Stats
    //
    // These were a fixed "QUICK STATS" grid — sleep and volume paired, hydration full width. They're
    // three independent widgets now, each carrying its own half/full width preference, so the same
    // default arrangement falls out of `SectionRowPacker` while any other one is a drag away.

    private var sleepCard: some View {
        Button {
            vm.showingLogSleep = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(Color.mHealth).frame(width: 8, height: 8)
                    Text("SLEEP")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.mHealth)
                }
                if let last = vm.sleepLog.first {
                    Text(String(format: "%.1f", last.duration) + "h")
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("Qual. \(qualityLabel(last.quality))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Text("Log sleep →")
                        .font(.caption)
                        .foregroundStyle(Color.mHealth)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .elosCard()
        }
        .buttonStyle(.plain)
    }

    private var gymVolCard: some View {
        // Three states, because the number means something different in each. Previously it showed only
        // the live draft, so it read "0 — tap to train" right after you'd finished a workout.
        StatCard(color: .mGym, label: "GYM VOL",
                 value: gymVolString,
                 sub: {
                     if vm.sessionVolumeKg > 0 { return "\(vm.weightUnit.label) this session" }
                     if vm.todayVolumeKg > 0   { return "\(vm.weightUnit.label) today" }
                     return "\(vm.weightUnit.label) — tap to train"
                 }()) {
            vm.selectedTab = .train
        }
    }

    private var gymVolString: String {
        let vol = vm.weightUnit.fromKg(vm.todayVolumeKg)
        if vol >= 1000 { return String(format: "%.1fk", vol / 1000) }
        return String(format: "%.0f", vol)
    }

    private var hydrationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(Color.mNutri).frame(width: 8, height: 8)
                Text("HYDRATION")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.mNutri)
            }
            Text("\(vm.hydration)")
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text("of \(vm.hydGoal) oz")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach([8, 16, 32], id: \.self) { oz in
                    Button("+\(oz)") { HapticManager.impact(.light); vm.addHydration(oz: oz) }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.mNutri)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.mNutri.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .buttonStyle(.plain)
                }
            }
            HStack(spacing: 6) {
                ForEach([8, 16, 32], id: \.self) { oz in
                    Button("-\(oz)") { HapticManager.impact(.light); vm.removeHydration(oz: oz) }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .elosCard()
    }

    // MARK: Helpers

    /// Routed through the shared modifier rather than restating the font here, so the accent-headers
    /// preference reaches this screen's headers along with everywhere else's.
    private func sectionHeader(_ text: String) -> some View {
        Text(text).elosSectionLabel()
    }

    private func qualityLabel(_ q: Int) -> String {
        switch q {
        case 1: return "Terrible"
        case 2: return "Poor"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return "—"
        }
    }
}

// MARK: - Stat Card
private struct StatCard: View {
    let color: Color
    let label: String
    let value: String
    let sub: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                }
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .elosCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Habit Pill
private struct HabitPillView: View {
    let habit: Habit
    let onToggle: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            HapticManager.impact(habit.done ? .light : .medium)
            onToggle()
        }) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(habit.done ? Color.tint : Color.secondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if habit.done {
                        Circle().fill(Color.tint).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.label)
                        .font(.system(.footnote, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("\(habit.streak)d streak")
                        .font(.elosNumeric(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(habit.done ? Color.tintSoft : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
            .scaleEffect(pressed ? 0.96 : 1)
            .animation(.elosPress, value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - Schedule Row
private struct ScheduleRowView: View {
    let row: ScheduleRow
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(row.time)
                    .font(.elosNumeric(.footnote, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)

                ModuleBarView(color: row.moduleColor, opacity: row.done ? 0.5 : 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.label)
                        .font(.subheadline)
                        .strikethrough(row.done)
                        .foregroundStyle(row.done ? Color.secondary : Color.primary)
                    if let sub = row.subtitle {
                        Text(sub)
                            .font(.caption)
                            .foregroundStyle(row.moduleColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if row.duration != "—" {
                    Text(row.duration)
                        .font(.elosNumeric(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(row.isCTA ? Color.mGym.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(!row.isCTA && !row.done)
    }
}

// MARK: - Assignment Row
private struct AssignmentRow: View {
    let assign: Assignment
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(assign.done ? Color.good : Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if assign.done {
                        Circle().fill(Color.good).frame(width: 24, height: 24)
                        Image(systemName: "checkmark").font(.system(.caption2, weight: .bold)).foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(assign.name)
                        .font(.subheadline)
                        .strikethrough(assign.done)
                        .foregroundStyle(assign.done ? .secondary : .primary)
                    Text("\(assign.subject) · \(DateDisplay.friendly(assign.due))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if assign.urgent && !assign.done {
                    ChipView(label: "Due soon", foreground: .mExams, background: .mExams.opacity(0.15))
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

