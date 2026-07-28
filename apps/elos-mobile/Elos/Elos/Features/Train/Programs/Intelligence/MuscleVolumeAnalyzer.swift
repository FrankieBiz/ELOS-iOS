import Foundation

/// How a muscle's volume sits against its productive band.
/// Case order is not meaningful — use `severity` to compare.
enum VolumeStatus: String, Equatable {
    case untrained    // no sets at all
    case under        // trained, but below the minimum effective volume
    case light        // at/above MEV, below the productive band
    case productive   // inside the productive band — the target
    case high         // above the band but still recoverable
    case excessive    // beyond maximum recoverable volume

    /// How badly this wants the lifter's attention. Used to roll a group row up to its worst child.
    /// An untrained muscle outranks an overworked one: a gap is the more actionable problem.
    var severity: Int {
        switch self {
        case .productive: return 0
        case .high:       return 1
        case .light:      return 2
        case .excessive:  return 3
        case .under:      return 4
        case .untrained:  return 5
        }
    }

    var isOnTarget: Bool { self == .productive || self == .high }
}

/// Sets credited to one muscle, split by how they were earned.
///
/// The split matters because "is this muscle *targeted*?" and "how much stimulus does it get?" are
/// different questions with different right answers. Bench press + incline press gives the triceps
/// real stimulus but zero *direct* work — so the coverage tip ("no direct triceps work") and the
/// volume bar (partially filled) are both correct, and the UI shows both segments rather than
/// pretending one number answers both.
struct MuscleCredit: Equatable {
    var direct: Double = 0     // sets where this is the primary muscle
    var indirect: Double = 0   // sets where it's secondary, at `TrainingScience.secondaryCredit`

    var total: Double { direct + indirect }
    var isTargeted: Bool { direct > 0 }

    static let zero = MuscleCredit()

    static func + (l: MuscleCredit, r: MuscleCredit) -> MuscleCredit {
        MuscleCredit(direct: l.direct + r.direct, indirect: l.indirect + r.indirect)
    }
}

/// One row of the coverage display. A group row (`fine == nil`) carries its fine children so the UI
/// can expand it; fine rows have `children == []`.
struct MuscleVolumeBar: Identifiable, Equatable {
    let fine: FineMuscle?
    let group: MuscleGroup
    let credit: MuscleCredit
    /// The productive band. `nil` on a multi-child group row: summing per-muscle targets would
    /// invent a number that means nothing (calves and quads don't need equal volume).
    let band: TrainingScience.VolumeBand?
    /// 0…1 for the bar. Reaching `targetLow` fills 0.75, `targetHigh` fills 1.0 — so "filling the
    /// bar" literally means "get into the productive band".
    let fill: Double
    /// The portion of `fill` earned by direct work, so the bar can render direct vs indirect.
    let directFill: Double
    let status: VolumeStatus
    /// Whether the current intent expects this muscle to be trained. A Push day does not expect
    /// hamstrings, so hamstrings are not shown as a failure.
    let isExpected: Bool
    /// Prehab/indirect muscles (rotator cuff, forearms) — never flagged as a gap.
    let isOptional: Bool
    let children: [MuscleVolumeBar]
    /// Group rows only: how many expected children are on target, out of how many.
    let inRangeCount: Int
    let expectedCount: Int

    var id: String { fine?.rawValue ?? "group-\(group.rawValue)" }
    var isGroupRow: Bool { fine == nil }
    var displayName: String { fine?.displayName ?? group.displayName }
    var isExpandable: Bool { children.count > 1 }
    var sets: Double { credit.total }
}

struct MuscleVolumeReport: Equatable {
    /// One row per `MuscleGroup`, in `MuscleGroup.allCases` order, each with its children.
    let bars: [MuscleVolumeBar]
    let creditByFine: [FineMuscle: MuscleCredit]
    /// Distinct days each muscle is trained *directly* — the input to `FrequencyScorer`.
    /// Indirect work doesn't count: a muscle isn't "trained twice a week" by two days of pressing.
    let directDaysByFine: [FineMuscle: Int]
    let expected: Set<FineMuscle>

    static let empty = MuscleVolumeReport(bars: [], creditByFine: [:],
                                          directDaysByFine: [:], expected: [])

    // Distinct labels for the group variants: `FineMuscle` and `MuscleGroup` share case names
    // (`.chest`, `.glutes`), so a single overloaded `sets(for:)` is ambiguous at the call site.
    func sets(for fine: FineMuscle) -> Double { creditByFine[fine]?.total ?? 0 }
    func sets(forGroup group: MuscleGroup) -> Double {
        group.children.reduce(0) { $0 + sets(for: $1) }
    }
    func directSets(for fine: FineMuscle) -> Double { creditByFine[fine]?.direct ?? 0 }
    func directSets(forGroup group: MuscleGroup) -> Double {
        group.children.reduce(0) { $0 + directSets(for: $1) }
    }
}

