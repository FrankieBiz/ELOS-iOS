import Combine
import SwiftUI

// MARK: - Stored shape

/// One screen's arrangement.
///
/// Width is stored as two opt-out sets rather than a `[Section: Span]` map for two reasons: a
/// dictionary keyed by an enum doesn't round-trip through `Codable` without extra conformance, and
/// storing only the *overrides* means a section whose shipped default later changes picks up the new
/// default for everyone who never touched it.
struct ScreenLayout: Codable, Hashable {
    var order: [LayoutSection] = []
    var hidden: Set<LayoutSection> = []
    var forcedHalf: Set<LayoutSection> = []
    var forcedFull: Set<LayoutSection> = []

    var isCustomized: Bool {
        !order.isEmpty || !hidden.isEmpty || !forcedHalf.isEmpty || !forcedFull.isEmpty
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        order      = try c.decodeIfPresent([LayoutSection].self, forKey: .order) ?? []
        hidden     = try c.decodeIfPresent(Set<LayoutSection>.self, forKey: .hidden) ?? []
        forcedHalf = try c.decodeIfPresent(Set<LayoutSection>.self, forKey: .forcedHalf) ?? []
        forcedFull = try c.decodeIfPresent(Set<LayoutSection>.self, forKey: .forcedFull) ?? []
    }
}

/// Which tabs exist, in what order, and where the app opens.
///
/// The resolving logic lives here rather than on the store because every interesting case — an
/// order saved before a tab existed, a bar that would draw six columns, a launch tab someone
/// hid — is a stored-state problem, and stored state is far easier to assert on than to walk a
/// simulator into. `LayoutStore` just persists what this decides.
struct TabLayout: Codable, Hashable {
    /// The bar draws at most five columns. This is not a style preference: five labels already
    /// share one row without reflowing, and at large Dynamic Type "TRAIN" and "STATS" collided
    /// with no gap between them. A sixth makes that worse, so something has to come off.
    static let maxVisible = 5

    /// Plan ships hidden. It's a course planner — schedule, assignments, exams — carried over
    /// from a different app, and it's the tab that loses its slot when Feed takes one. Hidden,
    /// never deleted: its records stay in SwiftData and switching it back on restores them.
    static let defaultHidden: Set<AppTab> = [.plan]

    /// Bumped when a shipped default changes in a way already-saved arrangements have to be
    /// reconciled with. `0` means "saved before this field existed".
    static let currentVersion = 1

