import Foundation

// MARK: - Navigation Enums
enum AppTab: String, Hashable, CaseIterable {
    case today, train, stats, plan, me

    var label: String {
        switch self {
        case .today: return "Today"
        case .train: return "Train"
        case .stats: return "Stats"
        case .plan:  return "Plan"
        case .me:    return "Me"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .train: return "dumbbell"
        case .stats: return "chart.line.uptrend.xyaxis"
        case .plan:  return "list.clipboard"
        case .me:    return "person.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .train: return "dumbbell.fill"
        case .stats: return "chart.line.uptrend.xyaxis"
        case .plan:  return "list.clipboard.fill"
        case .me:    return "person.circle.fill"
        }
    }
}

enum PlanSegment: String, CaseIterable {
    case schedule    = "Schedule"
    case assignments = "Assignments"
    case exams       = "Exams"
}

enum AssignFilter: String, CaseIterable {
    case all     = "All"
    case pending = "Pending"
    case done    = "Done"
}

// MARK: - Data Models
struct Habit: Identifiable {
    var id: String
    var label: String
    var category: String
    var streak: Int
    var done: Bool
}

struct Assignment: Identifiable {
    var id: Int
    var name: String
    var subject: String
    var due: String
    var urgent: Bool
    var done: Bool
}

struct Exam: Identifiable {
    var id: Int
    var subject: String
    var title: String
    var date: String
    var daysAway: Int
}

struct SleepEntry: Identifiable {
    var id = UUID()
    var date: String
    var bed: String
    var wake: String
    var duration: Double
    var quality: Int  // 1–5
}

struct WorkSet: Identifiable, Codable {
    var id = UUID()
    var weight: String
    var reps: String
    var rpe: String
    var done: Bool

    init(weight: String, reps: String, rpe: String, done: Bool = false) {
        self.weight = weight
        self.reps   = reps
        self.rpe    = rpe
        self.done   = done
    }

    enum CodingKeys: String, CodingKey { case id, weight, reps, rpe, done }

    // Tolerant decode so an older draft snapshot missing a field still loads.
    init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        id     = (try? c.decode(UUID.self,   forKey: .id))     ?? UUID()
        weight = (try? c.decode(String.self, forKey: .weight)) ?? ""
        reps   = (try? c.decode(String.self, forKey: .reps))   ?? ""
        rpe    = (try? c.decode(String.self, forKey: .rpe))    ?? ""
        done   = (try? c.decode(Bool.self,   forKey: .done))   ?? false
    }
}

struct Exercise: Identifiable, Codable {
    var id = UUID()
    var name: String
    var primaryMuscle: String
    var secondaryMuscles: [String]
    var setsLabel: String
    var lastBest: String
    var sets: [WorkSet]

    // Machine/equipment identity (nil = generic exercise, not tied to a specific machine).
    var equipmentId: String? = nil
    var equipmentDedupeKey: String? = nil
    var equipmentBrandName: String? = nil
    var isGenericExercise: Bool = true

    // True for bodyweight exercises that support a load attachment (belt, vest, plate).
    // When set, the weight field represents added weight only, not absolute load.
    var supportsAddedWeight: Bool = false

    // Per-exercise rest target (seconds) used to seed the rest timer.
    var restSeconds: Int = 90

    init(id: UUID = UUID(), name: String, primaryMuscle: String, secondaryMuscles: [String],
         setsLabel: String, lastBest: String, sets: [WorkSet],
         equipmentId: String? = nil, equipmentDedupeKey: String? = nil,
         equipmentBrandName: String? = nil, isGenericExercise: Bool = true,
         supportsAddedWeight: Bool = false, restSeconds: Int = 90) {
        self.id = id
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
        self.setsLabel = setsLabel
        self.lastBest = lastBest
        self.sets = sets
        self.equipmentId = equipmentId
        self.equipmentDedupeKey = equipmentDedupeKey
        self.equipmentBrandName = equipmentBrandName
        self.isGenericExercise = isGenericExercise
        self.supportsAddedWeight = supportsAddedWeight
        self.restSeconds = restSeconds
    }

    enum CodingKeys: String, CodingKey {
        case id, name, primaryMuscle, secondaryMuscles, setsLabel, lastBest, sets,
             equipmentId, equipmentDedupeKey, equipmentBrandName,
             isGenericExercise, supportsAddedWeight, restSeconds
    }

    // Tolerant decode so a draft snapshot from an older app version still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name                = (try? c.decode(String.self, forKey: .name)) ?? ""
        primaryMuscle       = (try? c.decode(String.self, forKey: .primaryMuscle)) ?? ""
        secondaryMuscles    = (try? c.decode([String].self, forKey: .secondaryMuscles)) ?? []
        setsLabel           = (try? c.decode(String.self, forKey: .setsLabel)) ?? ""
        lastBest            = (try? c.decode(String.self, forKey: .lastBest)) ?? ""
        sets                = (try? c.decode([WorkSet].self, forKey: .sets)) ?? []
        equipmentId         = try? c.decodeIfPresent(String.self, forKey: .equipmentId)
        equipmentDedupeKey  = try? c.decodeIfPresent(String.self, forKey: .equipmentDedupeKey)
        equipmentBrandName  = try? c.decodeIfPresent(String.self, forKey: .equipmentBrandName)
        isGenericExercise   = (try? c.decode(Bool.self, forKey: .isGenericExercise)) ?? true
        supportsAddedWeight = (try? c.decode(Bool.self, forKey: .supportsAddedWeight)) ?? false
        restSeconds         = (try? c.decode(Int.self, forKey: .restSeconds)) ?? 90
    }
}

struct MuscleVolume: Identifiable {
    var id = UUID()
    var muscle: String
    var current: Int
    var target: Int
    var trend: String
    var trendUp: Bool
    var onTrack: Bool
}

struct PersonalRecord: Identifiable {
    var id = UUID()
    var lift: String
    var weight: String
    var reps: String
}


