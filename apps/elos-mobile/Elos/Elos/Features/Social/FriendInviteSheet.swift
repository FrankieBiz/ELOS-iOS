import SwiftUI

struct FriendInviteSheet: View {
    let inviterUserId: String
    @EnvironmentObject private var socialVM: SocialViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var profile: PublicProfileResponse?
    @State private var isLoading = true
    @State private var requestSent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                if isLoading {
                    ProgressView()
                } else {
                    AvatarCircle(
                        initials: profile?.initials ?? "?",
                        hex: profile?.avatarHex ?? "#6C47FF",
                        size: 80
                    )

                    VStack(spacing: 6) {
                        Text("\(profile?.displayName ?? "Someone") wants to be your training partner")
                            .font(.title3).fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        if let uname = profile?.username {
                            Text("@\(uname)").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text("You'll compete on the weekly leaderboard and see each other's training stats.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)

                    if requestSent {
                        Label("Friend request sent!", systemImage: "checkmark.circle.fill")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.good)
                    } else {
                        Button {
                            HapticManager.success()
                            Task {
                                await socialVM.sendRequest(to: inviterUserId)
                                requestSent = true
                                try? await Task.sleep(for: .milliseconds(900))
                                dismiss()
                            }
                        } label: {
                            Text("Send Friend Request")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.tint)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 24)
                    }

                    Button("Maybe Later") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Friend Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Dismiss") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            profile = await socialVM.lookupPublicProfile(userId: inviterUserId)
            isLoading = false
        }
    }
}
