import Foundation

struct InjurySubstitutionEngine {

    private struct InjuryKey: Hashable {
        let part: InjuredPart
        let severity: InjurySeverity
    }

    private static let map: [String: [InjuryKey: String?]] = [
        "Barbell Overhead Press": [
            InjuryKey(part: .shoulder, severity: .mild):     "Dumbbell Lateral Raise",
            InjuryKey(part: .shoulder, severity: .moderate): "Cable Face Pull",
            InjuryKey(part: .shoulder, severity: .avoid):    nil,
        ],
        "Dumbbell Shoulder Press": [
            InjuryKey(part: .shoulder, severity: .mild):     "Dumbbell Lateral Raise",
            InjuryKey(part: .shoulder, severity: .moderate): "Band Pull-Apart",
            InjuryKey(part: .shoulder, severity: .avoid):    nil,
        ],
        "Barbell Back Squat": [
            InjuryKey(part: .knee, severity: .mild):         "Leg Press",
            InjuryKey(part: .knee, severity: .moderate):     "Goblet Squat",
            InjuryKey(part: .knee, severity: .avoid):        nil,
        ],
        "Leg Press": [
            InjuryKey(part: .knee, severity: .moderate):     "Seated Leg Extension",
            InjuryKey(part: .knee, severity: .avoid):        nil,
        ],
        "Barbell Deadlift": [
            InjuryKey(part: .lowerBack, severity: .mild):    "Romanian Deadlift",
            InjuryKey(part: .lowerBack, severity: .moderate):"Cable Pull-Through",
            InjuryKey(part: .lowerBack, severity: .avoid):   nil,
        ],
        "Romanian Deadlift": [
            InjuryKey(part: .lowerBack, severity: .mild):    "Cable Pull-Through",
            InjuryKey(part: .lowerBack, severity: .avoid):   nil,
        ],
        "Barbell Curl": [
            InjuryKey(part: .wrist, severity: .mild):        "Hammer Curl",
            InjuryKey(part: .wrist, severity: .moderate):    "Cable Curl",
            InjuryKey(part: .wrist, severity: .avoid):       nil,
        ],
        "Dumbbell Curl": [
            InjuryKey(part: .wrist, severity: .moderate):    "Cable Curl",
            InjuryKey(part: .wrist, severity: .avoid):       nil,
        ],
        "Barbell Row": [
            InjuryKey(part: .lowerBack, severity: .mild):    "Cable Row",
            InjuryKey(part: .lowerBack, severity: .avoid):   nil,
        ],
        "Skull Crushers": [
            InjuryKey(part: .elbow, severity: .mild):        "Cable Tricep Pushdown",
            InjuryKey(part: .elbow, severity: .moderate):    "Tricep Dips (Assisted)",
            InjuryKey(part: .elbow, severity: .avoid):       nil,
        ],
        "Tricep Dips": [
            InjuryKey(part: .elbow, severity: .moderate):    "Cable Tricep Pushdown",
            InjuryKey(part: .elbow, severity: .avoid):       nil,
        ],
        "Hip Thrust": [
            InjuryKey(part: .hip, severity: .mild):          "Glute Bridge",
            InjuryKey(part: .hip, severity: .moderate):      "Glute Bridge",
            InjuryKey(part: .hip, severity: .avoid):         nil,
        ],
        "Barbell Hip Thrust": [
            InjuryKey(part: .hip, severity: .mild):          "Dumbbell Glute Bridge",
            InjuryKey(part: .hip, severity: .avoid):         nil,
        ],
        "Box Jump": [
            InjuryKey(part: .ankle, severity: .mild):        "Step-Up",
            InjuryKey(part: .ankle, severity: .avoid):       nil,
        ],
        "Jump Rope": [
            InjuryKey(part: .ankle, severity: .mild):        "Rowing Machine",
            InjuryKey(part: .ankle, severity: .avoid):       nil,
        ],
        "Calf Raise": [
            InjuryKey(part: .ankle, severity: .mild):        "Seated Calf Raise",
            InjuryKey(part: .ankle, severity: .avoid):       nil,
        ],
        "Lateral Lunge": [
            InjuryKey(part: .knee, severity: .mild):         "Sumo Squat",
            InjuryKey(part: .knee, severity: .avoid):        nil,
        ],
        "Incline Barbell Press": [
            InjuryKey(part: .shoulder, severity: .moderate): "Machine Chest Press",
            InjuryKey(part: .shoulder, severity: .avoid):    nil,
        ],
        "Incline Dumbbell Press": [
            InjuryKey(part: .shoulder, severity: .avoid):    nil,
        ],
    ]

