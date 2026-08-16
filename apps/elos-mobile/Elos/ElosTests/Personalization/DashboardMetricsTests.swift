import Foundation
import Testing
@testable import Elos

struct DashboardMetricsTests {
    private let calendar = Calendar(identifier: .gregorian)
    /// A fixed "now" so these never depend on when the suite runs.
    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) }   // 2023-11-14 22:13 UTC

    private func daysAgo(_ days: Int, hour: Int = 12) -> Date {
        let start = calendar.startOfDay(for: now)
        let shifted = calendar.date(byAdding: .day, value: -days, to: start)!
        return calendar.date(byAdding: .hour, value: hour, to: shifted)!
    }

    private func session(_ days: Int, volume: Double = 100, hour: Int = 12) -> DashboardMetrics.SessionSummary {
        .init(finishedAt: daysAgo(days, hour: hour), volumeKg: volume)
    }

    // MARK: Window

    @Test func rollingWeekSpansSevenDaysEndingToday() {
        let window = DashboardMetrics.rollingWeek(endingOn: now, calendar: calendar)
        #expect(calendar.dateComponents([.day], from: window.start, to: window.end).day == 7)
    }

    /// A session finished this evening has to count — the window runs to the end of today, not the
    /// start of it.
    @Test func todaysLateSessionIsInsideTheWindow() {
        let window = DashboardMetrics.rollingWeek(endingOn: now, calendar: calendar)
        #expect(window.contains(daysAgo(0, hour: 23)))
    }

    @Test func sevenDaysAgoIsOutsideTheWindow() {
        let window = DashboardMetrics.rollingWeek(endingOn: now, calendar: calendar)
        #expect(!window.contains(daysAgo(7, hour: 12)))
        #expect(window.contains(daysAgo(6, hour: 12)))
    }

    // MARK: Counting

    /// Days trained, not sessions logged. Two sessions in one day is one training day — otherwise a
    /// widget can claim "6 of 4" against a split that plans four.
    @Test func twoSessionsInADayCountAsOneTrainingDay() {
        let window = DashboardMetrics.rollingWeek(endingOn: now, calendar: calendar)
        let sessions = [session(1, hour: 8), session(1, hour: 18), session(3)]
        #expect(DashboardMetrics.trainingDayCount(sessions, in: window, calendar: calendar) == 2)
    }

    @Test func sessionsOutsideTheWindowAreExcluded() {
        let window = DashboardMetrics.rollingWeek(endingOn: now, calendar: calendar)
        let sessions = [session(1), session(20), session(400)]
        #expect(DashboardMetrics.trainingDayCount(sessions, in: window, calendar: calendar) == 1)
    }

    @Test func noHistoryCountsZeroRatherThanFailing() {
        let window = DashboardMetrics.rollingWeek(endingOn: now, calendar: calendar)
        #expect(DashboardMetrics.trainingDayCount([], in: window, calendar: calendar) == 0)
        #expect(DashboardMetrics.volumeKg([], in: window) == 0)
    }

    // MARK: Volume

    @Test func volumeSumsOnlyTheSessionsInsideTheWindow() {
        let window = DashboardMetrics.rollingWeek(endingOn: now, calendar: calendar)
        let sessions = [session(0, volume: 1000), session(6, volume: 500), session(9, volume: 9999)]
        #expect(DashboardMetrics.volumeKg(sessions, in: window) == 1500)
    }

    // MARK: Planned days

    @Test func plannedDaysCountsOnlyGymEntries() {
        #expect(DashboardMetrics.plannedTrainingDays(
            loadTypes: ["gym", "rest", "gym", "skip", "exam", "gym"]) == 3)
        #expect(DashboardMetrics.plannedTrainingDays(loadTypes: []) == 0)
    }

    // MARK: Change

    @Test func percentChangeIsSignedAndProportional() {
        #expect(DashboardMetrics.percentChange(current: 150, previous: 100) == 50)
        #expect(DashboardMetrics.percentChange(current: 50, previous: 100) == -50)
        #expect(DashboardMetrics.percentChange(current: 100, previous: 100) == 0)
    }

    /// No previous week means no trend. Reporting "+100%" against a zero baseline is noise dressed
    /// as information.
    @Test func percentChangeIsNilWithoutABaseline() {
        #expect(DashboardMetrics.percentChange(current: 500, previous: 0) == nil)
    }
}
