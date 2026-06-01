import SwiftUI
import Combine

// MARK: - Session Summary

struct SessionSummary {
    var startedAt: Date
    var totalVolumeKg: Double
    var setsByMuscle: [String: Int]
    var prsHit: [String]
    var comparisonPercent: Double?
    var comparisonLabel: String?
    var nextWorkoutDay: UserSplitDayRecord?
    var nextWorkoutDate: Date?
}

// MARK: - Training Phase

enum TrainingPhase {
    case idle
    case warmup
    case active
    case postSummary
}

// MARK: - TrainingContext

final class TrainingContext: ObservableObject {

    // MARK: Phase
    @Published var phase: TrainingPhase = .idle

    // MARK: Navigation (owned here instead of TrainView @State)
    @Published var showSplitFinder    = false
    @Published var showAnalytics      = false
    @Published var showLibrary        = false
    @Published var showTemplates      = false
    @Published var showHistory        = false
    @Published var showStretches      = false
    @Published var showSplitLibrary   = false
    @Published var showLeaderboard    = false
    @Published var showExercisePicker = false

    // MARK: Readiness
    @Published var showReadinessSheet = false

    // MARK: Warmup
    @Published var warmupExercises: [WarmupExercise] = []
    @Published var warmupPhaseComplete = false

    // MARK: Post-session
    @Published var sessionSummary: SessionSummary? = nil
    @Published var showPostSummary = false
    @Published var pendingAnalytics = false

    // MARK: Derived (set by TrainView via update())
    private(set) var shouldSuggestDeload: Bool = false
    private(set) var readinessScore: Int? = nil

    var volumeNudge: String? {
        guard let score = readinessScore else { return nil }
        if score <= 2 { return "Very low energy today — consider reducing volume." }
        if score == 3 { return "Moderate fatigue — consider –20% volume today." }
        return nil
    }

    // MARK: - API

    func update(shouldDeload: Bool, readinessScore: Int?) {
        self.shouldSuggestDeload = shouldDeload || (readinessScore.map { $0 <= 2 } ?? false)
        self.readinessScore = readinessScore
    }

    func readinessDidComplete(_ record: ReadinessCheckInRecord) {
        showReadinessSheet = false
    }

    func sessionDidEnd(summary: SessionSummary) {
        sessionSummary = summary
        showPostSummary = true
        phase = .postSummary
    }

    func dismissPostSummary() {
        showPostSummary = false
        sessionSummary = nil
        phase = .idle
    }
}
