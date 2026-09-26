import Foundation

/// Scores whether the prescribed reps (and rest, when captured) match the user's goal.
/// Rest is only available for single-session templates; split days store sets/reps only, so
/// weekly scope scores reps alone.
enum RepRestScorer {
    static func score(resolvedDays: [[ResolvedExercise]],
                      scope: QualityScope,
                      profile: TrainingProfile) -> DimensionScore {
        let all = resolvedDays.flatMap { $0 }
        guard !all.isEmpty else {
            return DimensionScore(dimension: .repRest, score: 70, tips: [])
        }

        var tips: [QualityTip] = []
        var subscores: [Double] = []

        // Reps vs goal range
        let repRange = TrainingScience.repRange(for: profile.goal)
        var repTotal = 0, repInRange = 0
        for r in all {
            guard let parsed = parseReps(r.exercise.repsText) else { continue }
            repTotal += 1
            if repRange.overlaps(parsed) { repInRange += 1 }
        }
        if repTotal > 0 {
            let repScore = Double(repInRange) / Double(repTotal)
            subscores.append(repScore)
            if repScore < 0.6 {
                tips.append(QualityTip(
                    id: "rr-reps", dimension: .repRest, severity: .info,
                    message: "Most of your rep targets don't match \(profile.goal.displayName) — train mainly in the \(repRange.low)–\(repRange.high) rep range.",
                    action: .retuneReps))
            }
        }

        // Rest vs goal range — single-session only (split days don't capture rest)
        if scope == .singleSession {
            let restRange = TrainingScience.restRange(for: profile.goal)
            var restTotal = 0, restInRange = 0
            for r in all {
                guard let rest = r.exercise.restSeconds, rest > 0 else { continue }
                restTotal += 1
                // Allow isolation work to rest a bit less / accessories a bit more.
                let lo = Double(restRange.low) * 0.6
                let hi = Double(restRange.high) * 1.5
                if Double(rest) >= lo && Double(rest) <= hi { restInRange += 1 }
            }
            if restTotal > 0 {
                let restScore = Double(restInRange) / Double(restTotal)
                subscores.append(restScore)
                if restScore < 0.6 {
                    tips.append(QualityTip(
                        id: "rr-rest", dimension: .repRest, severity: .info,
                        message: restMessage(for: profile.goal, range: restRange),
                        action: .retuneRest))
                }
            }
        }

        guard !subscores.isEmpty else {
            return DimensionScore(dimension: .repRest, score: 80, tips: [])
        }
        let score = Int((subscores.reduce(0, +) / Double(subscores.count) * 100).rounded())
        return DimensionScore(dimension: .repRest, score: score, tips: tips)
    }

    // MARK: Helpers

    /// Pulls the numeric bounds out of a free-text rep field ("8-10", "8–10", "10", "8/side").
    /// Returns nil for non-numeric prescriptions like "AMRAP" or "Failure".
    static func parseReps(_ text: String) -> ClosedRange<Int>? {
        let numbers = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard let low = numbers.min(), let high = numbers.max() else { return nil }
        return low...high
    }

    private static func restMessage(for goal: LiftingGoal, range: TrainingScience.IntRange) -> String {
        switch goal {
        case .strength:
            return "Strength work needs full recovery — rest about \(range.low / 60)–\(range.high / 60) min on your heavy compounds."
        case .hypertrophy:
            return "For muscle growth, rest ~90s–3 min — enough to recover, short enough to keep volume up."
        case .endurance:
            return "For endurance, keep rest short (≤\(range.high)s) to build muscular stamina."
        case .weightLoss:
            return "For a lean/cut goal, short rests (\(range.low)–\(range.high)s) keep density and heart rate high."
        }
    }
}
