import SwiftUI

/// A glanceable, one-tap RPE picker that replaces the cramped typed RPE field. Stores the value
/// back into the `WorkSet.rpe` string so nothing downstream changes. Tapping the selected value
/// again clears it. Feeds the fatigue-aware overload engine that's currently starved of RPE data.
struct RPEEffortLadder: View {
    @Binding var rpe: String

    private var selected: Double? { RPEScale.parse(rpe) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(RPEScale.values, id: \.self) { value in
                        let isSelected = selected == value
                        Button {
                            rpe = isSelected ? "" : RPEScale.label(value)
                            HapticManager.selection()
                        } label: {
                            Text(RPEScale.label(value))
                                .font(.elosNumeric(.subheadline, weight: .semibold))
                                .frame(minWidth: 36, minHeight: 34)
                                .background(isSelected ? Color.tint : Color(.tertiarySystemBackground))
                                .foregroundStyle(isSelected ? .white : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
            if let s = selected {
                Text("RPE \(RPEScale.label(s)) · \(RPEScale.hint(for: s))")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Tap to rate effort (RPE)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}
