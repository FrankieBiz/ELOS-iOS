import Foundation

enum ExerciseAlternatives {
    static func pool(for muscle: String) -> [RecommendedExercise] {
        switch muscle {
        case "chest":           return chest
        case "lats":            return lats
        case "quads":           return quads
        case "hamstrings":      return hamstrings
        case "glutes":          return glutes
        case "lower_back":      return lowerBack
        case "front_delts":     return frontDelts
        case "side_delts":      return sideDelts
        case "rear_delts":      return rearDelts
        case "biceps":          return biceps
        case "triceps":         return triceps
        case "calves":          return calves
        case "core":            return core
        default:                return []
        }
    }

    private static let chest: [RecommendedExercise] = [
        RecommendedExercise(name: "Barbell Bench Press",     sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "chest"),
        RecommendedExercise(name: "Dumbbell Bench Press",    sets: 4, reps: "10", equipment: "Dumbbell",   primaryMuscle: "chest"),
        RecommendedExercise(name: "Incline Barbell Press",   sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "chest"),
        RecommendedExercise(name: "Incline Dumbbell Press",  sets: 4, reps: "10", equipment: "Dumbbell",   primaryMuscle: "chest"),
        RecommendedExercise(name: "Machine Chest Press",     sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "chest"),
        RecommendedExercise(name: "Cable Fly",               sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "chest"),
        RecommendedExercise(name: "Push-Up",                 sets: 3, reps: "15", equipment: "Bodyweight", primaryMuscle: "chest"),
    ]

    private static let lats: [RecommendedExercise] = [
        RecommendedExercise(name: "Barbell Row",             sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "lats"),
        RecommendedExercise(name: "Dumbbell Row",            sets: 4, reps: "10", equipment: "Dumbbell",   primaryMuscle: "lats"),
        RecommendedExercise(name: "Lat Pulldown",            sets: 4, reps: "10", equipment: "Machine",    primaryMuscle: "lats"),
        RecommendedExercise(name: "Cable Row",               sets: 4, reps: "10", equipment: "Machine",    primaryMuscle: "lats"),
        RecommendedExercise(name: "T-Bar Row",               sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "lats"),
        RecommendedExercise(name: "Pull-Ups",                sets: 3, reps: "8",  equipment: "Bodyweight", primaryMuscle: "lats"),
    ]

    private static let quads: [RecommendedExercise] = [
        RecommendedExercise(name: "Barbell Back Squat",      sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "quads"),
        RecommendedExercise(name: "Front Squat",             sets: 4, reps: "6",  equipment: "Barbell",    primaryMuscle: "quads"),
        RecommendedExercise(name: "Leg Press",               sets: 4, reps: "10", equipment: "Machine",    primaryMuscle: "quads"),
        RecommendedExercise(name: "Hack Squat",              sets: 4, reps: "8",  equipment: "Machine",    primaryMuscle: "quads"),
        RecommendedExercise(name: "Leg Extension",           sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "quads"),
        RecommendedExercise(name: "Goblet Squat",            sets: 3, reps: "10", equipment: "Dumbbell",   primaryMuscle: "quads"),
        RecommendedExercise(name: "Bulgarian Split Squat",   sets: 3, reps: "10/side", equipment: "Dumbbell", primaryMuscle: "quads"),
    ]

    private static let hamstrings: [RecommendedExercise] = [
        RecommendedExercise(name: "Romanian Deadlift",       sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "hamstrings"),
        RecommendedExercise(name: "Dumbbell RDL",            sets: 4, reps: "10", equipment: "Dumbbell",   primaryMuscle: "hamstrings"),
        RecommendedExercise(name: "Leg Curl",                sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "hamstrings"),
        RecommendedExercise(name: "Good Morning",            sets: 3, reps: "10", equipment: "Barbell",    primaryMuscle: "hamstrings"),
        RecommendedExercise(name: "Nordic Curl",             sets: 3, reps: "6",  equipment: "Bodyweight", primaryMuscle: "hamstrings"),
    ]

    private static let glutes: [RecommendedExercise] = [
        RecommendedExercise(name: "Hip Thrust",              sets: 4, reps: "10", equipment: "Barbell",    primaryMuscle: "glutes"),
        RecommendedExercise(name: "Dumbbell Hip Thrust",     sets: 4, reps: "12", equipment: "Dumbbell",   primaryMuscle: "glutes"),
        RecommendedExercise(name: "Sumo Deadlift",           sets: 4, reps: "6",  equipment: "Barbell",    primaryMuscle: "glutes"),
        RecommendedExercise(name: "Cable Pull-Through",      sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "glutes"),
        RecommendedExercise(name: "Step-Up",                 sets: 3, reps: "10/side", equipment: "Dumbbell", primaryMuscle: "glutes"),
    ]

    private static let lowerBack: [RecommendedExercise] = [
        RecommendedExercise(name: "Barbell Deadlift",        sets: 4, reps: "5",  equipment: "Barbell",    primaryMuscle: "lower_back"),
        RecommendedExercise(name: "Romanian Deadlift",       sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "lower_back"),
        RecommendedExercise(name: "Trap Bar Deadlift",       sets: 4, reps: "5",  equipment: "Barbell",    primaryMuscle: "lower_back"),
        RecommendedExercise(name: "Back Extension",          sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "lower_back"),
        RecommendedExercise(name: "Good Morning",            sets: 3, reps: "10", equipment: "Barbell",    primaryMuscle: "lower_back"),
    ]

