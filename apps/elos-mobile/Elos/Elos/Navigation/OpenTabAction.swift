import SwiftUI

/// Follows a cross-screen link to another tab.
///
/// Today's stat cards and "See all" rows used to write `vm.selectedTab` directly, which stopped
/// being safe once tabs became hideable: switching to a tab that isn't in the bar renders the
/// screen with nothing highlighted and no obvious way back. Routing through one action puts that
/// rule in a single place — `ContentView`, which owns both the selection and the tab bar — instead
/// of at nine call sites that would each need to know the visibility rules and carry their own
/// sheet. Adding a tab no longer means auditing every link that points at one.
struct OpenTabAction {
    private let handler: (AppTab) -> Void

    init(_ handler: @escaping (AppTab) -> Void) { self.handler = handler }

    func callAsFunction(_ tab: AppTab) { handler(tab) }
}

private struct OpenTabKey: EnvironmentKey {
    /// A no-op default so previews and anything hosted outside `ContentView` still render, rather
    /// than trapping on a dependency they don't have.
    static let defaultValue = OpenTabAction { _ in }
}

extension EnvironmentValues {
    var openTab: OpenTabAction {
        get { self[OpenTabKey.self] }
        set { self[OpenTabKey.self] = newValue }
    }
}
