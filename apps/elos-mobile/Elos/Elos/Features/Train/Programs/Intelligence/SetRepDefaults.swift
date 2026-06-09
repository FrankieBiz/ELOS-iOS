import Foundation

enum SetRepDefaults {
    static func defaults(forMovementPattern pattern: String) -> (sets: Int, reps: String) {
        switch pattern.lowercased().trimmingCharacters(in: .whitespaces) {
        case "squat", "hinge": return (4, "5-8")
        case "push", "pull":   return (4, "6-10")
        case "carry":          return (3, "10")
        default:               return (3, "10-15") // isolation, rotation, unknown
        }
    }
}
