import SwiftUI

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

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                DailyBriefCard()
                habitsSection
                scheduleSection
                upcomingDueSection
                quickStatsGrid
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vm.todayDateString)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(vm.greeting)
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }

    // MARK: Habits
    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("HABITS · \(vm.doneHabits)/\(vm.habits.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                SmallRingView(
                    progress: vm.habits.isEmpty ? 0 : Double(vm.doneHabits) / Double(vm.habits.count),
                    color: .mHabits,
                    size: 28
                )
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
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Add")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    Text("All caught up! 🎉")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(16)
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
    private var quickStatsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("QUICK STATS")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                sleepCard
                gymVolCard
                hydrationCard
            }
        }
    }

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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var gymVolCard: some View {
        StatCard(color: .mGym, label: "GYM VOL",
                 value: gymVolString,
                 sub: "lb this session") {
            vm.selectedTab = .train
        }
    }

    private var gymVolString: String {
        let vol = vm.sessionVolume
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
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Helpers
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("\(habit.streak)d streak")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(habit.done ? Color.tintSoft : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
            .scaleEffect(pressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: pressed)
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
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
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
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
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
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(assign.name)
                        .font(.subheadline)
                        .strikethrough(assign.done)
                        .foregroundStyle(assign.done ? .secondary : .primary)
                    Text("\(assign.subject) · \(assign.due)")
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

// MARK: - Small Ring
private struct SmallRingView: View {
    let progress: Double
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }
}
