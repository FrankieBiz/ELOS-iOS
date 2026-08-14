import Testing
@testable import Elos

struct ExerciseSubstitutionEngineTests {
    private static let squat = ExerciseCandidate(
        id: "1", name: "Barbell Back Squat", primaryMuscle: "quads",
        secondaryMuscles: ["glutes", "hamstrings"], equipment: "barbell",
        movementPattern: "squat", isCustom: false)
    private static let goblet = ExerciseCandidate(
        id: "2", name: "Goblet Squat", primaryMuscle: "quads",
        secondaryMuscles: ["glutes"], equipment: "dumbbell",
        movementPattern: "squat", isCustom: false)

    @Test func resolveSourceMatchesByNormalizedName() {
        let resolved = ExerciseSubstitutionEngine.resolveSource(
            name: "barbell   back squat", candidates: [Self.squat, Self.goblet])
        #expect(resolved?.id == Self.squat.id)
    }

    @Test func resolveSourceReturnsNilForUnresolvableName() {
        let resolved = ExerciseSubstitutionEngine.resolveSource(
            name: "Some Totally Custom Thing", candidates: [Self.squat, Self.goblet])
        #expect(resolved == nil)
    }

    private static let legExtension = ExerciseCandidate(
        id: "4", name: "Leg Extension", primaryMuscle: "quads",
        secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false)
    private static let legCurl = ExerciseCandidate(
        id: "5", name: "Leg Curl", primaryMuscle: "hamstrings",
        secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false)
    private static let rdl = ExerciseCandidate(
        id: "6", name: "Romanian Deadlift", primaryMuscle: "hamstrings",
        secondaryMuscles: ["glutes", "lower_back"], equipment: "barbell",
        movementPattern: "hinge", isCustom: false)

    @Test func exactMuscleMatchPlusPatternMatchDoesNotDoubleCountViaCompoundClass() {
        // Same primary muscle (+3) + same "squat" pattern (+1) + overlapping secondary "glutes"
        // (+1, both fixtures list it) = 5. Compound-class must NOT also fire here — patterns are
        // identical, not merely both-compound, so this stays 5, not 6.
        let (score, _) = ExerciseSubstitutionEngine.scoreCandidate(source: Self.squat, candidate: Self.goblet)
        #expect(score == 5)
    }

    @Test func crossPatternCompoundSimilarityScoresIndependently() {
        // Different muscle (group-only, +1) + shared secondary "glutes" (+1) + both compound but
        // different pattern, squat vs hinge (+1) = 3.
        let (score, _) = ExerciseSubstitutionEngine.scoreCandidate(source: Self.squat, candidate: Self.rdl)
        #expect(score == 3)
    }

    @Test func genericIsolationPatternIsNotATrueSignal() {
        // Antagonists (quads vs hamstrings) that happen to both be "isolation" pattern must NOT
        // get a pattern-match point — group-only (+1) is all they share.
        let (score, _) = ExerciseSubstitutionEngine.scoreCandidate(source: Self.legExtension, candidate: Self.legCurl)
        #expect(score == 1)
    }

    @Test func barbellSquatUnavailablePrefersEquipmentMatchedQuadCompounds() {
        let equipment = EquipmentPreference(posture: .custom, customTypes: ["dumbbell", "machine"])
        let all = [Self.squat, Self.goblet, Self.legExtension, Self.legCurl, Self.rdl]
        let results = ExerciseSubstitutionEngine.suggest(for: Self.squat, candidates: all, equipment: equipment)
        let names = results.map(\.name)
        #expect(names.first == "Goblet Squat")
        #expect(!names.contains("Leg Curl"))          // unrelated muscle+pattern, score 1, excluded
        #expect(!names.contains("Romanian Deadlift"))  // uses barbell, hard-filtered by equipment
    }

    @Test func legExtensionAndLegCurlNeverSuggestEachOther() {
        let results = ExerciseSubstitutionEngine.suggest(for: Self.legExtension, candidates: [Self.legCurl], equipment: .fullGym)
        #expect(results.isEmpty)
    }

    @Test func tiesBreakAlphabeticallyByName() {
        let zebra = ExerciseCandidate(id: "z", name: "Zebra Press", primaryMuscle: "quads",
            secondaryMuscles: [], equipment: "machine", movementPattern: "squat", isCustom: false)
        let apple = ExerciseCandidate(id: "a", name: "Apple Squat", primaryMuscle: "quads",
            secondaryMuscles: [], equipment: "machine", movementPattern: "squat", isCustom: false)
        let results = ExerciseSubstitutionEngine.suggest(for: Self.squat, candidates: [zebra, apple], equipment: .fullGym)
        #expect(results.map(\.name) == ["Apple Squat", "Zebra Press"])
    }

    @Test func sourceExcludedFromItsOwnSuggestions() {
        let results = ExerciseSubstitutionEngine.suggest(for: Self.squat, candidates: [Self.squat, Self.goblet], equipment: .fullGym)
        #expect(!results.map(\.name).contains("Barbell Back Squat"))
    }

    @Test func limitCapsResultCount() {
        let many = (0..<10).map { i in
            ExerciseCandidate(id: "m\(i)", name: "Quad Move \(i)", primaryMuscle: "quads",
                secondaryMuscles: [], equipment: "machine", movementPattern: "squat", isCustom: false)
        }
        let results = ExerciseSubstitutionEngine.suggest(for: Self.squat, candidates: many, equipment: .fullGym, limit: 5)
        #expect(results.count == 5)
    }
}
