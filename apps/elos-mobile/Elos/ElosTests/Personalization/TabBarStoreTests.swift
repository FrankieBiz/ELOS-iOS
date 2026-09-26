import Foundation
import Testing
@testable import Elos

/// `LayoutStore`'s tab half, against real `UserDefaults` in a throwaway suite.
///
/// Separate from `TabLayoutTests` on purpose: those cover the rules, these cover the two things
/// only the store can get wrong — refusing an edit that would overflow the bar, and writing a
/// migration back to disk instead of re-running it every launch.
/// Marked `@MainActor` because the types under test are: the project builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so `TabLayout`'s synthesized `Equatable` and
/// `Decodable` conformances are main-actor-isolated and using them from a nonisolated suite is a
/// warning today and an error under the Swift 6 language mode.
@MainActor
struct TabBarStoreTests {

    private static let storageKey = "elos.personalization.layout.v1"

    private func freshDefaults() -> UserDefaults {
        let suite = "TabBarStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: The bar holds five

    @Test func showingATabIsRefusedWhenTheBarIsFull() {
        let store = LayoutStore(defaults: freshDefaults())
        // Ships full: five visible, Plan hidden.
        #expect(store.visibleTabs.count == TabLayout.maxVisible)
        #expect(store.isTabHidden(.plan))
        #expect(!store.canShowTab(.plan))

        store.setTabHidden(.plan, false)
        #expect(store.isTabHidden(.plan), "showing a sixth tab must not silently succeed")
        #expect(store.visibleTabs.count == TabLayout.maxVisible)
    }

    @Test func freeingASlotLetsAnotherTabBack() {
        let store = LayoutStore(defaults: freshDefaults())
        store.setTabHidden(.stats, true)
        #expect(store.canShowTab(.plan))

        store.setTabHidden(.plan, false)
        #expect(!store.isTabHidden(.plan))
        #expect(store.visibleTabs == [.today, .train, .feed, .plan, .me])
    }

    @Test func alreadyVisibleTabsAlwaysReportShowable() {
        // `canShowTab` backs an enabled/disabled control; a visible tab isn't asking to be shown.
        let store = LayoutStore(defaults: freshDefaults())
        for tab in store.visibleTabs { #expect(store.canShowTab(tab)) }
    }

    @Test func hidingIsStillRefusedForTheLaunchTab() {
        let store = LayoutStore(defaults: freshDefaults())
        store.setLaunchTab(.train)
        #expect(!store.canHideTab(.train))
        store.setTabHidden(.train, true)
        #expect(!store.isTabHidden(.train))
    }

    @Test func resetRestoresTheShippedBar() {
        let store = LayoutStore(defaults: freshDefaults())
        store.setTabHidden(.stats, true)
        store.setTabHidden(.plan, false)
        store.resetTabs()
        #expect(store.visibleTabs == [.today, .train, .feed, .stats, .me])
    }

    // MARK: Migration on load

    @Test func aPreFeedArrangementIsMigratedAndWrittenBack() throws {
        let defaults = freshDefaults()
        let legacy = #"{"screens":{},"tabs":{"order":["today","train","stats","plan","me"],"hidden":[],"launchTab":"today"}}"#
        defaults.set(Data(legacy.utf8), forKey: Self.storageKey)

        let store = LayoutStore(defaults: defaults)
        #expect(store.visibleTabs == [.today, .train, .feed, .stats, .me])

        // Written back, not just held in memory: `config`'s `didSet` doesn't fire from an
        // initialiser, so without an explicit persist this would re-migrate on every launch.
        let raw = try #require(defaults.data(forKey: Self.storageKey))
        let reread = try JSONDecoder().decode(LayoutConfig.self, from: raw)
        #expect(reread.tabs.version == TabLayout.currentVersion)
        #expect(reread.tabs.hidden.contains(.plan))
        #expect(reread.tabs.order.contains(.feed))
    }

    @Test func anAlreadyMigratedStoreIsNotRewritten() throws {
        let defaults = freshDefaults()
        let store = LayoutStore(defaults: defaults)
        store.setTabHidden(.stats, true)
        let before = try #require(defaults.data(forKey: Self.storageKey))

        let reopened = LayoutStore(defaults: defaults)
        #expect(reopened.isTabHidden(.stats))
        let after = try #require(defaults.data(forKey: Self.storageKey))
        #expect(before == after)
    }
}
