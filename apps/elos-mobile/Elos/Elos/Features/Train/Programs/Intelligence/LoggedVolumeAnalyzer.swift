import Foundation

/// Per-muscle volume from **logged sets**, for the Stats tab.
///
/// This exists because the server can't answer the question. `/analytics/volume` buckets by
/// `LEFT JOIN exercise_definitions ON lower(exercise_name) = lower(name)`, so a set logged on
/// "PRIME Fitness Low Back Extension" matches no catalog row and lands in `'other'` — displayed as a
/// grey "Unmatched" bar. For a lifter who trains on brand machines that's most of their training.
///
/// The client knows strictly more: each set records what it trained at log time, and anything older
/// still resolves through equipment and the movement lexicon. So volume is computed here, from the same
/// `MuscleTargets` the coverage bars read, and the two can't disagree.
///
/// Pure value types only — no SwiftData, no network. `MuscleVolumeAnalyzer` answers the same question
/// for a *plan*; this one answers it for *history*.
enum LoggedVolumeAnalyzer {

    /// One completed set, reduced to what the analyzer needs.
    struct LoggedSet: Equatable {
        let targets: MuscleTargets
        let completedAt: Date

        init(targets: MuscleTargets, completedAt: Date) {
            self.targets = targets
            self.completedAt = completedAt
        }
    }

    /// One row of the Stats volume chart.
    struct MuscleRow: Identifiable, Equatable {
        let fine: FineMuscle
        let credit: MuscleCredit
        /// Weekly productive band from `TrainingScience` — the same landmarks the builder scores against.
        let band: TrainingScience.VolumeBand
        let status: VolumeStatus
        /// Muted by the lifter's own choice (`VolumeOverrides.excludedMuscles`), not by science —
        /// same distinction `MuscleVolumeAnalyzer.fineRow` already makes for the builder's coverage
        /// bars, so Stats can render "you told me to skip this" the same way rather than showing an
        /// ordinary in-progress row for a muscle the lifter has opted out of.
        let isExcluded: Bool

        var id: String { fine.rawValue }
        var displayName: String { fine.displayName }
        var total: Double { credit.total }
        /// Where the "target" marker sits on the axis.
        var target: Double { band.targetLow }
    }

    /// Sets per muscle over a trailing window, direct and indirect kept apart.
    ///
    /// Credit matches `MuscleVolumeAnalyzer.credits` exactly: a primary muscle earns the whole set, a
    /// secondary earns `TrainingScience.secondaryCredit`, and direct work supersedes indirect for the
    /// same muscle. Rows are returned in taxonomy order with any untrained muscle dropped.
    /// Takes the whole profile, not just experience: Stats shows the same weekly targets the builders
    /// score against, so it has to see the lifter's volume overrides too or the two screens disagree
    /// about what "on target" means.
    static func rows(sets: [LoggedSet],
                     since: Date,
                     profile: TrainingProfile = .default) -> [MuscleRow] {
        var credit: [FineMuscle: MuscleCredit] = [:]
        for s in sets where s.completedAt >= since {
            for (muscle, c) in credits(for: s.targets) {
                credit[muscle, default: .zero] = (credit[muscle] ?? .zero) + c
            }
        }
        return FineMuscle.allCases.compactMap { fine in
            guard let c = credit[fine], c.total > 0 else { return nil }
            let band = TrainingScience.weeklyBand(for: fine, profile: profile)
            return MuscleRow(fine: fine, credit: c, band: band,
                             status: MuscleVolumeAnalyzer.status(sets: c.total, band: band),
                             isExcluded: profile.volumeOverrides.excludedMuscles.contains(fine))
        }
    }

    /// Credit for one set's targets. One *set*, so a primary muscle earns 1.0 rather than the exercise's
    /// whole set count — the plan-side analyzer works in exercises, this one works in logged sets.
    static func credits(for targets: MuscleTargets) -> [FineMuscle: MuscleCredit] {
        guard !targets.isEmpty else { return [:] }
        var out: [FineMuscle: MuscleCredit] = [:]
        for m in targets.primary { out[m] = MuscleCredit(direct: 1, indirect: 0) }
        for m in targets.secondary where (out[m]?.direct ?? 0) == 0 {
            out[m] = MuscleCredit(direct: 0, indirect: TrainingScience.secondaryCredit)
        }
        return out
    }

    /// How many of the trained muscles are inside their productive band — the headline the chart needs
    /// so it says something, rather than leaving the lifter to read eight bars and decide.
    static func onTargetCount(_ rows: [MuscleRow]) -> (onTarget: Int, total: Int) {
        (rows.filter { $0.status.isOnTarget }.count, rows.count)
    }

    /// The muscles most worth attention: furthest below their productive band first. Optional
    /// prehab muscles (rotator cuff, forearms) are never nagged about.
    static func gaps(_ rows: [MuscleRow], limit: Int = 3) -> [MuscleRow] {
        rows.filter { !$0.band.isOptional && !$0.status.isOnTarget }
            .sorted { ($0.total / max($0.target, 1)) < ($1.total / max($1.target, 1)) }
            .prefix(limit)
            .map { $0 }
    }
}
