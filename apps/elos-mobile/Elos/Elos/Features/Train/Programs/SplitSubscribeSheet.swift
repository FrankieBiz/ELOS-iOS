import SwiftUI
import SwiftData

struct SplitSubscribeSheet: View {
    let recommendation: SplitRecommendation
    let daysPerWeek: Int
    let dismissAll: () -> Void

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var conflictResolution: ConflictResolution? = nil
    @State private var selectedWeekdays: Set<Int> = []
    @State private var orderedDays: [RecommendedDay] = []
    @State private var isSaving = false

    private enum ConflictResolution { case now, nextMonday }

    // Calendar weekday numbers: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    private let weekdays: [(label: String, value: Int)] = [
        ("Mon", 2), ("Tue", 3), ("Wed", 4), ("Thu", 5), ("Fri", 6), ("Sat", 7), ("Sun", 1)
    ]

    private var defaultWeekdays: Set<Int> {
        switch daysPerWeek {
        case 2:  return [2, 5]
        case 3:  return [2, 4, 6]
        case 4:  return [2, 3, 5, 6]
        case 5:  return [2, 3, 4, 6, 7]
        case 6:  return [2, 3, 4, 5, 6, 7]
        default: return [2, 4, 6]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if vm.activeSplit != nil, conflictResolution == nil {
                        conflictSection
                    } else {
                        dayAssignmentSection
                        if orderedDays.count > 1 {
                            dayOrderSection
                        }
                        confirmSection
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            selectedWeekdays = defaultWeekdays
            orderedDays = recommendation.days.filter { !$0.isRest }
            if vm.activeSplit == nil { conflictResolution = .now }
        }
    }

    // MARK: Conflict

    private var conflictSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You already have an active split")
                .font(.system(size: 22, weight: .bold))
            if let name = vm.activeSplit?.name {
                Text("Currently on: \(name)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(spacing: 10) {
                conflictButton(
                    "Switch Now",
                    subtitle: "Activate \(recommendation.name) immediately",
                    systemImage: "bolt.fill"
                ) { conflictResolution = .now }

                conflictButton(
                    "Start Next Monday",
                    subtitle: "\(recommendation.name) activates on the next Monday",
                    systemImage: "calendar.badge.clock"
                ) { conflictResolution = .nextMonday }
            }
        }
    }

    private func conflictButton(_ title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3).foregroundStyle(Color.tint).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).fontWeight(.semibold)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: Day assignment

    private var dayAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Your Training Days")
                    .font(.system(size: 22, weight: .bold))
                Text("Tap days to toggle. Minimum 2 training days.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekdays, id: \.value) { day in
                    Button {
                        if selectedWeekdays.contains(day.value) {
                            if selectedWeekdays.count > 2 { selectedWeekdays.remove(day.value) }
                        } else {
                            selectedWeekdays.insert(day.value)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.label).font(.system(size: 11, weight: .semibold))
                            Image(systemName: selectedWeekdays.contains(day.value) ? "dumbbell.fill" : "moon.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(selectedWeekdays.contains(day.value) ? Color.white : Color.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(selectedWeekdays.contains(day.value) ? Color.white : Color.primary)
                        .background(selectedWeekdays.contains(day.value) ? Color.tint : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Day Order

    private var dayOrderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Day Order")
                    .font(.system(size: 18, weight: .bold))
                Text("Reorder to match your preferred rotation.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(orderedDays.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    Text("\(i + 1)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.tint)
                        .frame(width: 3, height: 32)
                    Text(orderedDays[i].label)
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 2) {
                        Button {
                            moveDay(from: i, by: -1)
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(i == 0 ? Color.secondary.opacity(0.3) : Color.tint)
                        }
                        .buttonStyle(.plain)
                        .disabled(i == 0)

                        Button {
                            moveDay(from: i, by: 1)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(i == orderedDays.count - 1 ? Color.secondary.opacity(0.3) : Color.tint)
                        }
                        .buttonStyle(.plain)
                        .disabled(i == orderedDays.count - 1)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func moveDay(from index: Int, by direction: Int) {
        let target = index + direction
        guard target >= 0, target < orderedDays.count else { return }
        HapticManager.impact(.light)
        orderedDays.swapAt(index, target)
    }

    // MARK: Confirm

    private var confirmSection: some View {
        Button {
            Task { await saveAndDismiss() }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Start \(recommendation.name)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(selectedWeekdays.count >= 2 ? Color.tint : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(selectedWeekdays.count < 2 || isSaving)
    }

    // MARK: Save

    private func saveAndDismiss() async {
        isSaving = true
        let ownerID = vm.currentUserID
        guard !ownerID.isEmpty else { isSaving = false; return }

        let isNow = conflictResolution == .now
        let startAt: Date? = isNow ? nil : nextMonday()

        if isNow, let current = vm.activeSplit {
            current.isActive = false
        }

        // Ordered array: weekday numbers in Mon→Sun display order, filtered to selected
        let sortedPinned = weekdays.filter { selectedWeekdays.contains($0.value) }.map { $0.value }

        let splitRecord = UserSplitRecord(
            ownerID: ownerID,
            name: recommendation.name,
            isActive: isNow,
            activatedAt: isNow ? Date() : nil,
            libraryKey: "",
            syncPending: true,
            scheduledStartAt: startAt
        )
        splitRecord.pinnedWeekdays = sortedPinned
        splitRecord.includeWarmups = recommendation.includeWarmups
        modelContext.insert(splitRecord)

        for (idx, day) in orderedDays.enumerated() {
            let exercisesJSON = (try? String(
                data: JSONEncoder().encode(day.exercises.map { DayExercise(id: UUID().uuidString, name: $0.name) }),
                encoding: .utf8
            )) ?? "[]"
            let dayRecord = UserSplitDayRecord(
                splitID: splitRecord.id,
                orderIndex: idx,
                dayLabel: day.label,
                dayName: day.label,
                isRest: false,
                exercisesJSON: exercisesJSON
            )
            modelContext.insert(dayRecord)
        }

        try? modelContext.save()
        vm.loadActiveSplit()

        let record = splitRecord
        Task.detached { await vm.pushSplitToServer(record) }

        isSaving = false
        dismissAll()
    }

    private func nextMonday() -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.nextDate(after: today, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) ?? today
    }
}
