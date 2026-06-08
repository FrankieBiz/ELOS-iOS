import Foundation

struct ProfileResponse: Decodable {
    let user_id: String
    let first_name: String?
    let last_name: String?
    let height_cm: Double?
    let weight_kg: Double?
    let age_years: Int?
    let training_experience: String?
    let training_goal: String?
    let school_name: String?
    let school_year: String?
    let cal_goal: Int?
    let protein_goal: Int?
    let carb_goal: Int?
    let fat_goal: Int?
    let use_imperial: Bool?
    let onboarding_complete: Bool?
}
