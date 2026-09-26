import Foundation

extension Int {
    /// "1 day" / "2 days" — a count with a correctly pluralised noun.
    ///
    /// Exists so the fix is one call rather than a ternary at every site; the app had "1 Weeks",
    /// "1 days" and "1 exercises" scattered across History, the feed, friend profiles and split detail.
    /// Pass `plural` explicitly for irregular nouns.
    func pluralized(_ singular: String, _ plural: String? = nil) -> String {
        "\(self) \(self == 1 ? singular : (plural ?? singular + "s"))"
    }

    /// Just the noun, when the number is rendered separately (a big stat figure over its label).
    func pluralLabel(_ singular: String, _ plural: String? = nil) -> String {
        self == 1 ? singular : (plural ?? singular + "s")
    }
}

extension Double {
    /// Same, for set counts that can be fractional — assisting work is credited at half a set, so
    /// "1 set" is right but "1.5 sets" is too.
    func pluralized(_ singular: String, _ plural: String? = nil) -> String {
        let n = self == rounded() ? String(Int(self)) : String(format: "%.1f", self)
        return "\(n) \(self == 1 ? singular : (plural ?? singular + "s"))"
    }
}
