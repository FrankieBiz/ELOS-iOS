import Foundation

// MARK: - Enums

enum TrainingGoal: String, CaseIterable {
    case hypertrophy, strength, athletic, general

    var displayName: String {
        switch self {
        case .hypertrophy: return "Hypertrophy"
        case .strength:    return "Strength"
        case .athletic:    return "Athletic"
        case .general:     return "General Fitness"
        }
    }

    var icon: String {
        switch self {
        case .hypertrophy: return "dumbbell.fill"
        case .strength:    return "figure.strengthtraining.traditional"
        case .athletic:    return "figure.run"
        case .general:     return "heart.fill"
        }
    }
}

enum GymSize: String, CaseIterable {
    case commercial, small

    var displayName: String { self == .commercial ? "Commercial Gym" : "Small / Home Gym" }
    var icon: String         { self == .commercial ? "building.2.fill" : "house.fill" }
}

enum WarmupStyle: String, CaseIterable {
    case dynamic, staticStretch, both

    var displayName: String {
        switch self {
        case .dynamic:       return "Dynamic"
        case .staticStretch: return "Static Stretching"
        case .both:          return "Both"
        }
    }
}

enum InjuredPart: String, CaseIterable {
    case shoulder, knee, lowerBack, wrist, elbow, hip, ankle

    var displayName: String {
        switch self {
        case .shoulder:  return "Shoulder"
        case .knee:      return "Knee"
        case .lowerBack: return "Lower Back"
        case .wrist:     return "Wrist"
        case .elbow:     return "Elbow"
        case .hip:       return "Hip"
        case .ankle:     return "Ankle"
        }
    }
}

enum InjurySeverity: String, CaseIterable {
    case mild, moderate, avoid

    var displayName: String {
        switch self {
        case .mild:     return "Mild"
        case .moderate: return "Moderate"
        case .avoid:    return "Avoid"
        }
    }
}

enum SplitStyle: String, CaseIterable {
    case fullBody, upperLower, pushPullLegs, arnold, broSplit, athletic, anteriorPosterior

    var displayName: String {
        switch self {
        case .fullBody:           return "Full Body"
        case .upperLower:         return "Upper / Lower"
        case .pushPullLegs:       return "Push / Pull / Legs"
        case .arnold:             return "Arnold Split"
        case .broSplit:           return "Bro Split"
        case .athletic:           return "Athletic"
        case .anteriorPosterior:  return "Anterior / Posterior"
        }
    }

    var icon: String {
        switch self {
        case .fullBody:           return "circle.grid.2x2.fill"
        case .upperLower:         return "rectangle.split.2x1.fill"
        case .pushPullLegs:       return "triangle.fill"
        case .arnold:             return "star.fill"
        case .broSplit:           return "rectangle.split.3x1.fill"
        case .athletic:           return "figure.run"
        case .anteriorPosterior:  return "arrow.left.arrow.right"
        }
    }

    var structureDescription: String {
        switch self {
        case .fullBody:           return "All muscles, every session"
        case .upperLower:         return "Upper & lower body alternated"
        case .pushPullLegs:       return "Push / Pull / Legs days"
        case .arnold:             return "Chest+Back, Arms, Legs"
        case .broSplit:           return "One muscle group per day"
        case .athletic:           return "Power + hypertrophy focus"
        case .anteriorPosterior:  return "Front & back of body split"
        }
    }
}

enum Sport: String, CaseIterable {
    case basketball, football, soccer, baseball, tennis, swimming
    case mmaBoxing, wrestling, trackAndField, volleyball, hockey, golf, lacrosse

    var displayName: String {
        switch self {
        case .basketball:    return "Basketball"
        case .football:      return "Football"
        case .soccer:        return "Soccer"
        case .baseball:      return "Baseball"
        case .tennis:        return "Tennis"
        case .swimming:      return "Swimming"
        case .mmaBoxing:     return "MMA / Boxing"
        case .wrestling:     return "Wrestling"
        case .trackAndField: return "Track & Field"
        case .volleyball:    return "Volleyball"
        case .hockey:        return "Hockey"
        case .golf:          return "Golf"
        case .lacrosse:      return "Lacrosse"
        }
    }

    var icon: String {
        switch self {
        case .basketball:    return "basketball.fill"
        case .football:      return "football.fill"
        case .soccer:        return "soccerball"
        case .baseball:      return "baseball.fill"
        case .tennis:        return "tennis.racket"
        case .swimming:      return "figure.pool.swim"
        case .mmaBoxing:     return "figure.boxing"
        case .wrestling:     return "figure.wrestling"
        case .trackAndField: return "figure.run"
        case .volleyball:    return "volleyball.fill"
        case .hockey:        return "hockey.puck.fill"
        case .golf:          return "figure.golf"
        case .lacrosse:      return "figure.lacrosse"
        }
    }
}

// MARK: - Input structs

struct EquipmentProfile {
    var machineRatio: Double
    var dumbbellRatio: Double
    var barbellRatio: Double

    static let balanced = EquipmentProfile(machineRatio: 0.33, dumbbellRatio: 0.34, barbellRatio: 0.33)

    mutating func normalize() {
        let sum = machineRatio + dumbbellRatio + barbellRatio
        if sum == 0 {
            machineRatio = 0.33; dumbbellRatio = 0.34; barbellRatio = 0.33
        } else {
            machineRatio   /= sum
            dumbbellRatio  /= sum
            barbellRatio   /= sum
        }
    }
}

struct InjuryEntry: Identifiable {
    let id = UUID()
    var part: InjuredPart
    var severity: InjurySeverity
}

struct SplitFinderInput {
    var goal: TrainingGoal              = .hypertrophy
    var daysPerWeek: Int                = 4
    var sessionMinutes: Int             = 60
    var equipment: EquipmentProfile     = .balanced
    var gymSize: GymSize                = .commercial
    var preferredStructure: SplitStyle? = nil
    var sport: Sport?                   = nil
    var sportFocusRatio: Double         = 0.0
    var injuries: [InjuryEntry]         = []
    var includeWarmups: Bool            = false
    var warmupStyle: WarmupStyle?       = nil
}

// MARK: - Output structs

struct RecommendedExercise: Identifiable {
    let id = UUID()
    var name: String
    var sets: Int
    var reps: String
    var equipment: String   // "Barbell" | "Dumbbell" | "Machine" | "Bodyweight"
    var primaryMuscle: String
}

struct WarmupExercise: Identifiable {
    let id = UUID()
    var name: String
    var duration: String
}

struct RecommendedDay: Identifiable {
    let id = UUID()
    var label: String
    var isRest: Bool
    var exercises: [RecommendedExercise]
    var warmupBlock: [WarmupExercise]
}

struct SplitRecommendation: Identifiable {
    let id = UUID()
    var name: String
    var style: SplitStyle
    var days: [RecommendedDay]
    var estimatedMinutes: Int
    var matchScore: Double
    var matchTags: [String]
    var includeWarmups: Bool
}
