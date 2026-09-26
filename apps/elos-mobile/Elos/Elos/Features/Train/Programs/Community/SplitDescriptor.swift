import Foundation

// MARK: - SplitDescriptor
// Pure engine that turns a split's days into an at-a-glance description:
// per-day focus (Push / Pull / Legs / Upper / …), an overall archetype
// ("Push / Pull / Legs", "Upper / Lower", "Bro Split"…), and summary stats.
// No UI, no IO — unit-testable. Works for both local UserSplitDayRecord data
// and community split snapshots.

enum DayFocus: String, CaseIterable {
    case push, pull, legs, upper, lower, fullBody, arms, chest, back, shoulders, core, rest, other

    /// Short label shown in the day-pattern strip.
    var shortLabel: String {
        switch self {
        case .push:      return "PSH"
        case .pull:      return "PLL"
        case .legs:      return "LEG"
        case .upper:     return "UPR"
        case .lower:     return "LWR"
        case .fullBody:  return "FULL"
        case .arms:      return "ARM"
        case .chest:     return "CHT"
        case .back:      return "BCK"
        case .shoulders: return "SHD"
        case .core:      return "COR"
        case .rest:      return "—"
        case .other:     return "TRN"
        }
    }

    var displayName: String {
        switch self {
        case .push:      return "Push"
        case .pull:      return "Pull"
        case .legs:      return "Legs"
        case .upper:     return "Upper"
        case .lower:     return "Lower"
        case .fullBody:  return "Full Body"
        case .arms:      return "Arms"
        case .chest:     return "Chest"
        case .back:      return "Back"
        case .shoulders: return "Shoulders"
        case .core:      return "Core"
        case .rest:      return "Rest"
        case .other:     return "Training"
        }
    }
}

/// One day's input to the descriptor: rest flag, optional user-given name
/// ("Push Day"), and (exercise name, sets) pairs.
struct DescriptorDayInput {
    let isRest: Bool
    let dayName: String
    let exercises: [(name: String, sets: Int)]
}

struct DescribedDay: Identifiable {
    let id: Int          // order index
    let focus: DayFocus
}

struct SplitDescriptor {
    let days: [DescribedDay]
    let trainingDaysPerWeek: Int
    let archetype: String            // e.g. "Push / Pull / Legs"
    let topMuscles: [String]         // top muscle labels by weekly sets, max 3
    let totalWeeklySets: Int
    let estimatedMinutesPerSession: Int

    /// e.g. "5 Days · Push / Pull / Legs · ~60 min"
    var summaryLine: String {
        var parts = ["\(trainingDaysPerWeek) Day\(trainingDaysPerWeek == 1 ? "" : "s")", archetype]
        if estimatedMinutesPerSession > 0 { parts.append("~\(estimatedMinutesPerSession) min") }
        return parts.joined(separator: " · ")
    }

    // MARK: Building

    static func describe(days inputs: [DescriptorDayInput]) -> SplitDescriptor {
        let described = inputs.enumerated().map { idx, day in
            DescribedDay(id: idx, focus: classify(day))
        }
        let training = described.filter { $0.focus != .rest }
        let totalSets = inputs.reduce(0) { sum, day in
            day.isRest ? sum : sum + day.exercises.reduce(0) { $0 + $1.sets }
        }
        let setsPerSession = training.isEmpty ? 0 : totalSets / training.count
        // ~3 min per working set (set + rest) rounded to the nearest 5.
        let estMinutes = setsPerSession == 0 ? 0 : max(20, Int((Double(setsPerSession) * 3.0 / 5.0).rounded()) * 5)

        return SplitDescriptor(
            days: described,
            trainingDaysPerWeek: training.count,
            archetype: archetype(for: training.map(\.focus)),
            topMuscles: topMuscles(in: inputs),
            totalWeeklySets: totalSets,
            estimatedMinutesPerSession: estMinutes
        )
    }

    // MARK: Day classification

    static func classify(_ day: DescriptorDayInput) -> DayFocus {
        if day.isRest { return .rest }
        if let named = focusFromName(day.dayName) { return named }
        if day.exercises.isEmpty { return .rest }
        return focusFromExercises(day.exercises)
    }

    /// Day names like "Push Day" or "Upper A" are usually the author's intent —
    /// trust them before inferring from exercises.
    static func focusFromName(_ name: String) -> DayFocus? {
        let n = name.lowercased()
        guard !n.isEmpty else { return nil }
        if n.contains("rest") { return .rest }
        if n.contains("push") { return .push }
        if n.contains("pull") { return .pull }
        if n.contains("leg") || n.contains("quad") || n.contains("hamstring") { return .legs }
        if n.contains("upper") { return .upper }
        if n.contains("lower") { return .lower }
        if n.contains("full") { return .fullBody }
        if n.contains("arm") || (n.contains("bicep") && n.contains("tricep")) { return .arms }
        if n.contains("chest") { return .chest }
        if n.contains("back") { return .back }
        if n.contains("shoulder") || n.contains("delt") { return .shoulders }
        if n.contains("core") || n.contains("ab") { return .core }
        return nil
    }

