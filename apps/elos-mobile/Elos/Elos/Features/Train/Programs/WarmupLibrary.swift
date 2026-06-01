import Foundation

struct WarmupLibrary {

    static func budget(sessionMinutes: Int) -> (warmupMinutes: Int, minExercises: Int) {
        switch sessionMinutes {
        case ..<45:  return (5, 3)
        case 45:     return (8, 4)
        case 60:     return (10, 5)
        case 75:     return (10, 6)
        default:     return (12, 6)
        }
    }

    static func maxExercises(sessionMinutes: Int) -> Int {
        let (warmup, minEx) = budget(sessionMinutes: sessionMinutes)
        let workingMinutes = sessionMinutes - warmup
        let totalSets = workingMinutes / 3
        let fromSets = totalSets / 3
        return max(minEx, fromSets)
    }

    static func block(goal: TrainingGoal, style: WarmupStyle) -> [WarmupExercise] {
        switch style {
        case .dynamic:       return goal == .athletic ? athleticDynamic : liftingDynamic
        case .staticStretch: return staticBlock
        case .both:          return goal == .athletic ? athleticDynamic : liftingDynamic
        }
    }

    private static let liftingDynamic: [WarmupExercise] = [
        WarmupExercise(name: "Band Pull-Apart",  duration: "15 reps"),
        WarmupExercise(name: "Leg Swings",       duration: "10 reps/side"),
        WarmupExercise(name: "Hip Circles",      duration: "10 reps/side"),
        WarmupExercise(name: "Cat-Cow",          duration: "10 reps"),
        WarmupExercise(name: "Shoulder Circles", duration: "10 reps/side"),
    ]

    private static let athleticDynamic: [WarmupExercise] = [
        WarmupExercise(name: "High Knees",       duration: "30s"),
        WarmupExercise(name: "Lateral Shuffles", duration: "30s"),
        WarmupExercise(name: "Arm Circles",      duration: "20 reps"),
        WarmupExercise(name: "Inchworm",         duration: "5 reps"),
        WarmupExercise(name: "Jump Rope",        duration: "60s"),
    ]

    private static let staticBlock: [WarmupExercise] = [
        WarmupExercise(name: "Chest Opener",       duration: "30s/side"),
        WarmupExercise(name: "Hip Flexor Stretch", duration: "30s/side"),
        WarmupExercise(name: "Hamstring Stretch",  duration: "30s/side"),
        WarmupExercise(name: "Thoracic Rotation",  duration: "30s/side"),
    ]
}
