import Testing
@testable import Elos

struct ExerciseRankingEngineTests {
    private let bench   = ExerciseCandidate(id: "bench", name: "Barbell Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false)
    private let fly     = ExerciseCandidate(id: "fly", name: "Cable Fly", primaryMuscle: "chest", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false)
    private let curl    = ExerciseCandidate(id: "curl", name: "Leg Curl", primaryMuscle: "hamstrings", secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false)

    private func inputs(_ ctx: DayContext, query: String = "",
                        avail: @escaping (String) -> Bool = { _ in true }) -> RankingInputs {
        RankingInputs(context: ctx,
                      personalization: PersonalizationProvider(signals: .init()),
                      isEquipmentAvailable: avail, query: query)
    }

    @Test func pushDayRanksPushAboveLegs() {
        let ctx = DayContextInferrer.infer(dayName: "Push", added: [], catalog: [bench, fly, curl])
        let ranked = ExerciseRankingEngine.rank([curl, fly, bench], inputs: inputs(ctx))
        #expect(ranked.first?.id == "bench")
        #expect(ranked.last?.id == "curl")
    }
    @Test func compoundBeatsIsolationAtEqualTarget() {
        let ctx = DayContextInferrer.infer(dayName: "Push", added: [], catalog: [bench, fly])
        let ranked = ExerciseRankingEngine.rank([fly, bench], inputs: inputs(ctx))
        #expect(ranked.first?.id == "bench")
    }
    @Test func alreadyAddedIsDemoted() {
        let added = [DayExercise(id: "bench", name: "Barbell Bench Press")]
        let ctx = DayContextInferrer.infer(dayName: "Push", added: added, catalog: [bench, fly])
        let ranked = ExerciseRankingEngine.rank([bench, fly], inputs: inputs(ctx))
        #expect(ranked.first?.id == "fly")
    }
    @Test func queryDominatesAndMatchesSearchOrder() {
        let ctx = DayContext.empty
        let ranked = ExerciseRankingEngine.rank([curl, fly, bench], inputs: inputs(ctx, query: "bench"))
        #expect(ranked.first?.id == "bench")
        #expect(!ranked.contains { $0.id == "curl" })
    }
    @Test func unavailableEquipmentDemotedNotRemoved() {
        let ctx = DayContextInferrer.infer(dayName: "Push", added: [], catalog: [bench, fly])
        let ranked = ExerciseRankingEngine.rank([fly, bench],
            inputs: inputs(ctx, avail: { $0.lowercased() != "barbell" }))
        #expect(ranked.contains { $0.id == "bench" })
        #expect(ranked.first?.id == "fly")
    }
    @Test func alphabeticalModeIgnoresContext() {
        let ranked = ExerciseRankingEngine.rank([fly, bench, curl],
            inputs: inputs(.empty), mode: .alphabetical)
        #expect(ranked.map { $0.name } == ["Barbell Bench Press", "Cable Fly", "Leg Curl"])
    }
}
