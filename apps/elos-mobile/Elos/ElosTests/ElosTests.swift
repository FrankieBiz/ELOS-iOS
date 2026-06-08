//
//  ElosTests.swift
//  ElosTests
//

import Testing
import Foundation
@testable import Elos

// MARK: - FeedDateParser

struct FeedDateParserTests {
    @Test func parsesPostgresTimestamptzText() {
        #expect(FeedDateParser.parse("2026-06-06 12:01:26.123456+00") != nil)
        #expect(FeedDateParser.parse("2026-06-06 12:01:26+00") != nil)
    }

    @Test func parsesISO8601() {
        #expect(FeedDateParser.parse("2026-06-06T12:01:26Z") != nil)
    }

    @Test func returnsNilForGarbage() {
        #expect(FeedDateParser.parse("not a date") == nil)
        #expect(FeedDateParser.parse("") == nil)
    }
}

// MARK: - Formatters

struct FormattersTests {
    @Test func daysFromTodayIsZeroForToday() {
        let today = Formatters.isoDay.string(from: Date())
        #expect(Formatters.daysFromToday(toISODay: today) == 0)
    }

    @Test func daysFromTodayHandlesPastAndFuture() {
        let cal = Calendar.current
        let future = cal.date(byAdding: .day, value: 5, to: Date())!
        let past = cal.date(byAdding: .day, value: -3, to: Date())!
        #expect(Formatters.daysFromToday(toISODay: Formatters.isoDay.string(from: future)) == 5)
        #expect(Formatters.daysFromToday(toISODay: Formatters.isoDay.string(from: past)) == -3)
    }

    @Test func daysFromTodayIsZeroForUnparseable() {
        #expect(Formatters.daysFromToday(toISODay: "garbage") == 0)
    }
}

// MARK: - NamedUser display logic

private struct TestUser: NamedUser {
    var first_name: String
    var last_name: String
    var usernameOrNil: String?
    var avatarColorOrNil: String?
}

struct NamedUserTests {
    @Test func displayNamePrefersFullName() {
        let u = TestUser(first_name: "Dariel", last_name: "B", usernameOrNil: "db", avatarColorOrNil: nil)
        #expect(u.displayName == "Dariel B")
    }

    @Test func displayNameFallsBackToUsernameThenUnknown() {
        let withUsername = TestUser(first_name: "", last_name: "", usernameOrNil: "dariel", avatarColorOrNil: nil)
        #expect(withUsername.displayName == "@dariel")
        let nothing = TestUser(first_name: "", last_name: "", usernameOrNil: nil, avatarColorOrNil: nil)
        #expect(nothing.displayName == "Unknown")
    }

    @Test func initialsUsesFirstLetters() {
        let u = TestUser(first_name: "Dariel", last_name: "Bisignano", usernameOrNil: nil, avatarColorOrNil: nil)
        #expect(u.initials == "DB")
        let empty = TestUser(first_name: "", last_name: "", usernameOrNil: nil, avatarColorOrNil: nil)
        #expect(empty.initials == "?")
    }

    @Test func avatarHexDefaultsWhenMissing() {
        let missing = TestUser(first_name: "A", last_name: "B", usernameOrNil: nil, avatarColorOrNil: nil)
        #expect(missing.avatarHex == "#6C47FF")
        let custom = TestUser(first_name: "A", last_name: "B", usernameOrNil: nil, avatarColorOrNil: "#123456")
        #expect(custom.avatarHex == "#123456")
    }
}

// MARK: - Feed reaction math (optimistic)

@MainActor
struct FeedReactionMathTests {
    @Test func incrementAddsNewEmoji() {
        let vm = FeedViewModel()
        let result = vm.increment([], "🔥")
        #expect(result.count == 1)
        #expect(result.first?.emoji == "🔥")
        #expect(result.first?.count == 1)
    }

    @Test func incrementBumpsExistingEmoji() {
        let vm = FeedViewModel()
        let result = vm.increment([FeedReaction(emoji: "🔥", count: 2)], "🔥")
        #expect(result.first?.count == 3)
    }

    @Test func decrementRemovesWhenReachingZero() {
        let vm = FeedViewModel()
        let result = vm.decrement([FeedReaction(emoji: "🔥", count: 1)], "🔥")
        #expect(result.isEmpty)
    }

    @Test func decrementKeepsWhenCountRemains() {
        let vm = FeedViewModel()
        let result = vm.decrement([FeedReaction(emoji: "🔥", count: 3)], "🔥")
        #expect(result.first?.count == 2)
    }
}
