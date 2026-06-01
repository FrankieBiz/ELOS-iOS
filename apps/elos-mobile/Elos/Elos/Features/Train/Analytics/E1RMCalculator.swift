import Foundation

enum E1RMCalculator {
    // Epley formula — broadly applicable across rep ranges
    static func epley(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    // Brzycki formula — more accurate for low-rep work (≤ 10 reps)
    static func brzycki(weight: Double, reps: Int) -> Double {
        guard reps > 0, reps < 37 else { return weight }
        return weight * (36.0 / (37.0 - Double(reps)))
    }

    // Best estimate: Brzycki for ≤ 10 reps, Epley otherwise
    static func estimate(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        return reps <= 10 ? brzycki(weight: weight, reps: reps) : epley(weight: weight, reps: reps)
    }

    // Warm-up ramp sets for a given work weight and bar weight
    static func warmupSets(workWeight: Double, barWeight: Double = 20) -> [(weight: Double, reps: Int)] {
        guard workWeight > barWeight else { return [(barWeight, 10)] }
        let diff = workWeight - barWeight
        return [
            (barWeight + diff * 0.45, 10),
            (barWeight + diff * 0.60, 5),
            (barWeight + diff * 0.75, 3),
            (barWeight + diff * 0.90, 1),
        ]
    }
}
