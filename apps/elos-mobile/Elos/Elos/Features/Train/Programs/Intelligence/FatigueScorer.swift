import Foundation

/// Grades the two things a set count can't see: whether the sets land while the lifter can still do
/// them justice, and whether the hard movements come first.
///
/// Separate from `VolumeScorer` on purpose. Volume answers "is the dose right?" — fatigue answers
/// "will you actually get that dose?". A 24-set chest day can be correct on volume and still be a bad
/// session, and the lifter deserves to be told which of the two is wrong.
enum FatigueScorer {

    /// Effective-volume efficiency carries more weight than tidiness of order.
    private static let efficiencyWeight = 0.6
    private static let orderWeight      = 0.4

    private static let maxTips = 3

    static func score(resolvedDays: [[ResolvedExercise]],
                      dayNames: [String],
                      scope: QualityScope) -> DimensionScore {

        let populated = resolvedDays.indices.filter { !resolvedDays[$0].isEmpty }
        guard !populated.isEmpty else {
            return DimensionScore(dimension: .fatigue, score: 70, tips: [])
        }

        var efficiencies: [Double] = []
        var orders: [Double] = []
        var tips: [QualityTip] = []

        // Worst day first, so the most useful advice survives the tip cap.
        let byWorst = populated
            .map { (index: $0, fatigue: FatigueModel.analyze(day: resolvedDays[$0])) }
            .sorted { $0.fatigue.efficiency < $1.fatigue.efficiency }

        for (index, f) in byWorst {
            efficiencies.append(f.efficiency)
            orders.append(f.order.quality)

            let label = dayLabel(index: index, dayNames: dayNames, scope: scope)

            if f.efficiency < TrainingScience.minVolumeEfficiency, tips.count < maxTips {
                let lost = f.setsLostToFatigue
                tips.append(QualityTip(
                    id: "fatigue-long-\(index)", dimension: .fatigue, severity: .warn,
                    message: "\(label)\(Int(f.rawSets)) sets is long enough that roughly \(VolumeScorer.setsText((lost * 2).rounded() / 2)) of them land under heavy fatigue. Trimming the tail or moving some to another day buys back real volume.",
                    action: .noAction))
            }

            // Every remaining inversion is same-muscle by construction now — order.quality only
            // counts same-muscle pairs, so the filter that used to live here is redundant.
            if let bad = f.order.inversions.first, tips.count < maxTips {
                tips.append(QualityTip(
                    id: "fatigue-order-\(index)", dimension: .fatigue, severity: .info,
                    message: "\(label)\(bad.isolationName) comes before \(bad.compoundName), which pre-fatigues the muscle the compound needs most. Lead with the compound.",
                    action: .reorder(dayIndex: index)))
            }
        }

        let meanEfficiency = efficiencies.reduce(0, +) / Double(efficiencies.count)
        let meanOrder      = orders.reduce(0, +) / Double(orders.count)

        // Efficiency starts at `minVolumeEfficiency`-ish in practice, so rescale it across the range
        // that actually occurs: mapping 0.6…1.0 onto 0…1 keeps the dimension discriminating instead of
        // parking every session in the 80s.
        let floor = TrainingScience.fatigueQualityFloor
        let normalizedEfficiency = min(1, max(0, (meanEfficiency - floor) / (1 - floor)))

        let composite = normalizedEfficiency * efficiencyWeight + meanOrder * orderWeight
        return DimensionScore(dimension: .fatigue,
                              score: Int((composite * 100).rounded()),
                              tips: Array(tips.prefix(maxTips)))
    }

    /// "Friday: " for a week, "" for a single template — a lone session doesn't need naming.
    private static func dayLabel(index: Int, dayNames: [String], scope: QualityScope) -> String {
        guard scope == .weeklySplit else { return "" }
        let name = index < dayNames.count ? dayNames[index].trimmingCharacters(in: .whitespaces) : ""
        return name.isEmpty ? "" : "\(name): "
    }
}
