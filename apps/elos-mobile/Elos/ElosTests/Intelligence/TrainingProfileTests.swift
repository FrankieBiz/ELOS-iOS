import Testing
@testable import Elos

struct TrainingProfileTests {
    @Test func parsesGoals() {
        #expect(LiftingGoal(raw: "strength") == .strength)
        #expect(LiftingGoal(raw: "weight_loss") == .weightLoss)
        #expect(LiftingGoal(raw: "weight loss") == .weightLoss)
        #expect(LiftingGoal(raw: "HYPERTROPHY") == .hypertrophy)
        #expect(LiftingGoal(raw: "endurance") == .endurance)
        #expect(LiftingGoal(raw: "nonsense") == .hypertrophy)   // safe default
    }

    @Test func parsesExperience() {
        #expect(TrainingExperienceLevel(raw: "advanced") == .advanced)
        #expect(TrainingExperienceLevel(raw: "intermediate") == .intermediate)
        #expect(TrainingExperienceLevel(raw: "beginner") == .beginner)
        #expect(TrainingExperienceLevel(raw: "") == .beginner)   // safe default
    }

    @Test func defaultProfile() {
        #expect(TrainingProfile.default.goal == .hypertrophy)
        #expect(TrainingProfile.default.experience == .intermediate)
    }
}
