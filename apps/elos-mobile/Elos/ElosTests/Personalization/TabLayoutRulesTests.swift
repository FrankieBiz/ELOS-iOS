import Foundation
import Testing
@testable import Elos

/// The tab bar's stored state.
///
/// Everything here is a state you cannot walk a simulator into: an arrangement saved before Feed
/// existed, a bar that would draw six columns, a launch tab that got hidden some other way. That's
/// the whole reason the rules live on `TabLayout` as pure functions rather than inside the store.
/// Marked `@MainActor` because the types under test are: the project builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so `TabLayout`'s synthesized `Equatable` and
/// `Decodable` conformances are main-actor-isolated and using them from a nonisolated suite is a
/// warning today and an error under the Swift 6 language mode.
@MainActor
struct TabLayoutRulesTests {

    // MARK: Shipped defaults

    @Test func defaultBarShowsFiveWithPlanHidden() {
        let layout = TabLayout()
        #expect(layout.resolvedVisible == [.today, .train, .feed, .stats, .me])
        #expect(layout.hidden == [.plan])
        #expect(layout.resolvedVisible.count == TabLayout.maxVisible)
    }

    @Test func planIsHiddenNotRemoved() {
        // Switching it back on has to restore it — its assignments and courses are still in
        // SwiftData, and hiding a tab is not a delete.
        var layout = TabLayout()
        layout.hidden.remove(.plan)
        #expect(layout.resolvedOrder.contains(.plan))
        #expect(layout.resolvedVisible.contains(.plan))
    }

    @Test func defaultOrderPutsFeedAfterTrain() {
        #expect(TabLayout().resolvedOrder == [.today, .train, .feed, .stats, .plan, .me])
    }

    // MARK: Migration from a pre-Feed arrangement

    /// What every existing install actually has on disk: five tabs, nothing hidden, no version.
    private func legacyStored() -> TabLayout {
        var stored = TabLayout()
        stored.order = [.today, .train, .stats, .plan, .me]
        stored.hidden = []
        stored.launchTab = .today
        stored.version = 0
        return stored
    }

    @Test func migrationSlotsFeedAfterTrainRatherThanLast() {
        let out = TabLayout.migrated(legacyStored())
        // Appending would have put Feed past Me, at the far right of the bar.
        #expect(out.order == [.today, .train, .feed, .stats, .plan, .me])
    }

    @Test func migrationHidesPlanSoTheBarStillFits() {
        let out = TabLayout.migrated(legacyStored())
        #expect(out.hidden.contains(.plan))
        #expect(out.resolvedVisible == [.today, .train, .feed, .stats, .me])
    }

    @Test func migrationLeavesACuratedBarAlone() {
        // Someone who already hid Stats has room for Feed without giving up Plan. Taking Plan
        // away anyway would be overruling a choice they actually made.
        var stored = legacyStored()
        stored.hidden = [.stats]
        let out = TabLayout.migrated(stored)
        #expect(!out.hidden.contains(.plan))
        #expect(out.resolvedVisible == [.today, .train, .feed, .plan, .me])
    }

    @Test func migrationWontHideTheTabYouLaunchInto() {
        var stored = legacyStored()
        stored.launchTab = .plan
        let out = TabLayout.migrated(stored)
        #expect(!out.hidden.contains(.plan))
        #expect(out.resolvedVisible.contains(.plan))
        // The cap still holds, and the launch tab survives the trim.
        #expect(out.resolvedVisible.count <= TabLayout.maxVisible)
    }

    @Test func migrationIsIdempotent() {
        let once  = TabLayout.migrated(legacyStored())
        let twice = TabLayout.migrated(once)
        #expect(once == twice)
    }

    @Test func migrationLeavesCurrentVersionUntouched() {
        // A fresh install is already current; migrating it must not re-hide anything the lifter
        // deliberately switched back on.
        var current = TabLayout()
        current.hidden = []
        #expect(TabLayout.migrated(current) == current)
    }

    @Test func legacyJSONDecodesAsUnversionedAndMigrates() throws {
        let json = #"{"order":["today","train","stats","plan","me"],"hidden":[],"launchTab":"today"}"#
        let decoded = try JSONDecoder().decode(TabLayout.self, from: Data(json.utf8))
        #expect(decoded.version == 0)
        #expect(!decoded.order.contains(.feed))

        let out = TabLayout.migrated(decoded)
        #expect(out.version == TabLayout.currentVersion)
        #expect(out.resolvedVisible == [.today, .train, .feed, .stats, .me])
    }

    // MARK: Resolving is defensive — this is the app's only navigation

    @Test func neverRendersMoreThanTheBarFits() {
        var layout = TabLayout()
        layout.hidden = []
        #expect(layout.resolvedVisible.count == TabLayout.maxVisible)
    }

    @Test func trimmingNeverDropsTheLaunchTab() {
        var layout = TabLayout()
        layout.hidden = []
        layout.launchTab = .me          // last in the order, first to be trimmed
        #expect(layout.resolvedVisible.contains(.me))
        #expect(layout.resolvedVisible.count == TabLayout.maxVisible)
    }

    @Test func duplicatesInStoredOrderRenderOnce() {
        // A duplicate would hand `ForEach` two rows sharing one id.
        var layout = TabLayout()
        layout.order = [.today, .today, .train, .feed, .stats, .plan, .me]
        #expect(layout.resolvedOrder == [.today, .train, .feed, .stats, .plan, .me])
    }

    @Test func unknownAndMissingTabsAreReconciledAgainstTheCatalog() {
        var layout = TabLayout()
        layout.order = [.me, .today]    // saved before most tabs existed
        let resolved = layout.resolvedOrder
        #expect(resolved.prefix(2) == [.me, .today])
        #expect(Set(resolved) == Set(AppTab.allCases))
        #expect(resolved.count == AppTab.allCases.count)
    }

    @Test func hidingEverythingStillLeavesAWayToNavigate() {
        var layout = TabLayout()
        layout.hidden = Set(AppTab.allCases)
        #expect(layout.resolvedVisible == [.today])
    }

    @Test func aHiddenLaunchTabIsPutBack() {
        var layout = TabLayout()
        layout.launchTab = .stats
        layout.hidden = [.stats]
        #expect(layout.resolvedVisible.contains(.stats))
    }
}
