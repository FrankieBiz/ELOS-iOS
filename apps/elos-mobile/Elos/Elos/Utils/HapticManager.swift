import UIKit

/// Every haptic in the app goes through here, which is what makes a single "Haptics" switch in
/// personalization possible — the alternative was ~90 call sites each checking a flag.
enum HapticManager {
    private static var isEnabled: Bool { ThemeStore.shared.config.hapticsEnabled }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.warning)
    }

    static func selection() {
        guard isEnabled else { return }
        let g = UISelectionFeedbackGenerator()
        g.prepare()
        g.selectionChanged()
    }
}
