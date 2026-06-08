import Foundation

/// Fixed reaction set, mirrors FEED_REACTION_EMOJIS in elos-shared.
let feedReactionEmojis = ["🔥", "💪", "👏", "🎯", "👀"]

struct FeedAuthor: Decodable {
    let user_id: String
    let username: String
    let first_name: String
    let last_name: String
    let avatar_color: String
    // displayName / initials / avatarHex come from the NamedUser protocol.
}

struct FeedReaction: Decodable, Identifiable {
    var id: String { emoji }
    let emoji: String
    let count: Int
}

struct FeedTopLift: Decodable {
    let name: String
    let weight_kg: Double
    let reps: Int
}

struct FeedSplitDay: Decodable, Identifiable {
    var id: String { "\(order_index)-\(day_name)" }
    let order_index: Int
    let day_label: String
    let day_name: String
    let template_id: String
    let is_rest: Bool
    let exercises_json: String
}

/// Flattened payload: every field across the three post kinds is uniquely named,
/// so one struct with optionals decodes all of them.
struct FeedPayload: Decodable {
    // workout
    let date: String?
    let duration_min: Int?
    let volume_kg: Double?
    let total_sets: Int?
    let unique_exercises: Int?
    let top_lift: FeedTopLift?
    let pr: String?
    // pr
    let exercise_name: String?
    let weight_kg: Double?
    let reps: Int?
    let e1rm: Double?
    // split
    let name: String?
    let days: [FeedSplitDay]?
}

struct FeedPostResponse: Decodable, Identifiable {
    let id: String
    let kind: String
    let created_at: String
    let author: FeedAuthor
    let is_mine: Bool
    let payload: FeedPayload
    var reactions: [FeedReaction]
    var my_reaction: String?

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var relativeTime: String {
        guard let date = FeedDateParser.parse(created_at) else { return "" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    func reactionCount(_ emoji: String) -> Int {
        reactions.first { $0.emoji == emoji }?.count ?? 0
    }
}

struct FeedPageResponse: Decodable {
    let posts: [FeedPostResponse]
    let next_cursor: String?
}

/// Parses Postgres `timestamptz::text` ("2026-06-06 12:01:26.123456+00") and ISO8601.
enum FeedDateParser {
    private static let formatters: [DateFormatter] = {
        ["yyyy-MM-dd HH:mm:ss.SSSSSSxxx",
         "yyyy-MM-dd HH:mm:ssxxx",
         "yyyy-MM-dd HH:mm:ss.SSSSSSZ",
         "yyyy-MM-dd HH:mm:ssZ"].map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            return f
        }
    }()

    static func parse(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        for f in formatters {
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
