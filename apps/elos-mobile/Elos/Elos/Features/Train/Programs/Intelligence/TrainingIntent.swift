import Foundation

/// What the lifter says they're building — selected explicitly in the builder rather than guessed
/// from the day name. Intent drives which muscles are *expected* to be filled, so a Push template is
/// never nagged about hamstrings and `BalanceScorer` only falls back to name inference when the
/// lifter hasn't told us (`focus == nil`).
///
/// `focus` reuses the existing `SplitArchetype` — it already carries exactly the cases a session
/// focus needs (push/pull/legs/upper/lower/fullBody/arms/core), so a parallel enum would be a second
/// source of truth for the same concept.
struct TrainingIntent: Equatable, Codable {
    /// Drives rep/rest targets. Defaults from `UserProfileRecord.trainingGoal`.
    var goal: LiftingGoal
    /// The session's focus. `nil` = let the engine infer from the day name (the pre-intent behavior).
    /// Always `nil` at weekly scope — a whole week has no single focus.
    var focus: SplitArchetype?

    init(goal: LiftingGoal, focus: SplitArchetype? = nil) {
        self.goal = goal
        self.focus = focus
    }

    /// Seed from the user's saved profile, so the selector is never a blank chore.
    init(profile: TrainingProfile, focus: SplitArchetype? = nil) {
        self.init(goal: profile.goal, focus: focus)
    }

    static let `default` = TrainingIntent(goal: .hypertrophy)

    // MARK: JSON persistence
    //
    // Stored as a defaulted `intentJSON` string on the template/split record — the
    // `equipmentPreferenceJSON` precedent. Local-only: a lightweight SwiftData migration with no
    // backend contract change.

    var jsonString: String {
        guard let data = try? JSONEncoder().encode(self),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }

    init?(jsonString: String) {
        guard !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(TrainingIntent.self, from: data)
        else { return nil }
        self = decoded
    }
}

// MARK: - Display

extension SplitArchetype {
    /// Menu label for the focus picker.
    var displayName: String {
        switch self {
        case .push:     return "Push"
        case .pull:     return "Pull"
        case .legs:     return "Legs"
        case .upper:    return "Upper body"
        case .lower:    return "Lower body"
        case .fullBody: return "Full body"
        case .arms:     return "Arms"
        case .core:     return "Core"
        }
    }

    var icon: String {
        switch self {
        case .push:     return "arrow.up.circle"
        case .pull:     return "arrow.down.circle"
        case .legs:     return "figure.walk"
        case .upper:    return "figure.arms.open"
        case .lower:    return "figure.strengthtraining.functional"
        case .fullBody: return "figure.mixed.cardio"
        case .arms:     return "figure.boxing"
        case .core:     return "figure.core.training"
        }
    }
}

extension LiftingGoal {
    /// Menu label for the goal picker. Distinct from `displayName`, which is phrased to read
    /// mid-sentence inside a coaching tip ("…for muscle growth").
    var pickerLabel: String {
        switch self {
        case .strength:    return "Strength"
        case .hypertrophy: return "Muscle growth"
        case .endurance:   return "Endurance"
        case .weightLoss:  return "Fat loss"
        }
    }
}

// `SplitArchetype` and `LiftingGoal` are `String`-backed, so `Codable` conformance is synthesized —
// declared here rather than on the original decls to keep this feature's needs out of those files.
extension SplitArchetype: Codable {}
extension LiftingGoal: Codable {}
