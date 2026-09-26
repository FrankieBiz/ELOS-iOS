import Foundation
import Testing
@testable import Elos

// MARK: - Taxonomy

/// The coarsening layer is the load-bearing part of this feature: without it, the gym's learned
/// equipment is compared against a vocabulary it shares no strings with, and every gym-aware nudge
/// silently does nothing while still looking wired up.
struct GymEquipmentTaxonomyTests {

    @Test func selectorizedAndPlateLoadedAreMachines() {
        #expect(GymEquipmentTaxonomy.coarseTypes(forCatalogType: "Selectorized").contains("machine"))
        #expect(GymEquipmentTaxonomy.coarseTypes(forCatalogType: "Plate-Loaded").contains("machine"))
        #expect(GymEquipmentTaxonomy.coarseTypes(forCatalogType: "Strength Machine").contains("machine"))
    }

    @Test func cableIsCable() {
        #expect(GymEquipmentTaxonomy.coarseTypes(forCatalogType: "Cable") == ["cable"])
    }

    @Test func aCompoundTypeContributesEveryTokenItEarns() {
        let t = GymEquipmentTaxonomy.coarseTypes(forCatalogType: "Cable / Multi-Station")
        #expect(t.contains("cable"))
        #expect(t.contains("machine"))
    }

    @Test func benchesAndRacksAreFreeWeightStations() {
        let t = GymEquipmentTaxonomy.coarseTypes(forCatalogType: "Bench/Rack")
        #expect(t.contains("barbell"))
        #expect(t.contains("dumbbell"))
        #expect(!t.contains("machine"))
    }

    @Test func storageAndCardioAreNotTrainingEquipment() {
        #expect(!GymEquipmentTaxonomy.isTrainingRelevant(catalogType: "Storage"))
        #expect(!GymEquipmentTaxonomy.isTrainingRelevant(catalogType: "Storage / Accessory"))
        #expect(!GymEquipmentTaxonomy.isTrainingRelevant(catalogType: "Cardio"))
        #expect(!GymEquipmentTaxonomy.isTrainingRelevant(catalogType: "Flexibility"))
        #expect(GymEquipmentTaxonomy.isTrainingRelevant(catalogType: "Selectorized"))
    }

    /// The regression test that matters. Walks the REAL catalog rather than a hand-picked sample:
    /// every training-relevant equipment type shipping in `EquipmentDatabase` must coarsen into at
    /// least one token, and every token it produces must be one the exercise catalog actually uses.
    /// A new manufacturer vocabulary word that maps to nothing fails here instead of quietly
    /// disabling the gym nudge for everyone who owns that machine.
    @Test func everyRealCatalogTypeCoarsensIntoTheExerciseVocabulary() {
        let types = Set(EquipmentDatabase.all.map(\.equipmentType))
            .filter { GymEquipmentTaxonomy.isTrainingRelevant(catalogType: $0) }
        #expect(!types.isEmpty, "sanity: the catalog should have training equipment in it")

        for type in types {
            let coarse = GymEquipmentTaxonomy.coarseTypes(forCatalogType: type)
            #expect(!coarse.isEmpty, "\(type) coarsens to nothing — the gym nudge is dead for it")
            #expect(coarse.isSubset(of: GymEquipmentTaxonomy.exerciseVocabulary),
                    "\(type) produced tokens outside the exercise vocabulary: \(coarse)")
        }
    }
}

// MARK: - Inventory

struct GymInventoryTests {

    private func entry(_ key: String, type: String = "Selectorized", brand: String = "Hammer Strength",
                       excluded: Bool = false, seen: Int = 1) -> GymEquipmentEntry {
        GymEquipmentEntry(dedupeKey: key, equipmentId: "eq-\(key)", displayName: key,
                          brandName: brand, equipmentType: type, source: .logged,
                          timesSeen: seen, isExcluded: excluded)
    }

    @Test func anEmptyInventoryIsUnknownNotAnEmptyGym() {
        let inv = GymInventory(gymID: "g", gymName: "Fairless", entries: [])
        #expect(!inv.isKnown)
        // The critical asymmetry: we must never claim a machine is missing from a gym we know
        // nothing about, or a lifter's first session gets second-guessed on every exercise.
        #expect(!inv.knownMissing(dedupeKey: "anything"))
    }

    @Test func coarseTypesComeFromTheEntriesEquipmentTypes() {
        let inv = GymInventory(gymID: "g", gymName: "Fairless",
                               entries: [entry("row"), entry("pulldown", type: "Cable")])
        #expect(inv.equipmentTypes == ["machine", "cable"])
        #expect(inv.machineCount == 2)
    }

