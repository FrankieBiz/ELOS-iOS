import Foundation
import Testing
@testable import Elos

/// Covers the fix for "I used the PRIME Low Back Extension and it said I worked no lower back".
///
/// Picking a machine straight from the picker stores its *equipment* id as the exercise id, which
/// matches no catalog entry by id and no catalog entry by name — so the exercise resolved to nothing
/// and earned zero credit on every muscle. These tests run against the **real shipped equipment
/// database**, not fixtures, because the bug lived in the gap between the two datasets.
struct EquipmentMuscleMapTests {

    private func machine(_ needle: String) -> EquipmentRecord {
        let hit = EquipmentDatabase.all.first {
            $0.displayName.localizedCaseInsensitiveContains(needle)
        }
        #expect(hit != nil, "no shipped machine matching '\(needle)'")
        return hit!
    }

    // MARK: The reported bug

    @Test func lowBackExtensionTrainsTheLowerBack() {
        let t = EquipmentMuscleMap.targets(for: machine("PRIME Fitness Low Back Extension"))
        #expect(t?.primary == [.lowerBack])
        #expect(t?.secondary.contains(.glutes) == true)
    }

    /// End to end through the resolver: a machine picked with no catalog entry behind it still earns
    /// *direct* lower-back sets. This is the assertion that was false before the fix.
    @Test func machinePickedDirectlyEarnsDirectVolume() {
        let m = machine("PRIME Fitness Low Back Extension")
        let picked = DayExercise(id: m.equipmentId, name: m.displayName, sets: 4, reps: "10",
                                 equipmentId: m.equipmentId)
        let resolved = ExerciseResolver.resolve([[ScoredExercise(day: picked)]],
                                               catalog: QualityFixtures.catalog)

        #expect(resolved[0][0].candidate == nil, "precondition: this matches no catalog exercise")
        #expect(resolved[0][0].targets.primary == [.lowerBack])

        let credits = MuscleVolumeAnalyzer.credits(resolved[0][0])
        #expect(credits[.lowerBack]?.direct == 4)
        #expect(credits[.lowerBack]?.isTargeted == true)
        #expect(credits[.glutes]?.indirect ?? 0 > 0)
    }

    @Test func machinePickedDirectlyShowsUpInTheCoverageReport() {
        let m = machine("PRIME Fitness Low Back Extension")
        let picked = DayExercise(id: m.equipmentId, name: m.displayName, sets: 4, reps: "10",
                                 equipmentId: m.equipmentId)
        let resolved = ExerciseResolver.resolve([[ScoredExercise(day: picked)]],
                                               catalog: QualityFixtures.catalog)
        let report = QualityFixtures.volume(resolved, scope: .singleSession)

        #expect(report.directSets(for: .lowerBack) == 4)
        #expect(report.expected.contains(.lowerBack), "trained muscles are always expected")
    }

