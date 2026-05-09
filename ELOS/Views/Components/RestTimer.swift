import SwiftUI

// MARK: - RestTimer
// Animated countdown ring with color-graded intensity, shake at zero,
// and quick-add buttons for ±15s.

struct RestTimerView: View {
    let total: Int
    @Binding var remaining: Int
    var onComplete: () -> Void = {}
    var onSkip: () -> Void = {}
    var onAdjust: (Int) -> Void = { _ in }

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State private var pulse: CGFloat = 1.0

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(remaining) / Double(total)
    }

    private var ringColor: Color {
        switch fraction {
        case ..<0.25: return .brandDanger
        case ..<0.5:  return .brandWarn
        default:      return .brand
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer subtle pulse
                Circle()
                    .fill(ringColor.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulse)
                    .animation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 14)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: max(0, min(fraction, 1)))
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 200, height: 200)
                    .animation(.linear(duration: 0.3), value: remaining)
                    .shadow(color: ringColor.opacity(0.45), radius: 16, x: 0, y: 0)

                VStack(spacing: 0) {
                    Text(format(remaining))
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text("REST")
                        .font(.system(size: 11, weight: .heavy))
                        .kerning(1.0)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                adjustChip("-15s", delta: -15)
                adjustChip("+15s", delta: 15)
                Button {
                    Haptic.medium()
                    onSkip()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "forward.fill")
                        Text("Skip")
                    }
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color.brand, in: Capsule())
                }
                .buttonStyle(.pressable(scale: 0.95, haptic: .none))
            }
        }
        .padding()
        .onAppear { pulse = 1.06 }
        .onReceive(timer) { _ in
            guard remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 {
                Haptic.success()
                onComplete()
            } else if remaining <= 3 {
                Haptic.rigid()
            }
        }
    }

    private func adjustChip(_ label: String, delta: Int) -> some View {
        Button {
            remaining = max(0, remaining + delta)
            Haptic.light()
            onAdjust(delta)
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.brand)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.brand.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.pressable(scale: 0.95, haptic: .none))
    }

    private func format(_ s: Int) -> String {
        let m = s / 60, r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}

// MARK: - Compact rest banner (shown at top of active workout)

struct RestBanner: View {
    let total: Int
    @Binding var remaining: Int
    var onAdd: (Int) -> Void
    var onSkip: () -> Void

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(remaining) / Double(total)
    }

    private var ringColor: Color {
        switch fraction {
        case ..<0.25: return .brandDanger
        case ..<0.5:  return .brandWarn
        default:      return .brand
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0, min(fraction, 1)))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: remaining)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Rest")
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                Text(formatted)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: 6) {
                Button("+15") { onAdd(15) }
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(ringColor)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(ringColor.opacity(0.14), in: Capsule())

                Button("Skip", action: onSkip)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(ringColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ringColor.opacity(0.4), lineWidth: 1)
        )
    }

    private var formatted: String {
        let m = remaining / 60, r = remaining % 60
        return String(format: "%d:%02d", m, r)
    }
}
