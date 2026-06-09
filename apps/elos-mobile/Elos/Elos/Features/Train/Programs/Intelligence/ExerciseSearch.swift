import Foundation

enum ExerciseSearch {
    static let gymAliases: [String: String] = [
        "rdl": "romanian deadlift", "ohp": "overhead press", "cgbp": "close grip bench press",
        "bp": "bench press", "dl": "deadlift", "pd": "pulldown", "db": "dumbbell",
        "bb": "barbell", "bw": "bodyweight", "bis": "bicep", "tris": "tricep",
        "hams": "hamstring", "quads": "quad", "delts": "delt", "glutes": "glute",
        "calves": "calf", "abs": "core abdominal", "pecs": "chest pec", "lats": "lat",
        "traps": "trap", "shoulders": "delt shoulder", "arms": "bicep tricep",
        "legs": "quad hamstring leg",
    ]

    static func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
    }

    static func tokens(from raw: String) -> [String] {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
        let expanded = gymAliases[lower] ?? lower
        return expanded.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 2 }
    }

    static func normalizedQuery(_ raw: String) -> String {
        normalize(gymAliases[raw.lowercased().trimmingCharacters(in: .whitespaces)] ?? raw)
    }

    /// Generic-exercise relevance. nil = no match. Mirrors the previous ExercisePickerView.exerciseScore.
    static func score(_ c: ExerciseCandidate, tokens: [String], query: String) -> Int? {
        let nq = normalizedQuery(query)
        let name = normalize(c.name)
        let full = "\(name) \(normalize(c.primaryMuscle)) \(normalize(c.equipment)) \(normalize(c.movementPattern))"
        guard tokens.allSatisfy({ full.contains($0) }) else { return nil }
        if name == nq { return 100 }
        if name.hasPrefix(nq) { return 90 }
        if name.contains(nq) { return 80 }
        if tokens.allSatisfy({ name.contains($0) }) { return 70 }
        return 50
    }
}
