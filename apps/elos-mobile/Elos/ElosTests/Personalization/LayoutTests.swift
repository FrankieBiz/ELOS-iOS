import Foundation
import Testing
@testable import Elos

// MARK: - Row packing

struct SectionRowPackerTests {
    private func placed(_ section: LayoutSection, _ span: SectionSpan) -> PlacedSection {
        PlacedSection(section: section, span: span)
    }

    @Test func allFullWidthGivesOneRowEach() {
        let rows = SectionRowPacker.pack([
            placed(.todayGreeting, .full),
            placed(.todayHabits, .full),
        ])
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { if case .single = $0 { return true } else { return false } })
    }

    @Test func consecutiveHalvesPairIntoOneRow() {
        let rows = SectionRowPacker.pack([
            placed(.todaySleep, .half),
            placed(.todayGymVolume, .half),
        ])
        #expect(rows.count == 1)
        guard case .pair(let left, let right) = rows[0] else {
            Issue.record("expected a pair"); return
        }
        #expect(left.section == .todaySleep)
        #expect(right.section == .todayGymVolume)
    }

    /// The case that produces a stranded narrow card next to dead space if it isn't handled.
    @Test func loneHalfFallsBackToFullWidth() {
        let rows = SectionRowPacker.pack([
            placed(.todaySleep, .half),
            placed(.todayHabits, .full),
        ])
        #expect(rows.count == 2)
        guard case .single(let first) = rows[0] else {
            Issue.record("a half with no partner should render alone"); return
        }
        #expect(first.section == .todaySleep)
    }

    @Test func trailingHalfWithNoPartnerRendersAlone() {
        let rows = SectionRowPacker.pack([
            placed(.todaySleep, .half),
            placed(.todayGymVolume, .half),
            placed(.todayHydration, .half),
        ])
        // First two pair; the third has nothing after it.
        #expect(rows.count == 2)
        guard case .pair = rows[0] else { Issue.record("expected a pair first"); return }
        guard case .single(let last) = rows[1] else { Issue.record("expected a single last"); return }
        #expect(last.section == .todayHydration)
    }

    @Test func halvesSeparatedByAFullDoNotPair() {
        let rows = SectionRowPacker.pack([
            placed(.todaySleep, .half),
            placed(.todayHabits, .full),
            placed(.todayGymVolume, .half),
        ])
        #expect(rows.count == 3)
    }

    @Test func emptyInputGivesNoRows() {
        #expect(SectionRowPacker.pack([]).isEmpty)
    }
}

// MARK: - Order resolution

struct LayoutResolverTests {
    private let catalog: [LayoutSection] = [.todayGreeting, .todayHabits, .todaySchedule, .todayUpcoming]

    @Test func emptyStoredOrderFallsBackToCatalogOrder() {
        #expect(LayoutResolver.resolveOrder(stored: [], catalog: catalog) == catalog)
    }

    @Test func storedOrderIsHonoured() {
        let stored: [LayoutSection] = [.todayUpcoming, .todaySchedule, .todayHabits, .todayGreeting]
        #expect(LayoutResolver.resolveOrder(stored: stored, catalog: catalog) == stored)
    }

    /// The app-update case: the catalog gains a section a saved arrangement has never seen. It has to
    /// land where its author put it, not at the bottom of someone's screen.
    @Test func newCatalogSectionLandsAfterItsShippedNeighbour() {
        let stored: [LayoutSection] = [.todayGreeting, .todaySchedule, .todayUpcoming]
        let resolved = LayoutResolver.resolveOrder(stored: stored, catalog: catalog)
        // `todayHabits` ships between greeting and schedule.
        #expect(resolved == [.todayGreeting, .todayHabits, .todaySchedule, .todayUpcoming])
    }

    @Test func newSectionAtTheTopOfTheCatalogLandsAtTheTop() {
        let stored: [LayoutSection] = [.todayHabits, .todaySchedule, .todayUpcoming]
        let resolved = LayoutResolver.resolveOrder(stored: stored, catalog: catalog)
        #expect(resolved.first == .todayGreeting)
    }

    /// A section the catalog no longer has must not survive in the resolved order.
    @Test func retiredSectionIsDropped() {
        let stored: [LayoutSection] = [.todayGreeting, .trainRadar, .todayHabits]
        let resolved = LayoutResolver.resolveOrder(stored: stored, catalog: catalog)
        #expect(!resolved.contains(.trainRadar))
        #expect(resolved.count == catalog.count)
    }

