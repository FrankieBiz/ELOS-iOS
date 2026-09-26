import SwiftUI

/// The Feed tab.
///
/// Deliberately thin — the feed itself is still `FeedView`, unchanged from when it lived inside
/// `CrewView`'s segmented control. What changed is the framing. The feed used to be one of three
/// modes inside a sheet you could only reach from a button on Train or Me, which is exactly how
/// Discover went unnoticed; now it owns a screen, and Friends and Leaderboard sit behind the
/// toolbar instead of competing with it for the top of the view.
struct FeedTabView: View {
    @EnvironmentObject private var vm: AppViewModel
    @EnvironmentObject private var socialVM: SocialViewModel
    @EnvironmentObject private var feedVM: FeedViewModel

    @State private var showCrew = false
    @State private var splitShared = false

    /// Only offered when the active split has actually synced. A local-only split has no server
    /// id to point a post at, so the button would fail every time it was pressed.
    private var shareableSplitID: String? {
        guard let id = vm.activeSplit?.serverID, !id.isEmpty else { return nil }
        return id
    }

    var body: some View {
        NavigationStack {
            FeedView()
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Feed")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 18) {
                            if let serverID = shareableSplitID {
                                Button {
                                    HapticManager.success()
                                    Task {
                                        if await feedVM.shareSplit(serverID: serverID) {
                                            splitShared = true
                                        } else {
                                            vm.showError("Couldn't share your split. Please try again.")
                                        }
                                    }
                                } label: {
                                    Image(systemName: splitShared ? "checkmark.circle.fill" : "calendar.badge.plus")
                                        .foregroundStyle(splitShared ? Color.good : Color.tint)
                                }
                                .disabled(splitShared)
                                .accessibilityLabel("Share my split to the feed")
                            }

                            Button {
                                showCrew = true
                            } label: {
                                Image(systemName: "person.2")
                            }
                            .accessibilityLabel("Friends and leaderboard")
                        }
                    }
                }
        }
        .sheet(isPresented: $showCrew) {
            CrewView()
                .environmentObject(socialVM)
                .environmentObject(vm)
                .environmentObject(feedVM)
        }
        .task {
            // A feed you walked back to shouldn't still be showing what it loaded an hour ago.
            await feedVM.refreshIfStale()
        }
    }
}
