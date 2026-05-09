import SwiftUI
import Observation

// MARK: - App-level observable state

@Observable
final class AppState {

    // MARK: Profile
    var displayName: String = "" { didSet { save() } }
    var bodyweightKg: Double = 75 { didSet { save() } }
    var heightCm: Double = 178 { didSet { save() } }
    var experience: Experience = .intermediate { didSet { save() } }

    // MARK: Preferences
    var themeMode: ThemeMode = .vigil { didSet { save() } }
    var units: WeightUnit = .imperial { didSet { save() } }
    var defaultRestSeconds: Int = 90 { didSet { save() } }
    var hapticsEnabled: Bool = true { didSet { save() } }
    var soundsEnabled: Bool = true { didSet { save() } }
    var healthKitEnabled: Bool = false { didSet { save() } }

    // MARK: Program
    var activeProgramId: String = "ppl_default" { didSet { save() } }
    var programStartDate: Date = .now { didSet { save() } }

    // MARK: Smart Load — recommended weight per exercise (kg) based on user feedback
    var recommendedWeightsKg: [String: Double] = [:] { didSet { save() } }

    // MARK: Active workout (transient, in-memory)
    var activeWorkout: ActiveWorkout? = nil
    var isWorkoutActive: Bool { activeWorkout != nil }

    // MARK: Onboarding
    var hasCompletedOnboarding: Bool = false { didSet { save() } }

    // MARK: Streak
    var lastWorkoutDateKey: String = "" { didSet { save() } }
    var currentStreak: Int = 0 { didSet { save() } }
    var longestStreak: Int = 0 { didSet { save() } }

    // MARK: Plate setup (kg pairs available in gym)
    var availablePlatesKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25] { didSet { save() } }
    var barWeightKg: Double = 20 { didSet { save() } }

    var colorScheme: ColorScheme { themeMode.colorScheme }

    init() { load() }

    // MARK: - Streak management

    /// Call after a workout is finished — bumps the streak if needed.
    func registerCompletedWorkout(on date: Date = .now) {
        let today = date.dayKey
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)?.dayKey ?? ""

        if lastWorkoutDateKey == today { return }            // already counted today
        if lastWorkoutDateKey == yesterday {                  // continue streak
            currentStreak += 1
        } else if lastWorkoutDateKey.isEmpty {                // first ever workout
            currentStreak = 1
        } else {                                              // streak broken
            currentStreak = 1
        }
        lastWorkoutDateKey = today
        if currentStreak > longestStreak { longestStreak = currentStreak }
    }

    /// Called when re-entering the app — if the user missed yesterday, the streak is over.
    func touchStreakOnLaunch(now: Date = .now) {
        guard !lastWorkoutDateKey.isEmpty else { return }
        let today = now.dayKey
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)?.dayKey ?? ""
        if lastWorkoutDateKey != today && lastWorkoutDateKey != yesterday {
            currentStreak = 0
        }
    }

    // MARK: - Smart Load

    func recordDifficulty(_ d: LoadDifficulty, exerciseName: String, lastWeightKg: Double) {
        let bump = 2.5
        let next: Double
        switch d {
        case .tooEasy:   next = lastWeightKg + bump * 2
        case .justRight: next = lastWeightKg + bump
        case .tooHard:   next = max(lastWeightKg - bump, bump)
        }
        recommendedWeightsKg[exerciseName] = next
    }

    // MARK: Persistence (UserDefaults — small, plain keys)

    private let d = UserDefaults.standard

    private func save() {
        d.set(displayName,         forKey: "displayName")
        d.set(bodyweightKg,        forKey: "bodyweightKg")
        d.set(heightCm,            forKey: "heightCm")
        d.set(experience.rawValue, forKey: "experience")
        d.set(themeMode.rawValue,  forKey: "themeMode")
        d.set(units.rawValue,      forKey: "units")
        d.set(defaultRestSeconds,  forKey: "defaultRestSeconds")
        d.set(hapticsEnabled,      forKey: "hapticsEnabled")
        d.set(soundsEnabled,       forKey: "soundsEnabled")
        d.set(healthKitEnabled,    forKey: "healthKitEnabled")
        d.set(activeProgramId,     forKey: "activeProgramId")
        d.set(programStartDate,    forKey: "programStartDate")
        d.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        d.set(lastWorkoutDateKey,  forKey: "lastWorkoutDateKey")
        d.set(currentStreak,       forKey: "currentStreak")
        d.set(longestStreak,       forKey: "longestStreak")
        d.set(barWeightKg,         forKey: "barWeightKg")

        if let data = try? JSONEncoder().encode(recommendedWeightsKg) {
            d.set(data, forKey: "recommendedWeightsKg")
        }
        if let data = try? JSONEncoder().encode(availablePlatesKg) {
            d.set(data, forKey: "availablePlatesKg")
        }
    }

    private func load() {
        displayName       = d.string(forKey: "displayName") ?? ""
        bodyweightKg      = d.double(forKey: "bodyweightKg").nonZero ?? 75
        heightCm          = d.double(forKey: "heightCm").nonZero ?? 178
        experience        = Experience(rawValue: d.string(forKey: "experience") ?? "") ?? .intermediate
        themeMode         = ThemeMode(rawValue: d.string(forKey: "themeMode") ?? "") ?? .vigil
        units             = WeightUnit(rawValue: d.string(forKey: "units") ?? "") ?? .imperial
        defaultRestSeconds = d.integer(forKey: "defaultRestSeconds").nonZero ?? 90
        hapticsEnabled    = (d.object(forKey: "hapticsEnabled") as? Bool) ?? true
        soundsEnabled     = (d.object(forKey: "soundsEnabled") as? Bool) ?? true
        healthKitEnabled  = d.bool(forKey: "healthKitEnabled")
        activeProgramId   = d.string(forKey: "activeProgramId") ?? "ppl_default"
        programStartDate  = (d.object(forKey: "programStartDate") as? Date) ?? .now
        hasCompletedOnboarding = d.bool(forKey: "hasCompletedOnboarding")
        lastWorkoutDateKey = d.string(forKey: "lastWorkoutDateKey") ?? ""
        currentStreak     = d.integer(forKey: "currentStreak")
        longestStreak     = d.integer(forKey: "longestStreak")
        barWeightKg       = d.double(forKey: "barWeightKg").nonZero ?? 20

        if let data = d.data(forKey: "recommendedWeightsKg"),
           let dec  = try? JSONDecoder().decode([String: Double].self, from: data) {
            recommendedWeightsKg = dec
        }
        if let data = d.data(forKey: "availablePlatesKg"),
           let dec  = try? JSONDecoder().decode([Double].self, from: data) {
            availablePlatesKg = dec
        }
    }
}