    static let safePool: [RecommendedExercise] = [
        RecommendedExercise(name: "Machine Chest Press", sets: 3, reps: "10-12",    equipment: "Machine",    primaryMuscle: "chest"),
        RecommendedExercise(name: "Cable Fly",           sets: 3, reps: "12-15",    equipment: "Machine",    primaryMuscle: "chest"),
        RecommendedExercise(name: "Lat Pulldown",        sets: 3, reps: "10-12",    equipment: "Machine",    primaryMuscle: "lats"),
        RecommendedExercise(name: "Seated Cable Row",    sets: 3, reps: "10-12",    equipment: "Machine",    primaryMuscle: "lats"),
        RecommendedExercise(name: "Leg Extension",       sets: 3, reps: "12-15",    equipment: "Machine",    primaryMuscle: "quads"),
        RecommendedExercise(name: "Wall Sit",            sets: 3, reps: "30s",      equipment: "Bodyweight", primaryMuscle: "quads"),
        RecommendedExercise(name: "Leg Curl",            sets: 3, reps: "12-15",    equipment: "Machine",    primaryMuscle: "hamstrings"),
        RecommendedExercise(name: "Cable Kickback",      sets: 3, reps: "15",       equipment: "Machine",    primaryMuscle: "glutes"),
        RecommendedExercise(name: "Band Pull-Apart",     sets: 3, reps: "20",       equipment: "Bodyweight", primaryMuscle: "rear_delts"),
        RecommendedExercise(name: "Face Pull",           sets: 3, reps: "15",       equipment: "Machine",    primaryMuscle: "rear_delts"),
        RecommendedExercise(name: "Cable Curl",          sets: 3, reps: "12",       equipment: "Machine",    primaryMuscle: "biceps"),
        RecommendedExercise(name: "Tricep Pushdown",     sets: 3, reps: "12-15",    equipment: "Machine",    primaryMuscle: "triceps"),
        RecommendedExercise(name: "Plank",               sets: 3, reps: "30s",      equipment: "Bodyweight", primaryMuscle: "core"),
        RecommendedExercise(name: "Dead Bug",            sets: 3, reps: "10/side",  equipment: "Bodyweight", primaryMuscle: "core"),
    ]

    static func apply(to recommendations: inout [SplitRecommendation], input: SplitFinderInput) {
        guard !input.injuries.isEmpty else { return }
        let minEx = WarmupLibrary.budget(sessionMinutes: input.sessionMinutes).minExercises
        for i in recommendations.indices {
            for j in recommendations[i].days.indices where !recommendations[i].days[j].isRest {
                recommendations[i].days[j].exercises = processDay(
                    exercises: recommendations[i].days[j].exercises,
                    injuries: input.injuries,
                    minCount: minEx,
                    equipment: input.equipment
                )
            }
        }
    }

    private static func processDay(
        exercises: [RecommendedExercise],
        injuries: [InjuryEntry],
        minCount: Int,
        equipment: EquipmentProfile
    ) -> [RecommendedExercise] {
        var result: [RecommendedExercise] = []
        for ex in exercises {
            if let sub = substitute(exercise: ex, injuries: injuries) {
                result.append(sub)
            }
        }
        if result.count < minCount {
            let needed = minCount - result.count
            let existingNames = Set(result.map { $0.name })
            let candidates = safePool
                .filter { !existingNames.contains($0.name) }
                .sorted { equipScore($0, equipment: equipment) > equipScore($1, equipment: equipment) }
            result += candidates.prefix(needed)
        }
        return result
    }

    private static func substitute(exercise: RecommendedExercise, injuries: [InjuryEntry]) -> RecommendedExercise? {
        for injury in injuries {
            let key = InjuryKey(part: injury.part, severity: injury.severity)
            if let substitutions = map[exercise.name], substitutions[key] != nil {
                guard let subName = substitutions[key]! else { return nil }
                if let poolEx = safePool.first(where: { $0.name == subName }) {
                    return RecommendedExercise(name: poolEx.name, sets: exercise.sets,
                                               reps: exercise.reps, equipment: poolEx.equipment,
                                               primaryMuscle: poolEx.primaryMuscle)
                }
                return RecommendedExercise(name: subName, sets: exercise.sets,
                                           reps: exercise.reps, equipment: exercise.equipment,
                                           primaryMuscle: exercise.primaryMuscle)
            }
        }
        return exercise
    }

    private static func equipScore(_ ex: RecommendedExercise, equipment: EquipmentProfile) -> Double {
        switch ex.equipment {
        case "Machine":    return equipment.machineRatio
        case "Dumbbell":   return equipment.dumbbellRatio
        case "Barbell":    return equipment.barbellRatio
        default:           return 1.0
        }
    }
}
