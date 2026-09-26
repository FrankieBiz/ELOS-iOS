import Foundation

/// One movement a machine (or a named exercise) can be used for, with what it trains.
///
/// Most machines do one thing. Some do several — a Pec/Rear Delt station is a chest fly *and* a
/// reverse fly depending on which way you sit — and for those the lifter has to say which one they
/// did, because no amount of metadata can know.
struct MachineMovement: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let targets: MuscleTargets
}

/// Derives what a movement trains from its **name** first and the equipment database's `bodyParts`
/// second.
///
/// Name-before-bodyParts is deliberate. `bodyParts` is scraped manufacturer copy and is wrong often
/// enough to matter — PRIME's Double-Sided Preacher Curl is listed as `["Chest", "Shoulders"]` — while
/// the machine's *name* is written by someone describing the movement. So the name decides what earns
/// credit, and `bodyParts` only widens the list of muscles the lifter is *offered* in the check-off
/// sheet. Bad scraped data can therefore never silently corrupt a coverage number; it can only add an
/// extra unchecked option.
enum EquipmentMuscleMap {

    // MARK: Public API

    /// The movements this machine plausibly supports, best guess first.
    /// Empty only when neither the name nor `bodyParts` says anything usable (a dumbbell rack).
    static func movements(for record: EquipmentRecord) -> [MachineMovement] {
        let named = MovementLexicon.matches(name: record.machineName)
        guard !named.isEmpty else {
            return fromBodyParts(record).map { [MachineMovement(label: "Default", targets: $0)] } ?? []
        }
        // When the name is ambiguous, the manufacturer's own category breaks the tie — a
        // "Pec/Rear Delt" filed under Chest defaults to the fly, not the reverse fly.
        guard named.count > 1,
              let preferred: MuscleGroup = MuscleTaxonomy.fine(forMuscle: record.primaryCategory)?.group
        else { return named }
        func rank(_ m: MachineMovement) -> Int { m.targets.groups.first == preferred ? 0 : 1 }
        return named.sorted { rank($0) < rank($1) }
    }

    /// The single best guess at what this machine trains — what coverage uses until the lifter says
    /// otherwise.
    static func targets(for record: EquipmentRecord) -> MuscleTargets? {
        movements(for: record).first?.targets
    }

    /// A machine is ambiguous when its movements train **different primary muscles** — Pec/Rear Delt,
    /// or Leg Press/Calf Raise. Those are the cases where only the lifter knows the answer.
    ///
    /// The comparison is at `FineMuscle` level, deliberately between the two obvious alternatives:
    /// - Comparing every group each movement touches (including secondaries) over-fires. A
    ///   "Lat Pulldown / High Row" is lats either way, but the row's secondary rear-delts dragged in a
    ///   second group and made the app interrupt for nothing. That was 24 machines.
    /// - Comparing only the broad group under-fires. A Leg Press/Calf Raise is quads-or-calves, both
    ///   `.legs` — completely different muscles that a group check would call equivalent.
    static func isAmbiguous(_ record: EquipmentRecord) -> Bool {
        let ms = movements(for: record)
        guard ms.count > 1 else { return false }
        return Set(ms.compactMap { $0.targets.primary.first }).count > 1
    }

    /// Every muscle worth offering in the check-off sheet, in taxonomy order: the muscles from all
    /// plausible movements, plus whatever `bodyParts` claims. Deliberately generous — an option the
    /// lifter doesn't tick costs nothing.
    static func options(for record: EquipmentRecord) -> [FineMuscle] {
        var pool = Set(movements(for: record).flatMap { $0.targets.all })
        for part in record.bodyParts { pool.formUnion(expand(bodyPart: part)) }
        return FineMuscle.allCases.filter { pool.contains($0) }
    }

    // MARK: bodyParts

    /// Last-resort targets when the machine's name says nothing: the most specific `bodyPart` becomes
    /// the primary, the rest become secondaries.
    private static func fromBodyParts(_ record: EquipmentRecord) -> MuscleTargets? {
        // Tie-break by the record's own ordering, not just specificity. `sorted(by:)` is not a stable
        // sort in Swift, so a machine listing several equally-specific parts (Total Back:
        // ["Back", "Shoulders", "Rear Shoulders", "Biceps"]) could otherwise resolve to a different
        // primary on different runs — attribution has to be reproducible.
        let ranked = record.bodyParts.enumerated()
            .filter { !expand(bodyPart: $0.element).isEmpty }
            .sorted {
                specificity($0.element) != specificity($1.element)
                    ? specificity($0.element) > specificity($1.element)
                    : $0.offset < $1.offset
            }
            .map(\.element)
        guard let best = ranked.first, let primary = expand(bodyPart: best).first else { return nil }
        let rest = ranked.dropFirst().flatMap { expand(bodyPart: $0) }
        return MuscleTargets(primary: [primary], secondary: rest)
    }