    @Test func anExcludedEntryIsNotPartOfTheInventory() {
        let inv = GymInventory(gymID: "g", gymName: "Fairless",
                               entries: [entry("row"), entry("pulldown", excluded: true)])
        #expect(inv.has(dedupeKey: "row"))
        #expect(!inv.has(dedupeKey: "pulldown"))
        #expect(inv.isExcluded(dedupeKey: "pulldown"))
        #expect(inv.entries.count == 1, "excluded rows are tombstones, not inventory")
    }

    @Test func knownMissingOnlyFiresOnceTheGymIsActuallyKnown() {
        let inv = GymInventory(gymID: "g", gymName: "Fairless", entries: [entry("row")])
        #expect(inv.knownMissing(dedupeKey: "leg press"))
        #expect(!inv.knownMissing(dedupeKey: "row"))
    }

    @Test func brandsAreCollectedForDisplay() {
        let inv = GymInventory(gymID: "g", gymName: "F",
                               entries: [entry("a", brand: "Cybex"), entry("b", brand: "Nautilus")])
        #expect(inv.brands == ["Cybex", "Nautilus"])
    }
}

// MARK: - Learning rules

struct GymEquipmentLearningTests {

    private static let db: [EquipmentRecord] = [
        EquipmentRecord(equipmentId: "eq1", brandName: "Hammer Strength", machineName: "Row",
                        modelSeries: "", bodyParts: ["Back"], equipmentType: "Plate-Loaded",
                        primaryCategory: "Back", dedupeKey: "hammer|row"),
        EquipmentRecord(equipmentId: "eq2", brandName: "Cybex", machineName: "Dumbbell Rack",
                        modelSeries: "", bodyParts: [], equipmentType: "Storage",
                        primaryCategory: "Storage", dedupeKey: "cybex|db rack"),
    ]

    private func obs(_ key: String, gym: String = "gym-a", source: GymEquipmentSource = .logged,
                     at: Date = Date(timeIntervalSince1970: 1_000)) -> GymEquipmentObservation {
        GymEquipmentObservation(gymID: gym, dedupeKey: key, source: source, at: at)
    }

    // MARK: describe

    @Test func describeFillsDisplayFieldsFromTheCatalog() {
        let e = GymEquipmentLearning.describe(observation: obs("hammer|row"), database: Self.db)
        #expect(e?.displayName == "Hammer Strength Row")
        #expect(e?.brandName == "Hammer Strength")
        #expect(e?.equipmentType == "Plate-Loaded")
    }

    @Test func aDumbbellRackIsNotEvidenceOfATrainingStation() {
        #expect(GymEquipmentLearning.describe(observation: obs("cybex|db rack"), database: Self.db) == nil)
    }

    @Test func anUnknownMachineIsNotRecorded() {
        // Better to learn nothing than to show a blank row the lifter can't identify.
        #expect(GymEquipmentLearning.describe(observation: obs("who|knows"), database: Self.db) == nil)
    }

    @Test func aSightingWithNoGymIsNotRecorded() {
        #expect(GymEquipmentLearning.describe(observation: obs("hammer|row", gym: ""), database: Self.db) == nil)
    }

    // MARK: merge

    @Test func exclusionIsStickyAgainstAnyNumberOfNewSightings() {
        var existing = GymEquipmentEntry(dedupeKey: "hammer|row", source: .planned)
        existing.isExcluded = true
        let incoming = GymEquipmentLearning.describe(observation: obs("hammer|row", source: .logged),
                                                     database: Self.db)!

        let merged = GymEquipmentLearning.merged(existing: existing, incoming: incoming)

        #expect(merged.isExcluded, "a correction the lifter made must survive later evidence")
        #expect(merged.timesSeen == 1, "an excluded entry shouldn't accumulate sightings either")
    }

    @Test func sourceClimbsButNeverFalls() {
        let planned = GymEquipmentEntry(dedupeKey: "k", source: .planned)
        let logged = GymEquipmentEntry(dedupeKey: "k", source: .logged)
        let manual = GymEquipmentEntry(dedupeKey: "k", source: .manual)

        #expect(GymEquipmentLearning.merged(existing: planned, incoming: logged).source == .logged)
        #expect(GymEquipmentLearning.merged(existing: manual, incoming: planned).source == .manual)
        #expect(GymEquipmentLearning.merged(existing: manual, incoming: logged).source == .manual)
    }

