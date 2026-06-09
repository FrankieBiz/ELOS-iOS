import Testing
@testable import Elos

struct GuidanceLevelTests {
    @Test func beginnerIsFull() {
        #expect(GuidanceLevel(trainingExperience: "beginner") == .full)
    }
    @Test func intermediateAndAdvancedAreMinimal() {
        #expect(GuidanceLevel(trainingExperience: "intermediate") == .minimal)
        #expect(GuidanceLevel(trainingExperience: "advanced") == .minimal)
    }
    @Test func unknownDefaultsToFull() {
        #expect(GuidanceLevel(trainingExperience: "") == .full)
    }
}