    @Test func duplicatesInStoredOrderAreCollapsed() {
        let stored: [LayoutSection] = [.todayGreeting, .todayGreeting, .todayHabits]
        let resolved = LayoutResolver.resolveOrder(stored: stored, catalog: catalog)
        #expect(resolved.filter { $0 == .todayGreeting }.count == 1)
        #expect(Set(resolved) == Set(catalog))
    }

    @Test func everyScreenHasAtLeastOneSection() {
        for screen in CustomizableScreen.allCases {
            #expect(!LayoutSection.defaultOrder(for: screen).isEmpty, "\(screen.title) has no sections")
        }
    }

    /// A section is only reachable if some screen claims it — a case added without a descriptor
    /// pointing at the right screen would silently never render.
    @Test func everySectionBelongsToExactlyOneScreensDefaultOrder() {
        for section in LayoutSection.allCases {
            let owners = CustomizableScreen.allCases.filter {
                LayoutSection.defaultOrder(for: $0).contains(section)
            }
            #expect(owners == [section.screen], "\(section.rawValue) is not reachable from its screen")
        }
    }
}

// MARK: - Store

struct LayoutStoreTests {
    /// Each test gets its own suite so nothing touches (or is polluted by) the real app defaults.
    private func makeStore(_ name: String = UUID().uuidString) -> LayoutStore {
        LayoutStore(defaults: UserDefaults(suiteName: name)!)
    }

    @Test func defaultsMatchTheCatalog() {
        let store = makeStore()
        #expect(store.orderedSections(for: .today) == LayoutSection.defaultOrder(for: .today))
        #expect(!store.isCustomized(.today))
    }

    @Test func optInSectionsStartHidden() {
        let store = makeStore()
        #expect(store.isHidden(.todayStreak))
        #expect(!store.isHidden(.todayHabits))
        #expect(!store.placedSections(for: .today).map(\.section).contains(.todayStreak))
    }

    /// Regression: the store materialises a screen's order on first edit, and once an order exists
    /// every section it names counts as a deliberate choice. Materialising the order *without* also
    /// seeding `hidden` silently un-hid every opt-in widget — one nudge on Today dropped eight extra
    /// cards onto the screen.
    @Test func firstEditDoesNotUnhideOptInWidgets() {
        let store = makeStore()
        let visibleBefore = store.placedSections(for: .today).map(\.section)

        store.nudge(visibleBefore[1], by: 1)

        #expect(store.isHidden(.todayStreak))
        #expect(store.isHidden(.todayLatestPR))
        #expect(store.isHidden(.todayMuscleFocus))
        #expect(Set(store.placedSections(for: .today).map(\.section)) == Set(visibleBefore))
    }

    @Test func showingAnOptInWidgetPutsItOnTheScreen() {
        let store = makeStore()
        store.setHidden(.todayStreak, false)
        #expect(!store.isHidden(.todayStreak))
        #expect(store.placedSections(for: .today).map(\.section).contains(.todayStreak))
    }

    @Test func pinnedSectionsCannotBeHidden() {
        let store = makeStore()
        store.setHidden(.meSettings, true)
        #expect(!store.isHidden(.meSettings))
        store.setHidden(.trainStart, true)
        #expect(!store.isHidden(.trainStart))
    }

    @Test func nudgeMovesPastTheNextVisibleSection() {
        let store = makeStore()
        let before = store.placedSections(for: .today).map(\.section)
        guard before.count > 2 else { Issue.record("need at least three visible"); return }
        let subject = before[2]
        store.nudge(subject, by: -1)
        let after = store.placedSections(for: .today).map(\.section)
        #expect(after.firstIndex(of: subject) == 1)
        #expect(Set(after) == Set(before))
    }

    /// The reason `nudge` walks the visible list rather than the raw order: stepping onto a hidden
    /// neighbour would look like the button did nothing.
    @Test func nudgeSkipsHiddenNeighbours() {
        let store = makeStore()
        let visible = store.placedSections(for: .today).map(\.section)
        guard visible.count > 3 else { Issue.record("need at least four visible"); return }
        store.setHidden(visible[1], true)
        let subject = visible[2]
        store.nudge(subject, by: -1)
        let after = store.placedSections(for: .today).map(\.section)
        #expect(after.first == subject)
    }

