import Foundation

struct PersonalizationSignals {
    var favoriteNames: Set<String>
    var recentOrder: [String]
    var frequency: [String: Int]

    init(favoriteNames: Set<String> = [], recentOrder: [String] = [], frequency: [String: Int] = [:]) {
        self.favoriteNames = Set(favoriteNames.map { MuscleTaxonomy.normalize($0) })
        self.recentOrder = recentOrder.map { MuscleTaxonomy.normalize($0) }
        self.frequency = Dictionary(frequency.map { (MuscleTaxonomy.normalize($0.key), $0.value) },
                                    uniquingKeysWith: { a, _ in a })
    }
}

struct PersonalizationProvider {
    let signals: PersonalizationSignals
    private let maxFreq: Int

    init(signals: PersonalizationSignals) {
        self.signals = signals
        self.maxFreq = max(signals.frequency.values.max() ?? 0, 1)
    }

    /// 0…1. Weights: favorite 0.4, recency ≤0.3, frequency ≤0.3.
    func score(forName name: String) -> Double {
        let n = MuscleTaxonomy.normalize(name)
        var s = 0.0
        if signals.favoriteNames.contains(n) { s += 0.4 }
        if let idx = signals.recentOrder.firstIndex(of: n) {
            let depth = Double(signals.recentOrder.count)
            s += 0.3 * (1.0 - Double(idx) / max(depth, 1))
        }
        if let f = signals.frequency[n] {
            s += 0.3 * (Double(f) / Double(maxFreq))
        }
        return min(max(s, 0.0), 1.0)
    }
}
