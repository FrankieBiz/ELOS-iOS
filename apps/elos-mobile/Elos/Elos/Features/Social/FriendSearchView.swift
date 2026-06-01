import SwiftUI

struct FriendSearchView: View {
    @EnvironmentObject private var socialVM: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [UserSearchResultResponse] = []
    @State private var isSearching = false
    @State private var sentRequestIDs = Set<String>()

    var body: some View {
        NavigationView {
            Group {
                if results.isEmpty && query.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("Search by name or username")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty && !query.isEmpty && !isSearching {
                    VStack(spacing: 12) {
                        Text("No results for \"\(query)\"")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { user in
                        UserSearchResultRow(
                            user: user,
                            hasSentRequest: sentRequestIDs.contains(user.user_id)
                        ) {
                            Task {
                                await socialVM.sendRequest(to: user.user_id)
                                sentRequestIDs.insert(user.user_id)
                            }
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $query, prompt: "Name or username")
            .onChange(of: query) { _, newValue in
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard query == newValue else { return }
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
    let onAdd: () -> Void

    private var effectiveStatus: String {
        hasSentRequest ? "pending_sent" : user.friendship_status
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarCircle(initials: user.initials, hex: user.avatarHex, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline).fontWeight(.semibold)
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
