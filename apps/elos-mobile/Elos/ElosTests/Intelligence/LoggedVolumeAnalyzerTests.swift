import Foundation
import Testing
@testable import Elos

/// The Stats tab's volume chart. Computed on-device because `/analytics/volume` buckets by
/// `LEFT JOIN exercise_definitions ON lower(exercise_name) = lower(name)` — so a set logged on
/// "PRIME Fitness Low Back Extension" matched nothing and showed up as a grey "Unmatched" bar.
struct LoggedVolumeAnalyzerTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func daysAgo(_ d: Int) -> Date { now.addingTimeInterval(-Double(d) * 86_400) }
    private var weekAgo: Date { daysAgo(7) }

    private func set(_ targets: MuscleTargets, _ d: Int = 1) -> LoggedVolumeAnalyzer.LoggedSet {
        .init(targets: targets, completedAt: daysAgo(d))
    }

    // MARK: Credit

    @Test func aPrimaryMuscleEarnsAWholeSet() {
        let c = LoggedVolumeAnalyzer.credits(for: MuscleTargets(primary: [.lowerBack]))
        #expect(c[.lowerBack]?.direct == 1)
        #expect(c[.lowerBack]?.indirect == 0)
    }

    @Test func anAssistingMuscleEarnsAPartialSet() {
        let c = LoggedVolumeAnalyzer.credits(for: MuscleTargets(primary: [.chest], secondary: [.triceps]))
        #expect(c[.triceps]?.indirect == TrainingScience.secondaryCredit)
        #expect(c[.triceps]?.direct == 0)
    }

    /// Same rule as the plan-side analyzer: being the target beats assisting for the same muscle.
    @Test func directWorkSupersedesIndirectForTheSameMuscle() {
        let c = LoggedVolumeAnalyzer.credits(for: MuscleTargets(primary: [.chest], secondary: [.chest]))
        #expect(c[.chest]?.direct == 1)
        #expect(c[.chest]?.indirect == 0)
    }

    @Test func anUnattributedSetEarnsNothing() {
        #expect(LoggedVolumeAnalyzer.credits(for: MuscleTargets()).isEmpty)
    }

    // MARK: Rows

    @Test func setsAccumulatePerMuscle() {
        let rows = LoggedVolumeAnalyzer.rows(
            sets: Array(repeating: set(MuscleTargets(primary: [.chest], secondary: [.triceps])), count: 6),
            since: weekAgo)
        #expect(rows.first { $0.fine == .chest }?.credit.direct == 6)
        #expect(rows.first { $0.fine == .triceps }?.credit.indirect == 6 * TrainingScience.secondaryCredit)
    }

    @Test func setsOutsideTheWindowAreExcluded() {
        let rows = LoggedVolumeAnalyzer.rows(
            sets: [set(MuscleTargets(primary: [.chest]), 2), set(MuscleTargets(primary: [.quads]), 30)],
            since: weekAgo)
        #expect(rows.contains { $0.fine == .chest })
        #expect(!rows.contains { $0.fine == .quads }, "a set from 30 days ago is not this week's volume")
    }

    @Test func untrainedMusclesAreOmittedNotShownAsZero() {
        let rows = LoggedVolumeAnalyzer.rows(sets: [set(MuscleTargets(primary: [.chest]))], since: weekAgo)
        #expect(rows.map(\.fine) == [.chest])
    }

    @Test func rowsComeBackInTaxonomyOrder() {
        let rows = LoggedVolumeAnalyzer.rows(
            sets: [set(MuscleTargets(primary: [.abs])),
                   set(MuscleTargets(primary: [.chest])),
                   set(MuscleTargets(primary: [.biceps]))],
            since: weekAgo)
        // FineMuscle.allCases order: chest … biceps … abs
        #expect(rows.map(\.fine) == [.chest, .biceps, .abs])
    }

    @Test func emptyInputYieldsNoRows() {
        #expect(LoggedVolumeAnalyzer.rows(sets: [], since: weekAgo).isEmpty)
    }

    // MARK: Band context — the number the bar is compared against

    @Test func eachRowCarriesItsOwnWeeklyTarget() {
        let rows = LoggedVolumeAnalyzer.rows(
            sets: [set(MuscleTargets(primary: [.quads])), set(MuscleTargets(primary: [.sideDelts]))],
            since: weekAgo)
        let quads = rows.first { $0.fine == .quads }!
        let delts = rows.first { $0.fine == .sideDelts }!
        // A per-muscle target is the whole point: the same bar length means different things.
        #expect(quads.target == TrainingScience.weeklyBand(for: .quads, experience: .intermediate).targetLow)
        #expect(delts.target == TrainingScience.weeklyBand(for: .sideDelts, experience: .intermediate).targetLow)
    }

    @Test func statusReflectsTheProductiveBand() {
        let band = TrainingScience.weeklyBand(for: .chest, experience: .intermediate)
        let inRange = LoggedVolumeAnalyzer.rows(
            sets: Array(repeating: set(MuscleTargets(primary: [.chest])), count: Int(band.targetLow)),
            since: weekAgo)
        #expect(inRange.first?.status.isOnTarget == true)

        let under = LoggedVolumeAnalyzer.rows(
            sets: [set(MuscleTargets(primary: [.chest]))], since: weekAgo)
        #expect(under.first?.status.isOnTarget == false)
    }

    @Test func experienceMovesTheTarget() {
        let sets = Array(repeating: set(MuscleTargets(primary: [.chest])), count: 10)
        let beginner = LoggedVolumeAnalyzer.rows(
            sets: sets, since: weekAgo,
            profile: TrainingProfile(goal: .hypertrophy, experience: .beginner))
        let advanced = LoggedVolumeAnalyzer.rows(
            sets: sets, since: weekAgo,
            profile: TrainingProfile(goal: .hypertrophy, experience: .advanced))
        #expect(beginner.first!.target <= advanced.first!.target)
    }

    @Test func volumeOverrideMovesTheTarget() {
        let sets = Array(repeating: set(MuscleTargets(primary: [.chest])), count: 10)
        func target(_ o: VolumeOverrides) -> Double {
            LoggedVolumeAnalyzer.rows(
                sets: sets, since: weekAgo,
                profile: TrainingProfile(goal: .hypertrophy, experience: .intermediate,
                                         volumeOverrides: o)
            ).first!.target
        }
        #expect(target(VolumeOverrides(preference: .conservative)) < target(.none))
        #expect(target(VolumeOverrides(preference: .aggressive)) > target(.none))
        // An explicit group target replaces the derived one outright.
        #expect(target(VolumeOverrides(groupWeeklyTarget: [MuscleGroup.chest.rawValue: 30])) > target(.none))
    }

    // MARK: Headline + gaps

    @Test func onTargetCountSummarisesTheChart() {
        let chestBand = TrainingScience.weeklyBand(for: .chest, experience: .intermediate)
        var sets = Array(repeating: set(MuscleTargets(primary: [.chest])), count: Int(chestBand.targetLow))
        sets.append(set(MuscleTargets(primary: [.quads])))   // one lonely quad set
        let score = LoggedVolumeAnalyzer.onTargetCount(LoggedVolumeAnalyzer.rows(sets: sets, since: weekAgo))
        #expect(score == (onTarget: 1, total: 2))
    }

    @Test func gapsAreRankedByHowFarShortTheyFall() {
        // Quads need far more than side delts, so one set of each leaves quads further behind.
        let rows = LoggedVolumeAnalyzer.rows(
            sets: [set(MuscleTargets(primary: [.quads])), set(MuscleTargets(primary: [.sideDelts]))],
            since: weekAgo)
        #expect(LoggedVolumeAnalyzer.gaps(rows).first?.fine == .quads)
    }

    /// Prehab muscles are never nagged about — same rule the coverage bars follow.
    @Test func optionalMusclesAreNeverReportedAsGaps() {
        let rows = LoggedVolumeAnalyzer.rows(
            sets: [set(MuscleTargets(primary: [.rotatorCuff])), set(MuscleTargets(primary: [.forearms]))],
            since: weekAgo)
        #expect(!rows.isEmpty, "they still appear in the chart")
        #expect(LoggedVolumeAnalyzer.gaps(rows).isEmpty, "but are not called out as gaps")
    }

    @Test func aFullyCoveredWeekReportsNoGaps() {
        let band = TrainingScience.weeklyBand(for: .chest, experience: .intermediate)
        let rows = LoggedVolumeAnalyzer.rows(
            sets: Array(repeating: set(MuscleTargets(primary: [.chest])), count: Int(band.targetLow)),
            since: weekAgo)
        #expect(LoggedVolumeAnalyzer.gaps(rows).isEmpty)
    }

    // MARK: Excluded muscles — muted, not hidden, not treated as an ordinary gap

    /// A muscle the lifter has told the app to skip (globally, via `VolumeOverrides.excludedMuscles`)
    /// still needs *some* credit to appear as a row at all (`rows` drops zero-credit muscles
    /// unconditionally) — the realistic case is incidental secondary credit from an exercise
    /// targeting something else, same scenario the coverage bars handle.
    @Test func excludedMuscleWithIncidentalCreditIsFlaggedExcluded() {
        let profile = TrainingProfile(goal: .hypertrophy, experience: .intermediate,
                                      volumeOverrides: VolumeOverrides(excludedMuscles: [.lowerBack]))
        let rows = LoggedVolumeAnalyzer.rows(
            sets: [set(MuscleTargets(primary: [.lats], secondary: [.lowerBack]))],
            since: weekAgo, profile: profile)
        let lowerBackRow = rows.first { $0.fine == .lowerBack }
        #expect(lowerBackRow != nil, "incidental secondary credit must still produce a row")
        #expect(lowerBackRow?.isExcluded == true)
        #expect(rows.first { $0.fine == .lats }?.isExcluded == false)
    }

    @Test func nonExcludedMuscleRowReportsIsExcludedFalse() {
        let rows = LoggedVolumeAnalyzer.rows(sets: [set(MuscleTargets(primary: [.lats]))], since: weekAgo)
        #expect(rows.first { $0.fine == .lats }?.isExcluded == false)
    }

    // MARK: The bug this replaced

    /// A week of machine work must produce real muscle rows, not one "Unmatched" bucket.
    @Test func machineWorkIsAttributedRatherThanBucketedAsUnmatched() {
        let machine = EquipmentDatabase.all.first {
            $0.displayName.localizedCaseInsensitiveContains("PRIME Fitness Low Back Extension")
        }!
        let targets = EquipmentMuscleMap.targets(for: machine)!
        let rows = LoggedVolumeAnalyzer.rows(
            sets: Array(repeating: set(targets), count: 4), since: weekAgo)

        #expect(rows.contains { $0.fine == .lowerBack })
        #expect(rows.first { $0.fine == .lowerBack }?.credit.direct == 4)
        #expect(rows.allSatisfy { FineMuscle.allCases.contains($0.fine) }, "every row is a real muscle")
    }
}
