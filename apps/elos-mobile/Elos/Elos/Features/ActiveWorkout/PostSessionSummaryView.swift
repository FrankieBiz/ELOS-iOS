import SwiftUI
import SwiftData

struct PostSessionSummaryView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @EnvironmentObject var context: TrainingContext
    @Environment(\.modelContext) private var modelContext

    let summary: SessionSummary

    @State private var beforeProgress: GamificationEngine.UserProgress?
    @State private var afterProgress:  GamificationEngine.UserProgress?

    private var durationMinutes: Int {
        Int(Date().timeIntervalSince(summary.startedAt)) / 60
    }

    private var volumeLbs: String {
        let lbs = summary.totalVolumeKg * 2.205
        if lbs >= 1000 { return String(format: "%.1fk lbs", lbs / 1000) }
        return String(format: "%.0f lbs", lbs)
    }

    private var thisSessionXP: Int {
        let doneSets = trainVM.sessionSets.filter(\.isDone).count
        return GamificationEngine.sessionXP(completedSets: doneSets, hitPR: !summary.prsHit.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let after = afterProgress, let before = beforeProgress,
                       after.rank != before.rank {
                        rankUpBanner(after.rank)
                    }

                    headerCard
                    xpCard
                    if !summary.prsHit.isEmpty { prCard }
                    muscleCard
                    if summary.comparisonLabel != nil { comparisonCard }
                    if summary.nextWorkoutDay != nil { nextWorkoutCard }
                    analyticsButton
                    doneButton
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(true)
        .onAppear { computeProgress() }
    }

    // MARK: Header

    private var headerCard: some View {
        HStack(spacing: 0) {
            statColumn(title: "\(durationMinutes) min", sub: "Duration")
            Divider().frame(height: 40)
            statColumn(title: volumeLbs, sub: "Volume")
            Divider().frame(height: 40)
            statColumn(title: "\(trainVM.sessionSets.filter(\.isDone).count)", sub: "Sets")
        }
        .padding(16)
        .elosCard()
    }

    private func statColumn(title: String, sub: String) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.system(size: 18, weight: .bold, design: .monospaced))
            Text(sub).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: XP

    private var xpCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill").foregroundStyle(Color.tint)
            Text("+\(thisSessionXP) XP earned")
                .font(.subheadline).fontWeight(.semibold)
            Spacer()
            if let after = afterProgress {
                Text(after.rank.rawValue)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(after.rank.color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(after.rank.color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .elosCard()
    }

    // MARK: PRs

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PERSONAL RECORDS")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            ForEach(summary.prsHit, id: \.self) { exercise in
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                    Text(exercise).font(.subheadline).fontWeight(.semibold)
                    Spacer()
                }
            }
        }
        .padding(14)
        .elosCard()
    }

    // MARK: Muscle breakdown

    private var muscleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MUSCLES HIT")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            let sorted = summary.setsByMuscle.sorted { $0.value > $1.value }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sorted, id: \.key) { item in
                        VStack(spacing: 2) {
                            Text("\(item.value)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                            Text(item.key.capitalized)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(14)
        .elosCard()
    }

    // MARK: Comparison

    private var comparisonCard: some View {
        HStack(spacing: 8) {
            let pct = summary.comparisonPercent ?? 0
            Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                .foregroundStyle(pct >= 0 ? Color.good : Color.bad)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%+.0f%%", pct * 100))
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(pct >= 0 ? Color.good : Color.bad)
                if let label = summary.comparisonLabel {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .elosCard()
    }

    // MARK: Next Workout

    private var nextWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UP NEXT")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.nextWorkoutDay?.dayName ?? "Workout")
                        .font(.subheadline).fontWeight(.semibold)
                    if let date = summary.nextWorkoutDate {
                        Text(nextDateString(date))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "dumbbell.fill").foregroundStyle(Color.tint)
            }
        }
        .padding(14)
        .elosCard()
    }

    // MARK: Buttons

    private var analyticsButton: some View {
        Button {
            context.pendingAnalytics = true
            context.dismissPostSummary()
        } label: {
            Label("View Analytics", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.tintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var doneButton: some View {
        Button {
            context.dismissPostSummary()
        } label: {
            Text("Done")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.tint)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: Rank-up Banner

    private func rankUpBanner(_ rank: GamificationEngine.Rank) -> some View {
        HStack(spacing: 12) {
            Image(systemName: rank.icon).font(.title2).foregroundStyle(rank.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ranked Up!").font(.subheadline).fontWeight(.bold)
                Text("You're now \(rank.rawValue)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(rank.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(rank.color.opacity(0.35), lineWidth: 1))
    }

    private func nextDateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: date)
    }

    // MARK: Progress computation

    private func computeProgress() {
        let ownerID = vm.currentUserID
        guard !ownerID.isEmpty else { return }
        let allSessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())) ?? []
        let allSets     = (try? modelContext.fetch(FetchDescriptor<ExerciseSetRecord>())) ?? []
        let mySessions  = allSessions.filter { $0.ownerID == ownerID && $0.finishedAt != nil }
        let mySets      = allSets.filter { $0.ownerID == ownerID }
        let afterXP = GamificationEngine.totalXP(sessions: mySessions, sets: mySets,
                                                  prCount: vm.personalRecords.count)
        afterProgress = GamificationEngine.progress(totalXP: afterXP)
        let beforeXP = max(0, afterXP - thisSessionXP)
        beforeProgress = GamificationEngine.progress(totalXP: beforeXP)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
