import SwiftUI

// =====================================================================
//  VIGIL · components
//  flat surfaces · hairline borders · 4–6pt corners · zero gradients
// =====================================================================

// MARK: - Card (formerly GlassCard / SolidCard — both kept for back-compat)

struct GlassCard<Content: View>: View {
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.md
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.vSurface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.vLine, lineWidth: 0.5)
            )
    }
}

struct SolidCard<Content: View>: View {
    var padding: CGFloat = Theme.Space.md
    var radius: CGFloat = Theme.Radius.md
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.vSurface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.vLine, lineWidth: 0.5)
            )
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
            .glow(active: glow && configuration.isPressed, radius: glowRadius, intensity: 0.9)
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
    static func pressable(scale: CGFloat = 0.97,
                          haptic: PressableStyle.HapticKind = .light,
                          glow: Bool = true,
                          glowRadius: CGFloat = 16) -> PressableStyle {
        PressableStyle(scaleAmount: scale, hapticStyle: haptic, glow: glow, glowRadius: glowRadius)
    }
}

// MARK: - Primary CTA (platinum on obsidian, with aura)

struct PrimaryCTA: View {
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil
    var color: Color? = nil
    var height: CGFloat = 54
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        let fill = color ?? .vSignal
        Button(action: { Haptic.heavy(); action() }) {
            ZStack {
                fill
                if isLoading {
                    ProgressView().progressViewStyle(.circular).tint(.vBG)
                } else {
                    HStack(spacing: 10) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 15, weight: .black))
                        }
                        Text(title.uppercased())
                            .font(.system(size: 14, weight: .black))
                            .kerning(1.4)
                        if let subtitle {
                            Text(subtitle.uppercased())
                                .font(.system(size: 11, weight: .heavy))
                                .opacity(0.7)
                                .kerning(0.6)
                        }
                    }
                    .foregroundStyle(Color.vBG)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .glow(radius: 18, intensity: 0.45)
        }
        .buttonStyle(.pressable(scale: 0.98, haptic: .none, glow: true, glowRadius: 24))
    }
}

// MARK: - Secondary CTA (outlined)

struct SecondaryCTA: View {
    let title: String
    var icon: String? = nil
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        let c = color ?? .vSignal
        Button(action: { Haptic.light(); action() }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .heavy)) }
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .kerning(1.0)
            }
            .foregroundStyle(c)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.vBG, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(c, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable(scale: 0.96, haptic: .none))
    }
}

// MARK: - Ghost CTA (text-only)

struct GhostCTA: View {
    let title: String
    var icon: String? = nil
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        let c = color ?? Color.vLabelMute
        Button(action: { Haptic.light(); action() }) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .heavy)) }
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(1.0)
            }
            .foregroundStyle(c)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(Color.vLineHigh, lineWidth: 0.5)
            )
        }
        .buttonStyle(.pressable(scale: 0.97, haptic: .none))
    }
}

// MARK: - Section label (caps, kerned, with optional action)

struct SectionLabel: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.vSignal)
                .frame(width: 12, height: 2)
            Text(title.uppercased())
                .font(Theme.Font.label)
                .kerning(1.4)
                .foregroundStyle(.vLabelMute)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(0.8)
                        .foregroundStyle(.vSignal)
                }
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.top, Theme.Space.lg)
        .padding(.bottom, Theme.Space.xs)
    }
}

// MARK: - StatTile (dense, mono numbers)

struct StatTile: View {
    let label: String
    let value: String
    var sub: String? = nil
    var icon: String? = nil
    var accent: Color? = nil
    var highlight: Color? = nil

    var body: some View {
        let color = accent ?? .vSignal
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(color)
                }
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(1.2)
                    .foregroundStyle(.vLabelMute)
            }
            Text(value)
                .font(Theme.Font.mono(24, .black))
                .foregroundStyle(.vLabel)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let sub {
                Text(sub.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.vLabelFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(Color.vSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .strokeBorder(highlight ?? Color.vLine, lineWidth: 0.5)
        )
    }
}

