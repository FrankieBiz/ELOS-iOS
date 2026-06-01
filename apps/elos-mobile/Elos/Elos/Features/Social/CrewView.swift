import SwiftUI
import SwiftData

struct CrewView: View {
    @EnvironmentObject private var socialVM: SocialViewModel
    @EnvironmentObject private var vm: AppViewModel

    @State private var tab = 0
    @State private var showSearch = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Friends").tag(0)
                    Text("Leaderboard").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if tab == 0 {
                    friendsTab
                } else {
                    LeaderboardView()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if tab == 0 {
                        Button {
                            showSearch = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                FriendSearchView()
                    .environmentObject(socialVM)
            }
        }
        .task {
            let uid = vm.currentUserID
            if !uid.isEmpty {
                await socialVM.load(ownerID: uid)
            }
        }
    }

    @ViewBuilder
    private var friendsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !socialVM.pendingRequests.isEmpty {
                    pendingSection
                }
                if socialVM.friends.isEmpty && socialVM.pendingRequests.isEmpty {
                    emptyState
                } else if !socialVM.friends.isEmpty {
                    friendsSection
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Requests")
                .font(.subheadline).fontWeight(.semibold)
                .padding(.horizontal, 4)
            ForEach(socialVM.pendingRequests) { req in
                HStack(spacing: 12) {
                    AvatarCircle(initials: req.initials, hex: req.avatarHex, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(req.displayName).font(.subheadline).fontWeight(.semibold)
                        if let uname = req.username {
                            Text("@\(uname)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Accept") {
                        Task { await socialVM.accept(friendshipId: req.friendship_id) }
                    }
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.tint)
                    .clipShape(Capsule())

                    Button("Decline") {
                        Task { await socialVM.decline(friendshipId: req.friendship_id) }
                    }
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
                }
                .padding(12)
                .elosCard()
            }
        }
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Friends · \(socialVM.friends.count)")
                .font(.subheadline).fontWeight(.semibold)
                .padding(.horizontal, 4)
            ForEach(socialVM.friends) { friend in
                HStack(spacing: 12) {
                    AvatarCircle(initials: friend.initials, hex: friend.avatarHex, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.displayName).font(.subheadline).fontWeight(.semibold)
                        if let uname = friend.username {
                            Text("@\(uname)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    NavigationLink {
                        FriendProfileView(userId: friend.user_id, displayName: friend.displayName)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .elosCard()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await socialVM.remove(friendshipId: friend.friendship_id) }
                    } label: {
                        Label("Remove", systemImage: "person.fill.xmark")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No friends yet")
                .font(.headline)
            Text("Search for people to compete with each week")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showSearch = true
            } label: {
                Label("Find Friends", systemImage: "person.badge.plus")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.tint)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .elosCard()
    }
}
