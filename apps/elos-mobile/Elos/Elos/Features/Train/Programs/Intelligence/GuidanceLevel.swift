import Foundation

enum GuidanceLevel {
    case full, minimal
    init(trainingExperience: String) {
        switch trainingExperience.lowercased() {
        case "intermediate", "advanced": self = .minimal
        default: self = .full
        }
    }
}
