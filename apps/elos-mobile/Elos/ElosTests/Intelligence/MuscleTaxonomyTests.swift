import Testing
@testable import Elos

struct MuscleTaxonomyTests {
    @Test func normalizesUnderscoresAndCase() {
        #expect(MuscleTaxonomy.normalize("Rear_Delts") == "rear delts")
    }
    @Test func classifiesCompoundVsIsolation() {
        #expect(MuscleTaxonomy.isCompound(movementPattern: "push"))
        #expect(MuscleTaxonomy.isCompound(movementPattern: "hinge"))
        #expect(!MuscleTaxonomy.isCompound(movementPattern: "isolation"))
        #expect(!MuscleTaxonomy.isCompound(movementPattern: "rotation"))
    }
    @Test func mapsMuscleToGroup() {
        #expect(MuscleTaxonomy.group(forMuscle: "front_delts") == .shoulders)
        #expect(MuscleTaxonomy.group(forMuscle: "lats") == .back)
        #expect(MuscleTaxonomy.group(forMuscle: "rear_delts") == .back)
        #expect(MuscleTaxonomy.group(forMuscle: "quads") == .legs)
    }
    @Test func aliasesDayNameToArchetype() {
        #expect(MuscleTaxonomy.archetype(forDayName: "Push") == .push)
        #expect(MuscleTaxonomy.archetype(forDayName: "Chest & Tri") == .push)
        #expect(MuscleTaxonomy.archetype(forDayName: "Back & Bi") == .pull)
        #expect(MuscleTaxonomy.archetype(forDayName: "Leg Day") == .legs)
        #expect(MuscleTaxonomy.archetype(forDayName: "Upper") == .upper)
        #expect(MuscleTaxonomy.archetype(forDayName: "") == nil)
        #expect(MuscleTaxonomy.archetype(forDayName: "Cardio") == nil)
    }
    @Test func pushArchetypeTargetsPressingMuscles() {
        let t = MuscleTaxonomy.targetMuscles(forArchetype: .push)
        #expect(t.contains("chest"))
        #expect(t.contains("triceps"))
        #expect(!t.contains("lats"))
    }

    // MARK: - Fine muscle layer

    /// The load-bearing invariant: every muscle string in the real catalog vocabulary must resolve to
    /// a fine slot, and that slot's group must equal what `group(forMuscle:)` reports. Walking the
    /// whole vocabulary (not a sample) is the point — the secondary-only tokens like `hip_flexors`
    /// and `external_rotators` are exactly the ones a hand-picked sample would miss.
    @Test func everyKnownMuscleResolvesAndAgreesWithItsGroup() {
        for muscle in MuscleTaxonomy.knownMuscleVocabulary {
            let fine = MuscleTaxonomy.fine(forMuscle: muscle)
            #expect(fine != nil, "no fine slot for '\(muscle)'")
            guard let fine else { continue }
            #expect(MuscleTaxonomy.group(forMuscle: muscle) == fine.group,
                    "'\(muscle)' → \(fine) → \(fine.group), but group(forMuscle:) disagrees")
        }
    }

    /// `group(forMuscle:)` is derived from the fine layer, so a nil fine slot must mean a nil group —
    /// otherwise a muscle could be classified for scoring but silently dropped from the bars.
    @Test func unknownMuscleIsNilAtBothLevels() {
        #expect(MuscleTaxonomy.fine(forMuscle: "wingardium") == nil)
        #expect(MuscleTaxonomy.group(forMuscle: "wingardium") == nil)
    }

    /// Both were bugs before the fine layer: the rotators fell through to `nil` (7 seeded exercises
    /// invisible to every scorer), and `hip_flexors` hit the generic `contains("hip")` test and
    /// landed in `.glutes` instead of core.
    @Test func rotatorsAndHipFlexorsClassifyCorrectly() {
        #expect(MuscleTaxonomy.fine(forMuscle: "external_rotators") == .rotatorCuff)
        #expect(MuscleTaxonomy.fine(forMuscle: "internal_rotators") == .rotatorCuff)
        #expect(MuscleTaxonomy.group(forMuscle: "external_rotators") == .shoulders)

        #expect(MuscleTaxonomy.fine(forMuscle: "hip_flexors") == .abs)
        #expect(MuscleTaxonomy.group(forMuscle: "hip_flexors") == .core)
        // The generic hip/adductor strings must still reach glutes.
        #expect(MuscleTaxonomy.group(forMuscle: "adductors") == .glutes)
        #expect(MuscleTaxonomy.group(forMuscle: "hip_abductors") == .glutes)
    }

    /// "lateral raise"-style strings must not be swallowed by the `lat` test for the back.
    @Test func lateralDoesNotResolveAsLats() {
        #expect(MuscleTaxonomy.fine(forMuscle: "lateral delts") == .sideDelts)
        #expect(MuscleTaxonomy.fine(forMuscle: "lats") == .lats)
    }

    @Test func groupChildrenPartitionTheFineMuscles() {
        // Every fine muscle appears under exactly one group, and no group is empty.
        let all = MuscleGroup.allCases.flatMap { $0.children }
        #expect(Set(all).count == FineMuscle.allCases.count)
        #expect(all.count == FineMuscle.allCases.count)
        for g in MuscleGroup.allCases {
            #expect(!g.children.isEmpty)
            for child in g.children { #expect(child.group == g) }
        }
    }
}
