import Testing
@testable import Elos

/// Guards muscle attribution against the **real shipped catalog** rather than fixtures.
///
/// This matters because the failure mode is silent: if an exercise's muscle key doesn't resolve,
/// `MuscleVolumeAnalyzer.credits` simply returns nothing for it. The exercise still appears in the
/// picker and still logs fine — it just contributes zero to every coverage bar and quietly drags the
/// quality score down, with nothing on screen to indicate why. A fixture-based test can't catch that;
/// only walking the catalog can.
struct CatalogMuscleCoverageTests {

    private var allMuscles: Set<String> {
        var s = Set<String>()
        for (_, primary, secondaries, _, _) in ExerciseCatalog.catalog {
            s.insert(primary)
            secondaries.forEach { s.insert($0) }
        }
        return s
    }

    @Test func everyCatalogPrimaryMuscleResolves() {
        var unresolved: [String] = []
        for (name, primary, _, _, _) in ExerciseCatalog.catalog
        where MuscleTaxonomy.fine(forMuscle: primary) == nil {
            unresolved.append("\(name) → '\(primary)'")
        }
        #expect(unresolved.isEmpty, "unresolved primary muscles: \(unresolved.prefix(10))")
    }

    @Test func everyCatalogSecondaryMuscleResolves() {
        var unresolved = Set<String>()
        for (_, _, secondaries, _, _) in ExerciseCatalog.catalog {
            for m in secondaries where MuscleTaxonomy.fine(forMuscle: m) == nil { unresolved.insert(m) }
        }
        #expect(unresolved.isEmpty, "unresolved secondary muscles: \(unresolved.sorted())")
    }

    /// `knownMuscleVocabulary` is what the taxonomy's invariant test walks. If the catalog starts
    /// using a muscle that isn't declared there, that muscle goes unverified — which is exactly how
    /// "abs" (a primary on real exercises) slipped through unchecked.
    @Test func vocabularyConstantCoversTheRealCatalog() {
        let declared = Set(MuscleTaxonomy.knownMuscleVocabulary)
        let missing = allMuscles.subtracting(declared)
        #expect(missing.isEmpty, "catalog muscles missing from knownMuscleVocabulary: \(missing.sorted())")
    }

    /// Unambiguous attributions. A wrong answer here means the coverage bars credit the wrong muscle.
    @Test func attributionIsCorrectForUnambiguousLifts() {
        let expected: [String: MuscleGroup] = [
            "Barbell Bench Press": .chest,
            "Lat Pulldown": .back,
            "Barbell Row": .back,
            "Face Pull": .back,               // rear delts belong to pull work
            "Barbell Overhead Press": .shoulders,
            "Lateral Raise": .shoulders,      // must not resolve to lats via the "lat" substring
            "Barbell Curl": .arms,
            "Barbell Back Squat": .legs,
            "Romanian Deadlift": .legs,
            "Standing Calf Raise": .legs,
            "Hip Thrust": .glutes,
            "Plank": .core,
            "Hanging Leg Raise": .core,       // hip flexors are core, not glutes
        ]
        let byName = Dictionary(ExerciseCatalog.catalog.map { ($0.0, $0) }, uniquingKeysWith: { a, _ in a })

        for (name, group) in expected {
            guard let row = byName[name] else {
                Issue.record("'\(name)' is no longer in the catalog — update this test")
                continue
            }
            #expect(MuscleTaxonomy.group(forMuscle: row.1) == group,
                    "\(name): primary '\(row.1)' resolved to \(String(describing: MuscleTaxonomy.group(forMuscle: row.1))), expected \(group)")
        }
    }

    /// End-to-end: a push day built from real catalog entries must credit the pushing muscles and
    /// leave the untrained ones at zero.
    @Test func pushDayCreditsPushingMusclesOnly() {
        let candidates = ExerciseCatalog.catalog.map {
            ExerciseCandidate(id: $0.0, name: $0.0, primaryMuscle: $0.1, secondaryMuscles: $0.2,
                              equipment: $0.3, movementPattern: $0.4, isCustom: false)
        }
        func sx(_ name: String, _ sets: Int) -> ScoredExercise {
            ScoredExercise(id: name, name: name, sets: sets, repsText: "8-10", restSeconds: 120)
        }
        let resolved = ExerciseResolver.resolve(
            [[sx("Barbell Bench Press", 4), sx("Barbell Overhead Press", 3), sx("Straight Bar Pushdown", 3)]],
            catalog: candidates)
        #expect(resolved.flatMap { $0 }.allSatisfy { $0.candidate != nil },
                "a push-day exercise failed to match the catalog")

        let vol = MuscleVolumeAnalyzer.analyze(
            resolvedDays: resolved, scope: .singleSession, intent: nil, dayNames: ["Push"],
            profile: .init(goal: .hypertrophy, experience: .intermediate), catalog: candidates)

        #expect(vol.directSets(for: .chest) == 4)
        #expect(vol.directSets(for: .frontDelts) == 3)
        #expect(vol.directSets(for: .triceps) == 3)
        // Pressing adds secondary triceps credit on top of the direct pushdown work.
        #expect(vol.sets(for: .triceps) > vol.directSets(for: .triceps))
        #expect(vol.sets(forGroup: .legs) == 0)
        #expect(vol.sets(forGroup: .back) == 0)
    }
}