/// Single source of truth for per-muscle dosing. Both `VolumeScorer` and the coverage bars read this,
/// so the number the lifter sees and the number the score is computed from can never disagree.
enum MuscleVolumeAnalyzer {

    static func analyze(resolvedDays: [[ResolvedExercise]],
                        scope: QualityScope,
                        intent: TrainingIntent?,
                        dayNames: [String],
                        profile: TrainingProfile,
                        catalog: [ExerciseCandidate]) -> MuscleVolumeReport {

        var creditByFine: [FineMuscle: MuscleCredit] = [:]
        var directDaysByFine: [FineMuscle: Int] = [:]

        for day in resolvedDays {
            var directThisDay: Set<FineMuscle> = []
            for r in day {
                for (muscle, credit) in credits(r) {
                    creditByFine[muscle, default: .zero] = (creditByFine[muscle] ?? .zero) + credit
                    if credit.direct > 0 { directThisDay.insert(muscle) }
                }
            }
            for m in directThisDay { directDaysByFine[m, default: 0] += 1 }
        }

        let expected = expectedMuscles(scope: scope, intent: intent, dayNames: dayNames,
                                       trained: Set(creditByFine.keys),
                                       resolvedDays: resolvedDays, catalog: catalog)

        let bars = MuscleGroup.allCases.map { group in
            groupRow(group, creditByFine: creditByFine, expected: expected,
                     scope: scope, profile: profile)
        }

        return MuscleVolumeReport(bars: bars, creditByFine: creditByFine,
                                  directDaysByFine: directDaysByFine, expected: expected)
    }

    // MARK: Fractional credit

    /// Fine-muscle credit for one exercise. A secondary muscle earns half a set. When the primary and
    /// a secondary land in the same slot — or two secondaries do — the slot takes the *largest*
    /// credit rather than the sum, so one exercise can't inflate a muscle by naming it twice.
    /// Direct work supersedes indirect entirely for the same slot.
    static func credits(_ r: ResolvedExercise) -> [FineMuscle: MuscleCredit] {
        guard let c = r.candidate else { return [:] }
        let sets = Double(r.exercise.sets)
        guard sets > 0 else { return [:] }

        var out: [FineMuscle: MuscleCredit] = [:]
        if let primary = MuscleTaxonomy.fine(forMuscle: c.primaryMuscle) {
            out[primary] = MuscleCredit(direct: sets, indirect: 0)
        }
        for s in c.secondaryMuscles {
            guard let f = MuscleTaxonomy.fine(forMuscle: s) else { continue }
            guard out[f]?.direct ?? 0 == 0 else { continue }   // already trained directly here
            let indirect = sets * TrainingScience.secondaryCredit
            out[f] = MuscleCredit(direct: 0, indirect: max(out[f]?.indirect ?? 0, indirect))
        }
        return out
    }

    // MARK: Expectation

    /// Which muscles the current plan is *supposed* to cover.
    /// - A week should cover everything non-optional.
    /// - A single session covers only what its focus implies; with no focus we expect exactly what's
    ///   already there, so an unnamed template is never nagged about muscles it never claimed.
    static func expectedMuscles(scope: QualityScope,
                                intent: TrainingIntent?,
                                dayNames: [String],
                                trained: Set<FineMuscle>,
                                resolvedDays: [[ResolvedExercise]],
                                catalog: [ExerciseCandidate]) -> Set<FineMuscle> {
        switch scope {
        case .weeklySplit:
            return Set(FineMuscle.allCases.filter {
                !TrainingScience.weeklyBand(for: $0, experience: .intermediate).isOptional
            })

        case .singleSession:
            let focus = intent?.focus ?? inferredArchetype(dayNames: dayNames,
                                                           resolvedDays: resolvedDays,
                                                           catalog: catalog)
            guard let focus else { return trained }
            let fromFocus = MuscleTaxonomy.targetMuscles(forArchetype: focus)
                .compactMap { MuscleTaxonomy.fine(forMuscle: $0) }
            // Union with what's actually trained: if they've added it, it counts, even off-focus.
            return Set(fromFocus).union(trained)
        }
    }

    private static func inferredArchetype(dayNames: [String],
                                          resolvedDays: [[ResolvedExercise]],
                                          catalog: [ExerciseCandidate]) -> SplitArchetype? {
        let added = resolvedDays.flatMap { $0 }.map {
            DayExercise(id: $0.exercise.id, name: $0.exercise.name,
                        sets: $0.exercise.sets, reps: $0.exercise.repsText)
        }
        return DayContextInferrer.infer(dayName: dayNames.first ?? "",
                                        added: added, catalog: catalog).archetype
    }

