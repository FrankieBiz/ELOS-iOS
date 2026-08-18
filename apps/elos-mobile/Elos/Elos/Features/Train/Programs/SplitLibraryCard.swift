import SwiftUI

struct SplitLibraryCard: View {
    let split: WorkoutSplit
    let isFavorite: Bool
    /// Hidden when the card already sits inside a section titled with its category — the badge was
    /// pure repetition there, and at 160pt it truncated to "Olympia/Body…" / "Sport Perform…" while
    /// squeezing the title that actually distinguishes one program from another.
    var showsCategory: Bool = true
    let onFavoriteTap: () -> Void

    /// Scaled: a flat 160 truncated nearly every title, so "Jeff Nippard Fundamentals (3d)" and its
    /// 4-day sibling rendered as two identical-looking cards.
    @ScaledMetric(relativeTo: .subheadline) private var cardWidth: CGFloat = 168

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(split.title)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 24)

                HStack(spacing: 6) {
                    if showsCategory {
                        Text(split.category.rawValue)
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(categoryColor)
                            .lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(categoryColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text("\(split.daysPerWeek)d")
                        .font(.elosMicro)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }

                if !split.goals.isEmpty {
                    Text(split.goals.prefix(3).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(width: cardWidth, alignment: .topLeading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                HapticManager.impact(.light)
                onFavoriteTap()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.footnote)
                    .foregroundStyle(isFavorite ? Color.red : Color.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle favourite")
        }
    }

    private var categoryColor: Color {
        switch split.category {
        case .foundation:          return .tint
        case .creatorInspired:     return .orange
        case .olympiaBodybuilding: return .purple
        case .sportPerformance:    return .green
        case .homeMinimal:         return .brown
        case .specialization:      return .pink
        }
    }
}
