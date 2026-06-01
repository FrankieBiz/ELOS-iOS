import SwiftUI
import SwiftData
import Combine

// MARK: - Response types

struct FriendProfileResponse: Codable, Identifiable {
    var id: String { friendship_id }
    let friendship_id: String
    let user_id: String
    let username: String?
    let first_name: String
    let last_name: String
    let avatar_color: String?
    let status: String
    let is_requester: Bool

    var displayName: String {
        let full = "\(first_name) \(last_name)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (username.map { "@\($0)" } ?? "Unknown") : full
    }

    var initials: String {
        let f = first_name.first.map(String.init) ?? ""
        let l = last_name.first.map(String.init) ?? ""
        let combo = (f + l).uppercased()
        return combo.isEmpty ? "?" : combo
    }

    var avatarHex: String { avatar_color ?? "#6C47FF" }
}

struct LeaderboardEntryResponse: Codable, Identifiable {
    var id: String { "\(rank)-\(user_id)" }
    let rank: Int
    let user_id: String
    let username: String?
    let first_name: String
    let last_name: String
    let avatar_color: String?
    let value: Double
    let is_self: Bool

    var displayName: String {
        let full = "\(first_name) \(last_name)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (username.map { "@\($0)" } ?? "Unknown") : full
    }

    var initials: String {
        let f = first_name.first.map(String.init) ?? ""
        let l = last_name.first.map(String.init) ?? ""
        let combo = (f + l).uppercased()
        return combo.isEmpty ? "?" : combo
    }

    var avatarHex: String { avatar_color ?? "#6C47FF" }
}

struct WeeklyLeaderboardResponse: Codable {
    let metric: String
    let week_start: String
    let entries: [LeaderboardEntryResponse]
    let my_rank: Int
    let my_value: Double
}

struct MyStandingsResponse: Codable {
    struct MetricStanding: Codable {
        let rank: Int
        let value: Double
    }
    let week_start: String
    let total_friends: Int
    let volume: MetricStanding
    let sessions: MetricStanding
    let streak: MetricStanding
    let prs: MetricStanding
}

struct UserSearchResultResponse: Codable, Identifiable {
    var id: String { user_id }
    let user_id: String
    let username: String?
    let first_name: String
    let last_name: String
    let avatar_color: String?
    let friendship_status: String

    var displayName: String {
        let full = "\(first_name) \(last_name)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (username.map { "@\($0)" } ?? "Unknown") : full
    }

    var initials: String {
        let f = first_name.first.map(String.init) ?? ""
        let l = last_name.first.map(String.init) ?? ""
        let combo = (f + l).uppercased()
        return combo.isEmpty ? "?" : combo
    }

    var avatarHex: String { avatar_color ?? "#6C47FF" }
}

private struct FriendsListResponse: Codable { let friends: [FriendProfileResponse] }
private struct RequestsListResponse: Codable { let requests: [FriendProfileResponse] }
private struct SearchResponse: Codable { let users: [UserSearchResultResponse] }
private struct OkResponse: Codable { let ok: Bool }

// MARK: - ViewModel

@MainActor
class SocialViewModel: ObservableObject {
    private let context: ModelContext

    @Published var friends: [FriendProfileResponse] = []
    @Published var pendingRequests: [FriendProfileResponse] = []
    @Published var weeklyBoard: [LeaderboardEntryResponse] = []
    @Published var selectedMetric = "volume"
    @Published var standings: MyStandingsResponse?
    @Published var isLoading = false
    @Published var boardWeekStart = ""
    @Published var boardMyRank = 0
    @Published var boardMyValue: Double = 0

    init(context: ModelContext) {
        self.context = context
    }

    func load(ownerID: String) async {
        async let f: Void = syncFriends()
        async let r: Void = syncRequests()
        await f
        await r
    }

    func syncFriends() async {
        do {
            let resp: FriendsListResponse = try await ApiClient.shared.get("/social/friends")
            friends = resp.friends
        } catch {}
    }

    func syncRequests() async {
        do {
            let resp: RequestsListResponse = try await ApiClient.shared.get("/social/friends/requests")
            pendingRequests = resp.requests
        } catch {}
    }

    func loadBoard() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp: WeeklyLeaderboardResponse = try await ApiClient.shared.get("/leaderboard/weekly?metric=\(selectedMetric)")
            weeklyBoard = resp.entries
            boardWeekStart = resp.week_start
            boardMyRank = resp.my_rank
            boardMyValue = resp.my_value
        } catch {}
    }

    func loadStandings() async {
        do {
            let resp: MyStandingsResponse = try await ApiClient.shared.get("/leaderboard/standings")
            standings = resp
        } catch {}
    }

    func sendRequest(to addresseeId: String) async {
        struct Body: Encodable { let addresseeId: String }
        _ = try? await ApiClient.shared.post("/social/friends/request", body: Body(addresseeId: addresseeId)) as OkResponse
    }

    func accept(friendshipId: String) async {
        struct Empty: Codable {}
        _ = try? await ApiClient.shared.patch("/social/friends/\(friendshipId)/accept", body: Empty()) as OkResponse
        await syncFriends()
        await syncRequests()
    }

    func decline(friendshipId: String) async {
        struct Empty: Codable {}
        _ = try? await ApiClient.shared.patch("/social/friends/\(friendshipId)/decline", body: Empty()) as OkResponse
        await syncRequests()
    }

    func remove(friendshipId: String) async {
        _ = try? await ApiClient.shared.delete("/social/friends/\(friendshipId)") as OkResponse
        friends.removeAll { $0.friendship_id == friendshipId }
    }

    func search(query: String) async -> [UserSearchResultResponse] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        do {
            let resp: SearchResponse = try await ApiClient.shared.get("/social/search?q=\(encoded)")
            return resp.users
        } catch {
            return []
        }
    }

    func formattedValue(_ value: Double, metric: String) -> String {
        switch metric {
        case "volume":   return String(format: "%.0f kg", value)
        case "sessions": return "\(Int(value)) sessions"
        case "streak":   return "\(Int(value)) days"
        case "prs":      return "\(Int(value)) PRs"
        default:         return "\(Int(value))"
        }
    }
}
