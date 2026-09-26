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

/// How hard the lifter wants the science-derived volume targets pushed, as one multiplier over every
/// band. A blunt instrument on purpose: it's one control instead of sixteen.
enum VolumePreference: String, CaseIterable, Codable, Equatable {
    case conservative, standard, aggressive

    var scale: Double {
        switch self {
        case .conservative: return 0.85
        case .standard:     return 1.0
        case .aggressive:   return 1.15
        }
    }

    var label: String {
        switch self {
        case .conservative: return "Conservative"
        case .standard:     return "Standard"
        case .aggressive:   return "Aggressive"
        }
    }

    var blurb: String {
        switch self {
        case .conservative: return "Lower targets — better if you're short on recovery or time."
        case .standard:     return "The science-based defaults for your experience level."
        case .aggressive:   return "Higher targets — only if you're recovering well."
        }
    }
}

/// The lifter's deviations from the science defaults.
///
/// Deliberately group-level for numeric targets, not per-fine-muscle: there are sixteen fine muscles
/// and a sixteen-field form is a worse product than one multiplier plus a handful of group targets.
/// `TrainingScience` distributes a group target across its children in the science table's own
/// proportions. `excludedMuscles` is fine-muscle-level, not group-level, because it's a different
/// (much lower-cognitive-load) kind of control — a yes/no checklist, not a number to pick.
struct VolumeOverrides: Equatable, Codable {
    var preference: VolumePreference = .standard
    /// `MuscleGroup.rawValue` → the lifter's own weekly set target for that whole group.
    /// Present means "use my number"; absent means "use the derived one".
    var groupWeeklyTarget: [String: Int] = [:]
    /// Muscles the lifter has explicitly said they're not training, anywhere, ever — distinct from
    /// `TrainingIntent.excludedMuscles`, which is day/template-scoped. Forces `isOptional` on the
    /// muscle's band wherever it's read (`TrainingScience.weeklyBand`), so it's silently skipped by
    /// every scorer and shown muted (not as a red gap) in the coverage bars.
    var excludedMuscles: Set<FineMuscle> = []

    static let none = VolumeOverrides()

    var isCustomized: Bool {
        preference != .standard || !groupWeeklyTarget.isEmpty || !excludedMuscles.isEmpty
    }

    init(preference: VolumePreference = .standard,
         groupWeeklyTarget: [String: Int] = [:],
         excludedMuscles: Set<FineMuscle> = []) {
        self.preference = preference
        self.groupWeeklyTarget = groupWeeklyTarget
        self.excludedMuscles = excludedMuscles
    }

    // MARK: Backward-compatible decode
    //
    // Synthesized `Decodable` throws `keyNotFound` on a JSON blob saved before `excludedMuscles`
    // existed. `AppViewModel` decodes this with `try?` (`JSONDecoder().decode(VolumeOverrides.self,
    // ...)`), so a thrown decode doesn't crash — it silently resets `preference` and
    // `groupWeeklyTarget` back to defaults too, on every existing user's upgrade. Writing this
    // `init(from:)` by hand suppresses the synthesized memberwise init, which is why the explicit
    // one above exists.

    private enum CodingKeys: String, CodingKey {
        case preference, groupWeeklyTarget, excludedMuscles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preference = try c.decodeIfPresent(VolumePreference.self, forKey: .preference) ?? .standard
        groupWeeklyTarget = try c.decodeIfPresent([String: Int].self, forKey: .groupWeeklyTarget) ?? [:]
        excludedMuscles = try c.decodeIfPresent(Set<FineMuscle>.self, forKey: .excludedMuscles) ?? []
    }
}

struct TrainingProfile: Equatable {
    let goal: LiftingGoal
    let experience: TrainingExperienceLevel
    /// Carried in the profile rather than read from UserDefaults inside `TrainingScience`, so every
    /// band stays a pure function of its inputs and the whole engine remains testable.
    let volumeOverrides: VolumeOverrides

    init(goal: LiftingGoal,
         experience: TrainingExperienceLevel,
         volumeOverrides: VolumeOverrides = .none) {
        self.goal = goal
        self.experience = experience
        self.volumeOverrides = volumeOverrides
    }

    init(record: UserProfileRecord?, volumeOverrides: VolumeOverrides = .none) {
        self.init(goal: LiftingGoal(raw: record?.trainingGoal ?? ""),
                  experience: TrainingExperienceLevel(raw: record?.trainingExperience ?? ""),
                  volumeOverrides: volumeOverrides)
    }

    static let `default` = TrainingProfile(goal: .hypertrophy, experience: .intermediate)
}
