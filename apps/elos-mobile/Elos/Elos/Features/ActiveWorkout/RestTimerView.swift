import SwiftUI

/// Sticky rest bar pinned to the bottom of the active session (via `safeAreaInset`) so it never
/// scrolls away. Color-coded countdown, ±15s adjust, pause/resume, skip, and a next-set preview.
struct RestTimerBar: View {
    let seconds: Int
    let totalSeconds: Int
    let paused: Bool
    let nextLabel: String?
    let onMinus: () -> Void
    let onPlus: () -> Void
    let onPauseToggle: () -> Void
    let onSkip: () -> Void

    private var formatted: String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
    private var color: Color { seconds > 45 ? .good : seconds > 15 ? .warn : .bad }
    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, Double(seconds) / Double(totalSeconds)))
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 3).frame(width: 30, height: 30)
                Circle().trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 30, height: 30)
                Image(systemName: paused ? "pause.fill" : "timer")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(formatted)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text(nextLabel.map { "Next: \($0)" } ?? "Resting")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer()

            stepButton("−15", action: onMinus)
            Button(action: onPauseToggle) {
                Image(systemName: paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(Color(.tertiarySystemBackground))
                    .foregroundStyle(.secondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            stepButton("+15", action: onPlus)

            Button(action: onSkip) {
                Text("Skip").font(.caption).fontWeight(.semibold).foregroundStyle(Color.tint)
                    .padding(.horizontal, 10).padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 12).padding(.bottom, 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 42, height: 34)
                .background(Color(.tertiarySystemBackground))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// Brief confirmation toast with a one-tap undo, shown after a set is logged so an accidental
/// completion is trivially reversible.
struct UndoSnackbar: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.good)
            Text(message).font(.subheadline).foregroundStyle(.white)
            Spacer()
            Button("Undo", action: onUndo)
                .font(.subheadline).fontWeight(.bold).foregroundStyle(Color.tint)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.black.opacity(0.85))
        .clipShape(Capsule())
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
