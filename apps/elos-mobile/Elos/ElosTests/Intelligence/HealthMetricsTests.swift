import Testing
@testable import Elos

struct HealthMetricsTests {
    @Test func energyScalesWithDurationAndWeight() {
        // 1 hour at 80kg, 5 MET → 400 kcal.
        #expect(HealthEnergy.estimateKcal(durationSec: 3600, bodyWeightKg: 80) == 400)
        // Half the time → half the energy.
        #expect(HealthEnergy.estimateKcal(durationSec: 1800, bodyWeightKg: 80) == 200)
    }

    @Test func energyFallsBackWhenWeightUnknown() {
        // 1 hour, unknown weight → uses the default 75kg → 375 kcal.
        #expect(HealthEnergy.estimateKcal(durationSec: 3600, bodyWeightKg: 0) == 375)
    }

    @Test func energyNonNegativeForBadDuration() {
        #expect(HealthEnergy.estimateKcal(durationSec: -100, bodyWeightKg: 80) == 0)
    }

    @Test func recoveryHintNilWhenMissingOrNormal() {
        #expect(RecoveryHint.evaluate(restingHR: nil, baseline: 60) == nil)
        #expect(RecoveryHint.evaluate(restingHR: 62, baseline: nil) == nil)
        #expect(RecoveryHint.evaluate(restingHR: 62, baseline: 60) == nil)   // within 10%
    }

    @Test func recoveryHintFiresWhenElevated() {
        // 70 vs 60 baseline = +16% → elevated.
        #expect(RecoveryHint.evaluate(restingHR: 70, baseline: 60) != nil)
    }

    @Test func snapshotHasAnyMetricAndDerivesHint() {
        var s = HealthSnapshot.empty
        #expect(!s.hasAnyMetric)
        #expect(s.recoveryHint == nil)
        s.restingHeartRate = 70
        s.restingHRBaseline = 60
        #expect(s.hasAnyMetric)
        #expect(s.recoveryHint != nil)
    }
}
