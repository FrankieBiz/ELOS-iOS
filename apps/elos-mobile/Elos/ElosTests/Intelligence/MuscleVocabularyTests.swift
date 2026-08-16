import Foundation
import Testing
@testable import Elos

/// Guards the interchange format between the muscle-attribution layer and everything that stores or
/// displays muscle strings: logged sets, `Exercise.primaryMuscle`, and the stats screens.
///
/// The hazard is silent bucket-splitting. `dbPrimaryMuscle` returns the catalog's snake_case key
/// (`"lower_back"`); if the lexicon path returned the normalized form (`"lower back"`) the same muscle
/// would land in two buckets and every `switch` on those keys would miss one of them.
struct MuscleVocabularyTests {

    // MARK: catalogPrimary speaks the catalog's key

    @Test func catalogKeysAreSnakeCaseNotNormalized() {
        #expect(MuscleTargets(primary: [.lowerBack]).catalogPrimary == "lower_back")
        #expect(MuscleTargets(primary: [.rearDelts]).catalogPrimary == "rear_delts")
        #expect(MuscleTargets(primary: [.frontDelts]).catalogPrimary == "front_delts")
        #expect(MuscleTargets(primary: [.chest]).catalogPrimary == "chest")
    }

    @Test func everyFineMuscleHasACatalogKey() {
        for f in FineMuscle.allCases {
            #expect(MuscleTaxonomy.vocabularyKey(forFine: f) != nil, "\(f) has no catalog key")
        }
    }

    /// The round trip has to be stable, or a muscle drifts to a different slot each time it's stored
    /// and re-read.
    @Test func catalogKeyRoundTripsBackToTheSameMuscle() {
        for f in FineMuscle.allCases {
            let key = MuscleTaxonomy.vocabularyKey(forFine: f)
            #expect(MuscleTaxonomy.fine(forMuscle: key ?? "") == f, "\(f) → \(key ?? "nil") → drifted")
        }
    }

    @Test func catalogKeysSurviveTheDisplayHelper() {
        // `muscleDisplayName` is what the post-workout card and the picker render.
        #expect("lower_back".muscleDisplayName == "Lower Back")
        #expect("rear_delts".muscleDisplayName == "Rear Delts")
    }

    @Test func secondariesIncludeExtraPrimariesBeyondTheFirst() {
        // `Exercise` has room for one primary string, so additional primaries must not vanish.
        let t = MuscleTargets(primary: [.chest, .frontDelts], secondary: [.triceps])
        #expect(t.catalogPrimary == "chest")
        #expect(t.catalogSecondaries == ["front_delts", "triceps"])
    }

    // MARK: The stats screens' grouping

    /// `TrainView.muscleCounts` groups logged sets by `MuscleTaxonomy.group`. Every catalog key a set
    /// can carry must land in some group — the previous hand-listed switch matched only
    /// "lats"/"rear_delts" for Back, so lower-back and upper-back work counted toward nothing.
    @Test func everyCatalogKeyGroupsToABroadGroup() {
        for key in MuscleTaxonomy.knownMuscleVocabulary {
            #expect(MuscleTaxonomy.group(forMuscle: key) != nil, "\(key) groups to nothing")
        }
    }

    @Test func backWorkGroupsToBack() {
        for key in ["lower_back", "lats", "traps", "rhomboids", "rear_delts", "back"] {
            #expect(MuscleTaxonomy.group(forMuscle: key) == .back, "\(key) should group to Back")
        }
    }

    /// Weekly targets now come from `TrainingScience` rather than a second table, so every muscle a
    /// set can be attributed to must have a landmark.
    @Test func everyCatalogKeyHasAWeeklyTarget() {
        for key in MuscleTaxonomy.knownMuscleVocabulary {
            guard let fine = MuscleTaxonomy.fine(forMuscle: key) else { continue }
            let band = TrainingScience.weeklyBand(for: fine, experience: .intermediate)
            #expect(band.targetLow > 0, "\(key) has no productive-volume target")
        }
    }

    // MARK: The name-only fallback no longer mislabels

    /// The old private heuristic in `TrainViewModel` tested `contains("extension")` before anything
    /// else, so a back extension was reported as **quads** in the post-workout breakdown.
    @Test func backExtensionIsNotQuads() {
        let t = MovementLexicon.targets(forExerciseName: "PRIME Fitness Low Back Extension")
        #expect(t?.catalogPrimary == "lower_back")
    }

