import SwiftUI

// Confetti replaced by PRFlash (see SharedComponents.swift).
// Stub keeps existing call sites compiling.
struct ConfettiOverlay: View {
    var trigger: Int = 0
    var body: some View { Color.clear.allowsHitTesting(false) }
}
