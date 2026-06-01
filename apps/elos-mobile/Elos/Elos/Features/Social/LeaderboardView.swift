import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var socialVM: SocialViewModel
    @State private var showCrew = false

    private let metrics = ["volume", "sessions", "streak", "prs"]
    private let metricLabels = ["Volume", "Sessions", "Streak", "PRs"]

    var body: some View {
        VStack(spacing: 0) {
            metricPicker
            if socialVM.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if socialVM.weeklyBoard.isEmpty {
                emptyState
            } else {
                leaderboardList
            }
        }
        .task { await socialVM.loadBoard() }
        .onChange(of: socialVM.selectedMetric) { _, _ in
            Task { await socialVM.loadBoard() }
        }
    }

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(zip(metrics, metricLabels)), id: \.0) { metric, label in
                    Button {
                        socialVM.selectedMetric = metric
                    } label: {
                        Text(label)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(socialVM.selectedMetric == metric ? .white : Color.tint)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(socialVM.selectedMetric == metric ? Color.tint : Color.tint.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var leaderboardList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !socialVM.boardWeekStart.isEmpty {
                    Text(weekRangeLabel(from: socialVM.boardWeekStart))
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)
                }
                ForEach(socialVM.weeklyBoard) { entry in
                    LeaderboardRow(entry: entry, metric: socialVM.selectedMetric)
                        .background(entry.is_self ? Color.tint.opacity(0.07) : Color.clear)
                    Divider().padding(.leading, 56)
                }
            }
            .elosCard()
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No data yet")
                .font(.headline)
            Text("Add friends to see the weekly leaderboard")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func weekRangeLabel(from isoDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: isoDate) else { return "" }
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return "\(display.string(from: start))–\(display.string(from: end))"
    }
}

private struct LeaderboardRow: View {
    let entry: LeaderboardEntryResponse
    let metric: String

    private var rankIcon: String? {
        switch entry.rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = rankIcon {
                Text(icon).font(.title3).frame(width: 32)
            } else {
                Text("#\(entry.rank)")
                    .font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                    .frame(width: 32)
            }
            AvatarCircle(initials: entry.initials, hex: entry.avatarHex, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline).fontWeight(entry.is_self ? .bold : .regular)
                if entry.is_self {
                    Text("You").font(.caption2).foregroundStyle(Color.tint)
                }
            }
            Spacer()
            Text(formattedValue(entry.value, metric: metric))
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(entry.rank == 1 ? Color.tint : .primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func formattedValue(_ value: Double, metric: String) -> String {
        switch metric {
        case "volume":   return String(format: "%.0f kg", value)
        case "sessions": return "\(Int(value))"
        case "streak":   return "\(Int(value))d"
        case "prs":      return "\(Int(value)) PRs"
        default:         return "\(Int(value))"
        }
    }
}
