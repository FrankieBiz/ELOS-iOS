import SwiftUI

extension Font {
    static func elosDisplay(_ size: CGFloat = 36) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    static func elosNumber(_ size: CGFloat = 48) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    static func elosHeadline(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func elosBody(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func elosCaption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    static func elosLabel(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func elosMono(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}
