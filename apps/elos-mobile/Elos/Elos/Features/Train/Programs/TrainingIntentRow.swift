import SwiftUI

/// The "what are you building?" control. Two chips — focus and goal — that make the coach's targets
/// explicit instead of guessed from the day name.
///
/// `focus` is optional: `nil` means "let it work that out from the name", which is exactly the
/// pre-intent behaviour, so this never becomes a required step.
struct TrainingIntentRow: View {
    @Binding var intent: TrainingIntent
    /// Shown as the auto option's subtitle, e.g. the day name we'd infer from.
    var inferredFocus: SplitArchetype? = nil
    /// Weekly scope has no single focus — show only the goal chip.
    var showsFocus: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if showsFocus { focusChip }
            goalChip
            Spacer(minLength: 0)
        }
    }

    // MARK: Focus

    private var focusChip: some View {
        Menu {
            Button {
                intent.focus = nil
            } label: {
                Label(inferredFocus.map { "Automatic (\($0.displayName))" } ?? "Automatic",
                      systemImage: "wand.and.stars")
            }
            Divider()
            ForEach(SplitArchetype.allCases, id: \.self) { f in
                Button {
                    intent.focus = f
                } label: {
                    Label(f.displayName, systemImage: f.icon)
                }
            }
        } label: {
            chip(icon: resolvedFocus?.icon ?? "wand.and.stars",
                 text: resolvedFocus?.displayName ?? "Any focus",
                 isSet: intent.focus != nil)
        }
        .accessibilityLabel("Session focus")
        .accessibilityValue(resolvedFocus?.displayName ?? "Automatic")
    }

    private var resolvedFocus: SplitArchetype? { intent.focus ?? inferredFocus }

    // MARK: Goal

    private var goalChip: some View {
        Menu {
            ForEach(LiftingGoal.allCases, id: \.self) { g in
                Button { intent.goal = g } label: { Text(g.pickerLabel) }
            }
        } label: {
            chip(icon: "target", text: intent.goal.pickerLabel, isSet: true)
        }
        .accessibilityLabel("Training goal")
        .accessibilityValue(intent.goal.pickerLabel)
    }

    // MARK: Chip

    private func chip(icon: String, text: String, isSet: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(isSet ? Color.tint : Color.secondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(isSet ? Color.tintSoft : Color(.tertiarySystemGroupedBackground))
        .overlay(Capsule().stroke(isSet ? Color.tint.opacity(0.25) : .clear, lineWidth: 1))
        .clipShape(Capsule())
    }
}
