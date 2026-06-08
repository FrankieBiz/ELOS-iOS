import Foundation

/// Shared display helpers for the user-shaped response models (feed authors,
/// friends, leaderboard entries, search results). Conformers supply the raw
/// name/username/avatar fields; the defaults derive the presentation.
protocol NamedUser {
    var first_name: String { get }
    var last_name: String { get }
    var usernameOrNil: String? { get }
    var avatarColorOrNil: String? { get }
}

extension NamedUser {
    var displayName: String {
        let full = "\(first_name) \(last_name)".trimmingCharacters(in: .whitespaces)
        if !full.isEmpty { return full }
        if let u = usernameOrNil, !u.isEmpty { return "@\(u)" }
        return "Unknown"
    }

    var initials: String {
        let f = first_name.first.map(String.init) ?? ""
        let l = last_name.first.map(String.init) ?? ""
        let combo = (f + l).uppercased()
        return combo.isEmpty ? "?" : combo
    }

    var avatarHex: String {
        if let c = avatarColorOrNil, !c.isEmpty { return c }
        return "#6C47FF"
    }
}

// MARK: - Conformances

extension FeedAuthor: NamedUser {
    var usernameOrNil: String? { username.isEmpty ? nil : username }
    var avatarColorOrNil: String? { avatar_color }
}

extension FriendProfileResponse: NamedUser {
    var usernameOrNil: String? { username }
    var avatarColorOrNil: String? { avatar_color }
}

extension LeaderboardEntryResponse: NamedUser {
    var usernameOrNil: String? { username }
    var avatarColorOrNil: String? { avatar_color }
}

extension UserSearchResultResponse: NamedUser {
    var usernameOrNil: String? { username }
    var avatarColorOrNil: String? { avatar_color }
}