    /// Coarse `bodyParts` terms name a whole region, so they expand to every muscle in it rather than
    /// collapsing to one arbitrary pick. "Full Body" carries no information at all.
    static func expand(bodyPart: String) -> [FineMuscle] {
        switch MuscleTaxonomy.normalize(bodyPart) {
        case "full body":  return []
        case "back":       return [.lats, .upperBack]
        case "shoulders":  return [.frontDelts, .sideDelts]
        case "arms":       return [.biceps, .triceps]
        case "legs":       return [.quads, .hamstrings, .calves]
        case "core":       return [.abs]
        default:           return [MuscleTaxonomy.fine(forMuscle: bodyPart)].compactMap { $0 }
        }
    }

    /// Higher = names a single muscle rather than a region. Drives which `bodyPart` becomes primary.
    private static func specificity(_ part: String) -> Int {
        switch MuscleTaxonomy.normalize(part) {
        case "full body":                                        return 0
        case "back", "shoulders", "arms", "legs", "core":         return 1
        default:                                                 return 2
        }
    }
}

/// Name → movement table. Used for machines *and* for plain exercise names that aren't in the
/// catalog, so a custom "Reverse Hyper" still lands on the lower back instead of nowhere.
enum MovementLexicon {

    /// Every entry whose keywords appear in the name, best-guess order (table order), deduped by
    /// label. More than one match means the name itself is ambiguous.
    static func matches(name: String) -> [MachineMovement] {
        let tokens = loose(name).split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return [] }
        var out: [MachineMovement] = []
        var seen: Set<String> = []
        for e in table where e.keywords.contains(where: { hit($0, in: tokens) }) {
            guard seen.insert(e.label).inserted else { continue }
            out.append(MachineMovement(label: e.label,
                                       targets: MuscleTargets(primary: e.primary, secondary: e.secondary)))
        }
        return out
    }

    /// Does `keyword` appear in `tokens` as whole words, allowing the final word to be a prefix?
    ///
    /// Plain substring matching is wrong here in both directions. It over-matches — `"chin"` fired on
    /// "ma-chin-e", which made *every* machine in the database look like a pulldown — and the obvious
    /// fix of requiring exact word equality under-matches, missing the plurals the database is full of
    /// ("calves", "abductors", "dips"). Prefix-matching only the last word gets both: "chin" no longer
    /// touches "machine", while "calve" still reaches "calves" and "lat pull" still reaches
    /// "lat pulldown".
    private static func hit(_ keyword: String, in tokens: [String]) -> Bool {
        let parts = keyword.split(separator: " ").map(String.init)
        guard let last = parts.last, !parts.isEmpty, tokens.count >= parts.count else { return false }
        let lead = parts.dropLast()
        for start in 0...(tokens.count - parts.count) {
            guard Array(tokens[start..<(start + lead.count)]) == Array(lead) else { continue }
            if tokens[start + lead.count].hasPrefix(last) { return true }
        }
        return false
    }

    /// Best-guess targets for a free-text exercise name.
    static func targets(forExerciseName name: String) -> MuscleTargets? {
        matches(name: name).first?.targets
    }

    /// `MuscleTaxonomy.normalize` keeps `/` and `,`, which would hide the second half of
    /// "Pec/Rear Delt" behind a token boundary. Split on them here so both movements are found.
    private static func loose(_ s: String) -> String {
        MuscleTaxonomy.normalize(
            s.replacingOccurrences(of: "/", with: " ")
             .replacingOccurrences(of: ",", with: " ")
             .replacingOccurrences(of: "&", with: " ")
        )
    }

    private struct Entry {
        let label: String
        let keywords: [String]
        let primary: [FineMuscle]
        var secondary: [FineMuscle] = []
    }

    /// Order is the tie-break for "which movement did they most likely mean", so the more specific
    /// and more common machines come first. Keywords must be specific enough not to fire on unrelated
    /// names — a bare "press" or "extension" would match half the database.
    private static let table: [Entry] = [
        .init(label: "Rear delt",       keywords: ["rear delt", "rear shoulder", "reverse fly", "rear fly",
                                                   "reverse pec", "rear laterals"],
              primary: [.rearDelts], secondary: [.upperBack]),
        .init(label: "Pec fly",         keywords: ["pec fly", "pec deck", "peck deck", "chest fly",
                                                   "butterfly", "pec"],
              primary: [.chest], secondary: [.frontDelts]),
        .init(label: "Chest press",     keywords: ["chest press", "bench press", "incline press",
                                                   "decline press", "chest supported press"],
              primary: [.chest], secondary: [.frontDelts, .triceps]),
        // Not "lumbar": on this database that word names the *pad* ("Adjustable Lumbar Incline
        // Bench"), not the target, and it dragged chest benches onto the lower back.
        .init(label: "Back extension",  keywords: ["back extension", "hyperextension", "hyper extension",
                                                   "reverse hyper", "roman chair", "low back",
                                                   "lower back"],
              primary: [.lowerBack], secondary: [.glutes, .hamstrings]),
        .init(label: "Good morning",    keywords: ["good morning"],
              primary: [.lowerBack], secondary: [.hamstrings, .glutes]),
        .init(label: "Glute-ham raise", keywords: ["glute ham", "glute-ham", "ghd", "nordic"],
              primary: [.hamstrings], secondary: [.glutes, .lowerBack]),
        .init(label: "Deadlift",        keywords: ["deadlift", "rack pull"],
              primary: [.hamstrings], secondary: [.glutes, .lowerBack, .upperBack]),
        .init(label: "Pulldown",        keywords: ["pulldown", "pull down", "lat pull", "pull up",
                                                   "pullup", "chin"],
              primary: [.lats], secondary: [.biceps, .upperBack]),
        .init(label: "Pullover",        keywords: ["pullover", "pull over"],
              primary: [.lats], secondary: [.chest]),
        .init(label: "Row",             keywords: ["row"],
              primary: [.lats], secondary: [.upperBack, .rearDelts, .biceps]),
        .init(label: "Shrug",           keywords: ["shrug", "trap"],
              primary: [.upperBack]),
        // "Total Back" / "Upper Back" machines list four equally-specific bodyParts, so the fallback
        // had no principled way to choose between rear delts and biceps for a back machine.
        .init(label: "Upper back",      keywords: ["upper back", "total back"],
              primary: [.upperBack], secondary: [.lats, .rearDelts, .biceps]),
        .init(label: "Shoulder press",  keywords: ["shoulder press", "overhead press", "military press",
                                                   "deltoid press"],
              primary: [.frontDelts], secondary: [.sideDelts, .triceps]),
        // "Deltoid Raise"/"Deltoid Fly" is how 11 shipped machines name a lateral raise; without these
        // they fell back to the spec sheet's coarse "Shoulders" and guessed front delts.
        .init(label: "Lateral raise",   keywords: ["lateral raise", "lateral delt", "side delt",
                                                   "shoulder raise", "lateral shoulder",
                                                   "deltoid raise", "deltoid fly"],
              primary: [.sideDelts]),
        .init(label: "Rotator cuff",    keywords: ["rotator", "external rotation", "internal rotation"],
              primary: [.rotatorCuff]),
        .init(label: "Biceps curl",     keywords: ["biceps curl", "bicep curl", "preacher curl",
                                                   "arm curl", "concentration curl", "hammer curl",
                                                   "biceps", "bicep"],
              primary: [.biceps], secondary: [.forearms]),
        // Not a bare "kickback" — a Pendulum Kickback is a glute machine. "Tricep Kickback" still
        // lands here on "tricep", and a glute kickback still lands on "glute".
        // "Arm Extension" is a triceps machine. Left to the spec sheet, the ones tagged only
        // ["Full Body", "Arms"] expanded "Arms" to [biceps, triceps] and picked *biceps*.
        .init(label: "Triceps",         keywords: ["triceps", "tricep", "pushdown", "push down",
                                                   "skull", "dip", "arm extension"],
              primary: [.triceps]),
        .init(label: "Forearms",        keywords: ["wrist", "forearm", "grip"],
              primary: [.forearms]),
        .init(label: "Leg extension",   keywords: ["leg extension", "knee extension", "quad extension"],
              primary: [.quads]),
        .init(label: "Leg curl",        keywords: ["leg curl", "hamstring curl", "lying curl",
                                                   "seated leg curl", "hamstring"],
              primary: [.hamstrings]),
        // "squat" already covers every Pendulum Squat, so the brand word alone isn't needed — and as a
        // keyword it swept in the Pendulum Kickback, a glute machine.
        .init(label: "Squat / press",   keywords: ["leg press", "hack squat", "belt squat", "squat",
                                                   "sissy", "lunge", "split squat", "step up"],
              primary: [.quads], secondary: [.glutes]),
        .init(label: "Hip thrust",      keywords: ["hip thrust", "glute drive", "glute bridge",
                                                   "glute press", "hip extension", "glute"],
              primary: [.glutes], secondary: [.hamstrings]),
        // "Outer thigh" and "inner thigh" are the abductor/adductor machines' other name — 12 records.
        .init(label: "Hip abduction",   keywords: ["abductor", "abduction", "outer thigh"],
              primary: [.glutes]),
        .init(label: "Hip adduction",   keywords: ["adductor", "adduction", "inner thigh"],
              primary: [.glutes]),
        .init(label: "Calf raise",      keywords: ["calf", "calve"],
              primary: [.calves]),
        .init(label: "Abs",             keywords: ["abdominal", "ab crunch", "crunch", "oblique",
                                                   "torso", "sit up", "situp", "leg raise",
                                                   "knee raise", "vertical knee", "captain chair",
                                                   "ab machine", "plank"],
              primary: [.abs]),
    ]
}
