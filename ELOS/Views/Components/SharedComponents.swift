import SwiftUI

// MARK: - Flat Card (replaces GlassCard — no blur, flat surface + hairline)

struct GlassCard<Content: View>: View {
    @Environment(\.skin) private var skin
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.lg
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(skin.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(skin.hairline, lineWidth: 0.5)
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

// MARK: - Ground Card (replaces SolidCard — elevated surface)

struct SolidCard<Content: View>: View {
    @Environment(\.skin) private var skin
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(skin.surfaceHigh, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(skin.hairline, lineWidth: 0.5)
            )
    }
}

// MARK: - Pressable Button Style

struct PressableStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.96
    var hapticStyle: HapticKind = .light

    enum HapticKind { case light, medium, heavy, soft, none }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed else { return }
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

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
    static func pressable(scale: CGFloat = 0.96, haptic: PressableStyle.HapticKind = .light) -> PressableStyle {
        PressableStyle(scaleAmount: scale, hapticStyle: haptic)
    }
}

// MARK: - Primary CTA

struct PrimaryCTA: View {
    @Environment(\.skin) private var skin
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil
    var color: Color? = nil
    var height: CGFloat = 56
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        let fill = color ?? skin.accent
        Button(action: { Haptic.heavy(); action() }) {
            ZStack {
                fill
                if isLoading {
                    ProgressView().progressViewStyle(.circular).tint(skin.onAccent)
                } else {
                    HStack(spacing: 10) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 17, weight: .heavy))
                        }
                        VStack(spacing: 1) {
                            Text(title)
                                .font(.system(size: 16, weight: .heavy))
                            if let subtitle {
                                Text(subtitle)
                                    .font(.system(size: 11, weight: .semibold))
                                    .opacity(0.80)
                            }
                        }
                    }
                    .foregroundStyle(skin.onAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(.pressable(scale: 0.97, haptic: .none))
    }
}

// MARK: - Secondary CTA

struct SecondaryCTA: View {
    @Environment(\.skin) private var skin
    let title: String
    var icon: String? = nil
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        let c = color ?? skin.accent
        Button(action: { Haptic.light(); action() }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title).font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(c)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.pressable(scale: 0.95, haptic: .none))
    }
}

// MARK: - Ghost CTA

struct GhostCTA: View {
    @Environment(\.skin) private var skin
    let title: String
    var icon: String? = nil
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        let c = color ?? skin.accent
        Button(action: { Haptic.light(); action() }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title).font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(c)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(c.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable(scale: 0.97, haptic: .none))
    }
}

// MARK: - Section Label

struct SectionLabel: View {
    @Environment(\.skin) private var skin
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(Theme.Font.section)
                .foregroundStyle(skin.labelSub)
                .kerning(0.8)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(skin.accent)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, Theme.Space.lg)
        .padding(.bottom, Theme.Space.xs)
    }
}

// MARK: - Stat Tile

struct StatTile: View {
    @Environment(\.skin) private var skin
    let label: String
    let value: String
    var sub: String? = nil
    var icon: String? = nil
    var accent: Color? = nil
    var highlight: Color? = nil

    var body: some View {
        let color = accent ?? skin.accent
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                }
                Text(label.uppercased())
                    .font(Theme.Font.label)
                    .kerning(0.8)
                    .foregroundStyle(skin.labelSub)
            }
            Text(value)
                .font(Theme.Font.mono(26, .black))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(skin.labelFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(skin.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            highlight.map { c in
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(c.opacity(0.5), lineWidth: 1)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(skin.hairline, lineWidth: 0.5)
        )
    }
}

// MARK: - Ring Progress

struct RingProgress: View {
    @Environment(\.skin) private var skin
    let value: Double
    var size: CGFloat = 120
    var lineWidth: CGFloat = 10
    var color: Color? = nil
    var trackColor: Color? = nil
    var label: String? = nil
    var sublabel: String? = nil

    var body: some View {
        ZStack {
            Circle().stroke(trackColor ?? skin.hairline, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(value, 1)))
                .stroke(color ?? skin.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.bouncy, value: value)
            VStack(spacing: 2) {
                if let label {
                    Text(label)
                        .font(Theme.Font.mono(26, .black))
                        .foregroundStyle(skin.label)
                        .minimumScaleFactor(0.5)
                }
                if let sublabel {
                    Text(sublabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(skin.labelSub)
                }
            }
            .padding(.horizontal, lineWidth + 4)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Chip

struct Chip: View {
    @Environment(\.skin) private var skin
    let text: String
    var icon: String? = nil
    var color: Color? = nil
    var filled: Bool = false

    var body: some View {
        let c = color ?? skin.accent
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .bold)) }
            Text(text).font(.system(size: 11, weight: .heavy))
        }
        .foregroundStyle(filled ? skin.onAccent : c)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(filled ? c : c.opacity(0.12), in: Capsule())
    }
}

// MARK: - Empty State

struct EmptyStateCard: View {
    @Environment(\.skin) private var skin
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(skin.accentSubtle)
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(skin.accent)
            }
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(skin.label)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(skin.labelSub)
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

// MARK: - Animated Number

struct AnimatedNumber: View {
    let value: Double
    var format: String = "%.0f"
    var font: Font = Theme.Font.mono(48, .black)
    var color: Color? = nil

    @Environment(\.skin) private var skin
    @State private var current: Double = 0

    var body: some View {
        Text(String(format: format, current))
            .font(font)
            .foregroundStyle(color ?? skin.label)
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

// MARK: - Streak Badge (replaces animated flame — clean and direct)

struct StreakBadge: View {
    @Environment(\.skin) private var skin
    let count: Int
    var size: CGFloat = 36

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.6, weight: .heavy))
                .foregroundStyle(skin.accent)
            Text("\(count)")
                .font(Theme.Font.mono(size, .black))
                .foregroundStyle(skin.label)
        }
    }
}

// kept for call-site compatibility — just a typealias of StreakBadge
typealias StreakFlame = StreakBadge

// MARK: - PR Flash (replaces confetti — sharp scale burst)

struct PRFlashModifier: ViewModifier {
    let trigger: Int
    @State private var isFlashing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isFlashing ? 1.07 : 1.0)
            .brightness(isFlashing ? 0.12 : 0)
            .onChange(of: trigger) { _, _ in
                guard trigger > 0 else { return }
                withAnimation(Theme.Motion.quick) { isFlashing = true }
                withAnimation(Theme.Motion.snappy.delay(0.14)) { isFlashing = false }
            }
    }
}

extension View {
    func prFlash(trigger: Int) -> some View {
        modifier(PRFlashModifier(trigger: trigger))
    }
}

// MARK: - Hairline

struct Hairline: View {
    @Environment(\.skin) private var skin
    var inset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(skin.hairline)
            .frame(height: 0.5)
            .padding(.leading, inset)
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