    @Test func namesTheOldHeuristicGotWrong() {
        // (name, what it should resolve to) — each was mis-attributed by the substring ladder.
        let cases: [(String, String)] = [
            ("Low Back Extension", "lower_back"),   // was quads, via contains("extension")
            ("Leg Extension",      "quads"),
            ("Reverse Hyper",      "lower_back"),   // was "other"
            ("Lateral Raise",      "side_delts"),
            ("Rear Delt Fly",      "rear_delts"),
            ("Seated Calf Raise",  "calves"),
            ("Hip Abduction",      "glutes"),
            ("Rotary Torso",       "abs"),
        ]
        for (name, expected) in cases {
            #expect(MovementLexicon.targets(forExerciseName: name)?.catalogPrimary == expected,
                    "\(name) → \(MovementLexicon.targets(forExerciseName: name)?.catalogPrimary ?? "nil"), want \(expected)")
        }
    }

    // MARK: The muscle *label* vocabulary the strips and SplitDescriptor sum by

    /// `SplitDescriptor` classifies a community split day by summing sets per muscle label. It used to
    /// run a second keyword ladder that lived in `CreateTemplateView`; it now goes through the shared
    /// chain. These are the cases the existing `SplitDescriptorTests` depend on.
    @Test func descriptorLabelsAreUnchangedForTheCommonLifts() {
        let cases: [(String, String)] = [
            ("bench press",    "Chest"),
            ("squat",          "Quads"),
            ("bicep curl",     "Biceps"),
            ("barbell row",    "Back"),
            ("lat pulldown",   "Back"),
            ("overhead press", "Shoulders"),
            ("lateral raise",  "Shoulders"),
            ("calf raise",     "Calves"),
            ("Seated Leg Curl","Hamstrings"),
            ("Hip Thrust",     "Glutes"),
        ]
        for (name, expected) in cases {
            let label = muscleLabel(for: resolvedMuscleTargets(exerciseID: nil, name: name))
            #expect(label == expected, "\(name) → \(label ?? "nil"), want \(expected)")
        }
    }

    /// And the cases the old ladder got wrong or gave up on entirely.
    @Test func descriptorLabelsImproveOnTheOldLadder() {
        let cases: [(String, String, String)] = [
            ("Low Back Extension", "Back",  "was Quads, via contains(\"extension\")"),
            ("Reverse Hyper",      "Back",  "was nil"),
            ("Lateral Lunge",      "Quads", "was Shoulders, via contains(\"lateral\")"),
            ("Rotary Torso",       "Core",  "was nil"),
        ]
        for (name, expected, why) in cases {
            let label = muscleLabel(for: resolvedMuscleTargets(exerciseID: nil, name: name))
            #expect(label == expected, "\(name) → \(label ?? "nil"), want \(expected) (\(why))")
        }
    }

    /// Nothing known means nothing claimed — the strips drop the row rather than guessing a colour.
    @Test func anUnknownNameYieldsNoLabel() {
        #expect(muscleLabel(for: resolvedMuscleTargets(exerciseID: nil, name: "Zorble Machine")) == nil)
    }

    // MARK: Exercise carries its targets into the session

    @Test func exercisePrefersItsStoredTargets() {
        let ex = Exercise(name: "Anything", primaryMuscle: "chest", secondaryMuscles: [],
                          setsLabel: "3×10", lastBest: "", sets: [],
                          muscleTargets: MuscleTargets(primary: [.rearDelts]))
        #expect(ex.resolvedTargets.primary == [.rearDelts])
    }

    @Test func exerciseFallsBackToItsMuscleStrings() {
        let ex = Exercise(name: "Anything", primaryMuscle: "lower_back",
                          secondaryMuscles: ["glutes"],
                          setsLabel: "3×10", lastBest: "", sets: [])
        #expect(ex.resolvedTargets.primary == [.lowerBack])
        #expect(ex.resolvedTargets.secondary == [.glutes])
    }

    /// A draft encoded before this feature has no targets *and* an empty `primaryMuscle` — every
    /// session used to be built that way — so the name and machine still have to answer.
    @Test func exerciseWithNoMuscleDataFallsBackToNameAndMachine() {
        let bare = Exercise(name: "Reverse Hyper", primaryMuscle: "", secondaryMuscles: [],
                            setsLabel: "3×10", lastBest: "", sets: [])
        #expect(bare.resolvedTargets.primary == [.lowerBack])

        let machine = EquipmentDatabase.all.first {
            $0.displayName.localizedCaseInsensitiveContains("PRIME Fitness Low Back Extension")
        }!
        let viaMachine = Exercise(name: machine.displayName, primaryMuscle: "", secondaryMuscles: [],
                                  setsLabel: "3×10", lastBest: "", sets: [],
                                  equipmentId: machine.equipmentId)
        #expect(viaMachine.resolvedTargets.primary == [.lowerBack])
    }

    @Test func exerciseEncodesAndDecodesItsTargets() throws {
        let ex = Exercise(name: "Pec/Rear Delt", primaryMuscle: "rear_delts", secondaryMuscles: [],
                          setsLabel: "3×12", lastBest: "", sets: [],
                          muscleTargets: MuscleTargets(primary: [.rearDelts]))
        let back = try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(ex))
        #expect(back.muscleTargets?.primary == [.rearDelts])
    }

    /// Session drafts are persisted JSON; one written before `muscleTargets` existed must still load.
    @Test func legacyDraftJSONStillDecodes() throws {
        let legacy = #"{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","name":"Barbell Row","primaryMuscle":"back","secondaryMuscles":["biceps"],"setsLabel":"3×10","lastBest":"","sets":[]}"#
        let ex = try JSONDecoder().decode(Exercise.self, from: Data(legacy.utf8))
        #expect(ex.name == "Barbell Row")
        #expect(ex.muscleTargets == nil)
        #expect(ex.resolvedTargets.primary == [.upperBack])   // recovered from primaryMuscle
    }
}
