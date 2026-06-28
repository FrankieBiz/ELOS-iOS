import Foundation

/// Scores how well each muscle is *dosed*. Weekly scope judges sets/muscle/week against the
/// MEV→target→MRV ladder; session scope judges sets/muscle within one workout (junk-volume +
/// total-length sanity). Counts primary-muscle sets only — consistent with the weekly coverage chips.
enum VolumeScorer {
    static func score(resolvedDays: [[ResolvedExercise]],
                      scope: QualityScope,
                      profile: TrainingProfile) -> DimensionScore {
        let all = resolvedDays.flatMap { $0 }
        var setsPerGroup: [MuscleGroup: Int] = [:]
        for r in all {
            guard let g = r.muscleGroup else { continue }
            setsPerGroup[g, default: 0] += r.exercise.sets
        }
        guard !setsPerGroup.isEmpty else {
            return DimensionScore(dimension: .volume, score: 70, tips: [])
        }
        switch scope {
        case .weeklySplit:
            return weekly(setsPerGroup, profile: profile)
        case .singleSession:
            let total = all.reduce(0) { $0 + $1.exercise.sets }
            return session(setsPerGroup, total: total)
        }
    }

    // MARK: Weekly

    private static func weekly(_ setsPerGroup: [MuscleGroup: Int],
                               profile: TrainingProfile) -> DimensionScore {
        let lm = TrainingScience.weeklyVolume(for: profile.experience)
        var qualities: [Double] = []
        var tips: [QualityTip] = []

        for (g, sets) in setsPerGroup.sorted(by: { $0.value < $1.value }) {
            let name = g.rawValue.capitalized
            if sets < lm.mev {
                qualities.append(0.4)
                tips.append(QualityTip(
                    id: "vol-low-\(g.rawValue)", dimension: .volume, severity: .warn,
                    message: "\(name): only \(sets) sets/week — under the ~\(lm.mev)-set minimum to drive growth. Aim for \(lm.targetLow)–\(lm.targetHigh).",
                    action: .addMuscle(g.rawValue)))
            } else if sets < lm.targetLow {
                qualities.append(0.75)
                tips.append(QualityTip(
                    id: "vol-light-\(g.rawValue)", dimension: .volume, severity: .info,
                    message: "\(name): \(sets) sets/week is on the light side — \(lm.targetLow)–\(lm.targetHigh) is the productive range for you.",
                    action: .addMuscle(g.rawValue)))
            } else if sets <= lm.targetHigh {
                qualities.append(1.0)
            } else if sets <= lm.mrv {
                qualities.append(0.9)
            } else {
                qualities.append(0.5)
                tips.append(QualityTip(
                    id: "vol-high-\(g.rawValue)", dimension: .volume, severity: .warn,
                    message: "\(name): \(sets) sets/week may be more than you can recover from (~\(lm.mrv) is plenty). Trim a set or two.",
                    action: .noAction))
            }
        }

        let score = Int((qualities.reduce(0, +) / Double(qualities.count) * 100).rounded())
        return DimensionScore(dimension: .volume, score: score, tips: tips)
    }

    // MARK: Session

    private static func session(_ setsPerGroup: [MuscleGroup: Int], total: Int) -> DimensionScore {
        var qualities: [Double] = []
        var tips: [QualityTip] = []

        for (g, sets) in setsPerGroup.sorted(by: { $0.value > $1.value }) {
            let name = g.rawValue.capitalized
            if sets > TrainingScience.sessionJunkThreshold {
                qualities.append(0.5)
                tips.append(QualityTip(
                    id: "sess-junk-\(g.rawValue)", dimension: .volume, severity: .warn,
                    message: "\(name) gets \(sets) sets in one session — past ~\(TrainingScience.sessionJunkThreshold), extra sets add fatigue more than muscle. Spread some across the week.",
                    action: .noAction))
            } else if sets >= TrainingScience.sessionTargetLow {
                qualities.append(1.0)
            } else {
                qualities.append(0.85) // light/accessory work — fine within a session
            }
        }

        var score = Int((qualities.reduce(0, +) / Double(qualities.count) * 100).rounded())
        if total < TrainingScience.sessionTotalLow {
            score = min(score, 80)
            tips.append(QualityTip(
                id: "sess-short", dimension: .volume, severity: .info,
                message: "Short session — \(total) working sets total. There's room to add a movement or two.",
                action: .noAction))
        } else if total > TrainingScience.sessionTotalHigh {
            score = min(score, 75)
            tips.append(QualityTip(
                id: "sess-long", dimension: .volume, severity: .warn,
                message: "Long session — \(total) working sets. Quality tends to dip late; consider splitting this across two days.",
                action: .noAction))
        }
        return DimensionScore(dimension: .volume, score: score, tips: tips)
    }
}
