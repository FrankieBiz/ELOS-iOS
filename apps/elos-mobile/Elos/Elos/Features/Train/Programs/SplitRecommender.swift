import Foundation

private struct CandidateTemplate {
    let style: SplitStyle
    let compatibleDays: [Int]
    let days: [TemplateDay]
}

private struct TemplateDay {
    let label: String
    let isRest: Bool
    let exercises: [RecommendedExercise]
}

struct SplitRecommender {

    static func recommend(input: SplitFinderInput) -> [SplitRecommendation] {
        var eligible = allTemplates
            .filter { $0.compatibleDays.contains(input.daysPerWeek) }
            .filter { passes(eligibility: $0, input: input) }

        if let preferred = input.preferredStructure {
            let constrained = eligible.filter { $0.style == preferred }
            if !constrained.isEmpty { eligible = constrained }
        }

        let scored = eligible.map { template -> (CandidateTemplate, Double, Double, Double) in
            let gs    = goalScore(template: template, goal: input.goal)
            let sm    = sportModifier(template: template, input: input)
            let es    = equipmentScore(template: template, equipment: input.equipment)
            let ip    = injuryPenalty(template: template, injuries: input.injuries)
            let final = (gs + sm) * 0.40 + es * 0.35 + (1.0 - ip) * 0.25
            return (template, gs, es, final)
        }
        .sorted { $0.3 > $1.3 }

        var chosen: [(CandidateTemplate, Double, Double, Double)] = []
        if input.preferredStructure != nil {
            chosen = Array(scored.prefix(3))
        } else {
            var seenStyles = Set<SplitStyle>()
            for item in scored {
                if chosen.count == 3 { break }
                if !seenStyles.contains(item.0.style) {
                    chosen.append(item); seenStyles.insert(item.0.style)
                }
            }
            if chosen.count < 3 {
                for item in scored where chosen.count < 3 {
                    if !chosen.contains(where: { $0.0.style == item.0.style && abs($0.3 - item.3) < 0.0001 }) {
                        chosen.append(item)
                    }
                }
            }
        }

        return chosen.map { (template, gs, es, finalScore) in
            build(template: template, input: input, goalScore: gs, equipmentScore: es, finalScore: finalScore)
        }
    }

    // MARK: - Eligibility

    private static func passes(eligibility template: CandidateTemplate, input: SplitFinderInput) -> Bool {
        if input.gymSize == .small {
            if template.style == .broSplit { return false }
            if input.equipment.barbellRatio > 0.5 {
                if template.style == .pushPullLegs || template.style == .arnold { return false }
            }
        }
        return true
    }

    // MARK: - Scoring

    private static func goalScore(template: CandidateTemplate, goal: TrainingGoal) -> Double {
        let table: [SplitStyle: [TrainingGoal: Double]] = [
            .fullBody:           [.hypertrophy: 0.5,  .strength: 0.6,  .athletic: 0.6, .general: 1.0],
            .upperLower:         [.hypertrophy: 0.7,  .strength: 1.0,  .athletic: 0.7, .general: 0.7],
            .pushPullLegs:       [.hypertrophy: 1.0,  .strength: 0.6,  .athletic: 0.5, .general: 0.6],
            .arnold:             [.hypertrophy: 0.95, .strength: 0.5,  .athletic: 0.4, .general: 0.5],
            .broSplit:           [.hypertrophy: 0.85, .strength: 0.5,  .athletic: 0.3, .general: 0.5],
            .athletic:           [.hypertrophy: 0.4,  .strength: 0.7,  .athletic: 1.0, .general: 0.6],
            .anteriorPosterior:  [.hypertrophy: 0.75, .strength: 0.85, .athletic: 0.55, .general: 0.70],
        ]
        return table[template.style]?[goal] ?? 0.5
    }

    private static func sportModifier(template: CandidateTemplate, input: SplitFinderInput) -> Double {
        guard input.sport != nil, input.sportFocusRatio > 0 else { return 0 }
        if template.style == .athletic { return input.sportFocusRatio * 0.3 }
        if input.sportFocusRatio > 0.5 { return -0.1 }
        return 0
    }

