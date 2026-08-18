import SwiftUI

// The extra Today widgets. All ship hidden (`isOptIn` in the catalog) — the default Today screen
// stays the screen people already know, and these are what the "Add widgets" tray offers.
//
// Every one of them reads data the app already had and wasn't surfacing on Today: the streak lived
// only on the Train tab's rank card, weekly volume only in Stats, readiness only behind a prompt.
// Nothing here computes anything new — see `DashboardMetrics` for the arithmetic.

// MARK: - Shared tile

/// The house stat tile. Matches the sleep/volume cards Today already had, so an added widget sits
/// beside them rather than looking bolted on.
struct DashboardTile<Accessory: View>: View {
    let color: Color
    let label: String
    let value: String
    let sub: String
    var onTap: (() -> Void)?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        let card = VStack(alignment: .leading, spacing: Space.xs + 2) {
            HStack(spacing: Space.xs) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                accessory
            }
            Text(value)
                .font(.elosNumeric(.title))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(sub)
                .font(.elosCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.card)
        .elosCard()

        if let onTap {
            Button(action: onTap) { card }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
        } else {
            card.accessibilityElement(children: .combine)
        }
    }
}

extension DashboardTile where Accessory == EmptyView {
    init(color: Color, label: String, value: String, sub: String, onTap: (() -> Void)? = nil) {
        self.init(color: color, label: label, value: value, sub: sub, onTap: onTap) { EmptyView() }
    }
}

// MARK: - Streak

struct StreakWidget: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openTab) private var openTab

    var body: some View {
        let days = vm.trainingStreakDays
        DashboardTile(
            color: .mHabits,
            label: "STREAK",
            value: days == 0 ? "—" : "\(days)",
            sub: days == 0 ? "Train today to start one"
                           : (days == 1 ? "day in a row" : "days in a row"),
            onTap: { openTab(.train) }
        ) {
            if days > 0 {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(Color.mHabits)
            }
        }
    }
}

// MARK: - Sessions this week

struct SessionsThisWeekWidget: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openTab) private var openTab

    var body: some View {
        let done = vm.sessionsThisWeek
        let planned = vm.plannedSessionsThisWeek
        DashboardTile(
            color: .mGym,
            label: "SESSIONS",
            // "3 / 4" only when there's a plan to measure against; a bare count otherwise, rather
            // than inventing a denominator for someone with no split.
            value: planned > 0 ? "\(done)/\(planned)" : "\(done)",
            sub: planned > 0 ? "trained this week" : "in the last 7 days",
            onTap: { openTab(.train) }
        )
    }
}

// MARK: - Weekly volume

struct WeeklyVolumeWidget: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openTab) private var openTab

    var body: some View {
        let volume = vm.weightUnit.fromKg(vm.weeklyVolumeKg)
        let change = vm.weeklyVolumeChangePercent
        DashboardTile(
            color: .mNutri,
            label: "WEEK VOLUME",
            value: volume >= 1000 ? String(format: "%.1fk", volume / 1000) : String(format: "%.0f", volume),
            sub: "\(vm.weightUnit.label) over 7 days",
            onTap: { openTab(.stats) }
        ) {
            if let change, abs(change) >= 1 {
                HStack(spacing: 1) {
                    Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(abs(Int(change.rounded())))%")
                }
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(change > 0 ? Color.good : Color.secondary)
                .accessibilityLabel(change > 0 ? "Up \(abs(Int(change.rounded()))) percent on last week"
                                               : "Down \(abs(Int(change.rounded()))) percent on last week")
            }
        }
    }
}

// MARK: - Next workout

