import SwiftUI
import SwiftData

/// The gym switcher, as a drop-in component — a Menu showing the active gym plus a before/after
/// preview (`GymSwitchPreview`) before committing. Self-contained: takes only a `split` and derives
/// everything else via its own queries (the same shape `UserSplitDetailView` already uses in its own
/// `init`), so any screen holding a `UserSplitRecord` can embed the switcher without threading
/// catalog/profile/days through from the host view.
///
/// Originally lived inline inside `UserSplitDetailView` — extracted so `TodayView` (reached far more
/// often than a specific split's detail screen) can offer the same switcher without a second,
/// disconnected copy of this logic.
struct GymSwitcherControl: View {
    let split: UserSplitRecord
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var sortedDays: [UserSplitDayRecord]
    @Query(sort: \ExerciseDefinitionRecord.name) private var exerciseDefs: [ExerciseDefinitionRecord]
    @Query private var profiles: [UserProfileRecord]
    @Query(sort: \GymRecord.createdAt) private var gyms: [GymRecord]

    @State private var pendingGymSwitch: GymRecord? = nil

    init(split: UserSplitRecord) {
        self.split = split
        let id = split.id
        _sortedDays = Query(filter: #Predicate<UserSplitDayRecord> { $0.splitID == id }, sort: \.orderIndex)
    }

    private var exerciseCatalog: [ExerciseCandidate] { exerciseDefs.map(ExerciseCandidate.init(record:)) }
    private var splitIntent: TrainingIntent {
        split.intent ?? TrainingIntent(profile: TrainingProfile(record: profiles.first))
    }
    private var scoringProfile: TrainingProfile {
        TrainingProfile(goal: splitIntent.goal, experience: TrainingProfile(record: profiles.first).experience,
                        volumeOverrides: vm.volumeOverrides)
    }
    private var qualityReport: QualityReport {
        SavedSplitScoring.report(days: sortedDays, templateExercises: { vm.fetchTemplateExercises(templateID: $0) },
                                 catalog: exerciseCatalog, profile: scoringProfile, intent: splitIntent)
    }

    var body: some View {
        Group {
            if !gyms.isEmpty {
                gymSwitcherMenu
            }
        }
        .sheet(item: $pendingGymSwitch) { gym in
            GymSwitchPreview(gymName: gym.name,
                            changes: gymSwitchChanges(for: gym),
                            beforeScore: qualityReport.isScored ? qualityReport.overall : nil,
                            afterScore: afterGymSwitchScore(for: gym),
                            onConfirm: { applyGymSwitch(gym) },
                            onCancel: {})
        }
    }

    private var gymSwitcherMenu: some View {
        Menu {
            Button {
                vm.activeGymID = ""
            } label: {
                Label("No gym selected", systemImage: vm.activeGymID.isEmpty ? "checkmark" : "")
            }
            ForEach(gyms) { gym in
                Button {
                    guard vm.activeGymID != gym.id else { return }
                    pendingGymSwitch = gym
                } label: {
                    Label(gym.name, systemImage: vm.activeGymID == gym.id ? "checkmark" : "")
                }
            }
        } label: {
            HStack {
                Label("Gym", systemImage: "building.2")
                Spacer()
                Text(gyms.first { $0.id == vm.activeGymID }?.name ?? "None")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A day changes when it has a version tagged to `gym` that isn't already active — shown in
    /// the preview before anything is touched. `nil` `newVariantName` means "no version for this
    /// gym yet, stays as it is," which the preview renders honestly rather than hiding.
    private func gymSwitchChanges(for gym: GymRecord) -> [GymSwitchDayChange] {
        sortedDays.enumerated().compactMap { i, day -> GymSwitchDayChange? in
            guard !day.isRest else { return nil }
            let name = day.dayName.isEmpty ? day.dayLabel : day.dayName
            guard let variant = DayVariants.previewVariant(forGym: gym.id, day: day) else {
                return GymSwitchDayChange(id: i, dayName: name, newVariantName: nil)
            }
            let alreadyActive = DayVariants.set(for: day)?.activeID == variant.id
            return GymSwitchDayChange(id: i, dayName: name, newVariantName: alreadyActive ? nil : variant.name)
        }
    }

    /// Scores the split as it would read AFTER the switch, without mutating any real day — builds
    /// detached copies carrying the target variant's content (or the day's current content, for a
    /// day with no version for this gym) and runs them through the same `SavedSplitScoring.report`
    /// every other score reads.
    private func afterGymSwitchScore(for gym: GymRecord) -> Int? {
        let hypothetical = sortedDays.map { day -> UserSplitDayRecord in
            guard let variant = DayVariants.previewVariant(forGym: gym.id, day: day) else { return day }
            let exData = try? JSONEncoder().encode(variant.exercises)
            let exJSON = exData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let copy = UserSplitDayRecord(id: day.id, splitID: day.splitID, orderIndex: day.orderIndex,
                                         dayLabel: day.dayLabel, dayName: day.dayName,
                                         templateID: variant.templateID, isRest: day.isRest,
                                         exercisesJSON: exJSON)
            copy.excludedMuscles = day.excludedMuscles
            return copy
        }
        let report = SavedSplitScoring.report(days: hypothetical,
                                              templateExercises: { vm.fetchTemplateExercises(templateID: $0) },
                                              catalog: exerciseCatalog, profile: scoringProfile, intent: splitIntent)
        return report.isScored ? report.overall : nil
    }

    private func applyGymSwitch(_ gym: GymRecord) {
        for day in sortedDays {
            guard !day.isRest, let variant = DayVariants.previewVariant(forGym: gym.id, day: day) else { continue }
            DayVariants.switchTo(variantID: variant.id, day: day)
        }
        vm.activeGymID = gym.id
        gym.lastUsedAt = Date()
        split.syncPending = true
        try? modelContext.save()
        let record = split
        Task.detached {
            if !record.serverID.isEmpty {
                await vm.updateSplitOnServer(serverID: record.serverID, record: record)
            } else {
                await vm.pushSplitToServer(record)
            }
        }
    }
}
