import SwiftUI
import SwiftData

struct WorkoutSplitDetailView: View {
    let split: WorkoutSplit

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var userSplits: [UserSplitRecord]

    @Environment(\.dismiss) private var dismiss
    @State private var expandedDays: Set<String> = []
    @State private var showCopyMenu = false
    @State private var copiedMessage: String? = nil
    @State private var showCustomize = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                Divider()
                overviewSection
                Divider()
                scheduleSection
                Divider()
                workoutsSection
                Divider()
                progressionSection
                copyButtonsSection
                disclaimerSection
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(split.title)
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottom) {
            if let msg = copiedMessage {
                Text(msg)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.tint)
                    .clipShape(Capsule())
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: copiedMessage)
        .sheet(isPresented: $showCustomize) {
            CreateSplitView(template: split) { showCustomize = false }
                .environmentObject(vm)
        }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                categoryBadge
                levelBadge
                Spacer()
            }
            HStack(spacing: 16) {
                statItem(icon: "calendar", value: "\(split.daysPerWeek) days/wk")
                statItem(icon: "clock", value: split.sessionLength)
                statItem(icon: "dumbbell", value: split.equipment.first ?? "Full Gym")
            }
            if !split.goals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(split.goals, id: \.self) { goal in
                            Text(goal)
                                .font(.caption2).fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                .padding(.horizontal, -16)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private var categoryBadge: some View {
        Text(split.category.rawValue)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(categoryColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(categoryColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var levelBadge: some View {
        Text(split.level.rawValue)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(levelColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(levelColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private func statItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Best For")
            Text(split.bestFor)
                .font(.subheadline).foregroundStyle(.primary)

            if !split.avoidIf.isEmpty {
                sectionLabel("Scale or Avoid If")
                Text(split.avoidIf)
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            if !split.inspiredBy.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Inspired by public training style: \(split.inspiredBy)")
                        .font(.caption).foregroundStyle(.secondary)
                        .italic()
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    // MARK: Weekly Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Weekly Schedule")
            VStack(spacing: 6) {
                ForEach(split.weeklySchedule.isEmpty ? inferredSchedule : split.weeklySchedule, id: \.day) { sched in
                    HStack {
                        Text(sched.day)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(sched.focus)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private var inferredSchedule: [SplitScheduleDay] {
        split.workouts.map { SplitScheduleDay(day: "Day", focus: $0.focus) }
    }

    // MARK: Workouts

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Workouts")
                .padding(.horizontal, 16)
                .padding(.top, 16)
            ForEach(split.workouts, id: \.focus) { day in
                dayAccordion(day)
            }
            Spacer(minLength: 8)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder private func dayAccordion(_ day: SplitWorkoutDay) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    if expandedDays.contains(day.focus) {
                        expandedDays.remove(day.focus)
                    } else {
                        expandedDays.insert(day.focus)
                    }
                }
            } label: {
                HStack {
                    Text(day.focus)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(day.exercises.count) exercises")
                        .font(.caption).foregroundStyle(.secondary)
                    Image(systemName: expandedDays.contains(day.focus) ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if expandedDays.contains(day.focus) {
                Divider().padding(.leading, 16)
                VStack(spacing: 0) {
                    ForEach(Array(day.exercises.enumerated()), id: \.offset) { idx, ex in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(idx + 1)")
                                .font(.caption2).foregroundStyle(.secondary)
                                .frame(width: 18, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ex.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if !ex.prescription.isEmpty {
                                    Text(ex.prescription)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        if idx < day.exercises.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color(.tertiarySystemBackground))
            }
        }
        .background(Color(.systemBackground))
        Divider().padding(.leading, 16)
    }

    // MARK: Progression

    private var progressionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Progression")
            Text(split.progression.isEmpty ? "Add reps before adding load. Keep 1–2 reps in reserve on main lifts." : split.progression)
                .font(.subheadline).foregroundStyle(.primary)
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private var isSubscribed: Bool {
        userSplits.contains { $0.libraryKey == split.id }
    }

    private func subscribeSplit() {
        // If already subscribed, just set active
        if let existing = userSplits.first(where: { $0.libraryKey == split.id }) {
            vm.setActiveSplit(existing)
            Task { await vm.activateSplitOnServer(serverID: existing.serverID) }
            return
        }

        // Deactivate all existing splits
        for s in userSplits { s.isActive = false }

        let record = UserSplitRecord(
            ownerID: vm.currentUserID,
            name: split.title,
            isActive: true,
            libraryKey: split.id,
            syncPending: true
        )
        modelContext.insert(record)

        let encoder = JSONEncoder()
        for (i, day) in split.workouts.enumerated() {
            let exercises = day.exercises.map { DayExercise(id: UUID().uuidString, name: $0.name) }
            let jsonStr = (try? String(data: encoder.encode(exercises), encoding: .utf8)) ?? "[]"
            let dayRecord = UserSplitDayRecord(
                splitID: record.id,
                orderIndex: i,
                dayLabel: "Day \(i + 1)",
                dayName: day.focus,
                isRest: false,
                exercisesJSON: jsonStr
            )
            modelContext.insert(dayRecord)
        }
        try? modelContext.save()
        vm.loadActiveSplit()

        Task {
            await vm.pushSplitToServer(record)
            await vm.activateSplitOnServer(serverID: record.serverID)
        }
    }

    // MARK: Copy Buttons

    private var copyButtonsSection: some View {
        VStack(spacing: 10) {
            // Subscribe CTA
            if isSubscribed {
                Button {} label: {
                    Label("Already Added", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
            } else {
                Button { subscribeSplit() } label: {
                    Label("Subscribe", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.tint)
            }

            Button { showCustomize = true } label: {
                Label("Customize & Subscribe", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.tint)

            copyButton(title: "Copy Full Split", icon: "doc.on.doc") {
                copyToClipboard(split.copyText, label: "Split copied")
            }
            HStack(spacing: 10) {
                copyButton(title: "Copy Schedule", icon: "calendar") {
                    let schedText = split.weeklySchedule.map { "\($0.day): \($0.focus)" }.joined(separator: "\n")
                    copyToClipboard("SPLIT: \(split.title)\n\n\(schedText)", label: "Schedule copied")
                }
                copyButton(title: "Copy Exercises", icon: "list.bullet") {
                    let exText = split.workouts.map { day in
                        let exList = day.exercises.enumerated().map { "\($0.offset + 1). \($0.element.name)" }.joined(separator: "\n")
                        return "\(day.focus)\n\(exList)"
                    }.joined(separator: "\n\n")
                    copyToClipboard(exText, label: "Exercises copied")
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private func copyButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.tint)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func copyToClipboard(_ text: String, label: String) {
        UIPasteboard.general.string = text
        copiedMessage = label
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedMessage = nil
        }
    }

    // MARK: Disclaimer

    private var disclaimerSection: some View {
        Text("This is general training content, not medical advice. Scale volume and intensity to your recovery, injury history, sport schedule, and coach/clinician guidance.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(16)
            .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption).fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var categoryColor: Color {
        switch split.category {
        case .foundation:         return .tint
        case .creatorInspired:    return Color.orange
        case .olympiaBodybuilding: return Color.purple
        case .sportPerformance:   return Color.green
        case .homeMinimal:        return Color.brown
        case .specialization:     return Color.pink
        }
    }

    private var levelColor: Color {
        switch split.level {
        case .beginner:     return .green
        case .intermediate: return .orange
        case .advanced:     return .red
        case .athlete:      return .purple
        }
    }
}
