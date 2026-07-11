import Foundation

// Wire models for /community/splits (see elos-shared CommunitySplit*).

struct CommunitySplitDayResponse: Decodable, Hashable {
    let order_index: Int
    let day_label: String
    let day_name: String
    let template_id: String
    let is_rest: Bool
    let exercises_json: String
}

struct CommunitySplitAuthorResponse: Decodable, Hashable {
    let user_id: String
    let username: String
    let first_name: String
    let last_name: String
    let avatar_color: String

    var displayName: String {
        let full = "\(first_name) \(last_name)".trimmingCharacters(in: .whitespaces)
        if !username.isEmpty { return "@\(username)" }
        return full.isEmpty ? "Elos member" : full
    }

    /// First letter for the avatar circle (skips the "@" of a username handle).
    var avatarInitial: String {
        let base = username.isEmpty
            ? "\(first_name) \(last_name)".trimmingCharacters(in: .whitespaces)
            : username
        return (base.isEmpty ? "E" : String(base.prefix(1))).uppercased()
    }
}

struct CommunitySplitResponse: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let days: [CommunitySplitDayResponse]
    var imports_count: Int
    let created_at: String
    let is_mine: Bool
    let author: CommunitySplitAuthorResponse
}

struct CommunitySplitPageResponse: Decodable {
    let splits: [CommunitySplitResponse]
    let next_cursor: String?
}
