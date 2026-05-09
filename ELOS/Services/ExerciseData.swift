import Foundation
import SwiftUI

// MARK: - Static exercise library (~100 common exercises)

struct ExerciseDefinition: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let muscleGroup: String
    let secondaryMuscles: [String]
    let equipment: String
    let isCompound: Bool
    let description: String

    var icon: String {
        switch muscleGroup {
        case "Chest":     return "figure.strengthtraining.traditional"
        case "Back":      return "figure.rower"
        case "Shoulders": return "figure.strengthtraining.functional"
        case "Biceps":    return "figure.arms.open"
        case "Triceps":   return "figure.arms.open"
        case "Legs":      return "figure.run"
        case "Glutes":    return "figure.run"
        case "Core":      return "figure.core.training"
        case "Cardio":    return "figure.run.treadmill"
        case "Forearms":  return "hand.raised.fill"
        case "Traps":     return "person.crop.rectangle"
        default:          return "dumbbell.fill"
        }
    }

    var color: Color {
        switch muscleGroup {
        case "Chest":     return Color(hex: "#FF453A")
        case "Back":      return Color(hex: "#5E5CE6")
        case "Shoulders": return Color(hex: "#FF9F0A")
        case "Biceps":    return Color(hex: "#30D158")
        case "Triceps":   return Color(hex: "#0A84FF")
        case "Legs":      return Color(hex: "#BF5AF2")
        case "Glutes":    return Color(hex: "#FF375F")
        case "Core":      return Color(hex: "#64D2FF")
        case "Cardio":    return Color(hex: "#FFD60A")
        case "Forearms":  return Color(hex: "#FF6B35")
        case "Traps":     return Color(hex: "#5E5CE6")
        default:          return .brand
        }
    }
}