    @Test func datesTakeTheEarliestFirstAndLatestLast() {
        let early = Date(timeIntervalSince1970: 100)
        let late = Date(timeIntervalSince1970: 900)
        var existing = GymEquipmentEntry(dedupeKey: "k")
        existing.firstSeenAt = late
        existing.lastSeenAt = late
        var incoming = GymEquipmentEntry(dedupeKey: "k")
        incoming.firstSeenAt = early
        incoming.lastSeenAt = early

        // Backfill replays history out of order, so assigning either date straight from the
        // incoming sighting would be wrong roughly half the time.
        let merged = GymEquipmentLearning.merged(existing: existing, incoming: incoming)
        #expect(merged.firstSeenAt == early)
        #expect(merged.lastSeenAt == late)
        #expect(merged.timesSeen == 2)
    }

    @Test func aBlankStoredFieldIsBackfilledButGoodDataIsNeverOverwritten() {
        var existing = GymEquipmentEntry(dedupeKey: "k", displayName: "", brandName: "Cybex")
        existing.equipmentType = ""
        let incoming = GymEquipmentEntry(dedupeKey: "k", displayName: "Hammer Row",
                                         brandName: "Hammer Strength", equipmentType: "Plate-Loaded")

        let merged = GymEquipmentLearning.merged(existing: existing, incoming: incoming)
        #expect(merged.displayName == "Hammer Row")
        #expect(merged.equipmentType == "Plate-Loaded")
        #expect(merged.brandName == "Cybex", "a populated field wins over the incoming copy")
    }

    @Test func mergingIntoNothingJustTakesTheIncomingEntry() {
        let incoming = GymEquipmentEntry(dedupeKey: "k", source: .manual)
        #expect(GymEquipmentLearning.merged(existing: nil, incoming: incoming) == incoming)
    }

    // MARK: history

    private func set(sessionID: String, dedupeKey: String?, completedAt: Date? = Date()) -> ExerciseSetRecord {
        ExerciseSetRecord(ownerID: "u", sessionID: sessionID, exerciseName: "Row", setIndex: 0,
                          completedAt: completedAt, equipmentDedupeKey: dedupeKey)
    }

    @Test func historyOnlyYieldsSightingsFromGymTaggedSessions() {
        let sets = [set(sessionID: "s1", dedupeKey: "hammer|row"),
                    set(sessionID: "s2", dedupeKey: "hammer|row")]
        let obs = GymEquipmentLearning.observationsFromHistory(
            sets: sets, sessionGymByID: ["s1": "gym-a", "s2": ""])

        #expect(obs.count == 1)
        #expect(obs.first?.gymID == "gym-a")
        #expect(obs.first?.source == .logged)
    }

    @Test func anIncompleteSetIsNotEvidence() {
        let sets = [set(sessionID: "s1", dedupeKey: "hammer|row", completedAt: nil)]
        let obs = GymEquipmentLearning.observationsFromHistory(sets: sets, sessionGymByID: ["s1": "gym-a"])
        #expect(obs.isEmpty)
    }

    @Test func aGenericLiftTeachesNothingAboutEquipment() {
        let sets = [set(sessionID: "s1", dedupeKey: nil)]
        let obs = GymEquipmentLearning.observationsFromHistory(sets: sets, sessionGymByID: ["s1": "gym-a"])
        #expect(obs.isEmpty)
    }

    // MARK: plans

    @Test func planExercisesYieldPlannedSightingsForTheirOwnGym() {
        let exercises = [DayExercise(id: "1", name: "Row", equipmentDedupeKey: "hammer|row"),
                         DayExercise(id: "2", name: "Squat")]
        let obs = GymEquipmentLearning.observationsFromPlans(
            variantsByGym: [(gymID: "gym-a", exercises: exercises)])

        #expect(obs.count == 1, "the generic squat says nothing about equipment")
        #expect(obs.first?.source == .planned)
        #expect(obs.first?.gymID == "gym-a")
    }

    @Test func anUntaggedVariantYieldsNothing() {
        let exercises = [DayExercise(id: "1", name: "Row", equipmentDedupeKey: "hammer|row")]
        let obs = GymEquipmentLearning.observationsFromPlans(
            variantsByGym: [(gymID: "", exercises: exercises)])
        #expect(obs.isEmpty)
    }

    // MARK: fold

