import Foundation

enum ExerciseSortMode: String, CaseIterable {
    case smart = "Smart", alphabetical = "A–Z", mostUsed = "Most used", byMuscle = "By muscle"
}

struct RankingInputs {
    var context: DayContext
    var personalization: PersonalizationProvider
    var isEquipmentAvailable: (String) -> Bool = { _ in true }
    var query: String = ""
}

enum ExerciseRankingEngine {
    private static let wDay = 3.0, wCompound = 1.5, wPers = 1.0, wGap = 1.2, wDup = 4.0, wEquip = 2.0

    static func rank(_ candidates: [ExerciseCandidate], inputs: RankingInputs,
                     mode: ExerciseSortMode = .smart) -> [ExerciseCandidate] {
        let searching = inputs.query.trimmingCharacters(in: .whitespaces).count >= 2

        switch mode {
        case .alphabetical:
            return candidates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .mostUsed:
            return candidates.sorted { inputs.personalization.score(forName: $0.name) > inputs.personalization.score(forName: $1.name) }
        case .byMuscle:
            return candidates.sorted {
                let a = $0.primaryMuscle, b = $1.primaryMuscle
                return a == b ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending : a < b
            }
        case .smart:
            break
        }

        let scored: [(ExerciseCandidate, Double)] = candidates.compactMap { c in
            if searching {
                let toks = ExerciseSearch.tokens(from: inputs.query)
                guard let s = ExerciseSearch.score(c, tokens: toks, query: inputs.query) else { return nil }
                return (c, Double(s) * 10.0 + smartBrowseScore(c, inputs))
            }
            return (c, smartBrowseScore(c, inputs))
        }
        return scored.sorted { a, b in
            a.1 == b.1 ? a.0.name.localizedCaseInsensitiveCompare(b.0.name) == .orderedAscending : a.1 > b.1
        }.map { $0.0 }
    }

    private static func smartBrowseScore(_ c: ExerciseCandidate, _ inputs: RankingInputs) -> Double {
        let ctx = inputs.context
        var s = 0.0
        if ctx.hasFocus {
            s += wDay * dayMatch(c, ctx)
            s += wGap * coverageGap(c, ctx)
            s -= wDup * duplicatePenalty(c, ctx)
        }
        s += wCompound * (MuscleTaxonomy.isCompound(movementPattern: c.movementPattern) ? 1.0 : 0.0)
        s += wPers * inputs.personalization.score(forName: c.name)
        if !inputs.isEquipmentAvailable(c.equipment) { s -= wEquip }
        return s
    }

    private static func muscles(of c: ExerciseCandidate) -> [String] {
        [MuscleTaxonomy.normalize(c.primaryMuscle)] + c.secondaryMuscles.map { MuscleTaxonomy.normalize($0) }
    }

    private static func dayMatch(_ c: ExerciseCandidate, _ ctx: DayContext) -> Double {
        if ctx.targetMuscles.contains(MuscleTaxonomy.normalize(c.primaryMuscle)) { return 1.0 }
        if muscles(of: c).contains(where: { ctx.targetMuscles.contains($0) }) { return 0.5 }
        return 0.0
    }

    private static func coverageGap(_ c: ExerciseCandidate, _ ctx: DayContext) -> Double {
        let p = MuscleTaxonomy.normalize(c.primaryMuscle)
        guard ctx.targetMuscles.contains(p) else { return 0.0 }
        return ctx.addedPrimaryMuscles.contains(p) ? 0.0 : 1.0
    }

    private static func duplicatePenalty(_ c: ExerciseCandidate, _ ctx: DayContext) -> Double {
        if ctx.addedExerciseIDs.contains(c.id) || ctx.addedExerciseNames.contains(MuscleTaxonomy.normalize(c.name)) { return 1.0 }
        if ctx.addedPrimaryMuscles.contains(MuscleTaxonomy.normalize(c.primaryMuscle)) { return 0.5 }
        return 0.0
    }
}
