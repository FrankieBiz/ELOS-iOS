import Foundation
import SwiftData

// MARK: - WorkoutSession

@Model
final class WorkoutSession {
    var id: String = UUID().uuidString
    var name: String = ""
    var date: Date = Date.now
    var startedAt: Date = Date.now
    var endedAt: Date? = nil
    var durationMinutes: Int = 0
    var notes: String = ""
    var totalVolumeKg: Double = 0
    var templateId: String? = nil
    var programDay: String? = nil
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet] = []

    init(name: String, date: Date = .now, programDay: String? = nil, templateId: String? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.date = date
        self.startedAt = .now
        self.programDay = programDay
        self.templateId = templateId
        self.createdAt = .now
    }
}

// MARK: - WorkoutSet

@Model
final class WorkoutSet {
    var id: String = UUID().uuidString
    var exerciseName: String = ""
    var exerciseMuscleGroup: String = ""
    var orderIndex: Int = 0
    var setNumber: Int = 1
    var reps: Int = 0
    var weightKg: Double = 0
    var rpe: Double? = nil
    var isWarmup: Bool = false
    var notes: String = ""
    var completedAt: Date = Date.now
    var createdAt: Date = Date.now

    var session: WorkoutSession?

    init(exerciseName: String, muscleGroup: String, setNumber: Int, reps: Int,
         weightKg: Double, rpe: Double? = nil, isWarmup: Bool = false) {
        self.id = UUID().uuidString
        self.exerciseName = exerciseName
        self.exerciseMuscleGroup = muscleGroup
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.completedAt = .now
        self.createdAt = .now
    }

    /// Estimated 1RM (Epley formula). Returns nil for warmups or zero-rep sets.
    var estimated1RMKg: Double? {
        guard !isWarmup, reps > 0, weightKg > 0 else { return nil }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30.0)
    }
}

// MARK: - Custom Exercise

@Model
final class CustomExercise {
    var id: String = UUID().uuidString
    var name: String = ""
    var muscleGroup: String = ""
    var equipment: String = "Barbell"
    var notes: String = ""
    var isCompound: Bool = false
    var createdAt: Date = Date.now

    init(name: String, muscleGroup: String, equipment: String = "Barbell",
         isCompound: Bool = false, notes: String = "") {
        self.id = UUID().uuidString
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.notes = notes
        self.isCompound = isCompound
        self.createdAt = .now
    }
}

// MARK: - Personal Record

@Model
final class PersonalRecord {
    var id: String = UUID().uuidString
    var exerciseName: String = ""
    var weightKg: Double = 0
    var reps: Int = 1
    var estimated1RMKg: Double = 0
    var dateAchieved: Date = Date.now
    var notes: String = ""

    init(exerciseName: String, weightKg: Double, reps: Int = 1, estimated1RMKg: Double? = nil) {
        self.id = UUID().uuidString
        self.exerciseName = exerciseName
        self.weightKg = weightKg
        self.reps = reps
        self.estimated1RMKg = estimated1RMKg
            ?? (reps == 1 ? weightKg : weightKg * (1 + Double(reps) / 30.0))
        self.dateAchieved = .now
    }
}

// MARK: - Saved Workout Template

@Model
final class WorkoutTemplate {
    var id: String = UUID().uuidString
    var name: String = ""
    var subtitle: String = ""
    var exerciseNames: [String] = []
    var defaultSetsPerExercise: Int = 4
    var defaultReps: Int = 8
    var createdAt: Date = Date.now

    init(name: String, subtitle: String = "", exerciseNames: [String] = []) {
        self.id = UUID().uuidString
        self.name = name
        self.subtitle = subtitle
        self.exerciseNames = exerciseNames
        self.createdAt = .now
    }
}

// MARK: - Body Metric (weight log etc.)

@Model
final class BodyMetric {
    var id: String = UUID().uuidString
    var date: Date = Date.now
    var weightKg: Double = 0
    var bodyFatPct: Double? = nil
    var notes: String = ""
    var createdAt: Date = Date.now

    init(weightKg: Double, date: Date = .now, bodyFatPct: Double? = nil, notes: String = "") {
        self.id = UUID().uuidString
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPct = bodyFatPct
        self.notes = notes
        self.createdAt = .now
    }
}
