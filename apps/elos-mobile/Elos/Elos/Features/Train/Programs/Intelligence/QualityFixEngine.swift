import Foundation

/// The orchestrator behind the auto-fix button. Builds operations per tip, simulates them against
/// a hypothetical copy of the plan (never the real one), re-scores with the exact parameters the
/// builder itself uses, and only returns a proposal if it can prove the targeted tip actually
/// clears, or that the change helps even when it can't. Matched on `(id, action)`, not `id` alone —
/// `sel-order` reuses one id across days, so an id-only check would report false success.
enum QualityFixEngine {
    struct Context {
        let days: [[ScoredExercise]]
        let dayNames: [String]
        let dayIsRest: [Bool]
        let dayExcludedMuscles: [Set<FineMuscle>]
        let scope: QualityScope
        let profile: TrainingProfile
        let intent: TrainingIntent
        let catalog: [ExerciseCandidate]
        let personalization: PersonalizationProvider
        let equipmentPreference: EquipmentPreference
    }

    /// Cheap whitelist for the UI's auto-fix affordance — a tip can carry an actionable
    /// `TipAction` for the manual path without claiming to be auto-fixable. Volume-reduction and
    /// structural tips (vol-high-*, sess-*, bal-pushpull, bal-quadham, bal-single-group,
    /// sel-compound, fatigue-long-*, freq-once-*, vol-more) are deliberately absent: deciding what
    /// to *remove*, or how to restructure a week, is a judgement call, not a mechanical one.
    static func canFix(_ tip: QualityTip) -> Bool {
        let id = tip.id
        if id.hasPrefix("bal-gap-") || id.hasPrefix("bal-focusgap-") || id == "bal-noham" { return true }
        if id.hasPrefix("vol-low-") || id.hasPrefix("vol-light-") { return true }
        if id == "sel-hinge" { return true }
        if id == "sel-order" || id.hasPrefix("fatigue-order-") { return true }
        if id == "rr-reps" || id == "rr-rest" { return true }
        return false
    }

    static func propose(for tip: QualityTip, context: Context) -> FixProposal? {
        propose(for: tip, context: context, forcedCandidate: nil)
    }

    /// Re-proposes the same fix with a specific alternate candidate substituted for the top pick —
    /// "use a different exercise" in the preview.
    static func propose(for tip: QualityTip, context: Context, using alternate: ExerciseCandidate) -> FixProposal? {
        propose(for: tip, context: context, forcedCandidate: alternate)
    }

    private static func propose(for tip: QualityTip, context: Context,
                               forcedCandidate: ExerciseCandidate?) -> FixProposal? {
        guard canFix(tip) else { return nil }

        var alternates: [ExerciseCandidate] = []
        var placement: String?
        let operations: [FixOperation]
        var insertedCandidate: InsertSpec?

        switch tip.action {
        case .addMuscle(let payload), .addPattern(let payload):
            guard let chosen = FixDayChooser.choose(
                forMuscles: MuscleTaxonomy.targetMuscles(forPayload: payload),
                dayNames: context.dayNames, dayIsRest: context.dayIsRest,
                dayExercises: context.days, dayExcludedMuscles: context.dayExcludedMuscles,
                catalog: context.catalog, intent: context.intent
            ) else { return nil }
            let dayIndex = chosen.dayIndex

            let pickerContext = FixExercisePicker.Context(
                catalog: context.catalog, dayName: context.dayNames[dayIndex],
                addedDay: context.days[dayIndex], personalization: context.personalization,
                equipmentPreference: context.equipmentPreference)

            let isPattern: Bool = { if case .addPattern = tip.action { return true }; return false }()
            let candidates = isPattern
                ? FixExercisePicker.candidates(forPattern: payload, context: pickerContext)
                : FixExercisePicker.candidates(forMuscles: MuscleTaxonomy.targetMuscles(forPayload: payload),
                                               context: pickerContext)
            guard !candidates.isEmpty else { return nil }
            let chosenCandidate = forcedCandidate ?? candidates[0]
            alternates = candidates.filter { $0.id != chosenCandidate.id }

            let def = SetRepDefaults.defaults(forMovementPattern: chosenCandidate.movementPattern)
            let sets = doseSets(forTip: tip, context: context) ?? def.sets
            let spec = InsertSpec(dayIndex: dayIndex, insertAt: context.days[dayIndex].count,
                                  candidate: chosenCandidate, sets: sets, reps: def.reps)
            insertedCandidate = spec
            operations = [.insertExercise(spec)]
            let dayLabel = context.dayNames[dayIndex]
            placement = dayLabel.isEmpty ? chosen.reason : "\(dayLabel) — \(chosen.reason)"

        case .reorder(let dayIndex):
            guard context.days.indices.contains(dayIndex) else { return nil }
            let asDayExercises = context.days[dayIndex].map {
                DayExercise(id: $0.id, name: $0.name, sets: $0.sets, reps: $0.repsText)
            }
            let permutation = ExerciseOrderer.orderedIndices(asDayExercises, catalog: context.catalog)
            operations = [.reorderDay(dayIndex: dayIndex, permutation: permutation)]

        case .retuneReps:
            operations = retuneRepsOperations(context: context)

        case .retuneRest:
            operations = retuneRestOperations(context: context)

        case .noAction:
            return nil
        }

        guard !operations.isEmpty else { return nil }

        let before = TemplateQualityEngine.score(
            days: context.days, dayNames: context.dayNames, scope: context.scope,
            profile: context.profile, catalog: context.catalog, intent: context.intent,
            dayExclusions: context.dayExcludedMuscles, dayIsRest: context.dayIsRest)
        let simulated = operations.reduce(context.days) { days, op in op.apply(to: days) }
        let after = TemplateQualityEngine.score(
            days: simulated, dayNames: context.dayNames, scope: context.scope,
            profile: context.profile, catalog: context.catalog, intent: context.intent,
            dayExclusions: context.dayExcludedMuscles, dayIsRest: context.dayIsRest)

        let resolvesTip = !after.tips.contains { $0.id == tip.id && $0.action == tip.action }
        // A change that neither clears the tip nor improves the score is noise — offering it is
        // what "sloppy" looks like. A fix that clears the tip but costs a point or two elsewhere
        // IS still offered, with the regression visible in the preview.
        guard resolvesTip || after.overall > before.overall else { return nil }

        let summary = buildSummary(tip: tip, insert: insertedCandidate, placement: placement,
                                   resolvesTip: resolvesTip, operationCount: operations.count)
        return FixProposal(tip: tip, operations: operations, summary: summary,
                          before: before, after: after, resolvesTip: resolvesTip, alternates: alternates)
    }

