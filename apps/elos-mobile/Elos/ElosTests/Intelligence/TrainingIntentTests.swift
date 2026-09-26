import Foundation
import Testing
@testable import Elos

struct TrainingIntentTests {
    @Test func defaultHasNoExclusions() {
        #expect(TrainingIntent.default.excludedMuscles.isEmpty)
    }

    @Test func excludedMusclesRoundTripThroughJSON() {
        let intent = TrainingIntent(goal: .strength, focus: .upper, excludedMuscles: [.lowerBack])
        let restored = TrainingIntent(jsonString: intent.jsonString)
        #expect(restored == intent)
    }

    @Test func decodingPreExclusionJSONDefaultsToNoExclusions() {
        // A template saved before this field existed. Must not fail to decode (which would make
        // `TrainingIntent(jsonString:)` return nil and silently drop the lifter's saved goal/focus).
        let legacyJSON = """
        {"goal":"strength","focus":"upper"}
        """
        let restored = TrainingIntent(jsonString: legacyJSON)
        #expect(restored?.goal == .strength)
        #expect(restored?.focus == .upper)
        #expect(restored?.excludedMuscles.isEmpty == true)
    }

    @Test func decodingLegacyJSONWithNoFocusKeyStillWorks() {
        // `focus` was already optional before this change; synthesized Codable omits nil optionals
        // from the JSON entirely, so plenty of existing saved blobs have no "focus" key at all.
        let legacyJSON = """
        {"goal":"hypertrophy"}
        """
        let restored = TrainingIntent(jsonString: legacyJSON)
        #expect(restored?.goal == .hypertrophy)
        #expect(restored?.focus == nil)
        #expect(restored?.excludedMuscles.isEmpty == true)
    }
}
