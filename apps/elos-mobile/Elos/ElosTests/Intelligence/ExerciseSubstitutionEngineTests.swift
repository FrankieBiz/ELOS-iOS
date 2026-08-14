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
}
