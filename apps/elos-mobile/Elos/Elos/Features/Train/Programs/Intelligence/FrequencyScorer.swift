import Foundation

/// Scores training *frequency* — how many separate days each muscle is trained. Weekly scope only:
/// a single session has no frequency to judge.
///
/// This is the thing sets-per-week can't tell you. 20 sets of chest in one day and 10 sets twice a
/// week have identical weekly volume, but the split version grows more muscle. Counts **direct**
/// days only: two days of pressing don't make the triceps "trained twice a week."
enum FrequencyScorer {

    static func score(volume: MuscleVolumeReport,
                      scope: QualityScope,
                      profile: TrainingProfile) -> DimensionScore {
        // Not applicable to one workout — return a neutral score so it can never drag a template
        // down. (`TemplateQualityEngine` also gives it zero weight at session scope.)
        guard scope == .weeklySplit else {
            return DimensionScore(dimension: .frequency, score: 100, tips: [])
        }

        // Only judge muscles that are actually trained directly and expected to be. A muscle with no
        // direct work at all is a *coverage* gap — `BalanceScorer`'s story, not frequency's — and
        // penalising it here would double-count the same mistake.
        let candidates = volume.expected
            .filter { !TrainingScience.weeklyBand(for: $0, profile: profile).isOptional }
            .filter { volume.directSets(for: $0) > 0 }

        guard !candidates.isEmpty else {
            return DimensionScore(dimension: .frequency, score: 70, tips: [])
        }

        var qualities: [Double] = []
        var candidateTips: [(sets: Double, tip: QualityTip)] = []
        let target = TrainingScience.targetWeeklyFrequency

        for muscle in candidates {
            let days = volume.directDaysByFine[muscle] ?? 0
            let sets = volume.sets(for: muscle)
            let band = TrainingScience.weeklyBand(for: muscle, profile: profile)

            if days >= target {
                qualities.append(1.0)
            } else if sets >= band.targetLow {
                // Enough volume, crammed into one day — the case worth flagging.
                qualities.append(0.55)
                let setsText = sets == sets.rounded() ? String(Int(sets)) : String(format: "%.1f", sets)
                candidateTips.append((sets, QualityTip(
                    id: "freq-once-\(muscle.rawValue)", dimension: .frequency, severity: .warn,
                    message: "\(muscle.displayName): all \(setsText) sets land on one day. Splitting them across \(target) sessions builds more muscle at the same weekly volume.",
                    action: .noAction)))
            } else {
                // Trained once and lightly — that's a volume story, so stay quiet here.
                qualities.append(0.8)
            }
        }

        let score = Int((qualities.reduce(0, +) / Double(qualities.count) * 100).rounded())
        // Surface the biggest offenders first and cap the noise; the full report screen shows all.
        let tips = candidateTips.sorted { $0.sets > $1.sets }.prefix(3).map(\.tip)
        return DimensionScore(dimension: .frequency, score: score, tips: Array(tips))
    }
}
