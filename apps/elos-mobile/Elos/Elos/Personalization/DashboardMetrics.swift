import Foundation
import SwiftData

/// The numbers behind the opt-in Today widgets.
///
/// Pure statics over plain values — no SwiftData, no view model, no `Date()` read from inside. That's
/// deliberate and it's the house pattern: the rolling-window arithmetic here is the part with real
/// edge cases (week boundaries, unfinished sessions, empty history), and it's far cheaper to pin
/// those down in unit tests than to eyeball a card on a simulator.
enum DashboardMetrics {

    /// A finished session, reduced to the only two fields any of these need.
    struct SessionSummary {
        let finishedAt: Date
        let volumeKg: Double

        init(finishedAt: Date, volumeKg: Double) {
            self.finishedAt = finishedAt
            self.volumeKg = volumeKg
        }
    }

    /// The seven-day window ending today, inclusive. A rolling window rather than a calendar week:
    /// "this week" resetting to zero at midnight on Sunday makes a dashboard widget useless every
    /// Monday morning, which is exactly when someone checks whether they're on track.
    static func rollingWeek(endingOn now: Date, calendar: Calendar = .current) -> DateInterval {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        // Runs to the end of today, not the start — a session finished this afternoon counts.
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        return DateInterval(start: start, end: endOfToday)
    }

    static func sessions(_ sessions: [SessionSummary], in window: DateInterval) -> [SessionSummary] {
        sessions.filter { window.contains($0.finishedAt) }
    }

    /// Distinct *days* trained, not sessions logged. Two sessions on one day is one training day —
    /// counting them as two would let a widget claim "6 of 4" against a split that plans four.
    static func trainingDayCount(_ sessions: [SessionSummary],
                                 in window: DateInterval,
                                 calendar: Calendar = .current) -> Int {
        Set(Self.sessions(sessions, in: window).map { calendar.startOfDay(for: $0.finishedAt) }).count
    }

    static func volumeKg(_ sessions: [SessionSummary], in window: DateInterval) -> Double {
        Self.sessions(sessions, in: window).reduce(0) { $0 + $1.volumeKg }
    }

    /// How many of the next `loadTypes` are training days. Fed straight from `weekLoadMap`, whose
    /// vocabulary is "gym" / "rest" / "skip" / "exam".
    static func plannedTrainingDays(loadTypes: [String]) -> Int {
        loadTypes.filter { $0 == "gym" }.count
    }

    /// Percentage change between two windows, or nil when there's no earlier window to compare with
    /// — a widget reading "+100%" because last week was empty is noise dressed as a trend.
    static func percentChange(current: Double, previous: Double) -> Double? {
        guard previous > 0 else { return nil }
        return (current - previous) / previous * 100
    }
}

// MARK: - Wiring

extension AppViewModel {
    /// Every finished session for the signed-in user, as the flat summaries `DashboardMetrics` takes.
    var finishedSessionSummaries: [DashboardMetrics.SessionSummary] {
        guard !currentUserID.isEmpty else { return [] }
        let uid = currentUserID
        let desc = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == uid && $0.finishedAt != nil }
        )
        return ((try? modelContext.fetch(desc)) ?? []).compactMap { session in
            guard let finished = session.finishedAt else { return nil }
            return DashboardMetrics.SessionSummary(finishedAt: finished, volumeKg: session.totalVolume)
        }
    }

    /// Consecutive days trained, reusing the engine the Train tab's rank card already uses so the
    /// two can never disagree about what your streak is.
    var trainingStreakDays: Int {
        guard !currentUserID.isEmpty else { return 0 }
        let uid = currentUserID
        let desc = FetchDescriptor<WorkoutSessionRecord>(predicate: #Predicate { $0.ownerID == uid })
        return GamificationEngine.workoutStreak(sessions: (try? modelContext.fetch(desc)) ?? [])
    }

    var sessionsThisWeek: Int {
        DashboardMetrics.trainingDayCount(finishedSessionSummaries,
                                          in: DashboardMetrics.rollingWeek(endingOn: Date()))
    }

    /// Training days the active split plans over the coming week. Zero when there's no split, which
    /// the widget reads as "no target" rather than "you've missed everything".
    var plannedSessionsThisWeek: Int {
        guard activeSplit != nil else { return 0 }
        return DashboardMetrics.plannedTrainingDays(loadTypes: weekLoadMap(daysAhead: 7).map(\.loadType))
    }

    var weeklyVolumeKg: Double {
        DashboardMetrics.volumeKg(finishedSessionSummaries,
                                  in: DashboardMetrics.rollingWeek(endingOn: Date()))
    }

    /// Change against the seven days before this one.
    var weeklyVolumeChangePercent: Double? {
        let summaries = finishedSessionSummaries
        let calendar = Calendar.current
        let thisWeek = DashboardMetrics.rollingWeek(endingOn: Date())
        guard let priorEnd = calendar.date(byAdding: .day, value: -7, to: Date()) else { return nil }
        let lastWeek = DashboardMetrics.rollingWeek(endingOn: priorEnd)
        return DashboardMetrics.percentChange(
            current: DashboardMetrics.volumeKg(summaries, in: thisWeek),
            previous: DashboardMetrics.volumeKg(summaries, in: lastWeek)
        )
    }

    /// The next non-rest day on the split, and how far off it is. Nil when nothing is scheduled in
    /// the coming fortnight.
    var nextTrainingDay: (date: Date, name: String)? {
        guard activeSplit != nil else { return nil }
        for (date, loadType) in weekLoadMap(daysAhead: 14) where loadType == "gym" {
            let name = gymDay(for: date)?.dayName ?? "Training"
            return (date, name)
        }
        return nil
    }
}
