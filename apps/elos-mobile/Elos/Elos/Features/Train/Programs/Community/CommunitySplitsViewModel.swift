import SwiftUI
import Combine

@MainActor
final class CommunitySplitsViewModel: ObservableObject {
    @Published var splits: [CommunitySplitResponse] = []
    @Published var isLoading = false
    @Published var hasLoadedOnce = false
    @Published var loadFailed = false
    @Published private(set) var nextCursor: String?
    /// source user_split serverIDs the caller has already published (publish-state UI)
    @Published private(set) var importedIDs: Set<String> = []

    var hasMore: Bool { nextCursor != nil }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false; hasLoadedOnce = true }
        do {
            let page: CommunitySplitPageResponse = try await ApiClient.shared.get("/community/splits")
            splits = page.splits
            nextCursor = page.next_cursor
            loadFailed = false
        } catch {
            loadFailed = splits.isEmpty
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoading else { return }
        let encoded = cursor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cursor
        do {
            let page: CommunitySplitPageResponse = try await ApiClient.shared.get("/community/splits?cursor=\(encoded)")
            splits.append(contentsOf: page.splits)
            nextCursor = page.next_cursor
        } catch {}
    }

    // MARK: - Publish / unpublish

    @discardableResult
    func publish(serverID: String, description: String) async -> Bool {
        guard !serverID.isEmpty else { return false }
        struct Request: Encodable { let split_id: String; let description: String }
        do {
            let published: CommunitySplitResponse = try await ApiClient.shared.post(
                "/community/splits",
                body: Request(split_id: serverID, description: description)
            )
            // Replace any previous listing for the same source split, then prepend.
            splits.removeAll { $0.id == published.id }
            splits.insert(published, at: 0)
            HapticManager.success()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func unpublish(_ split: CommunitySplitResponse) async -> Bool {
        do {
            try await ApiClient.shared.deleteNoContent("/community/splits/\(split.id)")
            splits.removeAll { $0.id == split.id }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Import (caller triggers split sync afterward)

    @discardableResult
    func importSplit(_ split: CommunitySplitResponse) async -> Bool {
        struct Empty: Encodable {}
        do {
            let _: UserSplitResponse = try await ApiClient.shared.post(
                "/community/splits/\(split.id)/import", body: Empty()
            )
            importedIDs.insert(split.id)
            if let idx = splits.firstIndex(where: { $0.id == split.id }) {
                splits[idx].imports_count += 1
            }
            HapticManager.success()
            return true
        } catch {
            return false
        }
    }
}
