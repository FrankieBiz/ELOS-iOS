import SwiftUI
import SwiftData

struct PostSessionSummaryView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @EnvironmentObject var context: TrainingContext
    @EnvironmentObject var feedVM: FeedViewModel
    @Environment(\.modelContext) private var modelContext

    let summary: SessionSummary

    @State private var beforeProgress: GamificationEngine.UserProgress?
    @State private var afterProgress:  GamificationEngine.UserProgress?
    @State private var workoutShared = false
    @State private var sharedPRs: Set<String> = []
    @State private var shareImage: UIImage?

    private var durationMinutes: Int {
        Int(Date().timeIntervalSince(summary.startedAt)) / 60
    }

    private var volumeText: String {
        vm.weightUnit.formatVolume(kg: summary.totalVolumeKg)
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
                    shareToFriendsButton
                    shareImageButton
                    if !vm.healthKitEnabled && HealthKitService.shared.isAvailable {
                        connectHealthButton
                    }
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
        .sheet(isPresented: Binding(
            get: { shareImage != nil },
            set: { if !$0 { shareImage = nil } }
        )) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: Header

    private var headerCard: some View {
        HStack(spacing: 0) {
            statColumn(title: "\(durationMinutes) min", sub: "Duration")
            Divider().frame(height: 40)
            statColumn(title: volumeText, sub: "Volume")
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
                    Button {
                        Task { await sharePR(exercise) }
                    } label: {
                        Image(systemName: sharedPRs.contains(exercise)
                              ? "checkmark.circle.fill" : "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(sharedPRs.contains(exercise) ? Color.secondary : Color.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(sharedPRs.contains(exercise))
                    .accessibilityLabel("Share \(exercise) PR to friends")
                }
            }
        }
        .padding(14)
        .elosCard()
    }

    // MARK: Share to Friends

    private var doneSets: [ExerciseSetRecord] { trainVM.sessionSets.filter(\.isDone) }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: Date())
    }

    private func e1rm(_ s: ExerciseSetRecord) -> Double {
        s.weightKg * (1 + Double(s.reps) / 30)
    }

    private var topLiftPayload: FeedTopLift? {
        guard let best = doneSets.max(by: { ($0.weightKg, $0.reps) < ($1.weightKg, $1.reps) }) else {
            return nil
        }
        return FeedTopLift(name: best.exerciseName, weight_kg: best.weightKg, reps: best.reps)
    }

    private var connectHealthButton: some View {
        Button {
            Task { await vm.connectHealth() }
        } label: {
            Label("Connect Apple Health", systemImage: "heart.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.tintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var shareToFriendsButton: some View {
        Button {
            Task {
                let ok = await feedVM.shareWorkout(
                    date: dateString,
                    durationMin: durationMinutes,
                    volumeKg: summary.totalVolumeKg,
                    totalSets: doneSets.count,
                    uniqueExercises: Set(doneSets.map(\.exerciseName)).count,
                    topLift: topLiftPayload,
                    pr: summary.prsHit.first
                )
                if ok { workoutShared = true }
                else { vm.showError("Couldn't share your workout. Please try again.") }
            }
        } label: {
            Label(workoutShared ? "Shared to Friends" : "Share to Friends",
                  systemImage: workoutShared ? "checkmark.circle.fill" : "person.2.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(workoutShared ? Color.secondary : Color.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.tintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(workoutShared)
    }

    private var shareImageButton: some View {
        Button {
            renderShareImage()
        } label: {
            Label("Share Image", systemImage: "photo.on.rectangle.angled")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.tintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func renderShareImage() {
        let card = WorkoutShareCard(
            durationMinutes: durationMinutes,
            volumeString: volumeText,
            totalSets: doneSets.count,
            uniqueExercises: Set(doneSets.map(\.exerciseName)).count,
            topLift: topLiftPayload.map { (name: $0.name, weightKg: $0.weight_kg, reps: $0.reps) },
            capturedPR: summary.prsHit.first,
            unit: vm.weightUnit
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        // If rendering fails (e.g. off-screen layout issue), just don't present anything.
        shareImage = renderer.uiImage
    }

    private func sharePR(_ exercise: String) async {
        let sets = doneSets.filter { $0.exerciseName == exercise }
        guard let best = sets.max(by: { e1rm($0) < e1rm($1) }) else { return }
        let ok = await feedVM.sharePR(
            exerciseName: exercise,
            weightKg: best.weightKg,
            reps: best.reps,
            e1rm: e1rm(best)
        )
        if ok { sharedPRs.insert(exercise) }
        else { vm.showError("Couldn't share your PR. Please try again.") }
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
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                // Muted + non-tinted so the card reads as informational, not a tappable row.
                Image(systemName: "dumbbell.fill").foregroundStyle(.tertiary)
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
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(rank.color.opacity(0.35), lineWidth: 1))
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
