import Foundation
import HealthKit

/// The single boundary over HealthKit. Writes completed workouts and reads body weight / resting
/// heart rate / steps. Everything is best-effort: unavailable or unauthorized reads return nil and
/// writes return false — Health is enrichment, never a hard dependency. Pure logic (energy estimate,
/// recovery hint) lives in `HealthMetrics.swift` so this stays thin and the testable parts are testable.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        [HKWorkoutType.workoutType(), HKQuantityType(.activeEnergyBurned)]
    }
    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.bodyMass), HKQuantityType(.restingHeartRate), HKQuantityType(.stepCount)]
    }

    /// Request read/share authorization. Returns false if Health is unavailable or the request throws.
    /// (Note: HealthKit never reveals read-permission status, so callers just attempt reads.)
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Write

    /// Save one finished session to Health as a strength-training workout with an estimated energy.
    /// Returns true on success so the caller can mark the record `exportedToHealth`.
    func export(session: WorkoutSessionRecord, bodyWeightKg: Double) async -> Bool {
        guard isAvailable, let end = session.finishedAt, end > session.startedAt else { return false }
        let start = session.startedAt
        let kcal = HealthEnergy.estimateKcal(durationSec: end.timeIntervalSince(start), bodyWeightKg: bodyWeightKg)
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: start, end: end,
            duration: end.timeIntervalSince(start),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
            totalDistance: nil,
            metadata: nil
        )
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                store.save(workout) { _, error in
                    if let error { cont.resume(throwing: error) } else { cont.resume() }
                }
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Read

    func latestBodyWeightKg() async -> Double? {
        await mostRecent(HKQuantityType(.bodyMass), unit: .gramUnit(with: .kilo))
    }

    func restingHeartRate() async -> Double? {
        await mostRecent(HKQuantityType(.restingHeartRate), unit: HKUnit.count().unitDivided(by: .minute()))
    }

    func restingHRBaseline(days: Int = 14) async -> Double? {
        await average(HKQuantityType(.restingHeartRate),
                      unit: HKUnit.count().unitDivided(by: .minute()), days: days)
    }

    func todaySteps() async -> Int? {
        guard let sum = await sumToday(HKQuantityType(.stepCount), unit: .count()) else { return nil }
        return Int(sum)
    }

    // MARK: - Query helpers

    private func mostRecent(_ type: HKQuantityType, unit: HKUnit) async -> Double? {
        guard isAvailable else { return nil }
        return await withCheckedContinuation { cont in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: sort) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                cont.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func average(_ type: HKQuantityType, unit: HKUnit, days: Int) async -> Double? {
        guard isAvailable else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: .discreteAverage) { _, stats, _ in
                cont.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func sumToday(_ type: HKQuantityType, unit: HKUnit) async -> Double? {
        guard isAvailable else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}
