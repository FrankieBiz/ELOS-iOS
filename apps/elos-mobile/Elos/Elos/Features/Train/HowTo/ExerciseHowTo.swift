import Foundation
import SwiftData

/// Reference how-to content for a generic exercise. Keyed on the generic exercise,
/// so every brand-machine variant inherits it. Pure value type.
struct ExerciseHowTo: Identifiable, Equatable {
    let name: String
    let steps: [String]
    let imageKey: String?   // nil / "" -> no bundled photo

    var id: String { name }

    /// Returns nil when the record has no instructions (ⓘ then falls back to the muscle caption).
    static func from(record: ExerciseDefinitionRecord) -> ExerciseHowTo? {
        let steps = record.instructions
        guard !steps.isEmpty else { return nil }
        let key = record.imageKey.isEmpty ? nil : record.imageKey
        return ExerciseHowTo(name: record.name, steps: steps, imageKey: key)
    }
}

/// Looks up how-to content for an exercise by its (catalog) name.
enum ExerciseHowToLookup {
    static func find(name: String, in context: ModelContext) -> ExerciseHowTo? {
        var descriptor = FetchDescriptor<ExerciseDefinitionRecord>(
            predicate: #Predicate { $0.name == name }
        )
        descriptor.fetchLimit = 5
        let matches = (try? context.fetch(descriptor)) ?? []
        // Prefer a global catalog row (empty ownerID) over a custom one.
        let record = matches.first(where: { $0.ownerID.isEmpty }) ?? matches.first
        return record.flatMap(ExerciseHowTo.from(record:))
    }
}
