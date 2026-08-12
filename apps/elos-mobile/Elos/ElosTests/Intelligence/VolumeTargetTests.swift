import Foundation
import Testing
@testable import Elos

/// Per-session volume bands and the lifter's overrides.
///
/// The per-session band used to be a flat 4–10 sets for every muscle, which said a chest day and a calf
/// day want the same dose. It's now derived from the weekly band spread over `targetWeeklyFrequency`,
/// so the two numbers can't drift apart and a big muscle asks for more in a sitting than a small one.
struct VolumeTargetTests {

    private let standard = TrainingProfile(goal: .hypertrophy, experience: .intermediate)

    // MARK: Session bands

    @Test func everySessionBandIsWellFormed() {
        for m in FineMuscle.allCases {
            let s = TrainingScience.sessionBand(for: m, profile: standard)
            // No single workout is obliged to train any particular muscle.
            #expect(s.mev == 0)
            #expect(s.targetLow >= Double(TrainingScience.sessionPerMuscleFloor))
            #expect(s.targetHigh > s.targetLow)
            #expect(s.mrv >= s.targetHigh)
            // Past the junk threshold extra sets stop paying for themselves, whatever the muscle.
            #expect(s.mrv <= Double(TrainingScience.sessionJunkThreshold))
        }
    }

    @Test func aBigMuscleWantsMorePerSessionThanASmallOne() {
        let chest = TrainingScience.sessionBand(for: .chest, profile: standard)
        let lowerBack = TrainingScience.sessionBand(for: .lowerBack, profile: standard)
        #expect(chest.targetLow > lowerBack.targetLow)
    }

    @Test func sessionBandsRollUpTowardTheWeeklyBand() {
        let freq = Double(TrainingScience.targetWeeklyFrequency)
        for m in FineMuscle.allCases {
            let weekly = TrainingScience.weeklyBand(for: m, profile: standard)
            let session = TrainingScience.sessionBand(for: m, profile: standard)
            // Training a muscle at its session target across the target frequency should land at or
            // near the weekly productive floor — rounding and the per-muscle floor allow slack.
            #expect(session.targetLow * freq >= weekly.targetLow - 2)
        }
    }

    @Test func prehabMusclesStayOptionalAtSessionScope() {
        // Previously every session band was non-optional, so a template with two rotator-cuff sets was
        // marked "below minimum" for a muscle that is prehab work, not a volume target.
        for m in FineMuscle.allCases {
            let weekly = TrainingScience.weeklyBand(for: m, profile: standard)
            let session = TrainingScience.sessionBand(for: m, profile: standard)
            #expect(session.isOptional == weekly.isOptional)
        }
    }

    // MARK: Overrides

    @Test func thePreferenceMultiplierMovesEveryTarget() {
        func low(_ p: VolumePreference) -> Double {
            TrainingScience.weeklyBand(
                for: .chest,
                profile: TrainingProfile(goal: .hypertrophy, experience: .intermediate,
                                         volumeOverrides: VolumeOverrides(preference: p))
            ).targetLow
        }
        #expect(low(.conservative) < low(.standard))
        #expect(low(.aggressive) > low(.standard))
    }

    @Test func aGroupTargetIsDistributedAcrossItsChildrenAndSumsToTheRequest() {
        let group = MuscleGroup.back
        let requested = 30
        let profile = TrainingProfile(
            goal: .hypertrophy, experience: .intermediate,
            volumeOverrides: VolumeOverrides(groupWeeklyTarget: [group.rawValue: requested]))

        let summed = group.children.reduce(0.0) {
            $0 + TrainingScience.weeklyBand(for: $1, profile: profile).targetLow
        }
        // Each child rounds to a whole set, so allow one set of slack per child.
        #expect(abs(summed - Double(requested)) <= Double(group.children.count))
    }

