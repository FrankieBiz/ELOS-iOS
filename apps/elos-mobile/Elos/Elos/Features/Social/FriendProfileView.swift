import SwiftUI
import Combine

struct FriendStatsResponse: Codable {
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

@MainActor
final class FriendProfileViewModel: ObservableObject {
    @Published var stats: FriendStatsResponse?
    @Published var isLoading = false

    func loadStats(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        stats = try? await ApiClient.shared.get("/social/friends/\(userId)/stats") as FriendStatsResponse
    }
}

struct FriendProfileView: View {
    let userId: String
    let displayName: String

    @EnvironmentObject private var socialVM: SocialViewModel
    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var feedVM: FeedViewModel
    @StateObject private var profileVM = FriendProfileViewModel()
    @State private var showingReportSheet = false
    @State private var reportCategory = "other"
    @State private var reportNote = ""
    @State private var showingReportConfirmation = false
    @State private var showingBlockConfirm = false
    @State private var splitShared = false
    @Environment(\.dismiss) private var dismiss

    private var initials: String {
        guard let s = profileVM.stats else { return "?" }
        let f = s.first_name.first.map(String.init) ?? ""
        let l = s.last_name.first.map(String.init) ?? ""
        return (f + l).uppercased().isEmpty ? "?" : (f + l).uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if profileVM.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if let s = profileVM.stats {
                    headerSection(s)
                    statsGrid(s)
                    if !s.top_prs.isEmpty {
                        prsCard(s.top_prs)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Could not load profile.").foregroundStyle(.secondary)
                        Button("Retry") { Task { await profileVM.loadStats(userId: userId) } }
                            .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.tint)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await profileVM.loadStats(userId: userId) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let serverID = appVM.activeSplit?.serverID, !serverID.isEmpty {
                        Button {
                            HapticManager.success()
                            Task {
                                let ok = await feedVM.shareSplit(serverID: serverID)
                                if ok { splitShared = true }
                            }
                        } label: {
                            Label(
                                splitShared ? "Split Shared to Feed" : "Share my split",
                                systemImage: splitShared ? "checkmark.circle" : "calendar.badge.plus"
                            )
                        }
                        .disabled(splitShared)
                        Divider()
                    }
                    Button {
                        showingReportSheet = true
                    } label: {
                        Label("Report User", systemImage: "flag")
                    }
                    Button(role: .destructive) {
                        showingBlockConfirm = true
                    } label: {
                        Label("Block User", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .accessibilityLabel("More options")
                }
            }
        }
        .sheet(isPresented: $showingReportSheet) {
            reportSheet
        }
        .alert("Report Submitted", isPresented: $showingReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thank you. Our team will review this report.")
        }
        .confirmationDialog("Block \(displayName)?", isPresented: $showingBlockConfirm, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task {
                    if await socialVM.blockUser(userId) { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They'll be removed from your crew and won't see each other's posts or be able to add you.")
        }
    }

    private var reportSheet: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Category", selection: $reportCategory) {
                        Text("Spam").tag("spam")
                        Text("Harassment").tag("harassment")
                        Text("Inappropriate").tag("inappropriate")
                        Text("Other").tag("other")
                    }
                }
                Section("Additional Info (optional)") {
                    TextField("Tell us more…", text: $reportNote, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingReportSheet = false }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        let cat = reportCategory
                        let note = reportNote.isEmpty ? nil : reportNote
                        showingReportSheet = false
                        Task {
                            let ok = await socialVM.reportUser(reportedId: userId, category: cat, note: note)
                            if ok { showingReportConfirmation = true }
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.tint)
                }
            }
        }
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
            statCell(label: "Weekly Volume", value: appVM.weightUnit.formatVolume(kg: s.weekly_volume), icon: "scalemass")
            statCell(label: "Sessions", value: "\(s.weekly_sessions) this week", icon: "calendar")
            statCell(label: "Streak", value: s.current_streak.pluralized("day"), icon: "flame")
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
