import Foundation

/// The unit the ranking/guidance engines operate on. Both `ExerciseDefinitionRecord`
/// and the picker's server responses map into this so engines never touch SwiftData or the network.
struct ExerciseCandidate: Hashable, Identifiable {
    let id: String
    let name: String
    let primaryMuscle: String
    let secondaryMuscles: [String]
    let equipment: String
    let movementPattern: String
    let isCustom: Bool

    init(id: String, name: String, primaryMuscle: String, secondaryMuscles: [String],
         equipment: String, movementPattern: String, isCustom: Bool) {
        self.id = id; self.name = name; self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles; self.equipment = equipment
        self.movementPattern = movementPattern; self.isCustom = isCustom
    }

    init(record r: ExerciseDefinitionRecord) {
        self.init(id: r.id, name: r.name, primaryMuscle: r.primaryMuscle,
                  secondaryMuscles: r.secondaryMuscles, equipment: r.equipment,
                  movementPattern: r.movementPattern, isCustom: r.isCustom)
    }
}
