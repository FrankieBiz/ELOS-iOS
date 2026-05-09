import SwiftUI

// =====================================================================
//  OBSIDIAN · components
//  material surfaces · edge highlights · refined radius · quiet wealth
// =====================================================================

// MARK: - Card

struct GlassCard<Content: View>: View {
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.md
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.onyx)
            )
            .edgeHighlight(radius: radius)
    }
}

struct SolidCard<Content: View>: View {
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.md
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.onyx)
            )
            .edgeHighlight(radius: radius)
    }
}

// MARK: - Pressable button style

struct PressableStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.97
    var hapticStyle: HapticKind = .light
    var glow: Bool = true
    var glowRadius: CGFloat = 16

    enum HapticKind { case light, medium, heavy, soft, none }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .glow(active: glow && configuration.isPressed, radius: glowRadius, intensity: 0.8)
            .animation(Theme.Motion.press, value: configuration.isPressed)
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
    static func pressable(scale: CGFloat = 0.97,
                          haptic: PressableStyle.HapticKind = .light,
                          glow: Bool = true,
                          glowRadius: CGFloat = 16) -> PressableStyle {
        PressableStyle(scaleAmount: scale, hapticStyle: haptic, glow: glow, glowRadius: glowRadius)
    }
}

// MARK: - Primary CTA (platinum on obsidian, breath glow)

struct PrimaryCTA: View {
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil
    var color: Color? = nil
    var height: CGFloat = 56
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        let fill = color ?? .pearl
        Button(action: { Haptic.medium(); action() }) {
            ZStack {
                LinearGradient(
                    colors: [fill.opacity(0.98), fill],
                    startPoint: .top,
                    endPoint: .bottom
                )
                if isLoading {
                    ProgressView().progressViewStyle(.circular).tint(.obsidian)
                } else {
                    HStack(spacing: 10) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 15, weight: .regular))
                        }
                        Text(title)
                            .font(Theme.Font.title(18))
                        if let subtitle {
                            Text(subtitle)
                                .font(Theme.Font.body(13))
                                .opacity(0.55)
                        }
                    }
                    .foregroundStyle(Color.obsidian)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .breathGlow(minIntensity: 0.12, maxIntensity: 0.32, radius: 18)
        }
        .buttonStyle(.pressable(scale: 0.985, haptic: .none, glow: true, glowRadius: 22))
    }
}

// MARK: - Secondary CTA (outlined)

struct SecondaryCTA: View {
    let title: String
    var icon: String? = nil
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        let c = color ?? .pearl
        Button(action: { Haptic.light(); action() }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .regular)) }
                Text(title)
                    .font(Theme.Font.body(14, .medium))
            }
            .foregroundStyle(c)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Color.obsidian, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(c.opacity(0.35), lineWidth: 0.75)
            )
        }
        .buttonStyle(.pressable(scale: 0.97, haptic: .none))
    }
}

// MARK: - Ghost CTA (text link with underline border on press)

struct GhostCTA: View {
    let title: String
    var icon: String? = nil
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        let c = color ?? Color.silver
        Button(action: { Haptic.light(); action() }) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .regular)) }
                Text(title)
                    .font(Theme.Font.body(13, .regular))
            }
            .foregroundStyle(c)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Color.mist, lineWidth: 0.5)
            )
        }
        .buttonStyle(.pressable(scale: 0.97, haptic: .none, glow: false))
    }
}

// MARK: - Section label

struct SectionLabel: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.pearl.opacity(0.18))
                .frame(width: 16, height: 1)
            Text(title.uppercased())
                .font(Theme.Font.label)
                .kerning(1.6)
                .foregroundStyle(.silver)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(Theme.Font.body(13))
                            .foregroundStyle(.silver)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.shadowTxt)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.top, Theme.Space.lg)
        .padding(.bottom, Theme.Space.xs)
    }
}

// MARK: - StatTile

struct StatTile: View {
    let label: String
    let value: String
    var sub: String? = nil
    var icon: String? = nil
    var accent: Color? = nil
    var highlight: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(accent ?? .silver)
                }
                Text(label.uppercased())
                    .font(Theme.Font.label)
                    .kerning(1.4)
                    .foregroundStyle(.silver)
            }
            Text(value)
                .font(Theme.Font.display(36))
                .foregroundStyle(.pearl)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(Theme.Font.body(11))
                    .foregroundStyle(.shadowTxt)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 16)
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
    }
}

