import Foundation
import Combine
import SwiftData

struct ProfileUpdateBody: Codable {
    var first_name: String?
    var last_name: String?
    var height_cm: Double?
    var weight_kg: Double?
    var age_years: Int?
    var training_experience: String?
    var training_goal: String?
    var school_name: String?
    var school_year: String?
    var cal_goal: Int?
    var protein_goal: Int?
    var carb_goal: Int?
    var fat_goal: Int?
    var onboarding_complete: Bool?
}

final class OnboardingViewModel: ObservableObject {
    @Published var step = 0
    let totalSteps = 6

    // Step 1 — Name
    @Published var firstName = ""
    @Published var lastName  = ""

    // Step 2 — Body Metrics
    @Published var heightFeet   = 5
    @Published var heightInches = 10
    @Published var weightLbs: Double = 160
    @Published var ageYears  = 17
    @Published var useImperial = true

    // Step 3 — Experience & Goal
    @Published var experience   = "beginner"
    @Published var trainingGoal = "hypertrophy"

    // Step 4 — School & Nutrition
    @Published var schoolName   = ""
    @Published var schoolYear   = "sophomore"
    @Published var calGoal      = 2500
    @Published var proteinGoal  = 180
    @Published var carbGoal     = 300
    @Published var fatGoal      = 80
    @Published var useAutoCalc  = true

    // State
    @Published var isLoading     = false
    @Published var errorMessage: String?

    var canAdvance: Bool {
        switch step {
        case 1: return !firstName.isEmpty
        default: return true
        }
    }

    var heightCm: Double {
        if useImperial {
            return Double(heightFeet * 12 + heightInches) * 2.54
        }
        return Double(heightFeet * 100 + heightInches) // treated as cm when metric
    }

    var weightKg: Double {
        useImperial ? weightLbs * 0.453592 : weightLbs
    }

    var autoCalcCalories: Int {
        let wKg = weightKg
        let hCm = heightCm
        let age = Double(ageYears)
        // Mifflin–St Jeor (male estimate)
        let bmr = 10 * wKg + 6.25 * hCm - 5 * age + 5
        let tdee = bmr * 1.5
        switch trainingGoal {
        case "weight_loss":  return Int(tdee * 0.85)
        case "strength":     return Int(tdee * 1.1)
        case "hypertrophy":  return Int(tdee * 1.1)
        default:             return Int(tdee)
        }
    }

    var autoCalcProtein: Int { Int(weightKg * 2.0) }
    var autoCalcCarbs: Int {
        let remaining = autoCalcCalories - autoCalcProtein * 4 - autoCalcFat * 9
        return max(100, remaining / 4)
    }
    var autoCalcFat: Int { Int(weightKg * 1.0) }

    func applyAutoCalc() {
        calGoal     = autoCalcCalories
        proteinGoal = autoCalcProtein
        carbGoal    = autoCalcCarbs
        fatGoal     = autoCalcFat
    }

    func completeOnboarding(context: ModelContext, authStore: AuthStore) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }

        if useAutoCalc { applyAutoCalc() }

        let body = ProfileUpdateBody(
            first_name:          firstName,
            last_name:           lastName,
            height_cm:           heightCm,
            weight_kg:           weightKg,
            age_years:           ageYears,
            training_experience: experience,
            training_goal:       trainingGoal,
            school_name:         schoolName,
            school_year:         schoolYear,
            cal_goal:            calGoal,
            protein_goal:        proteinGoal,
            carb_goal:           carbGoal,
            fat_goal:            fatGoal,
            onboarding_complete: true
        )

        do {
            let _: ProfileUpdateBody = try await ApiClient.shared.patch("/profile", body: body)
        } catch {
            // Proceed even if network fails — record locally
        }

        let userID = authStore.currentUserID
        let profileRecord = UserProfileRecord(
            id: userID,
            ownerID: userID,
            email: "",
            firstName: firstName,
            lastName: lastName,
            heightCm: heightCm,
            weightKg: weightKg,
            ageYears: ageYears,
            trainingExperience: experience,
            trainingGoal: trainingGoal,
            schoolName: schoolName,
            schoolYear: schoolYear,
            calGoal: calGoal,
            proteinGoal: proteinGoal,
            carbGoal: carbGoal,
            fatGoal: fatGoal,
            onboardingComplete: true
        )
        context.insert(profileRecord)
        try? context.save()

        authStore.markOnboardingComplete()
    }
}