struct NextWorkoutWidget: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openTab) private var openTab
    @EnvironmentObject private var trainingContext: TrainingContext

    /// "Tomorrow" / "Thursday" / "Mar 4" — `DateDisplay.friendly` takes the app's stored ISO day
    /// strings, and round-tripping a `Date` through one just to format it here would be silly.
    private static func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: Date()),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        return days < 7 ? Formatters.weekdayLong.string(from: date)
                        : Formatters.weekdayMonthDay.string(from: date)
    }

    var body: some View {
        if let next = vm.nextTrainingDay {
            let isToday = Calendar.current.isDateInToday(next.date)
            HStack(spacing: Space.m) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3)
                    .foregroundStyle(Color.mGym)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT WORKOUT")
                        .elosSectionLabel()
                    Text(next.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .lineLimit(1)
                    Text(isToday ? "Today" : Self.dayLabel(for: next.date))
                        .font(.elosCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)

                Button {
                    HapticManager.impact(.medium)
                    if isToday {
                        vm.prepareExercisesForToday()
                        trainingContext.startSession(activeSplit: vm.activeSplit)
                        vm.showingSession = true
                    } else {
                        // Nothing to start yet — take them to the tab that can plan it instead of
                        // silently doing nothing.
                        openTab(.train)
                    }
                } label: {
                    Text(isToday ? "Start" : "View")
                        .font(.system(.footnote, weight: .bold))
                        .foregroundStyle(Color.onTint)
                        .padding(.horizontal, Space.l)
                        .padding(.vertical, Space.s)
                        .background(Color.tint, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(Space.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .elosCard()
        }
    }
}

// MARK: - Latest PR

struct LatestPRWidget: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openTab) private var openTab

    var body: some View {
        if let pr = vm.personalRecords.first {
            DashboardTile(
                color: .mAssign,
                label: "LATEST PR",
                value: pr.weight.isEmpty ? pr.reps : pr.weight,
                sub: pr.reps.isEmpty ? pr.lift : "\(pr.lift) · \(pr.reps)",
                onTap: { openTab(.stats) }
            ) {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(Color.mAssign)
            }
        }
    }
}

// MARK: - Readiness

struct ReadinessWidget: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openTab) private var openTab

    var body: some View {
        let score = vm.todayReadiness.map { Int($0.overallScore.rounded()) }
        DashboardTile(
            color: color(for: score),
            label: "READINESS",
            value: score.map { "\($0)" } ?? "—",
            // The check-in itself lives behind the Train tab's flow, so this points there rather
            // than trying to present a sheet from a screen that doesn't own it.
            sub: score == nil ? "Check in on Train" : descriptor(for: score ?? 0),
            onTap: { openTab(.train) }
        ) {
            Image(systemName: "gauge.medium")
                .font(.caption)
                .foregroundStyle(color(for: score))
        }
    }

    private func color(for score: Int?) -> Color {
        guard let score else { return .secondary }
        switch score {
        case 75...:  return .good
        case 50..<75: return .warn
        default:      return .bad
        }
    }

    private func descriptor(for score: Int) -> String {
        switch score {
        case 85...:   return "Ready to push"
        case 70..<85: return "Good to train"
        case 50..<70: return "Train, but ease off"
        default:      return "Consider recovery"
        }
    }
}

// MARK: - Body weight

struct BodyWeightWidget: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openTab) private var openTab

    var body: some View {
        if let kg = vm.healthSnapshot.bodyWeightKg, kg > 0 {
            DashboardTile(
                color: .mHealth,
                label: "BODY WEIGHT",
                value: vm.weightUnit.formatValue(kg: kg),
                sub: vm.healthKitEnabled ? "from Apple Health" : "latest logged",
                onTap: { openTab(.me) }
            )
        }
    }
}

// MARK: - Muscle focus

/// The top few muscles by set count this week — a compact read of where the work actually went,
/// without opening the Train tab's full panel.
struct MuscleFocusWidget: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.openTab) private var openTab

    private var top: [MuscleVolume] {
        vm.muscleVolume
            .sorted { $0.current > $1.current }
            .prefix(4)
            .filter { $0.current > 0 }
    }

    var body: some View {
        if !top.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    Text("MUSCLE FOCUS")
                        .elosSectionLabel()
                    Spacer()
                    Button("See all") { openTab(.train) }
                        .font(.elosCaption)
                        .foregroundStyle(Color.tint)
                        .buttonStyle(.plain)
                }

                ForEach(top) { entry in
                    let progress = entry.target > 0
                        ? min(1, Double(entry.current) / Double(entry.target))
                        : 0
                    VStack(alignment: .leading, spacing: Space.xs) {
                        HStack {
                            Text(entry.muscle.capitalized)
                                .font(.system(.footnote, weight: .medium))
                            Spacer()
                            Text(entry.target > 0 ? "\(entry.current)/\(entry.target) sets"
                                                  : "\(entry.current) sets")
                                .font(.elosNumeric(.caption2, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        ProgressBar(value: progress, color: entry.onTrack ? .good : .tint)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            // Four labelled bars in a card that may sit at half width can't reflow.
            .elosDenseLayout()
            .padding(Space.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .elosCard()
        }
    }
}