extension ExerciseDefinition {
    static let library: [ExerciseDefinition] = [
        // CHEST
        .init(id: "chest_1", name: "Barbell Bench Press", muscleGroup: "Chest", secondaryMuscles: ["Triceps", "Shoulders"], equipment: "Barbell", isCompound: true,  description: "Lie on a flat bench, grip the bar slightly wider than shoulder-width. Lower to chest, press up explosively."),
        .init(id: "chest_2", name: "Incline Dumbbell Press", muscleGroup: "Chest", secondaryMuscles: ["Triceps", "Shoulders"], equipment: "Dumbbell", isCompound: true, description: "Bench at 30–45°. Press dumbbells from chest level — emphasizes upper chest."),
        .init(id: "chest_3", name: "Cable Fly", muscleGroup: "Chest", secondaryMuscles: [], equipment: "Cable", isCompound: false, description: "Cables at shoulder height. Bring hands together in an arc, squeeze chest at peak."),
        .init(id: "chest_4", name: "Dumbbell Fly", muscleGroup: "Chest", secondaryMuscles: [], equipment: "Dumbbell", isCompound: false, description: "Lie flat. Open arms wide with slight elbow bend, squeeze chest to bring DBs together."),
        .init(id: "chest_5", name: "Push-Up", muscleGroup: "Chest", secondaryMuscles: ["Triceps", "Shoulders"], equipment: "Bodyweight", isCompound: true, description: "Body rigid, lower chest to floor, press back up. Hands slightly wider than shoulders."),
        .init(id: "chest_6", name: "Chest Dips", muscleGroup: "Chest", secondaryMuscles: ["Triceps"], equipment: "Bodyweight", isCompound: true, description: "Lean forward on parallel bars. Lower until 90° at elbows, press back up."),
        .init(id: "chest_7", name: "Pec Deck", muscleGroup: "Chest", secondaryMuscles: [], equipment: "Machine", isCompound: false, description: "Sit upright, squeeze handles together, pause at peak contraction."),
        .init(id: "chest_8", name: "Decline Bench Press", muscleGroup: "Chest", secondaryMuscles: ["Triceps"], equipment: "Barbell", isCompound: true, description: "Decline bench. Targets lower chest fibers more than flat or incline."),

        // BACK
        .init(id: "back_1", name: "Deadlift", muscleGroup: "Back", secondaryMuscles: ["Legs", "Core", "Traps"], equipment: "Barbell", isCompound: true, description: "Hip-hinge from the floor. Drive through heels, lock hips at the top. King of compound lifts."),
        .init(id: "back_2", name: "Pull-Up", muscleGroup: "Back", secondaryMuscles: ["Biceps"], equipment: "Bodyweight", isCompound: true, description: "Overhand grip. Pull chest to bar, retract shoulder blades."),
        .init(id: "back_3", name: "Barbell Row", muscleGroup: "Back", secondaryMuscles: ["Biceps", "Rear Delts"], equipment: "Barbell", isCompound: true, description: "Hinge at hips. Pull bar to navel, keep back flat."),
        .init(id: "back_4", name: "Lat Pulldown", muscleGroup: "Back", secondaryMuscles: ["Biceps"], equipment: "Cable", isCompound: true, description: "Pull bar to upper chest, drive elbows down and back."),
        .init(id: "back_5", name: "Seated Cable Row", muscleGroup: "Back", secondaryMuscles: ["Biceps", "Rear Delts"], equipment: "Cable", isCompound: true, description: "Row to navel, retract scapula fully, hold 1s at peak."),
        .init(id: "back_6", name: "Dumbbell Row", muscleGroup: "Back", secondaryMuscles: ["Biceps"], equipment: "Dumbbell", isCompound: true, description: "One knee on bench. Row DB to hip, elbow tight to torso."),
        .init(id: "back_7", name: "Face Pull", muscleGroup: "Back", secondaryMuscles: ["Rear Delts"], equipment: "Cable", isCompound: false, description: "Rope to face, flare elbows. Best rear-delt and rotator-cuff prehab."),
        .init(id: "back_8", name: "Chin-Up", muscleGroup: "Back", secondaryMuscles: ["Biceps"], equipment: "Bodyweight", isCompound: true, description: "Underhand grip pull-up. More biceps engagement than standard pull-up."),
        .init(id: "back_9", name: "T-Bar Row", muscleGroup: "Back", secondaryMuscles: ["Biceps"], equipment: "Barbell", isCompound: true, description: "Landmine T-bar row, neutral grip. Heavy mid-back loading."),
        .init(id: "back_10", name: "Hyperextension", muscleGroup: "Back", secondaryMuscles: ["Glutes", "Hamstrings"], equipment: "Bodyweight", isCompound: false, description: "Bench-supported back extension. Lower-back strength + glute bias."),

        // SHOULDERS
        .init(id: "sh_1", name: "Overhead Press", muscleGroup: "Shoulders", secondaryMuscles: ["Triceps"], equipment: "Barbell", isCompound: true, description: "Press bar overhead from shoulder height. Brace core hard."),
        .init(id: "sh_2", name: "Lateral Raise", muscleGroup: "Shoulders", secondaryMuscles: [], equipment: "Dumbbell", isCompound: false, description: "Raise dumbbells to shoulder height with slight elbow bend. Medial delt isolation."),
        .init(id: "sh_3", name: "Arnold Press", muscleGroup: "Shoulders", secondaryMuscles: ["Triceps"], equipment: "Dumbbell", isCompound: true, description: "Start palms in, rotate out as you press up. Hits all 3 delt heads."),
        .init(id: "sh_4", name: "Front Raise", muscleGroup: "Shoulders", secondaryMuscles: [], equipment: "Dumbbell", isCompound: false, description: "Raise DBs forward to shoulder height. Anterior deltoid focus."),
        .init(id: "sh_5", name: "Rear Delt Fly", muscleGroup: "Shoulders", secondaryMuscles: [], equipment: "Dumbbell", isCompound: false, description: "Bent over, raise DBs to sides. Rear delt + upper back."),
        .init(id: "sh_6", name: "Cable Lateral Raise", muscleGroup: "Shoulders", secondaryMuscles: [], equipment: "Cable", isCompound: false, description: "Constant tension lateral raise. Best medial delt isolation."),
        .init(id: "sh_7", name: "Seated DB Press", muscleGroup: "Shoulders", secondaryMuscles: ["Triceps"], equipment: "Dumbbell", isCompound: true, description: "Seated dumbbell shoulder press. Allows greater ROM than barbell."),

        // BICEPS
        .init(id: "bi_1", name: "Barbell Curl", muscleGroup: "Biceps", secondaryMuscles: [], equipment: "Barbell", isCompound: false, description: "Supinated curl, elbows pinned to sides. Full ROM."),
        .init(id: "bi_2", name: "Dumbbell Curl", muscleGroup: "Biceps", secondaryMuscles: [], equipment: "Dumbbell", isCompound: false, description: "Alternating or simultaneous curls. Supinate as you curl."),
        .init(id: "bi_3", name: "Hammer Curl", muscleGroup: "Biceps", secondaryMuscles: ["Brachialis"], equipment: "Dumbbell", isCompound: false, description: "Neutral grip. Targets brachialis and brachioradialis."),
        .init(id: "bi_4", name: "Preacher Curl", muscleGroup: "Biceps", secondaryMuscles: [], equipment: "Barbell", isCompound: false, description: "Arms braced on pad. Strict bicep isolation, no shoulder cheat."),
        .init(id: "bi_5", name: "Cable Curl", muscleGroup: "Biceps", secondaryMuscles: [], equipment: "Cable", isCompound: false, description: "Constant tension. Excellent peak contraction."),
        .init(id: "bi_6", name: "Concentration Curl", muscleGroup: "Biceps", secondaryMuscles: [], equipment: "Dumbbell", isCompound: false, description: "Seated, elbow on inner thigh. Best for peak development."),
        .init(id: "bi_7", name: "Incline DB Curl", muscleGroup: "Biceps", secondaryMuscles: [], equipment: "Dumbbell", isCompound: false, description: "Incline bench curl. Long-head bias from stretched position."),

        // TRICEPS
        .init(id: "tri_1", name: "Skull Crushers", muscleGroup: "Triceps", secondaryMuscles: [], equipment: "Barbell", isCompound: false, description: "Lower bar to forehead on flat bench, extend back. Long-head emphasis."),
        .init(id: "tri_2", name: "Tricep Dips", muscleGroup: "Triceps", secondaryMuscles: [], equipment: "Bodyweight", isCompound: true, description: "Upright torso on bars. Triceps bias over chest."),
        .init(id: "tri_3", name: "Cable Pushdown", muscleGroup: "Triceps", secondaryMuscles: [], equipment: "Cable", isCompound: false, description: "Push rope/bar down, fully extend. Elbows pinned."),
        .init(id: "tri_4", name: "Close-Grip Bench", muscleGroup: "Triceps", secondaryMuscles: ["Chest"], equipment: "Barbell", isCompound: true, description: "Hands shoulder-width. Heavy compound triceps."),
        .init(id: "tri_5", name: "Overhead Tri Extension", muscleGroup: "Triceps", secondaryMuscles: [], equipment: "Dumbbell", isCompound: false, description: "Hold DB overhead 2-handed, lower behind head, extend up."),
        .init(id: "tri_6", name: "Diamond Push-Up", muscleGroup: "Triceps", secondaryMuscles: ["Chest"], equipment: "Bodyweight", isCompound: true, description: "Hands in diamond shape. Best bodyweight tricep movement."),

        // LEGS
        .init(id: "leg_1", name: "Back Squat", muscleGroup: "Legs", secondaryMuscles: ["Core", "Glutes"], equipment: "Barbell", isCompound: true, description: "Bar on upper traps. Squat to parallel or below. King of leg lifts."),
        .init(id: "leg_2", name: "Romanian Deadlift", muscleGroup: "Legs", secondaryMuscles: ["Glutes", "Lower Back"], equipment: "Barbell", isCompound: true, description: "Hinge at hips, slight knee bend. Hamstring focus."),
        .init(id: "leg_3", name: "Leg Press", muscleGroup: "Legs", secondaryMuscles: ["Glutes"], equipment: "Machine", isCompound: true, description: "Feet shoulder-width. 90° at knees, drive back."),
        .init(id: "leg_4", name: "Walking Lunges", muscleGroup: "Legs", secondaryMuscles: ["Glutes"], equipment: "Dumbbell", isCompound: true, description: "Step into lunge, alternate. Unilateral quad + glute."),
        .init(id: "leg_5", name: "Leg Curl", muscleGroup: "Legs", secondaryMuscles: [], equipment: "Machine", isCompound: false, description: "Curl by knee flexion. Hamstring isolation."),
        .init(id: "leg_6", name: "Leg Extension", muscleGroup: "Legs", secondaryMuscles: [], equipment: "Machine", isCompound: false, description: "Quadriceps isolation. Pause at top contraction."),
        .init(id: "leg_7", name: "Hack Squat", muscleGroup: "Legs", secondaryMuscles: [], equipment: "Machine", isCompound: true, description: "Machine squat. Quad focus, less spinal load."),
        .init(id: "leg_8", name: "Bulgarian Split Squat", muscleGroup: "Legs", secondaryMuscles: ["Glutes"], equipment: "Dumbbell", isCompound: true, description: "Rear foot elevated. Best unilateral leg balance work."),
        .init(id: "leg_9", name: "Calf Raise", muscleGroup: "Legs", secondaryMuscles: [], equipment: "Machine", isCompound: false, description: "Rise on toes. Both standing & seated for soleus/gastroc."),
        .init(id: "leg_10", name: "Front Squat", muscleGroup: "Legs", secondaryMuscles: ["Core"], equipment: "Barbell", isCompound: true, description: "Bar in front rack. Upright torso = quad emphasis."),

        // GLUTES
        .init(id: "glu_1", name: "Hip Thrust", muscleGroup: "Glutes", secondaryMuscles: ["Hamstrings"], equipment: "Barbell", isCompound: true, description: "Shoulders on bench, drive hips up with bar across hips. Best glute activator."),
        .init(id: "glu_2", name: "Glute Bridge", muscleGroup: "Glutes", secondaryMuscles: ["Hamstrings"], equipment: "Bodyweight", isCompound: false, description: "Lie on back, bridge hips up, squeeze glutes. Progress to BB."),
        .init(id: "glu_3", name: "Cable Kickback", muscleGroup: "Glutes", secondaryMuscles: [], equipment: "Cable", isCompound: false, description: "Ankle strap. Kick back & up, squeeze glute at top."),
        .init(id: "glu_4", name: "Sumo Deadlift", muscleGroup: "Glutes", secondaryMuscles: ["Legs", "Back"], equipment: "Barbell", isCompound: true, description: "Wide stance, toes out. Glute + adductor focus."),

        // CORE
        .init(id: "co_1", name: "Plank", muscleGroup: "Core", secondaryMuscles: [], equipment: "Bodyweight", isCompound: false, description: "Rigid hold on forearms. Don't let hips sag."),
        .init(id: "co_2", name: "Cable Crunch", muscleGroup: "Core", secondaryMuscles: [], equipment: "Cable", isCompound: false, description: "Kneel, crunch down against cable. Best weighted ab move."),
        .init(id: "co_3", name: "Hanging Leg Raise", muscleGroup: "Core", secondaryMuscles: [], equipment: "Bodyweight", isCompound: false, description: "Hang from bar, raise legs to 90°+. Lower abs + hip flexors."),
        .init(id: "co_4", name: "Ab Wheel Rollout", muscleGroup: "Core", secondaryMuscles: [], equipment: "Wheel", isCompound: false, description: "Roll out from kneeling, extend fully, return slow."),
        .init(id: "co_5", name: "Russian Twist", muscleGroup: "Core", secondaryMuscles: [], equipment: "Bodyweight", isCompound: false, description: "Seated, feet up, twist torso. Add a plate for progression."),
        .init(id: "co_6", name: "Dead Bug", muscleGroup: "Core", secondaryMuscles: [], equipment: "Bodyweight", isCompound: false, description: "Lying on back, opposite arm + leg extension. Anti-extension."),

        // FOREARMS / TRAPS
        .init(id: "fo_1", name: "Wrist Curl", muscleGroup: "Forearms", secondaryMuscles: [], equipment: "Barbell", isCompound: false, description: "Forearms on thighs, curl wrists up. Wrist flexors."),
        .init(id: "fo_2", name: "Reverse Curl", muscleGroup: "Forearms", secondaryMuscles: ["Biceps"], equipment: "Barbell", isCompound: false, description: "Overhand curl. Brachioradialis + extensors."),
        .init(id: "tr_1", name: "Barbell Shrug", muscleGroup: "Traps", secondaryMuscles: [], equipment: "Barbell", isCompound: false, description: "Heavy shrug to ears. Pause at top."),
        .init(id: "tr_2", name: "Dumbbell Shrug", muscleGroup: "Traps", secondaryMuscles: [], equipment: "Dumbbell", isCompound: false, description: "DB shrug. More natural ROM than barbell."),

        // CARDIO
        .init(id: "ca_1", name: "Treadmill", muscleGroup: "Cardio", secondaryMuscles: [], equipment: "Machine", isCompound: false, description: "Steady-state or interval running. Log duration & pace."),
        .init(id: "ca_2", name: "Rowing", muscleGroup: "Cardio", secondaryMuscles: ["Back", "Legs"], equipment: "Machine", isCompound: true, description: "Legs drive first, then hips, then arms. Full-body conditioning."),
        .init(id: "ca_3", name: "Stair Climber", muscleGroup: "Cardio", secondaryMuscles: ["Glutes", "Legs"], equipment: "Machine", isCompound: false, description: "Glute & quad bias for cardio."),
        .init(id: "ca_4", name: "Jump Rope", muscleGroup: "Cardio", secondaryMuscles: ["Calves"], equipment: "Other", isCompound: false, description: "Low equipment, high intensity. Progress to double-unders."),
    ]

    static var muscleGroups: [String] {
        Array(Set(library.map(\.muscleGroup))).sorted { $0 < $1 }
    }

    static func search(_ q: String) -> [ExerciseDefinition] {
        guard !q.isEmpty else { return library }
        let lower = q.lowercased()
        return library.filter {
            $0.name.lowercased().contains(lower) ||
            $0.muscleGroup.lowercased().contains(lower) ||
            $0.equipment.lowercased().contains(lower)
        }
    }

    static func find(name: String) -> ExerciseDefinition? {
        library.first { $0.name == name }
    }

    static func find(id: String) -> ExerciseDefinition? {
        library.first { $0.id == id }
    }
}