    var order: [AppTab] = AppTab.allCases
    var hidden: Set<AppTab> = TabLayout.defaultHidden
    var launchTab: AppTab = .today
    var version: Int = TabLayout.currentVersion

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        order     = try c.decodeIfPresent([AppTab].self, forKey: .order) ?? AppTab.allCases
        hidden    = try c.decodeIfPresent(Set<AppTab>.self, forKey: .hidden) ?? TabLayout.defaultHidden
        launchTab = try c.decodeIfPresent(AppTab.self, forKey: .launchTab) ?? .today
        // Absent means this was written before versioning, which is exactly what needs migrating.
        version   = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
    }

    // MARK: Resolving

    /// Every tab exactly once, in the user's order, with anything the catalog gained since this
    /// was saved appended. Deduped: a duplicate would render the same tab twice and hand
    /// `ForEach` two rows with one id.
    var resolvedOrder: [AppTab] {
        var seen = Set<AppTab>()
        var ordered = order.filter { AppTab.allCases.contains($0) && seen.insert($0).inserted }
        for tab in AppTab.allCases where !ordered.contains(tab) { ordered.append(tab) }
        return ordered
    }

    /// The tabs the bar actually draws: non-empty, capped at `maxVisible`, and always containing
    /// the launch tab. This is the app's only navigation, so it has to return something usable
    /// however mangled the stored value gets.
    var resolvedVisible: [AppTab] {
        var visible = resolvedOrder.filter { !hidden.contains($0) }
        // Launching into a tab that isn't in the bar is a dead end. `setLaunchTab` and
        // `canHideTab` both prevent it; this covers a value that got there some other way.
        if !visible.contains(launchTab) { visible.append(launchTab) }
        // Trim from the end, never the launch tab.
        while visible.count > Self.maxVisible,
              let last = visible.lastIndex(where: { $0 != launchTab }) {
            visible.remove(at: last)
        }
        return visible.isEmpty ? [launchTab] : visible
    }

    // MARK: Migration

    /// Reconcile a stored arrangement with the shipped defaults.
    ///
    /// Runs once per version bump, on load. Everything it touches is a case you cannot reach by
    /// tapping around — an arrangement saved before Feed existed, a bar that would overflow — so
    /// it is covered by unit tests rather than by hand.
    static func migrated(_ stored: TabLayout) -> TabLayout {
        guard stored.version < currentVersion else { return stored }
        var out = stored

        // An order saved before Feed existed would otherwise append it last, past Me. Slot it
        // where it ships instead: straight after Train.
        if !out.order.contains(.feed) {
            if let i = out.order.firstIndex(of: .train) {
                out.order.insert(.feed, at: out.order.index(after: i))
            } else {
                out.order.append(.feed)
            }
        }

        // Adding Feed pushes an untouched bar to six. Plan is the one that gives up its slot —
        // unless the lifter already curated theirs down to something that fits, or they launch
        // into Plan, in which case taking it away would strand them.
        let wouldOverflow = out.resolvedOrder.filter { !out.hidden.contains($0) }.count > maxVisible
        if wouldOverflow && out.launchTab != .plan {
            out.hidden.insert(.plan)
        }

        out.version = currentVersion
        return out
    }
}

struct LayoutConfig: Codable, Hashable {
    /// Keyed by `CustomizableScreen.rawValue` — a `String` key so the dictionary encodes as a plain
    /// JSON object rather than the flat key/value array Swift emits for non-string keys.
    var screens: [String: ScreenLayout] = [:]
    var tabs: TabLayout = TabLayout()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        screens = try c.decodeIfPresent([String: ScreenLayout].self, forKey: .screens) ?? [:]
        tabs    = try c.decodeIfPresent(TabLayout.self, forKey: .tabs) ?? TabLayout()
    }
}

// MARK: - Store

/// Where every screen's arrangement lives.
///
/// Nothing here knows what a section *looks* like — it deals only in `LayoutSection` values, order,
/// visibility and width. `SectionStack` renders whatever this returns.
final class LayoutStore: ObservableObject {
    private static let storageKey = "elos.personalization.layout.v1"

    @Published private(set) var config: LayoutConfig {
        didSet {
            guard config != oldValue else { return }
            revision &+= 1
            persist()
        }
    }

    @Published private(set) var revision: Int = 0

    /// Non-nil while a screen is being rearranged in place. Drives the on-page edit chrome and the
    /// floating edit bar; deliberately *not* persisted — nobody wants to relaunch into edit mode.
    @Published var editingScreen: CustomizableScreen?