    private static func equipmentScore(template: CandidateTemplate, equipment: EquipmentProfile) -> Double {
        let all = template.days.flatMap { $0.exercises }
        guard !all.isEmpty else { return 1.0 }
        let matched = all.filter { ex in
            switch ex.equipment {
            case "Machine":    return equipment.machineRatio >= 0.2
            case "Dumbbell":   return equipment.dumbbellRatio >= 0.2
            case "Barbell":    return equipment.barbellRatio >= 0.2
            default:           return true
            }
        }
        return Double(matched.count) / Double(all.count)
    }

    private static func injuryPenalty(template: CandidateTemplate, injuries: [InjuryEntry]) -> Double {
        let avoidParts = injuries.filter { $0.severity == .avoid }.map { $0.part }
        guard !avoidParts.isEmpty else { return 0 }
        let muscleMap: [InjuredPart: Set<String>] = [
            .shoulder:  ["front_delts", "side_delts", "rear_delts"],
            .knee:      ["quads", "hamstrings"],
            .lowerBack: ["lower_back", "glutes"],
            .wrist:     ["forearms"],
            .elbow:     ["biceps", "triceps"],
            .hip:       ["hip_flexors", "glutes"],
            .ankle:     ["calves"],
        ]
        let avoidSet = Set(avoidParts.flatMap { muscleMap[$0] ?? [] })
        let conflicts = template.days.flatMap { $0.exercises }.filter { avoidSet.contains($0.primaryMuscle) }.count
        return min(Double(conflicts) * 0.05, 0.25)
    }

    // MARK: - Build

    private static func build(
        template: CandidateTemplate,
        input: SplitFinderInput,
        goalScore: Double,
        equipmentScore: Double,
        finalScore: Double
    ) -> SplitRecommendation {
        let maxEx = WarmupLibrary.maxExercises(sessionMinutes: input.sessionMinutes)
        let warmupBlock: [WarmupExercise] = input.includeWarmups
            ? WarmupLibrary.block(goal: input.goal, style: input.warmupStyle ?? .dynamic)
            : []

        let workoutDays = template.days.filter { !$0.isRest }.prefix(input.daysPerWeek)
        let builtDays: [RecommendedDay] = workoutDays.map { tDay in
            RecommendedDay(
                label: tDay.label, isRest: false,
                exercises: Array(tDay.exercises.prefix(maxEx)),
                warmupBlock: warmupBlock
            )
        }

        let tags = matchTags(finalScore: finalScore, goalScore: goalScore,
                             equipmentScore: equipmentScore, input: input, template: template)

        return SplitRecommendation(
            name: "\(input.daysPerWeek)-Day \(template.style.displayName)",
            style: template.style,
            days: builtDays,
            estimatedMinutes: input.sessionMinutes,
            matchScore: finalScore,
            matchTags: tags,
            includeWarmups: input.includeWarmups
        )
    }

    private static func matchTags(
        finalScore: Double, goalScore: Double, equipmentScore: Double,
        input: SplitFinderInput, template: CandidateTemplate
    ) -> [String] {
        var tags: [String] = []
        if finalScore >= 0.85    { tags.append("Excellent match") }
        if goalScore >= 0.9      { tags.append("Great for \(input.goal.displayName)") }
        if equipmentScore >= 0.9 { tags.append("Equipment-friendly") }
        if input.gymSize == .small && passes(eligibility: template, input: input) {
            tags.append("Works in any gym")
        }
        if input.sportFocusRatio >= 0.5 && template.style == .athletic {
            tags.append("Sport performance focus")
        }
        let muscleMap: [InjuredPart: Set<String>] = [
            .shoulder:  ["front_delts", "side_delts", "rear_delts"],
            .knee:      ["quads", "hamstrings"],
            .lowerBack: ["lower_back", "glutes"],
            .wrist:     ["forearms"],
            .elbow:     ["biceps", "triceps"],
            .hip:       ["hip_flexors", "glutes"],
            .ankle:     ["calves"],
        ]
        let allMuscles = Set(template.days.flatMap { $0.exercises }.map { $0.primaryMuscle })
        for entry in input.injuries where entry.severity == .avoid {
            let riskyMuscles = muscleMap[entry.part] ?? []
            if riskyMuscles.isDisjoint(with: allMuscles) {
                tags.append("\(entry.part.displayName)-safe")
            }
        }
        return Array(tags.prefix(3))
    }

