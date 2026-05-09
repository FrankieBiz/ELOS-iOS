import SwiftUI

// MARK: - Glass Card (translucent material with subtle border)

struct GlassCard<Content: View>: View {
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.lg
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.hairline.opacity(0.5), lineWidth: 0.5)
            )
            .overlay(
                tint.map {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill($0.opacity(0.06))
                        .allowsHitTesting(false)
                }
            )
    }
}

// MARK: - Solid Card (opaque, raised surface)

struct SolidCard<Content: View>: View {
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.hairline.opacity(0.4), lineWidth: 0.5)
            )
    }
}

// MARK: - Pressable Button Style — squishy press with haptic

struct PressableStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.96
    var hapticStyle: HapticKind = .light

    enum HapticKind { case light, medium, heavy, soft, none }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    switch hapticStyle {
                    case .light:  Haptic.light()
                    case .soft:   Haptic.soft()
                    case .medium: Haptic.medium()
                    case .heavy:  Haptic.heavy()
                    case .none:   break
                    }
                }
            }
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
    static func pressable(scale: CGFloat = 0.96, haptic: PressableStyle.HapticKind = .light) -> PressableStyle {
        PressableStyle(scaleAmount: scale, hapticStyle: haptic)
    }
}

// MARK: - Primary CTA — the big, satisfying button

struct PrimaryCTA: View {
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil
    var color: Color = .brand
    var height: CGFloat = 60
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: { Haptic.heavy(); action() }) {
            ZStack {
                LinearGradient(
                    colors: [color, color.opacity(0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                if isLoading {
                    ProgressView().progressViewStyle(.circular).tint(.white)
                } else {
                    HStack(spacing: 10) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .heavy))
                        }
                        VStack(spacing: 1) {
                            Text(title)
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                            if let subtitle {
                                Text(subtitle)
                                    .font(.system(size: 11, weight: .semibold))
                                    .opacity(0.85)
                            }
                        }
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: color.opacity(0.35), radius: 20, x: 0, y: 12)
        }
        .buttonStyle(.pressable(scale: 0.97, haptic: .none))
    }
}

// MARK: - Secondary button (filled tint)

struct SecondaryCTA: View {
    let title: String
    var icon: String? = nil
    var color: Color = .brand
    let action: () -> Void

    var body: some View {
        Button(action: { Haptic.light(); action() }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .bold)) }
                Text(title).font(.system(size: 15, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(color.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.pressable(scale: 0.95, haptic: .none))
    }
}

// MARK: - Ghost button (outlined)

struct GhostCTA: View {
    let title: String
    var icon: String? = nil
    var color: Color = .brand
    let action: () -> Void

    var body: some View {
        Button(action: { Haptic.light(); action() }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .bold)) }
                Text(title).font(.system(size: 15, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(
                Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.pressable(scale: 0.97, haptic: .none))
    }
}

// MARK: - Section Header (uppercase tracked + optional action)

struct SectionLabel: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(Theme.Font.section)
                .foregroundStyle(.secondary)
                .kerning(0.6)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.brand)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.lg)
        .padding(.bottom, Theme.Space.xs)
    }
}

// MARK: - Stat Tile

struct StatTile: View {
    let label: String
    let value: String
    var sub: String? = nil
    var icon: String? = nil
    var accent: Color = .primary
    var highlight: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                }
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Color.surfaceRaised)
        )
        .overlay(
            highlight.map { c in
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(c.opacity(0.5), lineWidth: 1)
            }
        )
    }
}

// MARK: - Ring Progress

struct RingProgress: View {
    let value: Double           // 0...1
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12
    var color: Color = .brand
    var trackColor: Color = Color(.systemGray5)
    var label: String? = nil
    var sublabel: String? = nil

    var body: some View {
        ZStack {
            Circle().stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(value, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.bouncy, value: value)
            VStack(spacing: 2) {
                if let label {
                    Text(label)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.5)
                }
                if let sublabel {
                    Text(sublabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, lineWidth + 4)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Chip

struct Chip: View {
    let text: String
    var icon: String? = nil
    var color: Color = .brand
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .bold)) }
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(filled ? .white : color)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(
            Capsule().fill(filled ? color : color.opacity(0.14))
        )
    }
}

// MARK: - Empty State

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.brand.opacity(0.12)).frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.brand)
            }
            VStack(spacing: 4) {
                Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                SecondaryCTA(title: actionTitle, action: action)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Animated big number (counts up smoothly)

struct AnimatedNumber: View {
    let value: Double
    var format: String = "%.0f"
    var font: Font = .system(size: 48, weight: .black, design: .rounded)
    var color: Color = .primary

    @State private var current: Double = 0

    var body: some View {
        Text(String(format: format, current))
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { current = value }
            }
            .onChange(of: value) { _, new in
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { current = new }
            }
    }
}

// MARK: - Streak flame

struct StreakFlame: View {
    let count: Int
    var size: CGFloat = 36
    @State private var flicker = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#FF453A"), Color(hex: "#FF9F0A"), Color(hex: "#FFD60A")],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .scaleEffect(flicker ? 1.05 : 0.97)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: flicker)
                    .onAppear { flicker = true }
            }
            Text("\(count)")
                .font(.system(size: size * 0.9, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Hairline divider

struct Hairline: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle().fill(Color.hairline.opacity(0.6)).frame(height: 0.5).padding(.leading, inset)
    }
}

// MARK: - Greeting helper

var elosGreeting: String {
    switch Calendar.current.component(.hour, from: .now) {
    case 0..<5:   return "Late night"
    case 5..<12:  return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<21: return "Good evening"
    default:      return "Good night"
    }
}