    @Test func aGroupTargetDoesNotLeakIntoOtherGroups() {
        let profile = TrainingProfile(
            goal: .hypertrophy, experience: .intermediate,
            volumeOverrides: VolumeOverrides(groupWeeklyTarget: [MuscleGroup.back.rawValue: 30]))
        #expect(TrainingScience.weeklyBand(for: .chest, profile: profile).targetLow
                  == TrainingScience.weeklyBand(for: .chest, profile: standard).targetLow)
    }

    @Test func anExplicitGroupTargetOverridesThePreferenceMultiplier() {
        // The lifter's own number is absolute — experience and preference already had their say when
        // they picked it, so applying the multiplier on top would silently move their setting.
        let target = 24
        func low(_ p: VolumePreference) -> Double {
            TrainingScience.weeklyBand(
                for: .lats,
                profile: TrainingProfile(
                    goal: .hypertrophy, experience: .intermediate,
                    volumeOverrides: VolumeOverrides(
                        preference: p, groupWeeklyTarget: [MuscleGroup.back.rawValue: target]))
            ).targetLow
        }
        #expect(low(.conservative) == low(.aggressive))
    }

    @Test func overridesReachThePerSessionBandToo() {
        let profile = TrainingProfile(
            goal: .hypertrophy, experience: .intermediate,
            volumeOverrides: VolumeOverrides(groupWeeklyTarget: [MuscleGroup.chest.rawValue: 40]))
        #expect(TrainingScience.sessionBand(for: .chest, profile: profile).targetLow
                  > TrainingScience.sessionBand(for: .chest, profile: standard).targetLow)
    }

    @Test func defaultOverridesChangeNothing() {
        for m in FineMuscle.allCases {
            #expect(TrainingScience.weeklyBand(for: m, profile: standard)
                      == TrainingScience.weeklyBand(for: m, experience: .intermediate))
        }
    }

    // MARK: Exclusion

    @Test func excludedMuscleIsOptionalRegardlessOfGroupTarget() {
        // A stale numeric target left over from before a muscle was excluded must not un-exclude it.
        let profile = TrainingProfile(
            goal: .hypertrophy, experience: .intermediate,
            volumeOverrides: VolumeOverrides(
                groupWeeklyTarget: [MuscleGroup.back.rawValue: 30],
                excludedMuscles: [.lowerBack]))
        #expect(TrainingScience.weeklyBand(for: .lowerBack, profile: profile).isOptional)
        // Lats, in the same group, are unaffected.
        #expect(!TrainingScience.weeklyBand(for: .lats, profile: profile).isOptional)
    }

    @Test func excludingAMuscleDoesNotZeroItsBandNumbers() {
        // Flag-flip, not zeroing — avoids a divide-by-zero in the bars if the muscle still gets
        // incidental indirect credit from another exercise.
        let excluded = VolumeOverrides(excludedMuscles: [.lowerBack])
        let profile = TrainingProfile(goal: .hypertrophy, experience: .intermediate, volumeOverrides: excluded)
        let band = TrainingScience.weeklyBand(for: .lowerBack, profile: profile)
        let unexcludedBand = TrainingScience.weeklyBand(for: .lowerBack, profile: standard)
        #expect(band.isOptional)
        #expect(band.targetLow == unexcludedBand.targetLow)
        #expect(band.targetHigh == unexcludedBand.targetHigh)
    }

    @Test func excludedMusclesRoundTripThroughJSON() {
        let overrides = VolumeOverrides(preference: .aggressive,
                                        groupWeeklyTarget: ["chest": 20],
                                        excludedMuscles: [.lowerBack, .forearms])
        let data = try! JSONEncoder().encode(overrides)
        let decoded = try! JSONDecoder().decode(VolumeOverrides.self, from: data)
        #expect(decoded == overrides)
    }

    @Test func decodingPreExclusionJSONDefaultsToNoExclusions() {
        // A user upgrading has a stored blob with no "excludedMuscles" key at all. This must not
        // throw and must not silently drop `preference`/`groupWeeklyTarget` (AppViewModel decodes
        // this with `try?`, so a thrown decode would silently reset the user's saved settings).
        let legacyJSON = """
        {"preference":"aggressive","groupWeeklyTarget":{"chest":20}}
        """.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(VolumeOverrides.self, from: legacyJSON)
        #expect(decoded.preference == .aggressive)
        #expect(decoded.groupWeeklyTarget["chest"] == 20)
        #expect(decoded.excludedMuscles.isEmpty)
    }

    @Test func isCustomizedIncludesExclusion() {
        var o = VolumeOverrides.none
        #expect(!o.isCustomized)
        o.excludedMuscles = [.lowerBack]
        #expect(o.isCustomized)
    }
}
