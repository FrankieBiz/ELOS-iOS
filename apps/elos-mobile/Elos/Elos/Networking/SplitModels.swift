import Foundation

struct UserSplitResponse: Decodable {
    let id: String
    let name: String
    let library_key: String
    let is_active: Bool
    let created_at: String
    let days: [UserSplitDayResponse]
}

struct UserSplitDayResponse: Decodable {
    let id: String
    let split_id: String
    let order_index: Int
    let day_label: String
    let day_name: String
    let template_id: String
    let is_rest: Bool
    let exercises_json: String
}

struct SplitConflictResponse: Decodable {
    let conflict: Bool
    let existing_id: String
}