    static func focusFromExercises(_ exercises: [(name: String, sets: Int)]) -> DayFocus {
        var sets: [String: Int] = [:]  // muscle label -> weekly sets
        for ex in exercises {
            guard let label = muscleLabel(for: resolvedMuscleTargets(exerciseID: nil, name: ex.name))
                else { continue }
            sets[label, default: 0] += ex.sets
        }
        guard !sets.isEmpty else { return .other }

        let push  = (sets["Chest"] ?? 0) + (sets["Shoulders"] ?? 0) + (sets["Triceps"] ?? 0)
        let pull  = (sets["Back"] ?? 0) + (sets["Biceps"] ?? 0)
        let legs  = (sets["Quads"] ?? 0) + (sets["Hamstrings"] ?? 0) + (sets["Glutes"] ?? 0) + (sets["Calves"] ?? 0)
        let arms  = (sets["Biceps"] ?? 0) + (sets["Triceps"] ?? 0)
        let total = push + pull + legs

        guard total > 0 else { return .other }
        let pushShare = Double(push) / Double(total)
        let pullShare = Double(pull) / Double(total)
        let legShare  = Double(legs) / Double(total)

        // A day is "dedicated" to a bucket when it dominates the volume.
        if legShare >= 0.7 { return .legs }
        if pushShare >= 0.7 {
            // Mostly chest with a little pressing support reads as a chest day.
            if let chest = sets["Chest"], chest * 2 >= push + 1, sets["Shoulders", default: 0] == 0 { return .chest }
            return .push
        }
        if pullShare >= 0.7 {
            if let back = sets["Back"], back == pull { return .back }
            return .pull
        }
        if Double(arms) / Double(total) >= 0.7 { return .arms }
        if legShare <= 0.15 { return .upper }
        if legShare >= 0.5 && pushShare + pullShare <= 0.3 { return .lower }
        return .fullBody
    }

    // MARK: Archetype

    static func archetype(for focuses: [DayFocus]) -> String {
        let training = focuses.filter { $0 != .rest }
        guard !training.isEmpty else { return "Rest Week" }

        let unique = Set(training)
        let pplSet: Set<DayFocus> = [.push, .pull, .legs]
        let ulSet: Set<DayFocus>  = [.upper, .lower]
        let broSet: Set<DayFocus> = [.chest, .back, .shoulders, .legs, .arms]

        if unique == [.fullBody] { return "Full Body" }
        // Name only the days that actually exist. These branches used to return the full
        // "Push / Pull / Legs" for any *subset* of two, so a Push+Pull week (no legs day at all)
        // was labelled "Push / Pull / Legs" — the split card then read "2 Days · Push / Pull /
        // Legs", contradicting its own day count and promising a leg day that isn't there.
        if unique.isSubset(of: pplSet) && unique.count >= 2 { return join(unique, order: [.push, .pull, .legs]) }
        if unique.isSubset(of: ulSet) { return join(unique, order: [.upper, .lower]) }
        if unique.isSubset(of: broSet) && unique.count >= 3 { return "Bro Split" }
        if unique.isSubset(of: pplSet.union(ulSet)) { return "PPL + Upper / Lower" }
        if unique.isSubset(of: pplSet.union([.fullBody])) { return "PPL + Full Body" }
        if unique.isSubset(of: ulSet.union([.fullBody])) { return "Upper / Lower + Full Body" }
        if unique.isSubset(of: pplSet.union([.arms, .core])) {
            return join(unique.intersection(pplSet), order: [.push, .pull, .legs])
        }
        return "Hybrid"
    }

    /// "Push / Pull", "Push / Pull / Legs" — the present focuses in a fixed, readable order.
    private static func join(_ focuses: Set<DayFocus>, order: [DayFocus]) -> String {
        order.filter { focuses.contains($0) }.map(\.displayName).joined(separator: " / ")
    }

    // MARK: Top muscles

    static func topMuscles(in inputs: [DescriptorDayInput]) -> [String] {
        var sets: [String: Int] = [:]
        for day in inputs where !day.isRest {
            for ex in day.exercises {
                guard let label = muscleLabel(for: resolvedMuscleTargets(exerciseID: nil, name: ex.name))
                else { continue }
                sets[label, default: 0] += ex.sets
            }
        }
        return sets.sorted { $0.value > $1.value }.prefix(3).map(\.key)
    }
}

// MARK: - Convenience builders

extension SplitDescriptor {
    /// Build from local SwiftData day records.
    static func describe(dayRecords: [UserSplitDayRecord]) -> SplitDescriptor {
        let inputs = dayRecords.sorted { $0.orderIndex < $1.orderIndex }.map { day -> DescriptorDayInput in
            let exs = (try? JSONDecoder().decode([DayExercise].self, from: Data(day.exercisesJSON.utf8))) ?? []
            return DescriptorDayInput(
                isRest: day.isRest,
                dayName: day.dayName,
                exercises: exs.map { ($0.name, $0.sets) }
            )
        }
        return describe(days: inputs)
    }

    /// Build from a community split snapshot.
    static func describe(communityDays: [CommunitySplitDayResponse]) -> SplitDescriptor {
        let inputs = communityDays.sorted { $0.order_index < $1.order_index }.map { day -> DescriptorDayInput in
            let exs = (try? JSONDecoder().decode([DayExercise].self, from: Data(day.exercises_json.utf8))) ?? []
            return DescriptorDayInput(
                isRest: day.is_rest,
                dayName: day.day_name,
                exercises: exs.map { ($0.name, $0.sets) }
            )
        }
        return describe(days: inputs)
    }
}
