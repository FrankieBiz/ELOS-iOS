import SwiftUI

/// The "what are you building?" control. Chips that make the coach's targets explicit instead of
/// guessed from the day name.
///
/// `focus` is optional: `nil` means "let it work that out from the name", which is exactly the
/// pre-intent behaviour, so this never becomes a required step. `excludedMuscles` is opt-in the same
/// way: an empty set means every scoring dimension behaves exactly as before this feature shipped.
struct TrainingIntentRow: View {
    @Binding var intent: TrainingIntent
    /// Shown as the auto option's subtitle, e.g. the day name we'd infer from.
    var inferredFocus: SplitArchetype? = nil
    /// Weekly scope has no single focus — show only the goal chip.
    var showsFocus: Bool = true
    /// The weekly split panel binds this row to the split-wide `TrainingIntent`, whose
    /// `excludedMuscles` the engine ignores at `.weeklySplit` scope (see
    /// `TemplateQualityEngine.score`) — the chip is hidden there too, so there's no control on
    /// screen that would silently do nothing. Per-day exclusion in that context is a separate
    /// per-day binding, not this row's `intent`.
    var showsSkip: Bool = true

    @State private var showingSkipSheet = false

    var body: some View {
        // Two/three chips side by side until the labels no longer fit, then stacked. Squeezed onto
        // one row at larger text sizes they truncated to "Any f…" and "Muscl…" — a control whose
        // entire job is to state the current focus and goal, unable to state either.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s) {
                if showsFocus { focusChip }
                goalChip
                if showsSkip { skipChip }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: Space.s) {
                if showsFocus { focusChip }
                goalChip
                if showsSkip { skipChip }
            }
        }
        .sheet(isPresented: $showingSkipSheet) {
            SkipMusclesSheet(selection: $intent.excludedMuscles)
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

    // MARK: Skip muscles

    private var skipChip: some View {
        Button {
            showingSkipSheet = true
        } label: {
            chip(icon: "eye.slash",
                 text: intent.excludedMuscles.isEmpty ? "Skip muscles" : "Skip (\(intent.excludedMuscles.count))",
                 isSet: !intent.excludedMuscles.isEmpty)
        }
        .accessibilityLabel("Skip muscles")
        .accessibilityValue(intent.excludedMuscles.isEmpty ? "None" : "\(intent.excludedMuscles.count) selected")
    }

    // MARK: Chip

    private func chip(icon: String, text: String, isSet: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(.caption2, weight: .semibold))
            Text(text)
                .font(.system(.caption, weight: .semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        // The chip sizes to its label; the row above decides whether both fit on one line.
        .fixedSize()
        .foregroundStyle(isSet ? Color.tint : Color.secondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(isSet ? Color.tintSoft : Color(.tertiarySystemGroupedBackground))
        .overlay(Capsule().stroke(isSet ? Color.tint.opacity(0.25) : .clear, lineWidth: 1))
        .clipShape(Capsule())
    }
}