// MARK: - Supporting enums


enum WeightUnit: String, CaseIterable {
    case imperial, metric
    var label: String { self == .imperial ? "lbs" : "kg" }
    var fullLabel: String { self == .imperial ? "Pounds (lbs)" : "Kilograms (kg)" }

    /// Convert kg → display unit value.
    func from(kg: Double) -> Double { self == .imperial ? kg * 2.2046226218 : kg }
    /// Convert display unit → kg.
    func toKg(_ value: Double) -> Double { self == .imperial ? value / 2.2046226218 : value }
}

enum Experience: String, CaseIterable {
    case beginner, intermediate, advanced
    var label: String { rawValue.capitalized }
    var description: String {
        switch self {
        case .beginner:     return "New to lifting (0–1 year)"
        case .intermediate: return "Consistent for 1–3 years"
        case .advanced:     return "3+ years of structured training"
        }
    }
}

enum LoadDifficulty: String, Codable, CaseIterable {
    case tooEasy, justRight, tooHard
    var label: String {
        switch self {
        case .tooEasy:   return "Too Easy"
        case .justRight: return "Just Right"
        case .tooHard:   return "Too Hard"
        }
    }
    var icon: String {
        switch self {
        case .tooEasy:   return "arrow.up.circle.fill"
        case .justRight: return "checkmark.seal.fill"
        case .tooHard:   return "arrow.down.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .tooEasy:   return .brandSuccess
        case .justRight: return .brand
        case .tooHard:   return .brandWarn
        }
    }
}

// MARK: - Active workout (transient draft kept in AppState)

struct ActiveWorkout: Identifiable {
    var id: String = UUID().uuidString
    var title: String
    var subtitle: String
    var startedAt: Date = .now
    var exercises: [DraftExercise]
    var notes: String = ""
}

struct DraftExercise: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var muscleGroup: String
    var targetSets: Int = 4
    var targetReps: Int = 8
    var sets: [DraftSet] = []
    var notes: String = ""

    static func == (l: DraftExercise, r: DraftExercise) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct DraftSet: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var weight: Double? = nil   // displayed in user's units
    var reps: Int? = nil
    var rpe: Double? = nil
    var isWarmup: Bool = false
    var completed: Bool = false
    var difficulty: LoadDifficulty? = nil
    var completedAt: Date? = nil
}
