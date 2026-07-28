import Foundation

/// Scores how well each muscle is *dosed*, reading the fractional per-muscle numbers from
/// `MuscleVolumeAnalyzer` so the score and the coverage bars can never disagree.
///
/// Grades at the `FineMuscle` level, because that's where the volume landmarks are defined and where
/// a problem is actionable — a "Legs: 24 sets" aggregate hides "hamstrings: 0".
///
/// Only muscles trained **directly** are graded, judged on their *total* (direct + indirect) volume.
/// Dosing is a question about what you chose to train: a muscle with no direct work at all is a
/// coverage problem, which `BalanceScorer` reports ("arms only get indirect work"). Grading it here
/// too would penalise the same mistake twice and bury the real advice under a duplicate.
enum VolumeScorer {
    static func score(volume: MuscleVolumeReport,
                      scope: QualityScope,
                      profile: TrainingProfile) -> DimensionScore {
        let graded = volume.creditByFine
            .filter { $0.value.direct > 0 }
            .filter { !isOptional($0.key, scope: scope, profile: profile) }

        guard !graded.isEmpty else {
            return DimensionScore(dimension: .volume, score: 70, tips: [])
        }

        switch scope {
        case .weeklySplit:
            return weekly(graded, profile: profile)
        case .singleSession:
            let total = volume.creditByFine.values.reduce(0.0) { $0 + $1.direct }
            return session(graded, totalDirectSets: total)
        }
    }

    private static func isOptional(_ m: FineMuscle,
                                   scope: QualityScope,
                                   profile: TrainingProfile) -> Bool {
        band(for: m, scope: scope, profile: profile).isOptional
    }

    private static func band(for m: FineMuscle,
                             scope: QualityScope,
                             profile: TrainingProfile) -> TrainingScience.VolumeBand {
        switch scope {
        case .weeklySplit:   return TrainingScience.weeklyBand(for: m, experience: profile.experience)
        case .singleSession: return TrainingScience.sessionBand(for: m)
        }
    }

    /// Sets read nicer as "12" than "12.0", but half-credit means "10.5" is a real value.
    static func setsText(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    // MARK: Weekly

    private static func weekly(_ graded: [FineMuscle: MuscleCredit],
                               profile: TrainingProfile) -> DimensionScore {
        var qualities: [Double] = []
        var tips: [QualityTip] = []

        // Ascending by volume so the most-neglected muscle's advice is generated first.
        for (muscle, credit) in graded.sorted(by: { $0.value.total < $1.value.total }) {
            let lm = TrainingScience.weeklyBand(for: muscle, experience: profile.experience)
            let sets = credit.total
            let name = muscle.displayName
            let setsStr = setsText(sets)

            switch MuscleVolumeAnalyzer.status(sets: sets, band: lm) {
            case .under:
                qualities.append(0.4)
                tips.append(QualityTip(
                    id: "vol-low-\(muscle.rawValue)", dimension: .volume, severity: .warn,
                    message: "\(name): only \(setsStr) sets/week — under the ~\(setsText(lm.mev))-set minimum to drive growth. Aim for \(setsText(lm.targetLow))–\(setsText(lm.targetHigh)).",
                    action: .addMuscle(muscle.rawValue)))
            case .light:
                qualities.append(0.75)
                tips.append(QualityTip(
                    id: "vol-light-\(muscle.rawValue)", dimension: .volume, severity: .info,
                    message: "\(name): \(setsStr) sets/week is on the light side — \(setsText(lm.targetLow))–\(setsText(lm.targetHigh)) is the productive range for you.",
                    action: .addMuscle(muscle.rawValue)))
            case .productive:
                qualities.append(1.0)
            case .high:
                qualities.append(0.9)
            case .excessive:
                qualities.append(0.5)
                tips.append(QualityTip(
                    id: "vol-high-\(muscle.rawValue)", dimension: .volume, severity: .warn,
                    message: "\(name): \(setsStr) sets/week may be more than you can recover from (~\(setsText(lm.mrv)) is plenty). Trim a set or two.",
                    action: .noAction))
            case .untrained:
                continue   // coverage is BalanceScorer's job
            }
        }

        guard !qualities.isEmpty else {
            return DimensionScore(dimension: .volume, score: 70, tips: [])
        }
        let score = Int((qualities.reduce(0, +) / Double(qualities.count) * 100).rounded())
        return DimensionScore(dimension: .volume, score: score, tips: tips)
    }

    // MARK: Session

    private static func session(_ graded: [FineMuscle: MuscleCredit],
                                totalDirectSets: Double) -> DimensionScore {
        var qualities: [Double] = []
        var tips: [QualityTip] = []

        for (muscle, credit) in graded.sorted(by: { $0.value.total > $1.value.total }) {
            let band = TrainingScience.sessionBand(for: muscle)
            let sets = credit.total

            switch MuscleVolumeAnalyzer.status(sets: sets, band: band) {
            case .excessive:
                qualities.append(0.5)
                tips.append(QualityTip(
                    id: "sess-junk-\(muscle.rawValue)", dimension: .volume, severity: .warn,
                    message: "\(muscle.displayName) gets \(setsText(sets)) sets in one session — past ~\(setsText(band.mrv)), extra sets add fatigue more than muscle. Spread some across the week.",
                    action: .noAction))
            case .productive, .high:
                qualities.append(1.0)
            case .light, .under:
                qualities.append(0.85)   // accessory work — fine within a session
            case .untrained:
                continue
            }
        }

        guard !qualities.isEmpty else {
            return DimensionScore(dimension: .volume, score: 70, tips: [])
        }
        var score = Int((qualities.reduce(0, +) / Double(qualities.count) * 100).rounded())

        let total = Int(totalDirectSets.rounded())
        if totalDirectSets < Double(TrainingScience.sessionTotalLow) {
            score = min(score, 80)
            tips.append(QualityTip(
                id: "sess-short", dimension: .volume, severity: .info,
                message: "Short session — \(total) working sets total. There's room to add a movement or two.",
                action: .noAction))
        } else if totalDirectSets > Double(TrainingScience.sessionTotalHigh) {
            score = min(score, 75)
            tips.append(QualityTip(
                id: "sess-long", dimension: .volume, severity: .warn,
                message: "Long session — \(total) working sets. Quality tends to dip late; consider splitting this across two days.",
                action: .noAction))
        }
        return DimensionScore(dimension: .volume, score: score, tips: tips)
    }
}
