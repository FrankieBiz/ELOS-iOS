import SwiftUI

struct FeedView: View {
    /// Decorative empty/error glyph. Deliberately a fixed 40 at the default text size — it's an
    /// illustration, not body copy — but scaled so it doesn't stay put while the message beside it grows.
    @ScaledMetric(relativeTo: .largeTitle) private var emptyStateGlyph: CGFloat = 40

    @EnvironmentObject private var feedVM: FeedViewModel
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if feedVM.posts.isEmpty && feedVM.loadFailed {
                    errorState
                } else if feedVM.posts.isEmpty && feedVM.hasLoadedOnce {
                    emptyState
                } else {
                    ForEach(feedVM.posts) { post in
                        FeedPostCard(post: post)
                            .onAppear {
                                if post.id == feedVM.posts.last?.id, feedVM.hasMore {
                                    Task { await feedVM.loadMore() }
                                }
                            }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .refreshable { await feedVM.load() }
        .task {
            if !feedVM.hasLoadedOnce { await feedVM.load() }
        }
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: emptyStateGlyph))
                .foregroundStyle(.secondary)
            Text("Couldn't load your feed")
                .font(.headline)
            Text("Check your connection and try again.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await feedVM.load() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: emptyStateGlyph))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)
            Text("Nothing here yet")
                .font(.headline)
            Text("Add friends and share a workout, PR, or split to start your feed.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .elosCard()
    }
}

// MARK: - Post card

struct FeedPostCard: View {
    let post: FeedPostResponse
    @EnvironmentObject private var feedVM: FeedViewModel
    @EnvironmentObject private var vm: AppViewModel
    @State private var imported = false
    @State private var showReportDialog = false
    @State private var showReportConfirm = false
    @State private var showBlockConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            ReactionBar(post: post)
        }
        .padding(14)
        .elosCard()
        .confirmationDialog("Report this post?", isPresented: $showReportDialog, titleVisibility: .visible) {
            ForEach(["spam", "harassment", "inappropriate", "other"], id: \.self) { category in
                Button(category.capitalized) {
                    Task {
                        if await feedVM.reportPost(post, category: category) {
                            showReportConfirm = true
                        } else {
                            vm.showError("Couldn't submit report. Please try again.")
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Report Submitted", isPresented: $showReportConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thank you. Our team will review this report.")
        }
        .confirmationDialog("Block \(post.author.displayName)?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task {
                    if !(await feedVM.blockAuthor(post)) {
                        vm.showError("Couldn't block this user. Please try again.")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see their posts and they won't be able to see yours.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            AvatarCircle(initials: post.author.initials, hex: post.author.avatarHex, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(post.author.displayName).font(.subheadline).fontWeight(.semibold)
                Text(headerSubtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if post.is_mine {
                Menu {
                    Button(role: .destructive) {
                        Task { await feedVM.deletePost(post) }
                    } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Post options")
            } else {
                Menu {
                    Button {
                        showReportDialog = true
                    } label: { Label("Report Post", systemImage: "flag") }
                    Button(role: .destructive) {
                        Task { await feedVM.blockAuthor(post) }
                    } label: { Label("Block \(post.author.displayName)", systemImage: "hand.raised") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Post options")
            }
        }
    }

    private var headerSubtitle: String {
        let kindLabel: String
        switch post.kind {
        case "workout": kindLabel = "shared a workout"
        case "pr":      kindLabel = "hit a PR"
        case "split":   kindLabel = "shared a split"
        default:        kindLabel = "posted"
        }
        let t = post.relativeTime
        return t.isEmpty ? kindLabel : "\(kindLabel) · \(t)"
    }

    @ViewBuilder
    private var content: some View {
        switch post.kind {
        case "workout": WorkoutPostContent(payload: post.payload)
        case "pr":      PrPostContent(payload: post.payload)
        case "split":   splitContent
        default:        EmptyView()
        }
    }

    private var splitContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SplitPostContent(payload: post.payload)
            if !post.is_mine {
                Button {
                    Task {
                        if await feedVM.importSplit(post: post) {
                            imported = true
                            await vm.syncSplitsFromServer()
                        }
                    }
                } label: {
                    Label(imported ? "Imported" : "Import Split",
                          systemImage: imported ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(imported ? Color.secondary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(imported ? Color(.tertiarySystemBackground) : Color.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(imported)
            }
        }
    }
}

// MARK: - Reaction bar

struct ReactionBar: View {
    let post: FeedPostResponse
    @EnvironmentObject private var feedVM: FeedViewModel

    var body: some View {
        HStack(spacing: Space.s) {
            ForEach(feedReactionEmojis, id: \.self) { emoji in
                let count = post.reactionCount(emoji)
                let mine = post.my_reaction == emoji
                Button {
                    Task { await feedVM.toggleReaction(post: post, emoji: emoji) }
                } label: {
                    HStack(spacing: 4) {
                        // Drawn as an SF Symbol, not the stored emoji: emoji were the one piece of
                        // iconography left in the app that came from a different visual system, and
                        // they can't take the tint that marks *your* reaction.
                        Image(systemName: FeedReactionStyle.symbol(for: emoji))
                            .font(.elosCaption)
                            .foregroundStyle(mine ? Color.tint : Color.secondary)
                            .symbolVariant(mine ? .fill : .none)
                        if count > 0 {
                            Text("\(count)")
                                .font(.elosNumeric(.caption2, weight: .semibold))
                                .foregroundStyle(mine ? Color.tint : .secondary)
                        }
                    }
                    .frame(minWidth: 24)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(mine ? Color.tintSoft : Color(.tertiarySystemBackground))
                    .overlay {
                        Capsule().strokeBorder(mine ? Color.tint.opacity(0.35) : .clear, lineWidth: 1)
                    }
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                // An emoji announces as "fire" / "flexed biceps", which tells a VoiceOver user nothing
                // about what the button does. Name the reaction and its state instead.
                .accessibilityLabel(FeedReactionStyle.name(for: emoji))
                .accessibilityValue(count > 0 ? "\(count)" : "none")
                .accessibilityAddTraits(mine ? [.isSelected] : [])
            }
            Spacer()
        }
    }
}

// MARK: - Content blocks

struct WorkoutPostContent: View {
    @EnvironmentObject private var appVM: AppViewModel
    let payload: FeedPayload

    private var volumeString: String {
        appVM.weightUnit.formatVolume(kg: payload.volume_kg ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                stat("\(payload.duration_min ?? 0)m", "Duration")
                divider
                stat(volumeString, "Volume")
                divider
                stat("\(payload.total_sets ?? 0)", "Sets")
                divider
                stat("\(payload.unique_exercises ?? 0)", "Exercises")
            }
            if let top = payload.top_lift {
                badge(icon: "flame.fill", color: Color.tint,
                      text: "Top Lift · \(top.name)",
                      trailing: "\(appVM.weightUnit.formatWeight(kg: top.weight_kg, decimals: 0)) × \(top.reps)")
            }
            if let pr = payload.pr {
                badge(icon: "trophy.fill", color: .yellow, text: "PR · \(pr)", trailing: nil)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Color(.separator).opacity(0.4)).frame(width: 1, height: 30)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.elosNumeric(.headline))
            Text(label).font(.elosMicro).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func badge(icon: String, color: Color, text: String, trailing: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.elosCaption).foregroundStyle(color)
            Text(text).font(.system(.footnote, weight: .medium)).lineLimit(1)
            Spacer()
            if let trailing {
                Text(trailing).font(.elosNumeric(.footnote))
            }
        }
    }
}

struct PrPostContent: View {
    @EnvironmentObject private var appVM: AppViewModel
    let payload: FeedPayload

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title3).foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(payload.exercise_name ?? "Personal Record")
                    .font(.system(.callout, weight: .bold))
                Text("\(appVM.weightUnit.formatWeight(kg: payload.weight_kg ?? 0, decimals: 0)) × \(payload.reps ?? 0)")
                    .font(.elosNumeric(.footnote, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 1) {
                Text(appVM.weightUnit.formatValue(kg: payload.e1rm ?? 0, decimals: 0))
                    .font(.elosNumeric(.title3))
                    .foregroundStyle(Color.tint)
                Text("e1RM").font(.elosMicro).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SplitPostContent: View {
    let payload: FeedPayload

    private var trainingDays: [FeedSplitDay] {
        (payload.days ?? []).filter { !$0.is_rest }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.elosBody).foregroundStyle(Color.tint)
                Text(payload.name ?? "Split")
                    .font(.system(.callout, weight: .bold))
                Spacer()
                Text(trainingDays.count.pluralized("day"))
                    .font(.system(.caption, weight: .medium)).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(trainingDays) { day in
                        Text(day.day_name)
                            .font(.system(.caption2, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
}
