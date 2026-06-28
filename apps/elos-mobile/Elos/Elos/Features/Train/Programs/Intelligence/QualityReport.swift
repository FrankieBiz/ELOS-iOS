import Foundation

/// The four scored dimensions of a workout's quality.
enum QualityDimension: String, CaseIterable {
    case volume, balance, selection, repRest

    var label: String {
        switch self {
        case .volume:    return "Volume"
        case .balance:   return "Balance"
        case .selection: return "Selection"
        case .repRest:   return "Reps & rest"
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
    case addMuscle(String)   // open the picker biased toward a muscle group
    case addPattern(String)  // suggest a movement pattern (e.g. "hinge")
    case reorder             // re-sort the day compounds-first
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

    static let empty = QualityReport(overall: 0, tier: .needsWork,
                                     dimensions: [], tips: [], isScored: false)
}
