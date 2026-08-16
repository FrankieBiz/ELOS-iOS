import Foundation
import SwiftData

// MARK: - Navigation Enums
// `Codable` so the tab bar's order, hidden set and launch tab can be persisted by `LayoutStore`.
enum AppTab: String, Hashable, CaseIterable, Codable, Identifiable {
    case today, train, stats, plan, me

    var id: String { rawValue }

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
    var notes: String = ""
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

    /// What this trains, resolved through `ResolvedExercise.targets` when the session was built.
    /// Carried alongside `primaryMuscle`/`secondaryMuscles` (which are derived from it) so the logged
    /// sets can record it and the post-workout muscle breakdown doesn't have to guess from the name.
    /// Optional so an in-flight session draft encoded before this existed still decodes.
    var muscleTargets: MuscleTargets? = nil

    init(id: UUID = UUID(), name: String, primaryMuscle: String, secondaryMuscles: [String],
         setsLabel: String, lastBest: String, sets: [WorkSet],
         equipmentId: String? = nil, equipmentDedupeKey: String? = nil,
         equipmentBrandName: String? = nil, isGenericExercise: Bool = true,
         supportsAddedWeight: Bool = false, restSeconds: Int = 90,
         muscleTargets: MuscleTargets? = nil) {
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
        self.muscleTargets = muscleTargets
    }

    enum CodingKeys: String, CodingKey {
        case id, name, primaryMuscle, secondaryMuscles, setsLabel, lastBest, sets,
             equipmentId, equipmentDedupeKey, equipmentBrandName,
             isGenericExercise, supportsAddedWeight, restSeconds, muscleTargets
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
        muscleTargets       = try? c.decodeIfPresent(MuscleTargets.self, forKey: .muscleTargets)
    }

    /// Re-point this exercise at a different lift, keeping the logged work.
    ///
    /// A swap has to replace the exercise's whole **identity**, not just its label. `ExerciseSwapSheet`
    /// used to assign `name` alone, which left everything else pointing at the lift you swapped *away
    /// from*:
    /// - `equipmentDedupeKey` drives `previousSets`, PR detection and the progressive-overload target,
    ///   so the new lift inherited the old machine's history and got an overload suggestion computed
    ///   against a different exercise.
    /// - the muscle fields kept crediting the old muscles, so swapping a bench press for a pulldown
    ///   still counted as chest volume.
    /// - `supportsAddedWeight` kept the old weight semantics, so a bodyweight swap read its load wrong.
    ///
    /// Sets are deliberately preserved: you swap mid-session having already logged work, and losing it
    /// would be worse than any of the above.
    mutating func adopt(_ picked: PickedExercise, in context: ModelContext) {
        let targets = resolvedMuscleTargets(
            exerciseID: picked.id, name: picked.name,
            equipmentId: picked.equipmentId, override: picked.muscleTargets,
            candidate: candidate(forID: picked.id, in: context))

        name = picked.name
        muscleTargets = targets.isEmpty ? nil : targets
        primaryMuscle = targets.catalogPrimary ?? ""
        secondaryMuscles = targets.catalogSecondaries
        equipmentId = picked.equipmentId
        equipmentDedupeKey = picked.equipmentDedupeKey
        equipmentBrandName = picked.equipmentBrandName
        isGenericExercise = (picked.equipmentDedupeKey ?? "").isEmpty
        supportsAddedWeight = ExerciseCatalog.weightableBodyweightExercises.contains(picked.name)
    }

    /// What this exercise trains, preferring the targets resolved when the session was built and
    /// falling back to the muscle strings for a draft that predates them.
    var resolvedTargets: MuscleTargets {
        if let t = muscleTargets, !t.isEmpty { return t }
        let fromStrings = MuscleTargets(primaryMuscle: primaryMuscle, secondaryMuscles: secondaryMuscles)
        if !fromStrings.isEmpty { return fromStrings }
        return ResolvedExercise(
            exercise: ScoredExercise(id: "", name: name, sets: 1, repsText: "",
                                     equipmentId: equipmentId),
            candidate: nil
        ).targets
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


