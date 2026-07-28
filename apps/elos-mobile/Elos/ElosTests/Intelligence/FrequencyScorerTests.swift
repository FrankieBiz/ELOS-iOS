import Testing
@testable import Elos

struct FrequencyScorerTests {
    private let intermediate = TrainingProfile(goal: .hypertrophy, experience: .intermediate)

    private func score(_ days: [[ScoredExercise]],
                       scope: QualityScope = .weeklySplit,
                       dayNames: [String]? = nil) -> DimensionScore {
        let resolved = QualityFixtures.resolve(days)
        let volume = QualityFixtures.volume(resolved, scope: scope,
                                            profile: intermediate, dayNames: dayNames)
        return FrequencyScorer.score(volume: volume, scope: scope, profile: intermediate)
    }

    /// Frequency is meaningless for one workout, so it must never drag a template's score down.
    @Test func singleSessionIsNeutral() {
        let d = score([[QualityFixtures.sx("bench", sets: 6)]], scope: .singleSession)
        #expect(d.score == 100)
        #expect(d.tips.isEmpty)
    }

    /// The case the whole dimension exists for: adequate weekly volume crammed into one day.
    @Test func allVolumeOnOneDayIsFlagged() {
        let d = score([[QualityFixtures.sx("bench", sets: 16)]], dayNames: ["Chest"])
        #expect(d.tips.contains { $0.id == "freq-once-chest" && $0.severity == .warn })
        #expect(d.score < 70)
    }

    @Test func sameVolumeSplitAcrossTwoDaysScoresFull() {
        let d = score([
            [QualityFixtures.sx("bench", sets: 8)],
            [QualityFixtures.sx("incline", sets: 8)],
        ], dayNames: ["A", "B"])
        #expect(d.score == 100)
        #expect(d.tips.isEmpty)
    }

    /// A muscle trained once *and* lightly is a volume problem, not a frequency one — staying quiet
    /// here keeps VolumeScorer's advice from being duplicated.
    @Test func lightSingleDayVolumeIsNotAFrequencyComplaint() {
        let d = score([[QualityFixtures.sx("bench", sets: 3)]], dayNames: ["Chest"])
        #expect(!d.tips.contains { $0.id == "freq-once-chest" })
    }

    /// Muscles with no direct work are a coverage gap (BalanceScorer's job); frequency must not
    /// double-penalise them.
    @Test func untrainedMusclesAreNotPenalisedHere() {
        let d = score([
            [QualityFixtures.sx("bench", sets: 8)],
            [QualityFixtures.sx("incline", sets: 8)],
        ], dayNames: ["A", "B"])
        // Legs are entirely absent yet frequency is still perfect — that's coverage's story.
        #expect(d.score == 100)
        #expect(!d.tips.contains { $0.id.contains("quads") })
    }

    @Test func nothingTrainedScoresNeutral() {
        let d = score([[ScoredExercise(id: "", name: "Mystery", sets: 4, repsText: "10")]])
        #expect(d.score == 70)
        #expect(d.tips.isEmpty)
    }

    @Test func tipCountIsCappedToStayReadable() {
        // Six muscles each crammed onto a single day would otherwise emit six warnings.
        let d = score([[
            QualityFixtures.sx("bench", sets: 16),
            QualityFixtures.sx("row", sets: 16),
            QualityFixtures.sx("squat", sets: 16),
            QualityFixtures.sx("legcurl", sets: 16),
            QualityFixtures.sx("curl", sets: 16),
            QualityFixtures.sx("lateral", sets: 16),
        ]], dayNames: ["Everything"])
        #expect(d.tips.count <= 3)
    }
}
