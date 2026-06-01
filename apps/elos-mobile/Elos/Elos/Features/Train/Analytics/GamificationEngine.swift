import SwiftUI
import SwiftData

struct GamificationEngine {

    // MARK: - Rank

    enum Rank: String, Equatable {
        case rookie     = "Rookie"
        case contender  = "Contender"
        case athlete    = "Athlete"
        case elite      = "Elite"
        case champion   = "Champion"
        case legend     = "Legend"

        static let ordered: [Rank] = [.rookie, .contender, .athlete, .elite, .champion, .legend]

        var minXP: Int {
            switch self {
            case .rookie:    return 0
            case .contender: return 500
            case .athlete:   return 2_000
            case .elite:     return 5_000
            case .champion:  return 12_000
            case .legend:    return 25_000
            }
        }

        private var maxXP: Int? {
            switch self {
            case .rookie:    return 499
            case .contender: return 1_999
            case .athlete:   return 4_999
            case .elite:     return 11_999
            case .champion:  return 24_999
            case .legend:    return nil
            }
        }

        var bandSize: Int { (maxXP.map { $0 - minXP + 1 }) ?? 25_000 }

        var nextRank: Rank? {
            guard let idx = Rank.ordered.firstIndex(of: self), idx + 1 < Rank.ordered.count
            else { return nil }
            return Rank.ordered[idx + 1]
        }

        var icon: String {
            switch self {
            case .rookie:    return "figure.run"
            case .contender: return "bolt.fill"
            case .athlete:   return "figure.strengthtraining.traditional"
            case .elite:     return "star.fill"
            case .champion:  return "trophy.fill"
            case .legend:    return "crown.fill"
            }
        }

        var color: Color {
            switch self {
            case .rookie:    return Color.secondary
            case .contender: return Color.good
            case .athlete:   return Color.tint
            case .elite:     return Color.blue
            case .champion:  return Color.purple
            case .legend:    return Color.yellow
            }
        }
    }

    // MARK: - Progress snapshot

    struct UserProgress {
        let totalXP: Int
        let rank: Rank
        let xpInBand: Int
        let bandSize: Int
        let progress: Double    // 0...1 within current band
        let xpToNext: Int       // 0 if legend

        var nextRankName: String { rank.nextRank?.rawValue ?? "" }
    }

    // MARK: - Core computations

    static func totalXP(
        sessions: [WorkoutSessionRecord],
        sets: [ExerciseSetRecord],
        prCount: Int
    ) -> Int {
        let sessionXP = sessions.filter { $0.finishedAt != nil }.count * 50
        let setXP     = sets.filter { $0.isDone }.count * 5
        let prXP      = prCount * 100
        return sessionXP + setXP + prXP
    }

    static func sessionXP(completedSets: Int, hitPR: Bool) -> Int {
        50 + completedSets * 5 + (hitPR ? 100 : 0)
    }

    static func workoutStreak(sessions: [WorkoutSessionRecord]) -> Int {
        let cal = Calendar.current
        let completedDays = Set(
            sessions
                .compactMap { $0.finishedAt }
                .map { cal.startOfDay(for: $0) }
        )
        var streak = 0
        var date = cal.startOfDay(for: Date())
        while completedDays.contains(date) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    static func progress(totalXP xp: Int) -> UserProgress {
        let rank    = Rank.ordered.last(where: { xp >= $0.minXP }) ?? .rookie
        let xpIn    = xp - rank.minXP
        let band    = rank.bandSize
        let toNext  = rank.nextRank.map { max(0, $0.minXP - xp) } ?? 0
        return UserProgress(
            totalXP:  xp,
            rank:     rank,
            xpInBand: xpIn,
            bandSize: band,
            progress: min(1.0, Double(xpIn) / Double(max(1, band))),
            xpToNext: toNext
        )
    }
}
