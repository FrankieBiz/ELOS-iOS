import SwiftUI

private struct FriendStatsResponse: Codable {
    let user_id: String
    let first_name: String
    let last_name: String
    let username: String?
    let avatar_color: String?
    let weekly_volume: Double
    let weekly_sessions: Int
    let current_streak: Int
    let top_prs: [PREntry]

    struct PREntry: Codable, Identifiable {
        var id: String { exercise_name }
        let exercise_name: String
        let e1rm: Double
        let best_weight: Double
        let best_reps: Int
    }
}

struct FriendProfileView: View {
    let userId: String
    let displayName: String

    @State private var stats: FriendStatsResponse?
    @State private var isLoading = false

    private var initials: String {
        guard let s = stats else { return "?" }
        let f = s.first_name.first.map(String.init) ?? ""
        let l = s.last_name.first.map(String.init) ?? ""
        return (f + l).uppercased().isEmpty ? "?" : (f + l).uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if let s = stats {
                    headerSection(s)
                    statsGrid(s)
                    if !s.top_prs.isEmpty {
                        prsCard(s.top_prs)
                    }
                } else {
                    Text("Could not load profile.").foregroundStyle(.secondary).padding(.top, 40)
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStats() }
    }

    private func loadStats() async {
        isLoading = true
        defer { isLoading = false }
        stats = try? await ApiClient.shared.get("/social/friends/\(userId)/stats") as FriendStatsResponse
    }

    private func headerSection(_ s: FriendStatsResponse) -> some View {
        VStack(spacing: 10) {
            AvatarCircle(
                initials: initials,
                hex: s.avatar_color ?? "#6C47FF",
                size: 80
            )
            Text("\(s.first_name) \(s.last_name)".trimmingCharacters(in: .whitespaces))
                .font(.title3).fontWeight(.bold)
            if let uname = s.username {
                Text("@\(uname)").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .elosCard()
    }

    private func statsGrid(_ s: FriendStatsResponse) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCell(label: "Weekly Volume", value: String(format: "%.0f kg", s.weekly_volume), icon: "scalemass")
            statCell(label: "Sessions", value: "\(s.weekly_sessions) this week", icon: "calendar")
            statCell(label: "Streak", value: "\(s.current_streak) days", icon: "flame")
            statCell(label: "Top Lift", value: s.top_prs.first.map { $0.exercise_name } ?? "—", icon: "trophy")
        }
    }

    private func statCell(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption).foregroundStyle(Color.tint)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(value).font(.subheadline).fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .elosCard()
    }

    private func prsCard(_ prs: [FriendStatsResponse.PREntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Lifts").font(.subheadline).fontWeight(.semibold)
            ForEach(prs) { pr in
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Color.tint).font(.caption)
                    Text(pr.exercise_name).font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f kg e1RM", pr.e1rm))
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .elosCard()
    }
}