// MARK: - Ring progress

struct RingProgress: View {
    let value: Double
    var size: CGFloat = 120
    var lineWidth: CGFloat = 6
    var color: Color? = nil
    var trackColor: Color? = nil
    var label: String? = nil
    var sublabel: String? = nil

    var body: some View {
        ZStack {
            Circle().stroke(trackColor ?? Color.mist, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(value, 1)))
                .stroke(
                    LinearGradient(colors: [.pearl, .auraHalo], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.glide, value: value)
            VStack(spacing: 2) {
                if let label {
                    Text(label)
                        .font(Theme.Font.mono(22, .medium))
                        .foregroundStyle(.pearl)
                        .minimumScaleFactor(0.5)
                }
                if let sublabel {
                    Text(sublabel.uppercased())
                        .font(Theme.Font.label)
                        .kerning(1.0)
                        .foregroundStyle(.silver)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Chip

struct Chip: View {
    let text: String
    var icon: String? = nil
    var color: Color? = nil
    var filled: Bool = false

    var body: some View {
        let c = color ?? .pearl
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .regular)) }
            Text(text.uppercased())
                .font(Theme.Font.label)
                .kerning(0.8)
        }
        .foregroundStyle(filled ? Color.obsidian : c)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(filled ? c : Color.clear)
        .overlay(
            Capsule()
                .strokeBorder(c.opacity(filled ? 0 : 0.4), lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Empty state

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Color.graphite)
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .thin))
                    .foregroundStyle(.silver)
            }
            VStack(spacing: 5) {
                Text(title)
                    .font(Theme.Font.heading(15))
                    .foregroundStyle(.pearl)
                Text(subtitle)
                    .font(Theme.Font.body(13))
                    .foregroundStyle(.silver)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                SecondaryCTA(title: actionTitle, action: action)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Animated number

struct AnimatedNumber: View {
    let value: Double
    var format: String = "%.0f"
    var font: Font = Theme.Font.display(48)
    var color: Color = .pearl

    @State private var current: Double = 0

    var body: some View {
        Text(String(format: format, current))
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(Theme.Motion.glide) { current = value }
            }
            .onChange(of: value) { _, new in
                withAnimation(Theme.Motion.smooth) { current = new }
            }
    }
}

// MARK: - Streak badge

struct StreakBadge: View {
    let count: Int
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Color.pearl).frame(width: 2, height: size * 0.5)
            Text("\(count)")
                .font(Theme.Font.mono(size * 0.5, .medium))
                .foregroundStyle(.pearl)
            Text("days")
                .font(.system(size: size * 0.28, weight: .regular))
                .foregroundStyle(.silver)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.xs)
    }
}

typealias StreakFlame = StreakBadge

// MARK: - PR flash

struct PRFlashModifier: ViewModifier {
    let trigger: Int
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .brightness(on ? 0.12 : 0)
            .glow(active: on, radius: 20, intensity: 0.7)
            .onChange(of: trigger) { _, _ in
                guard trigger > 0 else { return }
                withAnimation(Theme.Motion.press) { on = true }
                withAnimation(Theme.Motion.glide.delay(0.3)) { on = false }
            }
    }
}

extension View {
    func prFlash(trigger: Int) -> some View {
        modifier(PRFlashModifier(trigger: trigger))
    }
}

// MARK: - Hairline (gradient — feels carved)

struct Hairline: View {
    var inset: CGFloat = 0
    var body: some View {
        LinearGradient(
            colors: [.clear, Color.mist.opacity(0.6), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 0.5)
        .padding(.leading, inset)
    }
}

// MARK: - Index badge (kept as back-compat, visually refined)

struct IndexBadge: View {
    let n: Int
    var active: Bool = false
    var size: CGFloat = 26

    var body: some View {
        Text(String(format: "%02d", n))
            .font(Theme.Font.mono(10, .regular))
            .foregroundStyle(active ? Color.obsidian : .shadowTxt)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous)
                    .fill(active ? Color.pearl : Color.graphite)
            )
    }
}

// MARK: - Status dot

struct StatusDot: View {
    var color: Color = .pearl
    var size: CGFloat = 6
    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

// MARK: - Greeting

var elosGreeting: String {
    switch Calendar.current.component(.hour, from: .now) {
    case 0..<5:   return "You're up late"
    case 5..<12:  return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<21: return "Good evening"
    default:      return "Good night"
    }
}
