import Foundation
import Testing
@testable import Elos

/// The precedence chain in `ResolvedExercise.targets`: lifter override → catalog → machine → name.
/// Everything that displays or scores muscle work reads through it, so the order is load-bearing.
struct MuscleTargetResolutionTests {

    private func resolve(_ ex: ScoredExercise) -> ResolvedExercise {
        ExerciseResolver.resolve([[ex]], catalog: QualityFixtures.catalog)[0][0]
    }

    private var lowBackMachine: EquipmentRecord {
        EquipmentDatabase.all.first {
            $0.displayName.localizedCaseInsensitiveContains("PRIME Fitness Low Back Extension")
        }!
    }

    // MARK: Precedence

    @Test func catalogWinsWhenThereIsNoOverride() {
        #expect(resolve(QualityFixtures.sx("bench", sets: 3)).targets.primary == [.chest])
    }

    @Test func lifterOverrideBeatsTheCatalog() {
        // They ticked "rear delts" on something the catalog calls a chest exercise. They win.
        let ex = ScoredExercise(id: "bench", name: "Barbell Bench Press", sets: 3, repsText: "8",
                                muscleTargets: MuscleTargets(primary: [.rearDelts]))
        #expect(resolve(ex).targets.primary == [.rearDelts])
    }

    @Test func lifterOverrideBeatsTheMachine() {
        let m = lowBackMachine
        let ex = ScoredExercise(id: m.equipmentId, name: m.displayName, sets: 3, repsText: "10",
                                equipmentId: m.equipmentId,
                                muscleTargets: MuscleTargets(primary: [.hamstrings]))
        #expect(resolve(ex).targets.primary == [.hamstrings])
    }

    @Test func machineIsUsedWhenTheCatalogHasNothing() {
        let m = lowBackMachine
        let ex = ScoredExercise(id: m.equipmentId, name: m.displayName, sets: 3, repsText: "10",
                                equipmentId: m.equipmentId)
        #expect(resolve(ex).candidate == nil)
        #expect(resolve(ex).targets.primary == [.lowerBack])
    }

    /// A catalog exercise done *on* a machine keeps the catalog's answer — the catalog is the more
    /// precise statement about the movement, and the machine is just where it happened.
    @Test func catalogBeatsTheMachineForAKnownExercise() {
        let ex = ScoredExercise(id: "row", name: "Barbell Row", sets: 3, repsText: "8",
                                equipmentId: lowBackMachine.equipmentId)
        #expect(resolve(ex).targets.primary == [.upperBack])   // catalog says "back"
    }

    @Test func bareNameIsTheLastResort() {
        // No catalog entry, no equipment — a custom exercise typed in by hand.
        let ex = ScoredExercise(id: "", name: "Reverse Hyper", sets: 3, repsText: "12")
        #expect(resolve(ex).candidate == nil)
        #expect(resolve(ex).targets.primary == [.lowerBack])
    }

    @Test func trulyUnknownExercisesResolveToNothing() {
        let ex = ScoredExercise(id: "", name: "Zorble Machine", sets: 3, repsText: "10")
        #expect(resolve(ex).targets.isEmpty)
        #expect(!resolve(ex).hasKnownTargets)
        #expect(MuscleVolumeAnalyzer.credits(resolve(ex)).isEmpty)
    }

    /// An empty override means "go back to automatic", not "trains nothing" — that's what the sheet's
    /// Reset button sends.
    @Test func anEmptyOverrideFallsThroughToAutomatic() {
        let ex = ScoredExercise(id: "bench", name: "Barbell Bench Press", sets: 3, repsText: "8",
                                muscleTargets: MuscleTargets())
        #expect(resolve(ex).targets.primary == [.chest])
    }

    // MARK: Credit

    @Test func multiplePrimariesEachEarnFullCredit() {
        let ex = ScoredExercise(id: "", name: "Custom", sets: 4, repsText: "10",
                                muscleTargets: MuscleTargets(primary: [.chest, .frontDelts],
                                                             secondary: [.triceps]))
        let c = MuscleVolumeAnalyzer.credits(resolve(ex))
        #expect(c[.chest]?.direct == 4)
        #expect(c[.frontDelts]?.direct == 4)
        #expect(c[.triceps]?.direct == 0)
        #expect(c[.triceps]?.indirect == 4 * TrainingScience.secondaryCredit)
    }

    @Test func zeroSetsEarnNothing() {
        let ex = ScoredExercise(id: "bench", name: "Barbell Bench Press", sets: 0, repsText: "8")
        #expect(MuscleVolumeAnalyzer.credits(resolve(ex)).isEmpty)
    }

    @Test func overridingAwayFromAMuscleRemovesItsCredit() {
        // Re-tagging a bench press as rear delts must leave the chest with nothing, not both.
        let ex = ScoredExercise(id: "bench", name: "Barbell Bench Press", sets: 3, repsText: "8",
                                muscleTargets: MuscleTargets(primary: [.rearDelts]))
        let c = MuscleVolumeAnalyzer.credits(resolve(ex))
        #expect(c[.rearDelts]?.direct == 3)
        #expect(c[.chest] == nil)
    }

    // MARK: The taxonomy fix behind the rear-delt machines

    @Test func rearShouldersIsTheRearDeltsNotTheSideDelts() {
        // 98 shipped machines describe the rear delts as "Rear Shoulders". Before the fix this hit the
        // generic shoulder test and credited side delts.
        #expect(MuscleTaxonomy.fine(forMuscle: "Rear Shoulders") == .rearDelts)
        #expect(MuscleTaxonomy.fine(forMuscle: "rear_shoulders") == .rearDelts)
        #expect(MuscleTaxonomy.fine(forMuscle: "Shoulders") == .sideDelts)   // unchanged
    }

    @Test func everyRearShoulderMachineCreditsRearDelts() {
        let rearMachines = EquipmentDatabase.all.filter { $0.bodyParts.contains("Rear Shoulders") }
        #expect(!rearMachines.isEmpty, "precondition: the vocabulary still ships")
        for m in rearMachines {
            let opts = EquipmentMuscleMap.options(for: m)
            #expect(opts.contains(.rearDelts), "\(m.displayName) never offers rear delts")
        }
    }
}