// MARK: - Ring progress (sharp, single-color)

struct RingProgress: View {
    let value: Double
    var size: CGFloat = 120
    var lineWidth: CGFloat = 8
    var color: Color? = nil
    var trackColor: Color? = nil
    var label: String? = nil
    var sublabel: String? = nil

    var body: some View {
        ZStack {
            Circle().stroke(trackColor ?? Color.vLineHigh, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(value, 1)))
                .stroke(color ?? .vSignal, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.bouncy, value: value)
            VStack(spacing: 2) {
                if let label {
                    Text(label)
                        .font(Theme.Font.mono(22, .black))
                        .foregroundStyle(.vLabel)
                        .minimumScaleFactor(0.5)
                }
                if let sublabel {
                    Text(sublabel.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(1.0)
                        .foregroundStyle(.vLabelMute)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Tag (square pill, ALL CAPS)

struct Chip: View {
    let text: String
    var icon: String? = nil
    var color: Color? = nil
    var filled: Bool = false

    var body: some View {
        let c = color ?? .vSignal
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 8, weight: .black)) }
            Text(text.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .kerning(0.8)
        }
        .foregroundStyle(filled ? Color.vBG : c)
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(filled ? c : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous)
                .strokeBorder(c.opacity(filled ? 0 : 0.5), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xs, style: .continuous))
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
        VStack(spacing: 14) {
            ZStack {
                Rectangle()
                    .fill(Color.vSurfaceHigh)
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.vLabelMute)
            }
            VStack(spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .black))
                    .kerning(1.2)
                    .foregroundStyle(.vLabel)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.vLabelMute)
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

// MARK: - Animated number (mono)

struct AnimatedNumber: View {
    let value: Double
    var format: String = "%.0f"
    var font: Font = Theme.Font.mono(48, .black)
    var color: Color = .vLabel

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

// MARK: - Streak badge (square, mono, no flame)

struct StreakBadge: View {
    let count: Int
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 5) {
            Rectangle().fill(Color.vSignal).frame(width: 4, height: size * 0.55)
            Text("\(count)")
                .font(Theme.Font.mono(size * 0.55, .black))
                .foregroundStyle(.vLabel)
            Text("DAY")
                .font(.system(size: size * 0.32, weight: .heavy))
                .kerning(0.8)
                .foregroundStyle(.vLabelMute)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xs)
                .strokeBorder(Color.vLineHigh, lineWidth: 0.5)
        )
    }
}

typealias StreakFlame = StreakBadge

// MARK: - PR flash modifier

struct PRFlashModifier: ViewModifier {
    let trigger: Int
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(on ? 1.06 : 1.0)
            .brightness(on ? 0.10 : 0)
            .onChange(of: trigger) { _, _ in
                guard trigger > 0 else { return }
                withAnimation(Theme.Motion.quick) { on = true }
                withAnimation(Theme.Motion.snappy.delay(0.16)) { on = false }
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
    var inset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(Color.vLine)
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

// MARK: - Index badge (01, 02, 03 — tactical row markers)

struct IndexBadge: View {
    let n: Int
    var active: Bool = false
    var size: CGFloat = 26

    var body: some View {
        Text(String(format: "%02d", n))
            .font(Theme.Font.mono(11, .black))
            .foregroundStyle(active ? Color.vBG : .vLabelMute)
            .frame(width: size, height: size)
            .background(active ? Color.vSignal : Color.vSurfaceHigh)
            .overlay(
                Rectangle().strokeBorder(active ? Color.clear : Color.vLine, lineWidth: 0.5)
            )
    }
}

// MARK: - Status dot (filled circle, simple)

struct StatusDot: View {
    var color: Color = .vSignal
    var size: CGFloat = 6
    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

// MARK: - Greeting helper

var elosGreeting: String {
    switch Calendar.current.component(.hour, from: .now) {
    case 0..<5:   return "On the grind"
    case 5..<12:  return "Morning"
    case 12..<17: return "Afternoon"
    case 17..<21: return "Evening"
    default:      return "Late shift"
    }
}
