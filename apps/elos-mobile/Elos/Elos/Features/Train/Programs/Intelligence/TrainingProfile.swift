import Foundation

/// The user's training intent, normalized from the raw profile strings. Drives every
/// goal/experience-aware target the quality engine uses. Pure value type — mirrors the
/// `ExerciseCandidate(record:)` pattern so engines never touch SwiftData directly.
enum LiftingGoal: String, CaseIterable {
    case strength, hypertrophy, endurance, weightLoss

    init(raw: String) {
        switch raw.lowercased().trimmingCharacters(in: .whitespaces) {
        case "strength":                                 self = .strength
        case "endurance":                                self = .endurance
        case "weight_loss", "weightloss", "weight loss": self = .weightLoss
        default:                                         self = .hypertrophy
        }
    }

    var displayName: String {
        switch self {
        case .strength:    return "strength"
        case .hypertrophy: return "muscle growth"
        case .endurance:   return "endurance"
        case .weightLoss:  return "a lean/cut goal"
        }
    }
}

enum TrainingExperienceLevel: String, CaseIterable {
    case beginner, intermediate, advanced

    init(raw: String) {
        switch raw.lowercased().trimmingCharacters(in: .whitespaces) {
        case "advanced":     self = .advanced
        case "intermediate": self = .intermediate
        default:             self = .beginner
        }
    }
}

struct TrainingProfile: Equatable {
    let goal: LiftingGoal
    let experience: TrainingExperienceLevel

    init(goal: LiftingGoal, experience: TrainingExperienceLevel) {
        self.goal = goal
        self.experience = experience
    }

    init(record: UserProfileRecord?) {
        self.init(goal: LiftingGoal(raw: record?.trainingGoal ?? ""),
                  experience: TrainingExperienceLevel(raw: record?.trainingExperience ?? ""))
    }

    static let `default` = TrainingProfile(goal: .hypertrophy, experience: .intermediate)
}
