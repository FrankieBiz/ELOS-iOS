import Testing
@testable import Elos

struct PersonalizationProviderTests {
    @Test func favoriteBeatsUnknown() {
        let p = PersonalizationProvider(signals: .init(
            favoriteNames: ["bench press"], recentOrder: [], frequency: [:]))
        #expect(p.score(forName: "Bench Press") > p.score(forName: "Leg Curl"))
    }
    @Test func moreFrequentScoresHigher() {
        let p = PersonalizationProvider(signals: .init(
            favoriteNames: [], recentOrder: [], frequency: ["squat": 10, "curl": 1]))
        #expect(p.score(forName: "Squat") > p.score(forName: "Curl"))
    }
    @Test func recentScoresHigherThanNotRecent() {
        let p = PersonalizationProvider(signals: .init(
            favoriteNames: [], recentOrder: ["row", "press"], frequency: [:]))
        #expect(p.score(forName: "Row") > p.score(forName: "Deadlift"))
    }
    @Test func scoreIsClampedZeroToOne() {
        let p = PersonalizationProvider(signals: .init(
            favoriteNames: ["a"], recentOrder: ["a"], frequency: ["a": 100]))
        #expect(p.score(forName: "A") <= 1.0)
        #expect(p.score(forName: "Z") >= 0.0)
    }
}
