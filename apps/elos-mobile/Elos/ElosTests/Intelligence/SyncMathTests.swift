import Testing
@testable import Elos

struct SyncMathTests {
    @Test func setVolumeMultipliesWeightByReps() {
        #expect(SyncMath.setVolume(weightKg: 100, reps: 8) == 800)
        #expect(SyncMath.setVolume(weightKg: 0, reps: 10) == 0)
    }

    @Test func setVolumeClampsNegativeReps() {
        #expect(SyncMath.setVolume(weightKg: 100, reps: -3) == 0)
    }

    @Test func totalVolumeSumsSets() {
        let sets = [(weightKg: 100.0, reps: 8), (weightKg: 60.0, reps: 12), (weightKg: 0.0, reps: 15)]
        #expect(SyncMath.totalVolume(sets) == 800 + 720 + 0)
    }

    @Test func totalVolumeEmptyIsZero() {
        #expect(SyncMath.totalVolume([]) == 0)
    }
}