    // MARK: Dose sizing

    /// Sets needed to clear a `vol-low-*`/`vol-light-*` tip, sized from the actual shortfall
    /// against `credit.total` (not `.direct` — `VolumeScorer` grades total credit, so a muscle
    /// already earning indirect credit needs fewer new sets than its direct count suggests).
    /// `nil` for every other tip type, which falls back to the movement pattern's default sets.
    private static func doseSets(forTip tip: QualityTip, context: Context) -> Int? {
        guard tip.id.hasPrefix("vol-low-") || tip.id.hasPrefix("vol-light-"),
              case .addMuscle(let payload) = tip.action,
              let fine = FineMuscle(rawValue: payload) else { return nil }
        let resolvedDays = ExerciseResolver.resolve(context.days, catalog: context.catalog)
        let volume = MuscleVolumeAnalyzer.analyze(resolvedDays: resolvedDays, scope: context.scope,
                                                  intent: context.intent, dayNames: context.dayNames,
                                                  profile: context.profile, catalog: context.catalog)
        let band = TrainingScience.weeklyBand(for: fine, profile: context.profile)
        let target = tip.id.hasPrefix("vol-low-") ? band.mev : band.targetLow
        let shortfall = target - volume.sets(for: fine)
        guard shortfall > 0 else { return nil }
        return min(Int(shortfall.rounded(.up)), TrainingScience.maxAutoFixSetsPerExercise)
    }

    // MARK: Tier 2 — rep/rest retuning

    private static func retuneRepsOperations(context: Context) -> [FixOperation] {
        let range = TrainingScience.repRange(for: context.profile.goal)
        var ops: [FixOperation] = []
        for (dayIndex, day) in context.days.enumerated() {
            for (exerciseIndex, exercise) in day.enumerated() {
                guard let parsed = RepRestScorer.parseReps(exercise.repsText),
                      !range.overlaps(parsed) else { continue }
                ops.append(.setReps(dayIndex: dayIndex, exerciseIndex: exerciseIndex,
                                    reps: "\(range.low)-\(range.high)"))
            }
        }
        return ops
    }

    private static func retuneRestOperations(context: Context) -> [FixOperation] {
        let range = TrainingScience.restRange(for: context.profile.goal)
        let lo = Double(range.low) * 0.6, hi = Double(range.high) * 1.5
        let target = (range.low + range.high) / 2
        var ops: [FixOperation] = []
        for (dayIndex, day) in context.days.enumerated() {
            for (exerciseIndex, exercise) in day.enumerated() {
                guard let rest = exercise.restSeconds, rest > 0 else { continue }
                let restD = Double(rest)
                guard !(restD >= lo && restD <= hi) else { continue }
                ops.append(.setRest(dayIndex: dayIndex, exerciseIndex: exerciseIndex, seconds: target))
            }
        }
        return ops
    }

    // MARK: Summary

    private static func buildSummary(tip: QualityTip, insert: InsertSpec?, placement: String?,
                                     resolvesTip: Bool, operationCount: Int) -> FixSummary {
        if let insert {
            let headline = "Adds \(insert.candidate.name)"
            let detail = "\(insert.sets) × \(insert.reps) · \(insert.candidate.equipment)"
            let caveat = resolvesTip ? nil : "Helps, but may not fully close the gap"
            return FixSummary(headline: headline, detail: detail, placement: placement, caveat: caveat)
        }
        switch tip.action {
        case .reorder:
            return FixSummary(headline: "Reorders this day", detail: "Compounds before isolations",
                              placement: nil, caveat: nil)
        case .retuneReps:
            return FixSummary(headline: "Adjusts rep ranges",
                              detail: "\(operationCount) exercise\(operationCount == 1 ? "" : "s") retuned",
                              placement: nil, caveat: resolvesTip ? nil : "Helps, but some exercises may still be off-range")
        case .retuneRest:
            return FixSummary(headline: "Adjusts rest times",
                              detail: "\(operationCount) exercise\(operationCount == 1 ? "" : "s") retuned",
                              placement: nil, caveat: resolvesTip ? nil : "Helps, but some exercises may still be off-range")
        default:
            return FixSummary(headline: "Applies fix", detail: "", placement: nil, caveat: nil)
        }
    }
}
