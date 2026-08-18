import Foundation

/// Estimated-1RM maths and the "is this the same lift?" rule, in one place.
///
/// Both were duplicated: the Epley formula appeared in `TrainViewModel.checkAndUpdatePR`,
/// `PostSessionSummaryView.e1rm` and the backend's SQL, and the lift-grouping rule lived only inside
/// `TrainViewModel.sameLift`. Two copies of a formula drift; a formula that lives next to the rule it's
/// grouped by can at least be tested together.
enum StrengthMath {

    /// Epley: `w × (1 + reps/30)`. Returns nil where the estimate is meaningless rather than returning
    /// a number nobody should act on — a set with no weight (bodyweight, or the field left blank) has no
    /// 1RM, and past ~30 reps the formula stops describing strength. A zero here is what put "0 lb
    /// current" on the Stats tab's e1RM card.
    static func e1rm(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, reps > 0, reps <= 30 else { return nil }
        return weightKg * (1.0 + Double(reps) / 30.0)
    }

    /// Two logged sets are the same lift when they're on the same specific machine, or both are generic
    /// and share a name. This is what keeps PRs and progressive overload scoped to one machine — a
    /// 100kg Hammer Strength press is not a 100kg Cybex press.
    static func isSameLift(nameA: String, dedupeKeyA: String?,
                           nameB: String, dedupeKeyB: String?) -> Bool {
        let a = normalizedKey(dedupeKeyA)
        let b = normalizedKey(dedupeKeyB)
        if let a, let b { return a == b }
        if a == nil && b == nil { return nameA.caseInsensitiveCompare(nameB) == .orderedSame }
        return false
    }

    /// A blank or whitespace-only dedupe key means "generic", not "a machine whose key is empty".
    static func normalizedKey(_ key: String?) -> String? {
        guard let k = key?.trimmingCharacters(in: .whitespacesAndNewlines), !k.isEmpty else { return nil }
        return k.lowercased()
    }

    // MARK: Personal records

    /// One lift's best set.
    struct Best: Identifiable, Equatable {
        /// Display label — the brand-qualified name when the set came from a specific machine.
        let label: String
        let weightKg: Double
        let reps: Int
        let e1rm: Double
        let achievedAt: Date?

        var id: String { label }
    }

    /// Best set per lift, strongest first, computed from logged sets.
    ///
    /// Exists because the Stats PR board read `/analytics/prs` while the Train tab read `/prs`, and the
    /// two disagreed — one showed eleven records, the other none. The device has every set already, so
    /// it can answer without asking, consistently and offline.
    static func personalRecords<S: Sequence>(
        from sets: S,
        label: (String, String?) -> String = { name, brand in
            guard let brand, !brand.isEmpty, !name.localizedCaseInsensitiveContains(brand) else { return name }
            return "\(brand) \(name)"
        }
    ) -> [Best] where S.Element == (name: String, dedupeKey: String?, brand: String?,
                                    weightKg: Double, reps: Int, at: Date?) {
        var best: [String: Best] = [:]
        for s in sets {
            guard let e = e1rm(weightKg: s.weightKg, reps: s.reps) else { continue }
            // Group by machine when there is one, else by name — the same rule as `isSameLift`.
            let key = normalizedKey(s.dedupeKey) ?? s.name.lowercased()
            let candidate = Best(label: label(s.name, s.brand), weightKg: s.weightKg,
                                 reps: s.reps, e1rm: e, achievedAt: s.at)
            if let existing = best[key], existing.e1rm >= e { continue }
            best[key] = candidate
        }
        return best.values.sorted {
            $0.e1rm == $1.e1rm ? $0.label < $1.label : $0.e1rm > $1.e1rm
        }
    }
}
