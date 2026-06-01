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
        case .plan:  return "calendar"
        case .me:    return "person.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .train: return "dumbbell.fill"
        case .stats: return "chart.line.uptrend.xyaxis"
        case .plan:  return "calendar.fill"
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

struct WorkSet: Identifiable {
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
}

struct Exercise: Identifiable {
    var id = UUID()
    var name: String
    var primaryMuscle: String
    var secondaryMuscles: [String]
    var setsLabel: String
    var lastBest: String
    var sets: [WorkSet]
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


