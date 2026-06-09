import Foundation

struct BalanceWarning: Identifiable, Equatable {
    enum Severity { case info, warn }
    var id: String { message }
    let severity: Severity
    let message: String
}

enum WeeklyBalanceAnalyzer {
    static let lowSetLandmark = 10
    static let highSetLandmark = 22
    static let pushPullRatioLimit = 1.5

    static func analyze(days: [[DayExercise]], catalog: [ExerciseCandidate]) -> [BalanceWarning] {
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byName = Dictionary(catalog.map { (MuscleTaxonomy.normalize($0.name), $0) }, uniquingKeysWith: { a, _ in a })
        func lookup(_ ex: DayExercise) -> ExerciseCandidate? { byID[ex.id] ?? byName[MuscleTaxonomy.normalize(ex.name)] }

        var setsPerGroup: [MuscleGroup: Int] = [:]
        var pushSets = 0, pullSets = 0
        for day in days {
            for ex in day {
                guard let c = lookup(ex) else { continue }
                if let g = MuscleTaxonomy.group(forMuscle: c.primaryMuscle) {
                    setsPerGroup[g, default: 0] += ex.sets
                }
                switch c.movementPattern.lowercased() {
                case "push": pushSets += ex.sets
                case "pull": pullSets += ex.sets
                default: break
                }
            }
        }

        var warnings: [BalanceWarning] = []
        for g in MuscleGroup.allCases {
            let s = setsPerGroup[g] ?? 0
            if s > 0 && s < lowSetLandmark {
                warnings.append(.init(severity: .info, message: "\(g.rawValue.capitalized): only \(s) weekly sets — consider adding volume."))
            } else if s > highSetLandmark {
                warnings.append(.init(severity: .warn, message: "\(g.rawValue.capitalized): \(s) weekly sets — that's a lot; watch recovery."))
            }
        }
        if pushSets > 0 && pullSets > 0 {
            let ratio = Double(max(pushSets, pullSets)) / Double(min(pushSets, pullSets))
            if ratio > pushPullRatioLimit {
                let heavier = pushSets > pullSets ? "push" : "pull"
                warnings.append(.init(severity: .warn, message: "Push/pull imbalance — \(heavier) volume is \(String(format: "%.1f", ratio))× the other."))
            }
        }
        return warnings
    }
}