    /// And it reaches the picker's chip strip, which counts `DayContext.addedTargets`.
    @Test func machinePickedDirectlyCountsInCoverageChips() {
        let m = machine("PRIME Fitness Low Back Extension")
        let picked = DayExercise(id: m.equipmentId, name: m.displayName, sets: 4, reps: "10",
                                 equipmentId: m.equipmentId)
        let ctx = DayContextInferrer.infer(dayName: "Pull", added: [picked],
                                           catalog: QualityFixtures.catalog)
        #expect(MuscleCoverage.chips(context: ctx).first { $0.muscleGroup == "Back" }?.level
                == CoverageLevel.some)
    }

    // MARK: Machines that do more than one movement

    @Test func pecRearDeltStationIsAmbiguousAndOffersBothMovements() {
        let m = machine("PRIME Fitness Pec/Rear Delt")
        #expect(EquipmentMuscleMap.isAmbiguous(m))

        let labels = EquipmentMuscleMap.movements(for: m).map(\.label)
        #expect(labels.contains("Pec fly"))
        #expect(labels.contains("Rear delt"))

        // Filed under Chest by the manufacturer, so the fly is the default guess.
        #expect(EquipmentMuscleMap.targets(for: m)?.primary == [.chest])

        // Both answers are reachable from the sheet's presets.
        let rearDelt = EquipmentMuscleMap.movements(for: m).first { $0.label == "Rear delt" }
        #expect(rearDelt?.targets.primary == [.rearDelts])
    }

    @Test func aSingleMovementMachineIsNotAmbiguous() {
        #expect(!EquipmentMuscleMap.isAmbiguous(machine("PRIME Fitness Low Back Extension")))
    }

    @Test func ambiguityNeedsMoreThanOneBroadGroup() {
        // A machine whose movements all land in one group isn't worth interrupting the lifter for.
        let rowOnly = EquipmentRecord(
            equipmentId: "x", brandName: "Test", machineName: "Seated Row", modelSeries: "",
            bodyParts: ["Back", "Lats"], equipmentType: "Selectorized",
            primaryCategory: "Back", dedupeKey: "test|seated row|")
        #expect(!EquipmentMuscleMap.isAmbiguous(rowOnly))
    }

    /// Ambiguity is judged on the primary **muscle**, not the broad group and not every group touched.
    /// Both of the obvious alternatives are wrong, in opposite directions.
    @Test func ambiguityIsJudgedOnThePrimaryMuscle() {
        // Over-firing: a pulldown/row combo is lats either way. The row's secondary rear-delts pulled
        // in a second *group*, which used to make the app interrupt for nothing (24 machines did this).
        let pulldownRow = machine("Lat Pulldown / High Row")
        #expect(EquipmentMuscleMap.movements(for: pulldownRow).count > 1, "precondition: two movements")
        #expect(!EquipmentMuscleMap.isAmbiguous(pulldownRow))

        // Under-firing: quads and calves are both `.legs`, so a group-level check would call a
        // Leg Press / Calf Raise unambiguous and silently pick quads.
        let legPressCalf = machine("Leg Press / Calf Raise")
        #expect(EquipmentMuscleMap.isAmbiguous(legPressCalf))
    }

    @Test func aCombinedNameThatMeansOneMuscleDoesNotAsk() {
        // "Inner / Outer Thigh" is adduction and abduction — both credited to the glutes.
        #expect(!EquipmentMuscleMap.isAmbiguous(machine("Inner / Outer Thigh")))
        #expect(!EquipmentMuscleMap.isAmbiguous(machine("Glute Abductor")))
    }

    /// Attribution must be reproducible. `sorted(by:)` is not stable in Swift, so a machine listing
    /// several equally-specific bodyParts could otherwise resolve differently between runs.
    @Test func attributionIsDeterministic() {
        for m in EquipmentDatabase.all.prefix(300) {
            let first = EquipmentMuscleMap.targets(for: m)
            for _ in 0..<3 {
                #expect(EquipmentMuscleMap.targets(for: m) == first, "\(m.displayName) drifted")
            }
        }
    }

    /// Names the spec sheet alone got wrong, now resolved by the movement lexicon.
    @Test func namesThatTheSpecSheetAloneMisread() {
        // ["Full Body", "Arms"] expanded to [biceps, triceps] and picked biceps for a triceps machine.
        #expect(EquipmentMuscleMap.targets(for: machine("Eagle Arm Extension"))?.primary == [.triceps])
        // Four equally-specific parts, none of them the actual target.
        #expect(EquipmentMuscleMap.targets(for: machine("Selection Upper Back"))?.primary == [.upperBack])
        // Coarse "Shoulders" guessed front delts for what is a lateral raise.
        #expect(EquipmentMuscleMap.targets(for: machine("Deltoid Raise"))?.primary == [.sideDelts])
        // ...but a Deltoid *Press* really is a front-delt press, and must not start asking.
        #expect(EquipmentMuscleMap.targets(for: machine("Deltoid Press"))?.primary == [.frontDelts])
        #expect(!EquipmentMuscleMap.isAmbiguous(machine("Deltoid Press")))
        // Six equally-specific parts on a knee-raise tower.
        #expect(EquipmentMuscleMap.targets(for: machine("Vertical Knee Plus"))?.primary == [.abs])
    }

    /// Asking is an interruption, so it has to stay rare and always justified.
    @Test func askingStaysRare() {
        let trainable = EquipmentDatabase.all.filter {
            !["Storage", "Cardio", "Storage / Accessory"].contains($0.primaryCategory)
        }
        let asked = trainable.filter { EquipmentMuscleMap.isAmbiguous($0) }
        #expect(Double(asked.count) / Double(trainable.count) < 0.15,
                "\(asked.count)/\(trainable.count) machines ask — too many")
        // And never for a machine whose movements agree on the muscle.
        for m in asked {
            let primaries = Set(EquipmentMuscleMap.movements(for: m).compactMap { $0.targets.primary.first })
            #expect(primaries.count > 1, "\(m.displayName) asks but its movements agree")
        }
    }

    // MARK: Check-off options

    @Test func optionsCoverBothTheNameAndTheSpecSheet() {
        let opts = EquipmentMuscleMap.options(for: machine("PRIME Fitness Low Back Extension"))
        // From the movement lexicon:
        #expect(opts.contains(.lowerBack))
        #expect(opts.contains(.hamstrings))
        // From the record's own bodyParts (["Back", "Lower Back", "Core", "Glutes"]):
        #expect(opts.contains(.abs))
        #expect(opts.contains(.glutes))
        #expect(opts == FineMuscle.allCases.filter { opts.contains($0) }, "returned in taxonomy order")
    }

    @Test func optionsAreOfferedForAmbiguousMachines() {
        let opts = EquipmentMuscleMap.options(for: machine("PRIME Fitness Pec/Rear Delt"))
        #expect(opts.contains(.chest))
        #expect(opts.contains(.rearDelts))
    }

    // MARK: Bad scraped data can't corrupt credit

    /// PRIME's Double-Sided Preacher Curl really is listed as `["Chest", "Shoulders"]` in the shipped
    /// database. The name has to win, or a curl trains the chest.
    @Test func nameBeatsWrongBodyParts() {
        let m = EquipmentDatabase.all.first {
            $0.displayName.localizedCaseInsensitiveContains("Double-Sided Preacher Curl")
                && $0.bodyParts.contains("Chest")
        }
        #expect(m != nil, "precondition: the mis-tagged record still ships")
        #expect(EquipmentMuscleMap.targets(for: m!)?.primary == [.biceps])
    }

    @Test func storageAndCardioYieldNothing() {
        let rack = EquipmentRecord(
            equipmentId: "x", brandName: "Test", machineName: "3 Tier Dumbbell Rack", modelSeries: "",
            bodyParts: [], equipmentType: "Storage", primaryCategory: "Storage",
            dedupeKey: "test|3 tier dumbbell rack|")
        #expect(EquipmentMuscleMap.movements(for: rack).isEmpty)
        #expect(EquipmentMuscleMap.targets(for: rack) == nil)
    }

    /// "Full Body" is the database's shrug — it must not be turned into a muscle.
    @Test func fullBodyExpandsToNothing() {
        #expect(EquipmentMuscleMap.expand(bodyPart: "Full Body").isEmpty)
    }

    @Test func coarseBodyPartsExpandToTheWholeRegion() {
        #expect(EquipmentMuscleMap.expand(bodyPart: "Arms") == [.biceps, .triceps])
        #expect(EquipmentMuscleMap.expand(bodyPart: "Back") == [.lats, .upperBack])
        #expect(EquipmentMuscleMap.expand(bodyPart: "Legs") == [.quads, .hamstrings, .calves])
    }

    // MARK: bodyParts fallback, when the name says nothing

    @Test func unrecognizedNameFallsBackToMostSpecificBodyPart() {
        let odd = EquipmentRecord(
            equipmentId: "x", brandName: "Test", machineName: "Xtreme Unit 9000", modelSeries: "",
            bodyParts: ["Legs", "Quads"], equipmentType: "Selectorized",
            primaryCategory: "Legs", dedupeKey: "test|xtreme unit 9000|")
        // "Quads" is more specific than "Legs", so it becomes the primary.
        #expect(EquipmentMuscleMap.targets(for: odd)?.primary == [.quads])
    }

    // MARK: The whole shipped database

    /// Every machine a lifter can actually train on should attribute *something*. A silent nil here is
    /// exactly the failure mode the original bug had.
    @Test func everyTrainableMachineAttributesSomeMuscle() {
        let ignored: Set<String> = ["Storage", "Cardio", "Storage / Accessory"]
        let unattributed = EquipmentDatabase.all
            .filter { !ignored.contains($0.primaryCategory) && !ignored.contains($0.equipmentType) }
            .filter { !$0.bodyParts.isEmpty && $0.bodyParts != ["Full Body"] }
            .filter { EquipmentMuscleMap.targets(for: $0) == nil }
            .map(\.displayName)
        #expect(unattributed.isEmpty, "unattributed machines: \(unattributed.prefix(10))")
    }
}
