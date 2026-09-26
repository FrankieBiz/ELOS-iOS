import SwiftUI

struct FriendSearchView: View {
    @EnvironmentObject private var socialVM: SocialViewModel
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [UserSearchResultResponse] = []
    @State private var isSearching = false
    @State private var sentRequestIDs = Set<String>()
    @State private var acceptedIDs    = Set<String>()
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            Group {
                if results.isEmpty && query.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Find friends by their @username or full name")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty && !query.isEmpty && !isSearching {
                    VStack(spacing: 12) {
                        Text("No one found for \"\(query)\" — try a different name")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { user in
                        UserSearchResultRow(
                            user: user,
                            hasSentRequest: sentRequestIDs.contains(user.user_id),
                            hasAccepted:    acceptedIDs.contains(user.user_id)
                        ) {
                            Task {
                                // Only reflect success (insert + haptic) once the request actually lands.
                                if user.friendship_status == "pending_received",
                                   let fid = user.friendship_id {
                                    if await socialVM.accept(friendshipId: fid) {
                                        acceptedIDs.insert(user.user_id)
                                        HapticManager.success()
                                    } else {
                                        vm.showError("Couldn't accept the request. Please try again.")
                                    }
                                } else {
                                    if await socialVM.sendRequest(to: user.user_id) {
                                        sentRequestIDs.insert(user.user_id)
                                        HapticManager.success()
                                    } else {
                                        vm.showError("Couldn't send the request. Please try again.")
                                    }
                                }
                            }
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $query, prompt: "Search @username or name")
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    results = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    isSearching = true
                    results = await socialVM.search(query: newValue)
                    isSearching = false
                }
            }
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isSearching {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

private struct UserSearchResultRow: View {
    let user: UserSearchResultResponse
    let hasSentRequest: Bool
    let hasAccepted: Bool
    let onAdd: () -> Void

    private var effectiveStatus: String {
        if hasAccepted { return "accepted" }
        if hasSentRequest { return "pending_sent" }
        return user.friendship_status
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(initials: user.initials, hex: user.avatarHex, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                if let uname = user.username {
                    Text("@\(uname)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            actionButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch effectiveStatus {
        case "accepted":
            Label("Friends", systemImage: "checkmark")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
        case "pending_sent":
            Text("Sent ✓")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
        case "pending_received":
            Button("Accept") { onAdd() }
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.good)
                .clipShape(Capsule())
        default:
            Button("Add") { onAdd() }
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.tint)
                .clipShape(Capsule())
        }
    }
}