    private static let frontDelts: [RecommendedExercise] = [
        RecommendedExercise(name: "Barbell Overhead Press",  sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "front_delts"),
        RecommendedExercise(name: "Dumbbell Shoulder Press", sets: 3, reps: "10", equipment: "Dumbbell",   primaryMuscle: "front_delts"),
        RecommendedExercise(name: "Arnold Press",            sets: 3, reps: "10", equipment: "Dumbbell",   primaryMuscle: "front_delts"),
        RecommendedExercise(name: "Machine Shoulder Press",  sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "front_delts"),
        RecommendedExercise(name: "Pike Push-Up",            sets: 3, reps: "10", equipment: "Bodyweight", primaryMuscle: "front_delts"),
    ]

    private static let sideDelts: [RecommendedExercise] = [
        RecommendedExercise(name: "Dumbbell Lateral Raise",  sets: 3, reps: "12", equipment: "Dumbbell",   primaryMuscle: "side_delts"),
        RecommendedExercise(name: "Cable Lateral Raise",     sets: 3, reps: "15", equipment: "Machine",    primaryMuscle: "side_delts"),
        RecommendedExercise(name: "Machine Lateral Raise",   sets: 3, reps: "15", equipment: "Machine",    primaryMuscle: "side_delts"),
        RecommendedExercise(name: "Upright Row",             sets: 3, reps: "12", equipment: "Barbell",    primaryMuscle: "side_delts"),
    ]

    private static let rearDelts: [RecommendedExercise] = [
        RecommendedExercise(name: "Face Pull",               sets: 3, reps: "15", equipment: "Machine",    primaryMuscle: "rear_delts"),
        RecommendedExercise(name: "Rear Delt Fly",           sets: 3, reps: "15", equipment: "Dumbbell",   primaryMuscle: "rear_delts"),
        RecommendedExercise(name: "Reverse Pec Deck",        sets: 3, reps: "15", equipment: "Machine",    primaryMuscle: "rear_delts"),
        RecommendedExercise(name: "Band Pull-Apart",         sets: 3, reps: "20", equipment: "Bodyweight", primaryMuscle: "rear_delts"),
    ]

    private static let biceps: [RecommendedExercise] = [
        RecommendedExercise(name: "Barbell Curl",            sets: 3, reps: "10", equipment: "Barbell",    primaryMuscle: "biceps"),
        RecommendedExercise(name: "Dumbbell Curl",           sets: 3, reps: "12", equipment: "Dumbbell",   primaryMuscle: "biceps"),
        RecommendedExercise(name: "Hammer Curl",             sets: 3, reps: "12", equipment: "Dumbbell",   primaryMuscle: "biceps"),
        RecommendedExercise(name: "Cable Curl",              sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "biceps"),
        RecommendedExercise(name: "Preacher Curl",           sets: 3, reps: "10", equipment: "Barbell",    primaryMuscle: "biceps"),
    ]

    private static let triceps: [RecommendedExercise] = [
        RecommendedExercise(name: "Skull Crushers",              sets: 3, reps: "10", equipment: "Barbell",    primaryMuscle: "triceps"),
        RecommendedExercise(name: "Tricep Pushdown",             sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "triceps"),
        RecommendedExercise(name: "Close-Grip Bench Press",      sets: 3, reps: "10", equipment: "Barbell",    primaryMuscle: "triceps"),
        RecommendedExercise(name: "Overhead Tricep Extension",   sets: 3, reps: "12", equipment: "Dumbbell",   primaryMuscle: "triceps"),
        RecommendedExercise(name: "Tricep Dips",                 sets: 3, reps: "10", equipment: "Bodyweight", primaryMuscle: "triceps"),
    ]

    private static let calves: [RecommendedExercise] = [
        RecommendedExercise(name: "Calf Raise",              sets: 4, reps: "15", equipment: "Machine",    primaryMuscle: "calves"),
        RecommendedExercise(name: "Standing Calf Raise",     sets: 4, reps: "15", equipment: "Dumbbell",   primaryMuscle: "calves"),
        RecommendedExercise(name: "Seated Calf Raise",       sets: 3, reps: "15", equipment: "Machine",    primaryMuscle: "calves"),
        RecommendedExercise(name: "Donkey Calf Raise",       sets: 4, reps: "15", equipment: "Machine",    primaryMuscle: "calves"),
    ]

    private static let core: [RecommendedExercise] = [
        RecommendedExercise(name: "Plank",                   sets: 3, reps: "45s",     equipment: "Bodyweight", primaryMuscle: "core"),
        RecommendedExercise(name: "Dead Bug",                sets: 3, reps: "10/side", equipment: "Bodyweight", primaryMuscle: "core"),
        RecommendedExercise(name: "Ab Wheel Rollout",        sets: 3, reps: "10",      equipment: "Bodyweight", primaryMuscle: "core"),
        RecommendedExercise(name: "Pallof Press",            sets: 3, reps: "10/side", equipment: "Machine",    primaryMuscle: "core"),
        RecommendedExercise(name: "Cable Crunch",            sets: 3, reps: "15",      equipment: "Machine",    primaryMuscle: "core"),
        RecommendedExercise(name: "Hanging Leg Raise",       sets: 3, reps: "12",      equipment: "Bodyweight", primaryMuscle: "core"),
    ]
}