    // MARK: Row construction

    private static func groupRow(_ group: MuscleGroup,
                                 creditByFine: [FineMuscle: MuscleCredit],
                                 expected: Set<FineMuscle>,
                                 scope: QualityScope,
                                 profile: TrainingProfile) -> MuscleVolumeBar {
        let childBars = group.children.map { fine in
            fineRow(fine, credit: creditByFine[fine] ?? .zero,
                    isExpected: expected.contains(fine), scope: scope, profile: profile)
        }
        let totalCredit = childBars.reduce(MuscleCredit.zero) { $0 + $1.credit }
        let expectedChildren = childBars.filter { $0.isExpected }
        let inRange = expectedChildren.filter { $0.status.isOnTarget }.count

        // A single-child group (chest, glutes, core) *is* its child — mirror it, and expose no
        // children so the UI doesn't offer a chevron revealing a duplicate row. These are also the
        // only group rows with a meaningful band, so keep it.
        if group.children.count == 1, let only = childBars.first {
            return MuscleVolumeBar(
                fine: nil, group: group, credit: only.credit, band: only.band, fill: only.fill,
                directFill: only.directFill, status: only.status, isExpected: only.isExpected,
                isOptional: only.isOptional, children: [],
                inRangeCount: inRange, expectedCount: expectedChildren.count)
        }

        guard !expectedChildren.isEmpty else {
            // Nothing here is expected (e.g. Legs on a Push day) — a neutral, non-failing row.
            // Guarding this also avoids a 0/0 mean below.
            return MuscleVolumeBar(
                fine: nil, group: group, credit: totalCredit, band: nil, fill: 0, directFill: 0,
                status: totalCredit.total > 0 ? .productive : .untrained,
                isExpected: false, isOptional: false, children: childBars,
                inRangeCount: 0, expectedCount: 0)
        }

        let n = Double(expectedChildren.count)
        let meanFill = expectedChildren.reduce(0.0) { $0 + $1.fill } / n
        let meanDirectFill = expectedChildren.reduce(0.0) { $0 + $1.directFill } / n
        let worst = expectedChildren.max { $0.status.severity < $1.status.severity }!.status

        return MuscleVolumeBar(
            fine: nil, group: group, credit: totalCredit, band: nil, fill: meanFill,
            directFill: meanDirectFill, status: worst, isExpected: true, isOptional: false,
            children: childBars, inRangeCount: inRange, expectedCount: expectedChildren.count)
    }

    private static func fineRow(_ fine: FineMuscle,
                                credit: MuscleCredit,
                                isExpected: Bool,
                                scope: QualityScope,
                                profile: TrainingProfile) -> MuscleVolumeBar {
        let band: TrainingScience.VolumeBand = {
            switch scope {
            case .weeklySplit:   return TrainingScience.weeklyBand(for: fine, experience: profile.experience)
            case .singleSession: return TrainingScience.sessionBand(for: fine)
            }
        }()

        return MuscleVolumeBar(
            fine: fine, group: fine.group, credit: credit, band: band,
            fill: fill(sets: credit.total, band: band),
            directFill: fill(sets: credit.direct, band: band),
            status: status(sets: credit.total, band: band),
            isExpected: isExpected, isOptional: band.isOptional, children: [],
            inRangeCount: 0, expectedCount: 0)
    }

    // MARK: Fill & status

    /// Piecewise so the productive band occupies the top quarter of the bar: 0 → 0,
    /// `targetLow` → 0.75, `targetHigh` → 1.0, beyond → 1.0 (overflow shows up via `status`).
    static func fill(sets: Double, band: TrainingScience.VolumeBand) -> Double {
        guard sets > 0 else { return 0 }
        guard band.targetLow > 0 else { return sets >= band.targetHigh ? 1 : 0.75 }
        if sets < band.targetLow {
            return min(0.75, (sets / band.targetLow) * 0.75)
        }
        guard band.targetHigh > band.targetLow else { return 1 }
        let through = (sets - band.targetLow) / (band.targetHigh - band.targetLow)
        return min(1.0, 0.75 + through * 0.25)
    }

    static func status(sets: Double, band: TrainingScience.VolumeBand) -> VolumeStatus {
        if sets <= 0 { return .untrained }
        if sets > band.mrv { return .excessive }
        if sets > band.targetHigh { return .high }
        if sets >= band.targetLow { return .productive }
        if sets >= band.mev { return .light }
        return .under
    }
}
