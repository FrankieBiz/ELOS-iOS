import Foundation

enum EvidenceCertainty: String, CaseIterable {
    case high, medium, mediumLow, low

    var displayLabel: String {
        switch self {
        case .high:      return "High certainty"
        case .medium:    return "Medium certainty"
        case .mediumLow: return "Medium-low certainty"
        case .low:       return "Low certainty"
        }
    }
}

enum EvidenceTopic: String, CaseIterable {
    case exerciseSubstitution
}

struct EvidenceEntry {
    let claim: String
    let certainty: EvidenceCertainty
    let explanation: String
}

/// One place for every "backed by science" claim in the app, each honestly rated — not every
/// claim here is strongly supported, and the point of this library is to say so rather than bury
/// the caveat in a code comment. Add an entry per topic as new science-backed features ship.
enum EvidenceLibrary {
    static func entry(for topic: EvidenceTopic) -> EvidenceEntry {
        switch topic {
        case .exerciseSubstitution:
            return EvidenceEntry(
                claim: "Suggestions are ranked by matching primary muscle, movement pattern, and available equipment.",
                certainty: .mediumLow,
                explanation: "This is a practical heuristic, not a proven-equivalent substitution. " +
                    "No study has directly tested whether matching movement signature preserves " +
                    "results better than a simple same-muscle swap — in fact, one study found a hip " +
                    "thrust and a back squat produced similar hypertrophy and similar deadlift " +
                    "transfer despite very different muscle activation. Treat these as reasonable " +
                    "starting points, not guarantees."
            )
        }
    }
}
