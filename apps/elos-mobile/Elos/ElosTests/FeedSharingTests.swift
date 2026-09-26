import Foundation
import Testing
@testable import Elos

/// The pure parts of getting a workout onto the feed.
struct FeedSharingTests {

    // MARK: One post per workout

    @Test func noPRsMeansNoPRLine() {
        #expect(FeedPRSummary.label(for: []) == nil)
    }

    @Test func onePRReadsAsItself() {
        #expect(FeedPRSummary.label(for: ["Bench Press"]) == "Bench Press")
    }

    @Test func extraPRsAreCountedNotListed() {
        // The card renders this with `lineLimit(1)`. "Bench Press, Back Squat, Deadlift" would be
        // truncated mid-word; a count survives at any width.
        #expect(FeedPRSummary.label(for: ["Bench Press", "Back Squat"]) == "Bench Press +1 more")
        #expect(FeedPRSummary.label(for: ["Bench Press", "Back Squat", "Deadlift"]) == "Bench Press +2 more")
    }

    // MARK: Auto-share is three states, not two

    @Test func unaskedIsNotOn() {
        // The distinction the one-time prompt depends on: never answered is not the same as no.
        #expect(!FeedAutoShare.unasked.isOn)
        #expect(!FeedAutoShare.off.isOn)
        #expect(FeedAutoShare.on.isOn)
    }

    @Test func autoShareRoundTripsThroughItsStoredValue() {
        for state in [FeedAutoShare.unasked, .on, .off] {
            #expect(FeedAutoShare(rawValue: state.rawValue) == state)
        }
    }

    @Test func anUnrecognisedStoredValueFallsBackToAsking() {
        // Better to ask again than to guess "on" and start publishing unprompted.
        #expect(FeedAutoShare(rawValue: "garbage") == nil)
    }
}
