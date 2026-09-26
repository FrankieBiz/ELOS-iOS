import Testing
@testable import Elos
import Foundation

struct GamificationEngineTests {
    private let cal = Calendar.current

    private func daysAgo(_ n: Int) -> Date {
        cal.date(byAdding: .day, value: -n, to: Date())!
    }

    private func session(finishedDaysAgo n: Int) -> WorkoutSessionRecord {
        WorkoutSessionRecord(ownerID: "test", finishedAt: daysAgo(n))
    }

    @Test func noSessionsIsZero() {
        #expect(GamificationEngine.workoutStreak(sessions: []) == 0)
    }

    @Test func todayOnlyIsOne() {
        let sessions = [session(finishedDaysAgo: 0)]
        #expect(GamificationEngine.workoutStreak(sessions: sessions) == 1)
    }

    /// The regression this fix targets: a streak logged through yesterday must still read as
    /// alive first thing today, before that day's workout happens — not reset to 0 at midnight.
    @Test func yesterdayOnlyStaysAliveToday() {
        let sessions = (1...5).map { session(finishedDaysAgo: $0) }  // 5-day streak ending yesterday
        #expect(GamificationEngine.workoutStreak(sessions: sessions) == 5)
    }

    @Test func todayAndYesterdayCountsBoth() {
        let sessions = [session(finishedDaysAgo: 0), session(finishedDaysAgo: 1)]
        #expect(GamificationEngine.workoutStreak(sessions: sessions) == 2)
    }

    /// A real gap — nothing yesterday, nothing today — breaks the streak entirely.
    @Test func gapOfTwoDaysIsZero() {
        let sessions = [session(finishedDaysAgo: 2)]
        #expect(GamificationEngine.workoutStreak(sessions: sessions) == 0)
    }

    /// Only the contiguous tail counts — an old, broken streak further back doesn't inflate it.
    @Test func brokenStreakOnlyCountsContiguousTail() {
        let sessions = [
            session(finishedDaysAgo: 0), session(finishedDaysAgo: 1), session(finishedDaysAgo: 2),
            // gap at day 3
            session(finishedDaysAgo: 4), session(finishedDaysAgo: 5),
        ]
        #expect(GamificationEngine.workoutStreak(sessions: sessions) == 3)
    }

    @Test func multipleSessionsSameDayCountOnce() {
        let sessions = [session(finishedDaysAgo: 0), session(finishedDaysAgo: 0), session(finishedDaysAgo: 1)]
        #expect(GamificationEngine.workoutStreak(sessions: sessions) == 2)
    }

    @Test func unfinishedSessionsAreIgnored() {
        let unfinished = WorkoutSessionRecord(ownerID: "test", finishedAt: nil)
        #expect(GamificationEngine.workoutStreak(sessions: [unfinished]) == 0)
    }
}