    @Test func foldReducesRepeatSightingsIntoOneEntryPerMachinePerGym() {
        let observations = [obs("hammer|row", gym: "gym-a", source: .planned),
                            obs("hammer|row", gym: "gym-a", source: .logged),
                            obs("hammer|row", gym: "gym-b", source: .logged)]

        let folded = GymEquipmentLearning.fold(observations, database: Self.db)

        #expect(folded["gym-a"]?.count == 1)
        #expect(folded["gym-a"]?["hammer|row"]?.timesSeen == 2)
        #expect(folded["gym-a"]?["hammer|row"]?.source == .logged, "logged promotes the planned entry")
        #expect(folded["gym-b"]?["hammer|row"]?.timesSeen == 1, "gyms don't share an inventory")
    }

    @Test func foldSkipsSightingsItCannotDescribe() {
        let folded = GymEquipmentLearning.fold([obs("cybex|db rack"), obs("unknown|thing")],
                                                database: Self.db)
        #expect(folded.isEmpty)
    }
}

// MARK: - Binding generic picks to real machines

struct GymMachineBinderTests {

    private static let db: [EquipmentRecord] = [
        rec("eq1", "Nautilus", "Leg Extension", "nautilus|leg extension"),
        rec("eq2", "Hammer Strength", "Plate-Loaded Leg Extension", "hammer|pl leg extension"),
        rec("eq3", "Cybex", "Seated Row", "cybex|seated row"),
        rec("eq4", "Cybex", "Low Row", "cybex|low row"),
        rec("eq5", "Precor", "Leg Extension Bench", "precor|leg extension bench"),
    ]

    private static func rec(_ id: String, _ brand: String, _ machine: String,
                            _ key: String) -> EquipmentRecord {
        EquipmentRecord(equipmentId: id, brandName: brand, machineName: machine, modelSeries: "",
                        bodyParts: ["Legs"], equipmentType: "Selectorized",
                        primaryCategory: "Legs", dedupeKey: key)
    }

    private func inventory(_ keys: [String], seen: [String: Int] = [:]) -> GymInventory {
        GymInventory(gymID: "g", gymName: "Fairless", entries: keys.map { key in
            let r = Self.db.first { $0.dedupeKey == key }
            return GymEquipmentEntry(dedupeKey: key, equipmentId: r?.equipmentId ?? "",
                                     displayName: r?.displayName ?? "", brandName: r?.brandName ?? "",
                                     equipmentType: "Selectorized", source: .logged,
                                     timesSeen: seen[key] ?? 1)
        })
    }

    @Test func aGenericPickBindsToTheGymsOwnMachine() {
        let bound = GymMachineBinder.bind([DayExercise(id: "1", name: "Leg Extension")],
                                          inventory: inventory(["nautilus|leg extension"]),
                                          database: Self.db)
        #expect(bound.first?.equipmentDedupeKey == "nautilus|leg extension")
        #expect(bound.first?.equipmentBrandName == "Nautilus")
        #expect(bound.first?.equipmentId == "eq1")
    }

    @Test func aManufacturerPrefixStillCountsAsTheSameMovement() {
        let bound = GymMachineBinder.bind([DayExercise(id: "1", name: "Leg Extension")],
                                          inventory: inventory(["hammer|pl leg extension"]),
                                          database: Self.db)
        #expect(bound.first?.equipmentDedupeKey == "hammer|pl leg extension")
    }

    @Test func anExactNameBeatsAPrefixedOne() {
        let inv = inventory(["hammer|pl leg extension", "nautilus|leg extension"])
        let bound = GymMachineBinder.bind([DayExercise(id: "1", name: "Leg Extension")],
                                          inventory: inv, database: Self.db)
        #expect(bound.first?.equipmentDedupeKey == "nautilus|leg extension")
    }

    /// The failure this type exists to avoid: "Row" must not silently become "Low Row". A
    /// substring match — which is what the catalog's own `variants(forExercise:)` does — would
    /// bind one of these arbitrarily and pin overload history to a machine never chosen.
    @Test func aBareNameNeverSubstringMatchesADifferentMachine() {
        let inv = inventory(["cybex|seated row", "cybex|low row"])
        let bound = GymMachineBinder.bind([DayExercise(id: "1", name: "Row")],
                                          inventory: inv, database: Self.db)
        #expect(bound.first?.equipmentDedupeKey == nil, "an ambiguous name stays generic")
    }

    @Test func aTrailingWordMakesItADifferentPieceOfEquipment() {
        // "Leg Extension Bench" ends with "Bench", not with "Leg Extension" — suffix matching is
        // directional on purpose.
        let bound = GymMachineBinder.bind([DayExercise(id: "1", name: "Leg Extension")],
                                          inventory: inventory(["precor|leg extension bench"]),
                                          database: Self.db)
        #expect(bound.first?.equipmentDedupeKey == nil)
    }

