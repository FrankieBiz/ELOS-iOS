import Foundation
import Combine
import SwiftData

struct ProfileUpdateBody: Codable {
    var first_name: String?
    var last_name: String?
    var username: String?
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
    var use_imperial: Bool?
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step = 0
    let totalSteps = 6

    // Step 1 — Name & username
    @Published var firstName = ""
    @Published var lastName  = ""
    @Published var username  = ""
    @Published var usernameStatus: UsernameStatus = .empty
    private var usernameCheckTask: Task<Void, Never>?

    enum UsernameStatus: Equatable {
        case empty, checking, available, taken, invalid, unknown
    }

    // Step 2 — Body Metrics
    @Published var heightFeet   = 5
    @Published var heightInches = 10
    @Published var weightLbs: Double = 160
    @Published var ageYears  = 17
    @Published var useImperial = WeightUnit.localeDefault.useImperial

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
        // A valid format is required; if the server can't be reached to confirm
        // availability (.unknown), don't hard-block — the unique DB constraint is
        // the authoritative guard at save time.
        case 1: return !firstName.isEmpty && (usernameStatus == .available || usernameStatus == .unknown)
        default: return true
        }
    }

    // MARK: - Username validation & availability

    static func isValidUsername(_ s: String) -> Bool {
        s.range(of: "^[a-z][a-z0-9_]{2,19}$", options: .regularExpression) != nil
    }

    /// Called from the username field. Normalizes (lowercase, strip @/space),
    /// validates format, then debounces a live availability check.
    func onUsernameChanged(_ raw: String) {
        let normalized = raw.lowercased()
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespaces)
        if normalized != username { username = normalized; return } // re-enters with clean value

        usernameCheckTask?.cancel()
        guard !normalized.isEmpty else { usernameStatus = .empty; return }
        guard Self.isValidUsername(normalized) else { usernameStatus = .invalid; return }

        usernameStatus = .checking
        usernameCheckTask = Task { [normalized] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let available = await Self.checkAvailability(normalized)
            guard !Task.isCancelled, self.username == normalized else { return }
            switch available {
            case .some(true):  self.usernameStatus = .available
            case .some(false): self.usernameStatus = .taken
            case .none:        self.usernameStatus = .unknown   // couldn't reach the server
            }
        }
    }

    /// Returns true/false when the server answers; nil when it couldn't be reached
    /// (so callers can degrade gracefully instead of treating it as "taken").
    static func checkAvailability(_ u: String) async -> Bool? {
        struct Resp: Decodable { let available: Bool }
        let encoded = u.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? u
        let resp: Resp? = try? await ApiClient.shared.get("/profile/username-available?u=\(encoded)")
        return resp?.available
    }

    var heightCm: Double {
        if useImperial {
            return Double(heightFeet * 12 + heightInches) * 2.54
        }
        return Double(heightFeet * 100 + heightInches) // treated as cm when metric
    }

    var weightKg: Double {
        useImperial ? weightLbs * WeightUnit.kgPerLb : weightLbs
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
            username:            username.isEmpty ? nil : username,
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
            onboarding_complete: true,
            use_imperial:        useImperial
        )

        var networkSucceeded = false
        do {
            let _: ProfileResponse = try await ApiClient.shared.patch("/profile", body: body)
            networkSucceeded = true
        } catch {
            // Proceed even if network fails — syncPending will trigger retry on next launch
        }

        let userID = authStore.currentUserID
        // Upsert: update an existing profile row if one already exists (e.g. created by
        // syncProfileFromServer) instead of inserting a duplicate.
        let existingDesc = FetchDescriptor<UserProfileRecord>(
            predicate: #Predicate { $0.ownerID == userID }
        )
        let record = (try? context.fetch(existingDesc).first)
            ?? {
                let r = UserProfileRecord(id: userID, ownerID: userID, email: "")
                context.insert(r)
                return r
            }()
        record.firstName          = firstName
        record.lastName           = lastName
        record.username           = username
        record.heightCm           = heightCm
        record.weightKg           = weightKg
        record.ageYears           = ageYears
        record.trainingExperience = experience
        record.trainingGoal       = trainingGoal
        record.schoolName         = schoolName
        record.schoolYear         = schoolYear
        record.calGoal            = calGoal
        record.proteinGoal        = proteinGoal
        record.carbGoal           = carbGoal
        record.fatGoal            = fatGoal
        record.onboardingComplete = true
        record.syncPending        = !networkSucceeded
        record.useImperial        = useImperial
        try? context.save()

        authStore.markOnboardingComplete()
    }
}
