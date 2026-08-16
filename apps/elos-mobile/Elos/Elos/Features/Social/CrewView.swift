import SwiftUI
import SwiftData

struct CrewView: View {
    @EnvironmentObject private var socialVM: SocialViewModel
    @EnvironmentObject private var vm: AppViewModel
    @EnvironmentObject private var feedVM: FeedViewModel

    @State private var tab = 0
    @State private var showSearch = false
    @State private var friendPendingRemove: FriendProfileResponse?
    @State private var splitShared = false
    @State private var emptyStatePulse = false
    @Environment(\.dismiss) private var dismiss

    private var inviteURL: URL? {
        let userId = vm.currentUserID
        guard !userId.isEmpty else { return nil }
        return URL(string: "elos://add-friend?userId=\(userId)")
    }

    private var inviteMessage: String {
        // This text lands in someone else's messages app, so it's the app's most externally visible
        // copy. The flex emoji and exclamation made it read like an ad the user didn't write.
        if let uname = vm.userProfile?.username, !uname.isEmpty {
            return "Add me on Elos — @\(uname)"
        }
        return "Join my crew on Elos"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Feed").tag(0)
                    Text("Friends").tag(1)
                    Text("Leaderboard").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                switch tab {
                case 0:  FeedView()
                case 1:  friendsTab
                default: LeaderboardView()
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
                    if tab == 1 {
                        HStack(spacing: 16) {
                            if let serverID = vm.activeSplit?.serverID, !serverID.isEmpty {
                                Button {
                                    HapticManager.success()
                                    Task {
                                        let ok = await feedVM.shareSplit(serverID: serverID)
                                        if ok { splitShared = true }
                                    }
                                } label: {
                                    Image(systemName: splitShared ? "checkmark.circle.fill" : "calendar.badge.plus")
                                        .foregroundStyle(splitShared ? Color.good : Color.tint)
                                }
                                .accessibilityLabel("Share my split to crew feed")
                                .disabled(splitShared)
                            }
                            if let url = inviteURL {
                                ShareLink(item: url, message: Text(inviteMessage)) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .accessibilityLabel("Share invite link")
                            }
                            Button {
                                showSearch = true
                            } label: {
                                Image(systemName: "person.badge.plus")
                            }
                            .accessibilityLabel("Search for friends")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                FriendSearchView()
                    .environmentObject(socialVM)
                    .environmentObject(vm)
            }
            .confirmationDialog(
                "Remove friend?",
                isPresented: Binding(
                    get: { friendPendingRemove != nil },
                    set: { if !$0 { friendPendingRemove = nil } }
                ),
                presenting: friendPendingRemove
            ) { friend in
                Button("Remove", role: .destructive) {
                    HapticManager.warning()
                    Task { await socialVM.remove(friendshipId: friend.friendship_id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { friend in
                Text("\(friend.displayName) will be removed from your crew.")
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
                if !socialVM.sentRequests.isEmpty {
                    sentSection
                }
                if socialVM.friends.isEmpty && socialVM.pendingRequests.isEmpty && socialVM.sentRequests.isEmpty {
                    emptyState
                } else if !socialVM.friends.isEmpty {
                    friendsSection
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .refreshable { await socialVM.load(ownerID: vm.currentUserID) }
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
                        HapticManager.success()
                        Task { await socialVM.accept(friendshipId: req.friendship_id) }
                    }
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.tint)
                    .clipShape(Capsule())

                    Button("Decline") {
                        HapticManager.impact(.light)
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

    private var sentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sent")
                .font(.subheadline).fontWeight(.semibold)
                .padding(.horizontal, 4)
            ForEach(socialVM.sentRequests) { req in
                HStack(spacing: 12) {
                    AvatarCircle(initials: req.initials, hex: req.avatarHex, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(req.displayName).font(.subheadline).fontWeight(.semibold)
                        if let uname = req.username {
                            Text("@\(uname)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("Pending")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
                .padding(12)
                .elosCard()
                .contextMenu {
                    Button(role: .destructive) {
                        HapticManager.impact(.light)
                        Task { await socialVM.cancelSentRequest(friendshipId: req.friendship_id) }
                    } label: {
                        Label("Cancel Request", systemImage: "xmark.circle")
                    }
                }
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
                    Menu {
                        Button(role: .destructive) {
                            friendPendingRemove = friend
                        } label: {
                            Label("Remove from Crew", systemImage: "person.fill.xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Friend options")
                    NavigationLink {
                        FriendProfileView(userId: friend.user_id, displayName: friend.displayName)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("View profile")
                }
                .padding(12)
                .elosCard()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .nonRepeating, value: emptyStatePulse)
                .onAppear { emptyStatePulse.toggle() }
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
