import SwiftUI

struct SplitLibraryCard: View {
    let split: WorkoutSplit
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(split.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 24)

                HStack(spacing: 6) {
                    Text(split.category.rawValue)
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(categoryColor.opacity(0.12))
                        .clipShape(Capsule())
                    Text("\(split.daysPerWeek)d")
                        .font(.caption2)
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
            .frame(width: 160, alignment: .topLeading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                HapticManager.impact(.light)
                onFavoriteTap()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 13))
                    .foregroundStyle(isFavorite ? Color.red : Color.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
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