    @Test func nudgeAtTheEdgeIsANoOp() {
        let store = makeStore()
        let before = store.placedSections(for: .today).map(\.section)
        store.nudge(before[0], by: -1)
        #expect(store.placedSections(for: .today).map(\.section) == before)
        #expect(!store.canNudge(before[0], by: -1))
    }

    @Test func spanOverrideAppliesOnlyToResizableSections() {
        let store = makeStore()
        #expect(store.span(for: .todaySleep) == .half)
        store.setSpan(.todaySleep, .full)
        #expect(store.span(for: .todaySleep) == .full)

        // `todaySchedule` is a timeline — it never offers the control, so it can't be forced narrow.
        store.setSpan(.todaySchedule, .half)
        #expect(store.span(for: .todaySchedule) == .full)
    }

    @Test func movingBeforeAnotherSectionReordersWithoutLoss() {
        let store = makeStore()
        let before = store.orderedSections(for: .today)
        guard let last = before.last, let first = before.first else { return }
        store.move(last, before: first)
        let after = store.orderedSections(for: .today)
        #expect(after.first == last)
        #expect(after.count == before.count)
        #expect(Set(after) == Set(before))
    }

    @Test func resetRestoresTheShippedArrangement() {
        let store = makeStore()
        store.setHidden(.todayHabits, true)
        store.setSpan(.todaySleep, .full)
        store.nudge(store.placedSections(for: .today).map(\.section)[1], by: 1)
        #expect(store.isCustomized(.today))

        store.reset(.today)
        #expect(!store.isCustomized(.today))
        #expect(store.orderedSections(for: .today) == LayoutSection.defaultOrder(for: .today))
        #expect(!store.isHidden(.todayHabits))
        #expect(store.span(for: .todaySleep) == .half)
    }

    @Test func arrangementSurvivesAReload() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store = LayoutStore(defaults: defaults)
        store.setHidden(.todayHabits, true)
        store.setHidden(.todayStreak, false)
        store.setSpan(.todayHydration, .half)

        let reloaded = LayoutStore(defaults: defaults)
        #expect(reloaded.isHidden(.todayHabits))
        #expect(!reloaded.isHidden(.todayStreak))
        #expect(reloaded.span(for: .todayHydration) == .half)
    }
}

// MARK: - Tab bar

struct TabLayoutTests {
    private func makeStore() -> LayoutStore {
        LayoutStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    /// Six tabs exist, five fit. Plan is the one that ships hidden — see `TabLayout.defaultHidden`.
    @Test func defaultsToTheShippedBar() {
        let store = makeStore()
        #expect(store.visibleTabs == [.today, .train, .feed, .stats, .me])
        #expect(store.orderedTabs == AppTab.allCases)
        #expect(store.config.tabs.launchTab == .today)
    }

    @Test func hidingATabRemovesItFromTheBar() {
        let store = makeStore()
        store.setTabHidden(.stats, true)
        #expect(!store.visibleTabs.contains(.stats))
        #expect(store.orderedTabs.contains(.stats))   // still listed in the editor
    }

    /// The bar is the app's only navigation; it can never be emptied.
    @Test func cannotHideBelowTwoTabs() {
        let store = makeStore()
        for tab in [AppTab.stats, .plan, .me, .train] {
            store.setTabHidden(tab, true)
        }
        #expect(store.visibleTabs.count >= 2)
    }

    @Test func cannotHideTheLaunchTab() {
        let store = makeStore()
        store.setLaunchTab(.train)
        store.setTabHidden(.train, true)
        #expect(store.visibleTabs.contains(.train))
    }

    @Test func choosingAHiddenTabAsLaunchUnhidesIt() {
        let store = makeStore()
        store.setTabHidden(.stats, true)
        store.setLaunchTab(.stats)
        #expect(!store.isTabHidden(.stats))
        #expect(store.visibleTabs.contains(.stats))
    }

    @Test func reorderingPersistsAndKeepsEveryTab() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store = LayoutStore(defaults: defaults)
        store.moveTabs(fromOffsets: IndexSet(integer: 4), toOffset: 0)

        let reloaded = LayoutStore(defaults: defaults)
        #expect(reloaded.orderedTabs.first == AppTab.allCases[4])
        #expect(Set(reloaded.orderedTabs) == Set(AppTab.allCases))
    }
}
