import Foundation

/// Scores a *saved* `UserSplitRecord` the same way `CreateSplitView` scores one being built —
/// resolution and math live in exactly one place so the two can never quietly disagree about what
/// a day actually trains. Pure: no `ModelContext`, no SwiftUI. Template lookup is injected as a
/// closure so this stays headless and harness-testable.
enum SavedSplitScoring {

    /// One day's exercises, resolved with the SAME precedence `AppViewModel.prepareExercises(for:)`
    /// uses (`AppViewModel.swift:686-718`): a non-empty decoded `exercisesJSON` wins outright;
    /// `templateID` is consulted only when it doesn't. Any divergence here means the score
    /// describes a workout different from the one that actually starts.
    ///
    /// This is a decode guard, not a string check — `"[]"`, `""`, and malformed JSON all fall
    /// through to the template, matching `prepareExercises` exactly.
    static func dayExercises(for day: UserSplitDayRecord,
                             templateExercises: (String) -> [TemplateExerciseRecord]) -> [DayExercise] {
        if let data = day.exercisesJSON.data(using: .utf8),
           let infos = try? JSONDecoder().decode([DayExercise].self, from: data),
           !infos.isEmpty {
            return infos
        }

        guard !day.templateID.isEmpty else { return [] }
        let tmpl = templateExercises(day.templateID)   // expected pre-sorted by orderIndex
        guard !tmpl.isEmpty else { return [] }
        return tmpl.map { ex in
            DayExercise(id: ex.exerciseID ?? ex.id, name: ex.exerciseName,
                       sets: ex.targetSets, reps: ex.targetReps,
                       equipmentId: ex.equipmentId,
                       equipmentDedupeKey: ex.equipmentDedupeKey,
                       equipmentBrandName: ex.equipmentBrandName,
                       muscleTargets: ex.muscleTargets)
        }
    }

    /// Whether a day genuinely resolves via its template rather than its own exercise list —
    /// i.e. `dayExercises` fell through to the template branch. A day can carry a non-empty
    /// `templateID` *and* a non-empty `exercisesJSON`; ad-hoc wins, so that day is NOT
    /// template-backed by this definition. Auto-fix (Task 3) uses this, not `!templateID.isEmpty`,
    /// to decide whether there's an ad-hoc list it can safely edit.
    static func isTemplateBacked(_ day: UserSplitDayRecord) -> Bool {
        guard let data = day.exercisesJSON.data(using: .utf8),
              let infos = try? JSONDecoder().decode([DayExercise].self, from: data)
        else { return !day.templateID.isEmpty }
        return infos.isEmpty && !day.templateID.isEmpty
    }

    /// `days` must already be sorted by `orderIndex` — the caller (a `@Query` or a manual sort)
    /// owns that; this stays pure and doesn't second-guess ordering.
    static func report(days: [UserSplitDayRecord],
                       templateExercises: (String) -> [TemplateExerciseRecord],
                       catalog: [ExerciseCandidate],
                       profile: TrainingProfile,
                       intent: TrainingIntent) -> QualityReport {
        let scored: [[ScoredExercise]] = days.map { day in
            day.isRest ? [] : dayExercises(for: day, templateExercises: templateExercises).map(ScoredExercise.init(day:))
        }
        return TemplateQualityEngine.score(
            days: scored,
            dayNames: days.map(\.dayName),
            scope: .weeklySplit,
            profile: profile,
            catalog: catalog,
            intent: intent,
            dayExclusions: days.map(\.excludedMuscles),
            dayIsRest: days.map(\.isRest))
    }

    /// Per-day headline numbers, mirroring `CreateSplitView.daySummaries` — each day scored on its
    /// own at session scope, which is what makes "Monday 82 / Friday 41" meaningful.
    static func daySummaries(days: [UserSplitDayRecord],
                            templateExercises: (String) -> [TemplateExerciseRecord],
                            catalog: [ExerciseCandidate],
                            profile: TrainingProfile,
                            splitGoal: LiftingGoal) -> [SplitDaySummary] {
        days.enumerated().compactMap { i, day in
            guard !day.isRest else { return nil }
            let exercises = dayExercises(for: day, templateExercises: templateExercises)
            guard !exercises.isEmpty else { return nil }
            let scored = exercises.map(ScoredExercise.init(day:))
            let dayIntent = TrainingIntent(goal: splitGoal, focus: nil,
                                          excludedMuscles: day.excludedMuscles)
            let r = TemplateQualityEngine.score(days: [scored], dayNames: [day.dayName],
                                                scope: .singleSession,
                                                profile: profile,
                                                catalog: catalog,
                                                intent: dayIntent)
            return SplitDaySummary(
                id: i,
                name: day.dayName,
                exerciseCount: exercises.count,
                sets: exercises.reduce(0) { $0 + $1.sets },
                score: r.isScored ? r.overall : nil,
                report: r)
        }
    }
}