    // MARK: - Templates

    private static let allTemplates: [CandidateTemplate] = [

        CandidateTemplate(style: .fullBody, compatibleDays: [2, 3], days: [
            TemplateDay(label: "Full Body A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",     sets: 4, reps: "5",       equipment: "Barbell",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Barbell Bench Press",    sets: 4, reps: "5",       equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Row",            sets: 4, reps: "5",       equipment: "Barbell",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Dumbbell Lateral Raise", sets: 3, reps: "12",      equipment: "Dumbbell",   primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Plank",                  sets: 3, reps: "30s",     equipment: "Bodyweight", primaryMuscle: "core"),
            ]),
            TemplateDay(label: "Full Body B", isRest: false, exercises: [
                RecommendedExercise(name: "Romanian Deadlift",      sets: 4, reps: "8",       equipment: "Barbell",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Incline Dumbbell Press", sets: 4, reps: "10",      equipment: "Dumbbell",   primaryMuscle: "chest"),
                RecommendedExercise(name: "Lat Pulldown",           sets: 4, reps: "10",      equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Curl",           sets: 3, reps: "10",      equipment: "Barbell",    primaryMuscle: "biceps"),
                RecommendedExercise(name: "Calf Raise",             sets: 3, reps: "15",      equipment: "Machine",    primaryMuscle: "calves"),
            ]),
            TemplateDay(label: "Full Body C", isRest: false, exercises: [
                RecommendedExercise(name: "Leg Press",              sets: 4, reps: "10",      equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Barbell Overhead Press", sets: 4, reps: "8",       equipment: "Barbell",    primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Cable Row",              sets: 4, reps: "10",      equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Tricep Pushdown",        sets: 3, reps: "12",      equipment: "Machine",    primaryMuscle: "triceps"),
                RecommendedExercise(name: "Dead Bug",               sets: 3, reps: "10/side", equipment: "Bodyweight", primaryMuscle: "core"),
            ]),
        ]),

        CandidateTemplate(style: .upperLower, compatibleDays: [3, 4], days: [
            TemplateDay(label: "Upper A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",    sets: 4, reps: "6",  equipment: "Barbell",  primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Row",            sets: 4, reps: "6",  equipment: "Barbell",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Overhead Press", sets: 3, reps: "8",  equipment: "Barbell",  primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Lat Pulldown",           sets: 3, reps: "10", equipment: "Machine",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Curl",           sets: 3, reps: "10", equipment: "Barbell",  primaryMuscle: "biceps"),
                RecommendedExercise(name: "Skull Crushers",         sets: 3, reps: "10", equipment: "Barbell",  primaryMuscle: "triceps"),
            ]),
            TemplateDay(label: "Lower A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",     sets: 4, reps: "6",  equipment: "Barbell",  primaryMuscle: "quads"),
                RecommendedExercise(name: "Romanian Deadlift",      sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Leg Press",              sets: 3, reps: "10", equipment: "Machine",  primaryMuscle: "quads"),
                RecommendedExercise(name: "Leg Curl",               sets: 3, reps: "12", equipment: "Machine",  primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Calf Raise",             sets: 4, reps: "15", equipment: "Machine",  primaryMuscle: "calves"),
            ]),
            TemplateDay(label: "Upper B", isRest: false, exercises: [
                RecommendedExercise(name: "Incline Dumbbell Press",  sets: 4, reps: "10", equipment: "Dumbbell", primaryMuscle: "chest"),
                RecommendedExercise(name: "Cable Row",               sets: 4, reps: "10", equipment: "Machine",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Dumbbell Shoulder Press", sets: 3, reps: "10", equipment: "Dumbbell", primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Machine Chest Press",     sets: 3, reps: "12", equipment: "Machine",  primaryMuscle: "chest"),
                RecommendedExercise(name: "Hammer Curl",             sets: 3, reps: "12", equipment: "Dumbbell", primaryMuscle: "biceps"),
                RecommendedExercise(name: "Tricep Pushdown",         sets: 3, reps: "12", equipment: "Machine",  primaryMuscle: "triceps"),
            ]),
            TemplateDay(label: "Lower B", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Deadlift",        sets: 4, reps: "5",       equipment: "Barbell",  primaryMuscle: "lower_back"),
                RecommendedExercise(name: "Hip Thrust",              sets: 4, reps: "10",      equipment: "Barbell",  primaryMuscle: "glutes"),
                RecommendedExercise(name: "Leg Extension",           sets: 3, reps: "12",      equipment: "Machine",  primaryMuscle: "quads"),
                RecommendedExercise(name: "Lateral Lunge",           sets: 3, reps: "10/side", equipment: "Dumbbell", primaryMuscle: "quads"),
                RecommendedExercise(name: "Calf Raise",              sets: 4, reps: "15",      equipment: "Machine",  primaryMuscle: "calves"),
            ]),
        ]),

        CandidateTemplate(style: .pushPullLegs, compatibleDays: [3, 4, 5, 6], days: [
            TemplateDay(label: "Push A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",    sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Overhead Press", sets: 3, reps: "8",  equipment: "Barbell",  primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Incline Dumbbell Press", sets: 3, reps: "10", equipment: "Dumbbell", primaryMuscle: "chest"),
                RecommendedExercise(name: "Dumbbell Lateral Raise", sets: 3, reps: "12", equipment: "Dumbbell", primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Skull Crushers",         sets: 3, reps: "10", equipment: "Barbell",  primaryMuscle: "triceps"),
            ]),
            TemplateDay(label: "Pull A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Row",            sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Lat Pulldown",           sets: 3, reps: "10", equipment: "Machine",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Cable Row",              sets: 3, reps: "10", equipment: "Machine",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Curl",           sets: 3, reps: "10", equipment: "Barbell",  primaryMuscle: "biceps"),
                RecommendedExercise(name: "Face Pull",              sets: 3, reps: "15", equipment: "Machine",  primaryMuscle: "rear_delts"),
            ]),
            TemplateDay(label: "Legs A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",     sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "quads"),
                RecommendedExercise(name: "Romanian Deadlift",      sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Leg Press",              sets: 3, reps: "10", equipment: "Machine",  primaryMuscle: "quads"),
                RecommendedExercise(name: "Leg Curl",               sets: 3, reps: "12", equipment: "Machine",  primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Calf Raise",             sets: 4, reps: "15", equipment: "Machine",  primaryMuscle: "calves"),
            ]),
            TemplateDay(label: "Push B", isRest: false, exercises: [
                RecommendedExercise(name: "Incline Barbell Press",   sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Dumbbell Shoulder Press", sets: 3, reps: "10", equipment: "Dumbbell",   primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Cable Fly",               sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Cable Lateral Raise",     sets: 3, reps: "15", equipment: "Machine",    primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Tricep Dips",             sets: 3, reps: "10", equipment: "Bodyweight", primaryMuscle: "triceps"),
            ]),
            TemplateDay(label: "Pull B", isRest: false, exercises: [
                RecommendedExercise(name: "Lat Pulldown",            sets: 4, reps: "10", equipment: "Machine",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Cable Row",               sets: 4, reps: "10", equipment: "Machine",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Face Pull",               sets: 3, reps: "15", equipment: "Machine",  primaryMuscle: "rear_delts"),
                RecommendedExercise(name: "Hammer Curl",             sets: 3, reps: "12", equipment: "Dumbbell", primaryMuscle: "biceps"),
                RecommendedExercise(name: "Dumbbell Curl",           sets: 3, reps: "12", equipment: "Dumbbell", primaryMuscle: "biceps"),
            ]),
            TemplateDay(label: "Legs B", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Deadlift",        sets: 4, reps: "5",       equipment: "Barbell",  primaryMuscle: "lower_back"),
                RecommendedExercise(name: "Hip Thrust",              sets: 4, reps: "10",      equipment: "Barbell",  primaryMuscle: "glutes"),
                RecommendedExercise(name: "Leg Extension",           sets: 3, reps: "12",      equipment: "Machine",  primaryMuscle: "quads"),
                RecommendedExercise(name: "Lateral Lunge",           sets: 3, reps: "10/side", equipment: "Dumbbell", primaryMuscle: "quads"),
                RecommendedExercise(name: "Calf Raise",              sets: 4, reps: "15",      equipment: "Machine",  primaryMuscle: "calves"),
            ]),
        ]),

        CandidateTemplate(style: .arnold, compatibleDays: [3, 6], days: [
            TemplateDay(label: "Chest & Back", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",    sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Row",            sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Incline Dumbbell Press", sets: 3, reps: "10", equipment: "Dumbbell", primaryMuscle: "chest"),
                RecommendedExercise(name: "Lat Pulldown",           sets: 3, reps: "10", equipment: "Machine",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Cable Fly",              sets: 3, reps: "12", equipment: "Machine",  primaryMuscle: "chest"),
            ]),
            TemplateDay(label: "Shoulders & Arms", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Overhead Press", sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Dumbbell Lateral Raise", sets: 3, reps: "12", equipment: "Dumbbell", primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Barbell Curl",           sets: 3, reps: "10", equipment: "Barbell",  primaryMuscle: "biceps"),
                RecommendedExercise(name: "Skull Crushers",         sets: 3, reps: "10", equipment: "Barbell",  primaryMuscle: "triceps"),
                RecommendedExercise(name: "Face Pull",              sets: 3, reps: "15", equipment: "Machine",  primaryMuscle: "rear_delts"),
            ]),
            TemplateDay(label: "Legs", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",     sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "quads"),
                RecommendedExercise(name: "Romanian Deadlift",      sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Leg Press",              sets: 3, reps: "10", equipment: "Machine",  primaryMuscle: "quads"),
                RecommendedExercise(name: "Hip Thrust",             sets: 3, reps: "10", equipment: "Barbell",  primaryMuscle: "glutes"),
                RecommendedExercise(name: "Calf Raise",             sets: 4, reps: "15", equipment: "Machine",  primaryMuscle: "calves"),
            ]),
        ]),

        CandidateTemplate(style: .broSplit, compatibleDays: [5], days: [
            TemplateDay(label: "Chest", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",    sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Incline Dumbbell Press", sets: 4, reps: "10", equipment: "Dumbbell",   primaryMuscle: "chest"),
                RecommendedExercise(name: "Machine Chest Press",    sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Cable Fly",              sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Tricep Dips",            sets: 3, reps: "10", equipment: "Bodyweight", primaryMuscle: "triceps"),
            ]),
            TemplateDay(label: "Back", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Row",            sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Lat Pulldown",           sets: 4, reps: "10", equipment: "Machine",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Cable Row",              sets: 3, reps: "10", equipment: "Machine",  primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Deadlift",       sets: 3, reps: "5",  equipment: "Barbell",  primaryMuscle: "lower_back"),
                RecommendedExercise(name: "Face Pull",              sets: 3, reps: "15", equipment: "Machine",  primaryMuscle: "rear_delts"),
            ]),
            TemplateDay(label: "Shoulders", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Overhead Press",  sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Dumbbell Lateral Raise",  sets: 4, reps: "12", equipment: "Dumbbell", primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Dumbbell Shoulder Press", sets: 3, reps: "10", equipment: "Dumbbell", primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Cable Lateral Raise",     sets: 3, reps: "15", equipment: "Machine",  primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Face Pull",               sets: 3, reps: "15", equipment: "Machine",  primaryMuscle: "rear_delts"),
            ]),
            TemplateDay(label: "Arms", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Curl",            sets: 4, reps: "10", equipment: "Barbell",  primaryMuscle: "biceps"),
                RecommendedExercise(name: "Skull Crushers",          sets: 4, reps: "10", equipment: "Barbell",  primaryMuscle: "triceps"),
                RecommendedExercise(name: "Hammer Curl",             sets: 3, reps: "12", equipment: "Dumbbell", primaryMuscle: "biceps"),
                RecommendedExercise(name: "Tricep Pushdown",         sets: 3, reps: "12", equipment: "Machine",  primaryMuscle: "triceps"),
                RecommendedExercise(name: "Cable Curl",              sets: 3, reps: "12", equipment: "Machine",  primaryMuscle: "biceps"),
            ]),
            TemplateDay(label: "Legs", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",      sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "quads"),
                RecommendedExercise(name: "Romanian Deadlift",       sets: 4, reps: "8",  equipment: "Barbell",  primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Leg Press",               sets: 3, reps: "10", equipment: "Machine",  primaryMuscle: "quads"),
                RecommendedExercise(name: "Hip Thrust",              sets: 3, reps: "10", equipment: "Barbell",  primaryMuscle: "glutes"),
                RecommendedExercise(name: "Calf Raise",              sets: 4, reps: "15", equipment: "Machine",  primaryMuscle: "calves"),
            ]),
        ]),

        CandidateTemplate(style: .anteriorPosterior, compatibleDays: [2, 4], days: [
            TemplateDay(label: "Anterior", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",     sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Overhead Press",  sets: 3, reps: "8",  equipment: "Barbell",    primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Leg Press",               sets: 4, reps: "10", equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Barbell Curl",            sets: 3, reps: "10", equipment: "Barbell",    primaryMuscle: "biceps"),
                RecommendedExercise(name: "Leg Extension",           sets: 3, reps: "12", equipment: "Machine",    primaryMuscle: "quads"),
            ]),
            TemplateDay(label: "Posterior", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Deadlift",        sets: 4, reps: "5",  equipment: "Barbell",    primaryMuscle: "lower_back"),
                RecommendedExercise(name: "Barbell Row",             sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Romanian Deadlift",       sets: 4, reps: "8",  equipment: "Barbell",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Hip Thrust",              sets: 3, reps: "10", equipment: "Barbell",    primaryMuscle: "glutes"),
                RecommendedExercise(name: "Face Pull",               sets: 3, reps: "15", equipment: "Machine",    primaryMuscle: "rear_delts"),
            ]),
        ]),

        CandidateTemplate(style: .athletic, compatibleDays: [3, 4, 5], days: [
            TemplateDay(label: "Power Lower", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",      sets: 5, reps: "5",       equipment: "Barbell",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Barbell Deadlift",        sets: 4, reps: "4",       equipment: "Barbell",    primaryMuscle: "lower_back"),
                RecommendedExercise(name: "Box Jump",                sets: 4, reps: "5",       equipment: "Bodyweight", primaryMuscle: "quads"),
                RecommendedExercise(name: "Lateral Lunge",           sets: 3, reps: "10/side", equipment: "Dumbbell",   primaryMuscle: "quads"),
                RecommendedExercise(name: "Calf Raise",              sets: 3, reps: "15",      equipment: "Machine",    primaryMuscle: "calves"),
            ]),
            TemplateDay(label: "Power Upper", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",     sets: 5, reps: "5",       equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Row",             sets: 4, reps: "5",       equipment: "Barbell",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Overhead Press",  sets: 3, reps: "6",       equipment: "Barbell",    primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Pull-Ups",                sets: 3, reps: "8",       equipment: "Bodyweight", primaryMuscle: "lats"),
                RecommendedExercise(name: "Plank",                   sets: 3, reps: "45s",     equipment: "Bodyweight", primaryMuscle: "core"),
            ]),
            TemplateDay(label: "Hypertrophy Lower", isRest: false, exercises: [
                RecommendedExercise(name: "Romanian Deadlift",       sets: 4, reps: "8",       equipment: "Barbell",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Hip Thrust",              sets: 4, reps: "10",      equipment: "Barbell",    primaryMuscle: "glutes"),
                RecommendedExercise(name: "Leg Press",               sets: 3, reps: "10",      equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Leg Curl",                sets: 3, reps: "12",      equipment: "Machine",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Jump Rope",               sets: 3, reps: "60s",     equipment: "Bodyweight", primaryMuscle: "calves"),
            ]),
            TemplateDay(label: "Hypertrophy Upper", isRest: false, exercises: [
                RecommendedExercise(name: "Incline Dumbbell Press",  sets: 4, reps: "10",      equipment: "Dumbbell",   primaryMuscle: "chest"),
                RecommendedExercise(name: "Cable Row",               sets: 4, reps: "10",      equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Dumbbell Lateral Raise",  sets: 3, reps: "12",      equipment: "Dumbbell",   primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Barbell Curl",            sets: 3, reps: "10",      equipment: "Barbell",    primaryMuscle: "biceps"),
                RecommendedExercise(name: "Dead Bug",                sets: 3, reps: "10/side", equipment: "Bodyweight", primaryMuscle: "core"),
            ]),
        ]),
    ]
}
