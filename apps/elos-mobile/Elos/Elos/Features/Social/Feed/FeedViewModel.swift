import SwiftUI
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [FeedPostResponse] = []
    @Published var isLoading = false
    @Published var hasLoadedOnce = false
    @Published var loadFailed = false
    @Published private(set) var nextCursor: String?

    /// Whether finishing a workout posts it to the feed, and whether we've asked yet.
    ///
    /// Written through `didSet` so the choice survives relaunch; see `FeedAutoShare` for why this
    /// is three states rather than a `Bool`.
    @Published var autoShare: FeedAutoShare {
        didSet { defaults.set(autoShare.rawValue, forKey: Self.autoShareKey) }
    }

    private static let autoShareKey = "elos.feed.autoShare"
    private let defaults: UserDefaults

    /// When the feed was last fetched in full, for `refreshIfStale()`.
    private var lastLoadedAt: Date?
    private static let staleAfter: TimeInterval = 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoShare = defaults.string(forKey: Self.autoShareKey)
            .flatMap(FeedAutoShare.init(rawValue:)) ?? .unasked
    }

    var hasMore: Bool { nextCursor != nil }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false; hasLoadedOnce = true }
        do {
            let page: FeedPageResponse = try await ApiClient.shared.get("/feed")
            posts = page.posts
            nextCursor = page.next_cursor
            loadFailed = false
            lastLoadedAt = Date()
        } catch {
            // Distinguish a failed load from a genuinely empty feed.
            loadFailed = posts.isEmpty
        }
    }

    /// Re-fetch when returning to the tab on a feed that's gone stale.
    ///
    /// The first load is `FeedView`'s job — this only refreshes something already on screen, so
    /// switching tabs doesn't wipe the feed back to a spinner every time.
    func refreshIfStale() async {
        guard hasLoadedOnce, !isLoading else { return }
        guard let last = lastLoadedAt, Date().timeIntervalSince(last) > Self.staleAfter else { return }
        await load()
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoading else { return }
        let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
        do {
            let page: FeedPageResponse = try await ApiClient.shared.get("/feed?cursor=\(encoded)")
            posts.append(contentsOf: page.posts)
            nextCursor = page.next_cursor
        } catch {}
    }

    // MARK: - Reactions (optimistic)

    func toggleReaction(post: FeedPostResponse, emoji: String) async {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let current = posts[idx].my_reaction

        struct Ok: Decodable { let ok: Bool }
        if current == emoji {
            applyReaction(at: idx, from: emoji, to: nil)
            HapticManager.impact(.light)
            _ = try? await ApiClient.shared.delete("/feed/\(post.id)/react") as Ok
        } else {
            applyReaction(at: idx, from: current, to: emoji)
            HapticManager.impact(.light)
            struct ReactRequest: Encodable { let emoji: String }
            _ = try? await ApiClient.shared.put("/feed/\(post.id)/react", body: ReactRequest(emoji: emoji)) as Ok
        }
    }

    private func applyReaction(at idx: Int, from old: String?, to new: String?) {
        var reactions = posts[idx].reactions
        if let old { reactions = decrement(reactions, old) }
        if let new { reactions = increment(reactions, new) }
        posts[idx].reactions = reactions
        posts[idx].my_reaction = new
    }

    // Internal (not private) so the optimistic reaction math is unit-testable.
    func increment(_ list: [FeedReaction], _ emoji: String) -> [FeedReaction] {
        var copy = list
        if let i = copy.firstIndex(where: { $0.emoji == emoji }) {
            copy[i] = FeedReaction(emoji: emoji, count: copy[i].count + 1)
        } else {
            copy.append(FeedReaction(emoji: emoji, count: 1))
        }
        return copy
    }

    func decrement(_ list: [FeedReaction], _ emoji: String) -> [FeedReaction] {
        var copy = list
        if let i = copy.firstIndex(where: { $0.emoji == emoji }) {
            let newCount = copy[i].count - 1
            if newCount <= 0 { copy.remove(at: i) }
            else { copy[i] = FeedReaction(emoji: emoji, count: newCount) }
        }
        return copy
    }

    // MARK: - Delete own post

    func deletePost(_ post: FeedPostResponse) async {
        posts.removeAll { $0.id == post.id }
        try? await ApiClient.shared.deleteNoContent("/feed/\(post.id)")
    }

    // MARK: - Moderation (Guideline 1.2)

    func reportPost(_ post: FeedPostResponse, category: String) async -> Bool {
        struct Body: Encodable { let reportedId: String; let category: String; let note: String? }
        struct Ok: Decodable { let ok: Bool }
        do {
            _ = try await ApiClient.shared.post(
                "/social/report",
                body: Body(reportedId: post.author.user_id, category: category, note: nil)
            ) as Ok
            return true
        } catch {
            return false
        }
    }

    /// Block the author and, on success, immediately remove all of their posts from the feed.
    func blockAuthor(_ post: FeedPostResponse) async -> Bool {
        struct Body: Encodable { let blockedId: String }
        struct Ok: Decodable { let ok: Bool }
        let authorID = post.author.user_id
        do {
            _ = try await ApiClient.shared.post("/social/block", body: Body(blockedId: authorID)) as Ok
            posts.removeAll { $0.author.user_id == authorID }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Sharing (returns true on success)

    /// Returns the created post so the caller can undo it — auto-share needs a handle on what it
    /// just published, which a `Bool` can't give it.
    @discardableResult
    func shareWorkout(date: String, durationMin: Int, volumeKg: Double, totalSets: Int,
                       uniqueExercises: Int, topLift: FeedTopLift?, pr: String?,
                       silent: Bool = false) async -> FeedPostResponse? {
        struct TopLiftRequest: Encodable { let name: String; let weight_kg: Double; let reps: Int }
        struct Payload: Encodable {
            let date: String
            let duration_min: Int
            let volume_kg: Double
            let total_sets: Int
            let unique_exercises: Int
            let top_lift: TopLiftRequest?
            let pr: String?
        }
        struct Request: Encodable { let kind = "workout"; let payload: Payload }
        let topReq = topLift.map { TopLiftRequest(name: $0.name, weight_kg: $0.weight_kg, reps: $0.reps) }
        let req = Request(payload: Payload(
            date: date, duration_min: durationMin, volume_kg: volumeKg,
            total_sets: totalSets, unique_exercises: uniqueExercises, top_lift: topReq, pr: pr))
        return await createPost(req, silent: silent)
    }

    @discardableResult
    func sharePR(exerciseName: String, weightKg: Double, reps: Int, e1rm: Double) async -> Bool {
        struct Payload: Encodable { let exercise_name: String; let weight_kg: Double; let reps: Int; let e1rm: Double }
        struct Request: Encodable { let kind = "pr"; let payload: Payload }
        let req = Request(payload: Payload(exercise_name: exerciseName, weight_kg: weightKg, reps: reps, e1rm: e1rm))
        return await createPost(req) != nil
    }

    @discardableResult
    func shareSplit(serverID: String) async -> Bool {
        guard !serverID.isEmpty else { return false }
        struct Empty: Encodable {}
        do {
            let post: FeedPostResponse = try await ApiClient.shared.post("/feed/split/\(serverID)", body: Empty())
            posts.insert(post, at: 0)
            HapticManager.success()
            return true
        } catch {
            return false
        }
    }

    /// `silent` suppresses the success haptic. An auto-shared workout posts without anyone
    /// pressing anything, and a celebratory buzz for an action the lifter didn't take reads as
    /// the app twitching.
    private func createPost(_ body: some Encodable, silent: Bool = false) async -> FeedPostResponse? {
        do {
            let post: FeedPostResponse = try await ApiClient.shared.post("/feed", body: body)
            posts.insert(post, at: 0)
            if !silent { HapticManager.success() }
            return post
        } catch {
            return nil
        }
    }

    // MARK: - Import split (caller triggers split sync afterward)

    @discardableResult
    func importSplit(post: FeedPostResponse) async -> Bool {
        struct Empty: Encodable {}
        do {
            let _: UserSplitResponse = try await ApiClient.shared.post("/feed/\(post.id)/import", body: Empty())
            HapticManager.success()
            return true
        } catch {
            return false
        }
    }
}
