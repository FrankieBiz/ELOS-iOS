import Foundation

/// Scores muscular balance: push/pull symmetry, antagonist pairing (quad vs hamstring), and
/// coverage gaps. Coverage is scope-aware — a weekly split should train every major group, while
/// a single focused session (e.g. a Push day) is judged only against its inferred focus.
enum BalanceScorer {
    /// Muscle counts come from `volume` but read **direct** (primary) sets only, on purpose.
    /// "Is this muscle targeted?" and "how much stimulus does it get?" are different questions:
    /// bench + incline press gives the triceps real fractional volume but zero direct work, and
    /// "add some direct triceps work" is the correct coaching. The bars show both segments, so the
    /// tip and the bar agree rather than contradicting each other.
    static func score(resolvedDays: [[ResolvedExercise]],
                      scope: QualityScope,
                      dayNames: [String],
                      intent: TrainingIntent?,
                      volume: MuscleVolumeReport,
                      catalog: [ExerciseCandidate]) -> DimensionScore {
        let all = resolvedDays.flatMap { $0 }
        guard all.contains(where: { $0.candidate != nil }) else {
            return DimensionScore(dimension: .balance, score: 70, tips: [])
        }

        var tips: [QualityTip] = []
        var penalties = 0.0

        // Push / pull (movement-pattern level)
        var pushSets = 0, pullSets = 0
        for r in all {
            switch r.movementPattern {
            case "push": pushSets += r.exercise.sets
            case "pull": pullSets += r.exercise.sets
            default: break
            }
        }
        if pushSets > 0 && pullSets > 0 {
            let ratio = Double(max(pushSets, pullSets)) / Double(min(pushSets, pullSets))
            if ratio > TrainingScience.pushPullRatioLimit {
                let heavier = pushSets > pullSets ? "pushing" : "pulling"
                let addMore = pushSets > pullSets ? "rows and pulls" : "presses"
                penalties += 0.22
                tips.append(QualityTip(
                    id: "bal-pushpull", dimension: .balance, severity: .warn,
                    message: "Push/pull is off — \(heavier) volume is \(String(format: "%.1f", ratio))× the other. Add more \(addMore) to keep the shoulders healthy.",
                    action: .noAction))
            }
        }

        // Antagonist: quads vs hamstrings (posterior chain is the commonly-neglected side)
        let quadSets = volume.directSets(for: .quads)
        let hamSets  = volume.directSets(for: .hamstrings)
        if quadSets > 0 && hamSets == 0 {
            penalties += 0.18
            tips.append(QualityTip(
                id: "bal-noham", dimension: .balance, severity: .warn,
                message: "Quads are trained but there's no direct hamstring work — add a hinge (RDL, leg curl) to balance the knee and build the posterior chain.",
                action: .addMuscle("hamstrings")))
        } else if quadSets > 0 && hamSets > 0 {
            let ratio = Double(max(quadSets, hamSets)) / Double(min(quadSets, hamSets))
            if ratio > TrainingScience.antagonistRatioLimit {
                penalties += 0.12
                let heavier = quadSets > hamSets ? "quad" : "hamstring"
                tips.append(QualityTip(
                    id: "bal-quadham", dimension: .balance, severity: .info,
                    message: "Quad/hamstring volume is lopsided (\(heavier)-dominant). Even it out for balanced legs and knee health.",
                    action: .noAction))
            }
        }

        // Coverage gaps — scope aware
        switch scope {
        case .weeklySplit:
            let major: [MuscleGroup] = [.chest, .back, .legs, .shoulders, .arms]
            for g in major where volume.directSets(forGroup: g) == 0 {
                // A group can have zero *direct* work yet real indirect volume (arms off presses and
                // rows). That's a lighter problem than a true blind spot, so say so and penalise less.
                let indirect = volume.sets(forGroup: g)
                if indirect > 0 {
                    penalties += 0.08
                    tips.append(QualityTip(
                        id: "bal-gap-\(g.rawValue)", dimension: .balance, severity: .info,
                        message: "\(g.displayName) only gets indirect work from your compounds. Add a direct \(g.rawValue) movement to actually drive growth there.",
                        action: .addMuscle(g.rawValue)))
                } else {
                    penalties += 0.14
                    tips.append(QualityTip(
                        id: "bal-gap-\(g.rawValue)", dimension: .balance, severity: .warn,
                        message: "No \(g.rawValue) work this week — every major muscle should be trained. Add a \(g.rawValue) movement or day.",
                        action: .addMuscle(g.rawValue)))
                }
            }
            if volume.directSets(forGroup: .core) == 0 {
                penalties += 0.05
                tips.append(QualityTip(
                    id: "bal-gap-core", dimension: .balance, severity: .info,
                    message: "No direct core work — a couple of ab/anti-rotation sets round out the week.",
                    action: .addMuscle("core")))
            }

        case .singleSession:
            let trained = Set(MuscleGroup.allCases.filter { volume.directSets(forGroup: $0) > 0 })
            // Explicit intent wins; fall back to inferring from the day name.
            let archetype: SplitArchetype? = intent?.focus ?? {
                let added = all.map {
                    DayExercise(id: $0.exercise.id, name: $0.exercise.name,
                                sets: $0.exercise.sets, reps: $0.exercise.repsText)
                }
                return DayContextInferrer.infer(dayName: dayNames.first ?? "",
                                                added: added, catalog: catalog).archetype
            }()
            if let arch = archetype {
                let targetGroups = archetypeGroups(arch)
                for g in targetGroups.subtracting(trained) {
                    penalties += 0.12
                    tips.append(QualityTip(
                        id: "bal-focusgap-\(g.rawValue)", dimension: .balance, severity: .info,
                        message: "This looks like a \(arch.rawValue) day, but \(g.rawValue) isn't covered yet — add a \(g.rawValue) movement.",
                        action: .addMuscle(g.rawValue)))
                }
            } else if trained.count == 1, all.count >= 3, let only = trained.first {
                // Unfocused session hammering a single muscle group reads as unstructured.
                penalties += 0.25
                tips.append(QualityTip(
                    id: "bal-single-group", dimension: .balance, severity: .info,
                    message: "This session only trains \(only.rawValue). Most workouts hit 2–3 muscle groups — add another, or name the day so guidance can tailor to it.",
                    action: .noAction))
            }
        }

        let score = max(0, min(100, Int(((1.0 - penalties) * 100).rounded())))
        return DimensionScore(dimension: .balance, score: score, tips: tips)
    }

    // MARK: Helpers

    private static func archetypeGroups(_ a: SplitArchetype) -> Set<MuscleGroup> {
        Set(MuscleTaxonomy.targetMuscles(forArchetype: a).compactMap { MuscleTaxonomy.group(forMuscle: $0) })
    }
}