    @Test func aTieBreaksTowardTheMachineUsedMoreOften() {
        let inv = inventory(["cybex|seated row", "cybex|low row"],
                            seen: ["cybex|low row": 9, "cybex|seated row": 2])
        let bound = GymMachineBinder.bind([DayExercise(id: "1", name: "Low Row")],
                                          inventory: inv, database: Self.db)
        #expect(bound.first?.equipmentDedupeKey == "cybex|low row")
    }

    @Test func anExistingEquipmentChoiceIsNeverOverwritten() {
        let chosen = DayExercise(id: "1", name: "Leg Extension",
                                 equipmentId: "eqX", equipmentDedupeKey: "someone|else",
                                 equipmentBrandName: "Panatta")
        let bound = GymMachineBinder.bind([chosen], inventory: inventory(["nautilus|leg extension"]),
                                          database: Self.db)
        #expect(bound.first?.equipmentDedupeKey == "someone|else", "the lifter's own pick wins")
    }

    @Test func anUnknownGymRewritesNothing() {
        let bound = GymMachineBinder.bind([DayExercise(id: "1", name: "Leg Extension")],
                                          inventory: .unknown, database: Self.db)
        #expect(bound.first?.equipmentDedupeKey == nil)
    }

    @Test func anExerciseWithNoMachineAtThisGymIsLeftAlone() {
        let bound = GymMachineBinder.bind([DayExercise(id: "1", name: "Barbell Bench Press")],
                                          inventory: inventory(["nautilus|leg extension"]),
                                          database: Self.db)
        #expect(bound.first?.equipmentDedupeKey == nil)
        #expect(bound.first?.name == "Barbell Bench Press", "the exercise itself is untouched")
    }
}

// MARK: - The nudge, end to end

struct GymAwareRankingTests {

    /// The earlier version of this test used a synthetic `equipmentType: "Machine"`, which happened
    /// to normalize straight onto the exercise catalog's "machine" token — so it passed while the
    /// real catalog ("Selectorized", "Plate-Loaded", …) matched nothing. This drives the bias from
    /// a REAL catalog type through the coarsening layer, which is the path production takes.
    @Test func aRealCatalogTypeActuallyProducesTheRankingBias() {
        let record = EquipmentRecord(equipmentId: "eq1", brandName: "Hammer Strength",
                                     machineName: "Row", modelSeries: "", bodyParts: ["Back"],
                                     equipmentType: "Selectorized", primaryCategory: "Back",
                                     dedupeKey: "hammer|row")
        let inventory = GymInventory(gymID: "g", gymName: "Fairless",
                                     entries: [GymEquipmentLearning.describe(
                                        observation: GymEquipmentObservation(gymID: "g", dedupeKey: "hammer|row"),
                                        database: [record])!])

        #expect(inventory.equipmentTypes.contains("machine"),
                "a real 'Selectorized' record has to reach the engine as 'machine'")

        // Named so the alphabetical tiebreak favors B; only the gym bias can flip the order.
        let a = ExerciseCandidate(id: "a", name: "Zebra Press", primaryMuscle: "chest",
                                  secondaryMuscles: [], equipment: "machine",
                                  movementPattern: "isolation", isCustom: false)
        let b = ExerciseCandidate(id: "b", name: "Apple Fly", primaryMuscle: "chest",
                                  secondaryMuscles: [], equipment: "cable",
                                  movementPattern: "isolation", isCustom: false)
        var inputs = RankingInputs(context: .empty, personalization: PersonalizationProvider(signals: .init()))
        inputs.gymEquipmentTypes = inventory.equipmentTypes

        #expect(ExerciseRankingEngine.rank([a, b], inputs: inputs).map(\.id) == ["a", "b"])
    }

    @Test func anUnknownGymBiasesNothing() {
        let a = ExerciseCandidate(id: "a", name: "Zebra Press", primaryMuscle: "chest",
                                  secondaryMuscles: [], equipment: "machine",
                                  movementPattern: "isolation", isCustom: false)
        let b = ExerciseCandidate(id: "b", name: "Apple Fly", primaryMuscle: "chest",
                                  secondaryMuscles: [], equipment: "cable",
                                  movementPattern: "isolation", isCustom: false)
        var inputs = RankingInputs(context: .empty, personalization: PersonalizationProvider(signals: .init()))
        inputs.gymEquipmentTypes = GymInventory.unknown.equipmentTypes

        #expect(ExerciseRankingEngine.rank([a, b], inputs: inputs).map(\.id) == ["b", "a"],
                "an unknown gym must leave the ordering exactly as it was")
    }
}
