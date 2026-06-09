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
}
