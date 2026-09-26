import Foundation

/// The scored dimensions of a workout's quality. `frequency` applies to a week only — a single
/// session has no frequency to judge, so it carries zero weight at `.singleSession` scope.
enum QualityDimension: String, CaseIterable {
    case volume, balance, selection, repRest, frequency, fatigue

    var label: String {
        switch self {
        case .volume:    return "Volume"
        case .balance:   return "Balance"
        case .selection: return "Selection"
        case .repRest:   return "Reps & rest"
        case .frequency: return "Frequency"
        case .fatigue:   return "Fatigue & order"
        }
    }

    /// Whether this dimension is meaningful at the given scope.
    func applies(to scope: QualityScope) -> Bool {
        switch self {
        case .frequency: return scope == .weeklySplit
        default:         return true
        }
    }
}

/// Qualitative band for the overall 0–100 score.
enum QualityTier: String {
    case needsWork = "Needs work"
    case solid     = "Solid"
    case dialedIn  = "Dialed in"
    case optimized = "Optimized"

    init(score: Int) {
        switch score {
        case ..<55:   self = .needsWork
        case 55..<75: self = .solid
        case 75..<90: self = .dialedIn
        default:      self = .optimized
        }
    }
}

/// Tip urgency. Raw value doubles as sort priority (higher = surfaced first).
enum TipSeverity: Int, Comparable {
    case good = 0, info = 1, warn = 2
    static func < (lhs: TipSeverity, rhs: TipSeverity) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// An optional one-tap follow-up a tip can offer the builder UI.
enum TipAction: Equatable {
    case addMuscle(String)        // open the picker biased toward a muscle group
    case addPattern(String)       // suggest a movement pattern (e.g. "hinge")
    /// Re-sort a day compounds-first. Carries the day index because at weekly scope there is no
    /// implicit "the day" — the split builder needs to know *which* day to reorder.
    case reorder(dayIndex: Int)
    /// Rewrite out-of-range rep targets to the goal's range. A pure numeric edit — no exercise
    /// choice involved, which is what makes it auto-fixable at all.
    case retuneReps
    /// Rewrite out-of-range rest targets to the goal's range. Single-session scope only — split
    /// days don't capture rest.
    case retuneRest
    case noAction

    var isActionable: Bool { self != .noAction }
}

struct QualityTip: Identifiable, Equatable {
    let id: String           // stable dedupe key
    let dimension: QualityDimension
    let severity: TipSeverity
    let message: String
    let action: TipAction

    init(id: String, dimension: QualityDimension, severity: TipSeverity,
         message: String, action: TipAction = .noAction) {
        self.id = id
        self.dimension = dimension
        self.severity = severity
        self.message = message
        self.action = action
    }
}

struct DimensionScore: Identifiable, Equatable {
    var id: String { dimension.rawValue }
    let dimension: QualityDimension
    let score: Int           // 0–100
    let tips: [QualityTip]
}

struct QualityReport: Equatable {
    let overall: Int         // 0–100
    let tier: QualityTier
    let dimensions: [DimensionScore]
    let tips: [QualityTip]   // merged, deduped, ranked — for inline display
    let isScored: Bool       // false when there's too little to score meaningfully
    /// Per-muscle coverage rows (one per `MuscleGroup`, each with fine children). Populated even
    /// when `isScored` is false, so the bars can fill in as the lifter builds.
    let volume: MuscleVolumeReport
    /// Compound/isolation mix and pattern spread.
    let movement: MovementProfile

    init(overall: Int, tier: QualityTier, dimensions: [DimensionScore], tips: [QualityTip],
         isScored: Bool, volume: MuscleVolumeReport = .empty,
         movement: MovementProfile = .empty) {
        self.overall = overall
        self.tier = tier
        self.dimensions = dimensions
        self.tips = tips
        self.isScored = isScored
        self.volume = volume
        self.movement = movement
    }

    static let empty = QualityReport(overall: 0, tier: .needsWork,
                                     dimensions: [], tips: [], isScored: false)

    /// Dimension scores that apply at the given scope, in `QualityDimension.allCases` order.
    func dimensions(for scope: QualityScope) -> [DimensionScore] {
        dimensions.filter { $0.dimension.applies(to: scope) }
    }
}