    /// Set to open the full editor sheet on a particular screen's tab.
    @Published var customizingScreen: CustomizableScreen?
    @Published var showingCustomizeSheet = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(LayoutConfig.self, from: data) {
            var migrated = decoded
            migrated.tabs = TabLayout.migrated(decoded.tabs)
            config = migrated
            // `config`'s `didSet` doesn't run from an initialiser, so a migration would sit in
            // memory and re-run on every launch. Write it back once, here.
            if migrated != decoded { persist() }
        } else {
            config = LayoutConfig()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func mutate(_ change: (inout LayoutConfig) -> Void) {
        var next = config
        change(&next)
        config = next
    }

    private func mutate(_ screen: CustomizableScreen, _ change: (inout ScreenLayout) -> Void) {
        mutate { config in
            var layout = config.screens[screen.rawValue] ?? ScreenLayout()
            // A screen with no stored order yet needs one materialised before an edit, or a single
            // "move down" would produce a one-element order and lose every other section's position.
            //
            // Seeding `hidden` at the same time is not optional. Once an order exists, every section
            // it names is treated as a deliberate choice — so materialising the order alone silently
            // un-hid every opt-in widget, and the first nudge on Today dumped eight extra cards onto
            // the screen. The snapshot has to capture both halves of the default.
            if layout.order.isEmpty {
                layout.order = LayoutSection.defaultOrder(for: screen)
                layout.hidden = Set(layout.order.filter(\.isOptIn))
            }
            change(&layout)
            config.screens[screen.rawValue] = layout
        }
    }

    // MARK: Reading

    /// Every section on a screen, in the user's order, hidden ones included.
    func orderedSections(for screen: CustomizableScreen) -> [LayoutSection] {
        LayoutResolver.resolveOrder(
            stored: config.screens[screen.rawValue]?.order ?? [],
            catalog: LayoutSection.defaultOrder(for: screen)
        )
    }

    func isHidden(_ section: LayoutSection) -> Bool {
        if section.isPinned { return false }
        guard let layout = config.screens[section.screen.rawValue] else { return section.isOptIn }
        if layout.hidden.contains(section) { return true }
        // Present in the catalog but not in a stored order means the catalog gained it after this
        // arrangement was saved — so its shipped default decides, not the absence of a record.
        if !layout.order.isEmpty && !layout.order.contains(section) { return section.isOptIn }
        return false
    }

    func span(for section: LayoutSection) -> SectionSpan {
        guard section.canResize else { return .full }
        guard let layout = config.screens[section.screen.rawValue] else { return section.defaultSpan }
        if layout.forcedHalf.contains(section) { return .half }
        if layout.forcedFull.contains(section) { return .full }
        return section.defaultSpan
    }

    /// The visible sections of a screen, in order, with their widths resolved.
    func placedSections(for screen: CustomizableScreen) -> [PlacedSection] {
        orderedSections(for: screen)
            .filter { !isHidden($0) }
            .map { PlacedSection(section: $0, span: span(for: $0)) }
    }

    func hiddenSections(for screen: CustomizableScreen) -> [LayoutSection] {
        orderedSections(for: screen).filter { isHidden($0) }
    }

    func isCustomized(_ screen: CustomizableScreen) -> Bool {
        config.screens[screen.rawValue]?.isCustomized ?? false
    }

    var isAnyScreenCustomized: Bool {
        CustomizableScreen.allCases.contains { isCustomized($0) }
    }

    // MARK: Writing

    func setHidden(_ section: LayoutSection, _ hidden: Bool) {
        guard !section.isPinned else { return }
        mutate(section.screen) { layout in
            if hidden { layout.hidden.insert(section) } else { layout.hidden.remove(section) }
        }
    }

    func toggleHidden(_ section: LayoutSection) {
        setHidden(section, !isHidden(section))
    }

    func setSpan(_ section: LayoutSection, _ span: SectionSpan) {
        guard section.canResize else { return }
        mutate(section.screen) { layout in
            layout.forcedHalf.remove(section)
            layout.forcedFull.remove(section)
            // Only record a choice that differs from the shipped default, so the stored arrangement
            // stays a diff rather than a full snapshot.
            guard span != section.defaultSpan else { return }
            if span == .half { layout.forcedHalf.insert(section) } else { layout.forcedFull.insert(section) }
        }
    }

    func toggleSpan(_ section: LayoutSection) {
        setSpan(section, span(for: section) == .half ? .full : .half)
    }

    /// Reorder from the editor's `List`, whose rows are the screen's full order (hidden included).
    func move(in screen: CustomizableScreen, fromOffsets: IndexSet, toOffset: Int) {
        mutate(screen) { layout in
            var resolved = LayoutResolver.resolveOrder(
                stored: layout.order,
                catalog: LayoutSection.defaultOrder(for: screen)
            )
            resolved.move(fromOffsets: fromOffsets, toOffset: toOffset)
            layout.order = resolved
        }
    }

    /// Move a section one place up or down **past the next visible section**, which is what the
    /// on-page arrows have to do: stepping over a hidden neighbour would look like a no-op.
    func nudge(_ section: LayoutSection, by delta: Int) {
        guard delta != 0 else { return }
        let screen = section.screen
        var resolved = orderedSections(for: screen)
        guard let from = resolved.firstIndex(of: section) else { return }

        let stride = delta > 0 ? 1 : -1
        var cursor = from + stride
        var remaining = abs(delta)
        var target: Int?
        while cursor >= 0 && cursor < resolved.count {
            if !isHidden(resolved[cursor]) {
                remaining -= 1
                if remaining == 0 { target = cursor; break }
            }
            cursor += stride
        }
        guard let destination = target else { return }

        resolved.remove(at: from)
        resolved.insert(section, at: destination)
        mutate(screen) { $0.order = resolved }
    }

    func canNudge(_ section: LayoutSection, by delta: Int) -> Bool {
        let visible = placedSections(for: section.screen).map(\.section)
        guard let index = visible.firstIndex(of: section) else { return false }
        let target = index + delta
        return target >= 0 && target < visible.count
    }

    /// Drop `section` immediately above `other`. Backs the drag-and-drop in the editor, where the
    /// drop target is a row rather than an index.
    func move(_ section: LayoutSection, before other: LayoutSection) {
        guard section != other, section.screen == other.screen else { return }
        let screen = section.screen
        var resolved = orderedSections(for: screen)
        guard let from = resolved.firstIndex(of: section) else { return }
        resolved.remove(at: from)
        guard let target = resolved.firstIndex(of: other) else { return }
        resolved.insert(section, at: target)
        mutate(screen) { $0.order = resolved }
    }

    func reset(_ screen: CustomizableScreen) {
        mutate { $0.screens[screen.rawValue] = nil }
    }

    func resetAllLayouts() {
        mutate { $0.screens = [:] }
    }

    // MARK: Tabs

    /// Visible tabs in the user's order. Non-empty, duplicate-free, and capped at
    /// `TabLayout.maxVisible` — the tab bar is the app's only navigation, so this can never
    /// return nothing however mangled the stored value is. The rules live on `TabLayout`.
    var visibleTabs: [AppTab] { config.tabs.resolvedVisible }

    var orderedTabs: [AppTab] { config.tabs.resolvedOrder }

    func isTabHidden(_ tab: AppTab) -> Bool { config.tabs.hidden.contains(tab) }

    /// Hiding is refused when it would leave fewer than two tabs, or when it would hide the tab the
    /// app launches into.
    func canHideTab(_ tab: AppTab) -> Bool {
        if isTabHidden(tab) { return true }
        if tab == config.tabs.launchTab { return false }
        return visibleTabs.count > 2
    }

    /// Showing is refused when the bar is already full. There are six tabs and room for five, so
    /// adding one back means taking one off first — the alternative is a silently ignored tap.
    func canShowTab(_ tab: AppTab) -> Bool {
        if !isTabHidden(tab) { return true }
        return visibleTabs.count < TabLayout.maxVisible
    }

    func setTabHidden(_ tab: AppTab, _ hidden: Bool) {
        guard hidden ? canHideTab(tab) : canShowTab(tab) else { return }
        mutate { config in
            if hidden { config.tabs.hidden.insert(tab) } else { config.tabs.hidden.remove(tab) }
        }
    }

    func moveTabs(fromOffsets: IndexSet, toOffset: Int) {
        mutate { config in
            var ordered = config.tabs.resolvedOrder
            ordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
            config.tabs.order = ordered
        }
    }

    func setLaunchTab(_ tab: AppTab) {
        mutate { config in
            config.tabs.launchTab = tab
            // Launching into a tab you can't navigate back to would be a dead end.
            config.tabs.hidden.remove(tab)
        }
    }

    func resetTabs() {
        mutate { $0.tabs = TabLayout() }
    }

    func resetEverything() {
        config = LayoutConfig()
    }
}
