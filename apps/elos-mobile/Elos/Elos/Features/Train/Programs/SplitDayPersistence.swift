import Foundation
import SwiftData

/// Persists a split builder's 7-day arrays into `UserSplitDayRecord`s by **updating existing rows
/// in place**, never deleting and reinserting them.
///
/// Extracted out of `CreateSplitView.saveSplit()` (where this used to be a nested function that
/// deleted every day and rebuilt it from scratch) for two reasons: deleting and rebuilding
/// regenerates every row's local `id` on every save, and it silently drops any column the
/// builder's own `@State` doesn't carry — the builder only ever hydrates the six wire fields on
/// `.onAppear`, so a day-local column added later (variants) would simply cease to exist the
/// moment Edit → Save ran, with no signal at all. Living in its own file (rather than
/// `SplitHelpers.swift`) because it needs `SwiftData`'s `ModelContext`, and `SplitHelpers.swift` is
/// copied verbatim into the pure-logic swiftc harness this project uses to run engine tests
/// outside Xcode — adding a SwiftData import there would break every one of those harnesses.
///
/// Shared by both of `CreateSplitView.saveSplit()`'s paths: edit mode passes its currently
/// persisted rows as `existing`; create mode passes `[]`, so every day falls to the insert branch
/// and this doubles as the one place a day row is ever constructed.
enum SplitDayPersistence {

    /// A day the lifter never touched — no exercises, no template, no name — is a rest day, not a
    /// training day with nothing in it. A day that was given a name is left alone; that's a
    /// deliberate placeholder the lifter still intends to fill.
    static func isEffectivelyRest(_ i: Int, dayIsRest: [Bool], dayExercises: [[DayExercise]],
                                  dayTemplateIDs: [String], dayNames: [String]) -> Bool {
        dayIsRest[i] || (dayExercises[i].isEmpty
                         && dayTemplateIDs[i].isEmpty
                         && dayNames[i].trimmingCharacters(in: .whitespaces).isEmpty)
    }

    static func upsertDays(splitID: String,
                           dayLabels: [String],
                           dayNames: [String],
                           dayTemplateIDs: [String],
                           dayIsRest: [Bool],
                           dayExercises: [[DayExercise]],
                           dayExcludedMuscles: [Set<FineMuscle>],
                           existing: [UserSplitDayRecord],
                           modelContext: ModelContext) {
        let encoder = JSONEncoder()
        let byIndex = Dictionary(uniqueKeysWithValues: existing.map { ($0.orderIndex, $0) })

        for (i, label) in dayLabels.enumerated() {
            let rest = isEffectivelyRest(i, dayIsRest: dayIsRest, dayExercises: dayExercises,
                                        dayTemplateIDs: dayTemplateIDs, dayNames: dayNames)
            let exData = try? encoder.encode(dayExercises[i])
            let exJSON = exData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let dayName = rest ? "Rest" : (dayNames[i].isEmpty ? label : dayNames[i])
            let templateID = rest ? "" : dayTemplateIDs[i]
            let json = rest ? "[]" : exJSON
            let exclusions = rest ? [] : dayExcludedMuscles[i]

            if let day = byIndex[i] {
                day.dayLabel = label
                day.dayName = dayName
                day.templateID = templateID
                day.isRest = rest
                day.exercisesJSON = json
                day.excludedMuscles = exclusions
                // variantsJSON deliberately untouched — the builder doesn't own it.
            } else {
                let day = UserSplitDayRecord(
                    splitID: splitID, orderIndex: i, dayLabel: label,
                    dayName: dayName, templateID: templateID, isRest: rest, exercisesJSON: json)
                day.excludedMuscles = exclusions
                modelContext.insert(day)
            }
        }

        // Defensive only — `dayLabels` is always 7 entries, so a real split never has a stray row
        // beyond index 6. Guards against orphaning a row if that ever changes.
        for day in existing where day.orderIndex >= dayLabels.count { modelContext.delete(day) }
    }
}
