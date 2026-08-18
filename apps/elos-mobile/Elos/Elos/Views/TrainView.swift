import SwiftUI
import SwiftData

// MARK: - Week day data (dynamic — built from active split)
private struct WeekDay: Identifiable {
    let id = UUID()
    let letter: String
    let number: Int
    let title: String
    let sublabel: String
    let isToday: Bool
    let isPast: Bool
    let loadColor: Color
}

// MARK: - Main View
struct TrainView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @EnvironmentObject var socialVM: SocialViewModel
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var context: TrainingContext
    @Environment(\.modelContext) private var modelContext

    /// Minimum width of a quick-action tile, scaled so the grid drops to two columns exactly when the
    /// labels would otherwise start truncating. 104pt lays the six actions out as a clean 3×2 at default
    /// sizes — a fifth tile under a row of four read as an orphan.
    @ScaledMetric(relativeTo: .caption2) private var quickActionMinWidth: CGFloat = 104
    /// Width of a recent-exercise chip. Scaled so the lift name keeps its two lines instead of
    /// truncating as the text grows.
    @ScaledMetric(relativeTo: .caption) private var recentChipWidth: CGFloat = 140

    @State private var expandedExercise: UUID?
    @State private var selectedMuscleName: String? = "chest"
    @State private var prsExpanded         = false
    @State private var waitingForReadiness = false
    @State private var userProgress: GamificationEngine.UserProgress?
    @State private var workoutStreak: Int = 0
    @State private var sessionCount: Int = 0
    @State private var showSkipConfirm = false

    private enum TrainState {
        case noSplit
        case restDay
        case gymDayNoReadiness
        case gymDayReady
    }

    private var trainState: TrainState {
        guard vm.activeSplit != nil else { return .noSplit }
        let isGymToday = vm.weekLoadMap(daysAhead: 1).first?.loadType == "gym"
        guard isGymToday else { return .restDay }
        guard vm.todayReadiness != nil else { return .gymDayNoReadiness }
        return .gymDayReady
    }

    /// The conditions that used to be `if` statements wrapped around each card in the stack. Moved
    /// here so `SectionStack` can drop an empty section without leaving its spacing behind — and so
    /// edit mode can still show a placeholder for a card that has no data yet.
    private func isAvailable(_ section: LayoutSection) -> Bool {
        switch section {
        case .trainDeload:       return context.shouldSuggestDeload
        case .trainRank:         return userProgress != nil
        case .trainRecents:      return !trainVM.recentExercises.isEmpty
        case .trainMuscleVolume: return !vm.muscleVolume.isEmpty
        case .trainPRs:          return !vm.personalRecords.isEmpty
        default:                 return true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                SectionStack(screen: .train, spacing: 20, isAvailable: isAvailable) { section in
                    switch section {
                    case .trainDeload: deloadBanner
                    case .trainRank:
                        if let progress = userProgress {
                            XPRankCard(
                                progress: progress,
                                workoutStreak: workoutStreak,
                                sessionCount: sessionCount,
                                prCount: vm.personalRecords.count
                            )
                        }
                    case .trainStatus:
                        // Four mutually exclusive states of one slot, so they move as a unit —
                        // splitting the readiness prompt away from the header it belongs under would
                        // let someone strand it at the bottom of the screen.
                        switch trainState {
                        case .noSplit:           noSplitHint
                        case .restDay:           restDayCard
                        case .gymDayNoReadiness: VStack(spacing: 20) { programHeader; readinessPromptCard }
                        case .gymDayReady:       programHeader
                        }
                    case .trainWeekStrip:    weekStrip
                    case .trainLeaderboard:  leaderboardCard
                    case .trainQuickActions: quickActions
                    case .trainRecents:      recentExercisesRow
                    case .trainStart:        startButton
                    case .trainExercises:    exercisesSection
                    case .trainMuscleVolume: muscleVolumePanel
                    case .trainRadar:        weeklyRadarCard
                    case .trainPRs:          personalRecordsCard
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .elosPageBackground()
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CustomizeScreenButton(screen: .train)
                }
            }
        }
        .onAppear {
            if expandedExercise == nil {
                expandedExercise = vm.exercises.first?.id
            }
            vm.loadActiveSplit()
            computeUserProgress()
            Task { await trainVM.loadRecentExercises() }
            context.update(
                shouldDeload: trainVM.showDeloadSuggestion,
                readinessScore: vm.todayReadiness.map { Int($0.overallScore.rounded()) }
            )
        }
        .sheet(isPresented: $context.showSplitFinder) {
            SplitFinderView(dismissAll: { context.showSplitFinder = false })
                .environmentObject(vm)
        }
        // Presents the Stats tab's own view rather than a second, older copy of it. `AnalyticsView`
        // was a near-duplicate of `StatsView` — same four cards — but still carried the chip bug
        // `StatsView` documents fixing ("Bench Press" and "Overhead Press" both labelled "Press") and
        // the server-side volume chart that buckets machine work as "Unmatched".
        .sheet(isPresented: $context.showAnalytics)        { StatsView() }
        .sheet(isPresented: $context.showLibrary)          { ExerciseLibraryView(modelContext: vm.modelContext) }
        .sheet(isPresented: $context.showDiscover)         { DiscoverLibraryView(modelContext: vm.modelContext) }
        .sheet(isPresented: $context.showTemplates)        { TemplatesView(modelContext: vm.modelContext) }
        .sheet(isPresented: $context.showStretches)        { StretchRoutinesView() }
        .sheet(isPresented: $context.showSplitLibrary)     { ProgramsView().environmentObject(vm) }
        .sheet(isPresented: $context.showHistory)          { WorkoutHistoryView() }
        .sheet(isPresented: $context.showLeaderboard) {
            CrewView()
                .environmentObject(socialVM)
                .environmentObject(vm)
                .environmentObject(feedVM)
        }
        .sheet(isPresented: $context.showReadinessSheet) {
            ReadinessCheckInView(
                onDismiss: { context.showReadinessSheet = false },
                onComplete: { record in
                    context.readinessDidComplete(record)
                    vm.loadTodayReadiness()
                    waitingForReadiness = false
                    startSessionWithWarmup()
                }
            )
            .environmentObject(vm)
        }
        .sheet(isPresented: $context.showPostSummary) {
            if let summary = context.sessionSummary {
                PostSessionSummaryView(summary: summary)
                    .environmentObject(vm)
                    .environmentObject(trainVM)
                    .environmentObject(context)
            }
        }
        .task {
            let uid = vm.currentUserID
            if !uid.isEmpty {
                await socialVM.load(ownerID: uid)
            }
            await socialVM.loadStandings()
            await socialVM.loadBoard()
            await vm.loadPersonalRecords()
            computeUserProgress()
        }
        .onChange(of: vm.showingSession) { _, isShowing in
            if !isShowing {
                computeUserProgress()
                Task { await vm.loadPersonalRecords(); computeUserProgress() }
            }
        }
        .onChange(of: vm.todayReadiness?.id) { _, _ in
            context.update(
                shouldDeload: trainVM.showDeloadSuggestion,
                readinessScore: vm.todayReadiness.map { Int($0.overallScore.rounded()) }
            )
        }
        .onChange(of: context.showReadinessSheet) { _, isShowing in
            if !isShowing && waitingForReadiness {
                waitingForReadiness = false
                startSessionWithWarmup()
            }
        }
        .onChange(of: context.showPostSummary) { _, isShowing in
            if !isShowing && context.pendingAnalytics {
                context.pendingAnalytics = false
                context.showAnalytics = true
            }
        }
    }

    private func startSessionWithWarmup() {
        context.startSession(activeSplit: vm.activeSplit)
        vm.showingSession = true
    }

    // MARK: Context State Cards

    private var noSplitHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("No active split — tap Programs below to set one up.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var restDayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "moon.fill").foregroundStyle(Color.tint)
                Text("Rest Day").font(.system(.title3, weight: .bold))
                Spacer()
            }
            if let next = vm.weekLoadMap(daysAhead: 7).first(where: { $0.loadType == "gym" }) {
                let cal = Calendar.current
                let daysAway = (cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                                   to: cal.startOfDay(for: next.date)).day ?? 0)
                let dayName = vm.gymDay(for: next.date)?.dayName ?? "Workout"
                Text("Next: \(dayName) in \(daysAway) day\(daysAway == 1 ? "" : "s")")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .elosCard()
    }

    private var readinessPromptCard: some View {
        Button { context.showReadinessSheet = true } label: {
            HStack(spacing: 14) {
                // Was three differently-hued icons (indigo moon, orange flame, yellow bolt) for the
                // sleep/soreness/motivation dimensions the check-in covers — reads as a sticker pack
                // rather than a single control. One icon, one hue, same restraint as every other
                // interactive glyph in the app (tint = interactive, per the app-wide convention).
                Image(systemName: "gauge.medium")
                    .font(.system(.title2, weight: .medium))
                    .foregroundStyle(Color.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick check-in before you train?")
                        .font(.subheadline).fontWeight(.semibold)
                    Text("Takes 10 seconds — helps us guide your session.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Deload Banner
    private var deloadBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(Color.warn)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Deload Suggested")
                    .font(.subheadline).fontWeight(.semibold)
                Text(trainVM.showDeloadSuggestion
                     ? trainVM.deloadMessage
                     : "Your readiness is low today — consider lighter volume to recover.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                withAnimation { trainVM.showDeloadSuggestion = false }
            } label: {
                Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss deload suggestion")
        }
        .padding(14)
        .background(Color.warn.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.warn.opacity(0.3), lineWidth: 1))
    }

    // MARK: Program Header
    private var programHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let split = vm.activeSplit {
                        let dayCount = vm.activeSplitDays.count
                        let dayIdx   = vm.currentSplitDayIndex
                        let dayName  = vm.currentSplitDay.map { $0.isRest ? "Rest" : ($0.dayName.isEmpty ? "Workout" : $0.dayName) } ?? "—"
                        // Matches restDayCard's icon+title pairing right above this in the same
                        // stack — that state had a moon glyph, this one (the far more common state)
                        // had none, so the two read as different screens rather than sibling states.
                        HStack(spacing: 8) {
                            Image(systemName: "dumbbell.fill").foregroundStyle(Color.tint)
                            Text("\(dayName) · Day \(dayIdx + 1) of \(dayCount)")
                                .font(.system(.title3, weight: .bold))
                        }
                        Text(split.name)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No Active Split")
                            .font(.system(.title3, weight: .bold))
                        Button("Pick a split in Programs") { context.showSplitLibrary = true }
                            .font(.footnote)
                            .foregroundStyle(Color.tint)
                    }
                }
                Spacer()
                if let activatedAt = vm.activeSplit?.activatedAt {
                    let cal = Calendar.current
                    let weeksIn = max(1, (cal.dateComponents([.weekOfYear], from: activatedAt, to: Date()).weekOfYear ?? 0) + 1)
                    Text("Wk \(weeksIn)")
                        .font(.elosNumeric(.subheadline, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .elosCard()
    }

    private func computeUserProgress() {
        let ownerID = vm.currentUserID
        guard !ownerID.isEmpty else { return }
        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())) ?? []
        let sets     = (try? modelContext.fetch(FetchDescriptor<ExerciseSetRecord>())) ?? []
        let mySessions = sessions.filter { $0.ownerID == ownerID }
        let mySets     = sets.filter     { $0.ownerID == ownerID }
        let xp = GamificationEngine.totalXP(
            sessions: mySessions,
            sets: mySets,
            prCount: vm.personalRecords.count
        )
        userProgress   = GamificationEngine.progress(totalXP: xp)
        workoutStreak  = GamificationEngine.workoutStreak(sessions: mySessions)
        sessionCount   = mySessions.filter { $0.finishedAt != nil }.count
    }

    // MARK: Week Strip
    private var weekStrip: some View {
        // The strip lives inside a 16pt-gutter VStack, so it was being clipped flush against both
        // screen edges — the last day looked broken rather than scrollable. Negative margins let it
        // bleed to the true edges, and the inset padding restores the gutter for the content, so the
        // first card lines up with everything above it and the last one runs off cleanly.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(buildWeekDays()) { day in WeekDayCard(day: day) }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 2)   // room for the selected card's shadow
        }
        .padding(.horizontal, -Space.gutter)
        .scrollClipDisabled()
    }

    private func buildWeekDays() -> [WeekDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
        let loadMap = vm.weekLoadMap(daysAhead: 7)
        return loadMap.enumerated().map { _, entry in
            let date = entry.date
            let comps = cal.dateComponents([.weekday, .day], from: date)
            let letter = dayLetters[(comps.weekday ?? 1) - 1]
            let number = comps.day ?? 0
            let isToday = cal.isDateInToday(date)
            let isPast  = date < today

            switch entry.loadType {
            case "gym":
                let dayName = vm.gymDay(for: date).flatMap { $0.dayName.isEmpty ? nil : $0.dayName } ?? "Gym"
                return WeekDay(letter: letter, number: number, title: dayName,
                               sublabel: "Train", isToday: isToday, isPast: isPast, loadColor: .mGym)
            case "exam":
                return WeekDay(letter: letter, number: number, title: "Exam",
                               sublabel: "Study", isToday: isToday, isPast: isPast, loadColor: .mExams)
            case "skip":
                return WeekDay(letter: letter, number: number, title: "Skipped",
                               sublabel: "—", isToday: isToday, isPast: isPast, loadColor: .secondary)
            default:
                return WeekDay(letter: letter, number: number, title: "Rest",
                               sublabel: "Recover", isToday: isToday, isPast: isPast, loadColor: .secondary)
            }
        }
    }

    // MARK: Leaderboard Card
    private var leaderboardCard: some View {
        Button {
            context.showLeaderboard = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("This Week", systemImage: "trophy")
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text(weekRangeLabel())
                        .font(.caption2).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                if socialVM.friends.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(.secondary)
                        Text("Add friends to compete")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    // Medal emoji here were a second, independent copy of the ones in
                    // LeaderboardView; both now draw the shared PodiumBadge.
                    HStack(spacing: 0) {
                        ForEach(Array(socialVM.weeklyBoard.prefix(3).enumerated()), id: \.element.id) { idx, entry in
                            HStack(spacing: Space.xs + 2) {
                                PodiumBadge(rank: entry.rank, size: 22)
                                AvatarCircle(initials: entry.initials, hex: entry.avatarHex, size: 24)
                                Text(entry.displayName.components(separatedBy: " ").first ?? entry.displayName)
                                    .font(.system(.caption, weight: entry.is_self ? .semibold : .regular))
                                    .foregroundStyle(entry.is_self ? Color.tint : .primary)
                                    .lineLimit(1)
                            }
                            if idx < 2 { Spacer(minLength: Space.s) }
                        }
                        Spacer(minLength: 0)
                    }
                    if let standings = socialVM.standings {
                        let rank = rankValue(for: socialVM.selectedMetric, standings: standings)
                        let val  = metricValue(for: socialVM.selectedMetric, standings: standings)
                        Text("You're #\(rank) · \(socialVM.formattedValue(val, metric: socialVM.selectedMetric, unit: vm.weightUnit))")
                            .font(.caption).foregroundStyle(Color.tint)
                    }
                }
            }
            .padding(14)
            .elosCard()
        }
        .buttonStyle(.plain)
    }

    private func weekRangeLabel() -> String {
        // Derived from `isoWeekStart()` — the same boundary the chart's data uses. This label was
        // computed with `Calendar.current`, which starts the week on Sunday in the US, so it read
        // "Jul 26 – Aug 1" over a chart actually covering Mon 27th to Sun 2nd: the header described a
        // different week from the one plotted beneath it.
        let start = isoWeekStart()
        let end = Calendar(identifier: .iso8601).date(byAdding: .day, value: 6, to: start) ?? start
        return "\(Formatters.monthDay.string(from: start))–\(Formatters.monthDay.string(from: end))"
    }

    private func rankValue(for metric: String, standings: MyStandingsResponse) -> Int {
        switch metric {
        case "volume":   return standings.volume.rank
        case "sessions": return standings.sessions.rank
        case "streak":   return standings.streak.rank
        case "prs":      return standings.prs.rank
        default:         return standings.volume.rank
        }
    }

    private func metricValue(for metric: String, standings: MyStandingsResponse) -> Double {
        switch metric {
        case "volume":   return standings.volume.value
        case "sessions": return standings.sessions.value
        case "streak":   return standings.streak.value
        case "prs":      return standings.prs.value
        default:         return standings.volume.value
        }
    }

    // MARK: Quick Actions
    private var recentExercisesRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: Space.s) {
                // The label yields, the button doesn't: at large text sizes both grew, the row
                // overflowed, and "Browse all" — the actionable half — ran off the trailing edge.
                Text("RECENT")
                    .elosSectionLabel()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button("Browse all") { context.showExercisePicker = true }
                    .font(.elosCaption)
                    .foregroundStyle(Color.tint)
                    .fixedSize()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(trainVM.recentExercises) { ex in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ex.name)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.primary)
                                // Two lines. A lift name is the content of the chip, and truncating it
                                // to "Barbell Bench…" loses the distinction between variants; a slightly
                                // taller row is the cheaper cost. Width is scaled on top of this.
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(ex.primary_muscle.muscleDisplayName)
                                .font(.elosMicro)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        // Scaled, not a flat 140: at large text every chip truncated to "Barbell…".
                        .frame(width: recentChipWidth, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .sheet(isPresented: $context.showExercisePicker) {
            ExercisePickerView(onPickSingle: { _ in
                context.showExercisePicker = false
                return true
            })
        }
    }

    /// Four across, falling to two-by-two when the labels no longer fit.
    ///
    /// Fixed at four columns, larger text sizes truncated "Templates" to "Templat…" and pushed
    /// "Library" past the screen edge — the app's main navigation, unreadable. An adaptive grid keeps
    /// four across at default sizes and reflows instead of clipping.
    private var quickActions: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: quickActionMinWidth), spacing: Space.s + 2)],
            spacing: Space.s + 2
        ) {
            QuickActionButton(icon: "list.bullet.clipboard", label: "Templates",
                              tint: .tint)    { context.showTemplates    = true }
            QuickActionButton(icon: "calendar.badge.plus",   label: "Programs",
                              tint: .mSched)  { context.showSplitLibrary = true }
            QuickActionButton(icon: "figure.cooldown",       label: "Stretches",
                              tint: .mGym)    { context.showStretches    = true }
            QuickActionButton(icon: "dumbbell",              label: "Library",
                              tint: .mAssign) { context.showLibrary      = true }
            // Discover was fully built — client and backend (`/library/*`, `/machines`) — but nothing
            // ever presented `DiscoverLibraryView`, so ~2,000 lines of working feature were unreachable.
            QuickActionButton(icon: "sparkles.rectangle.stack", label: "Discover",
                              tint: .mNutri)  { context.showDiscover     = true }
            // Promoted out of the toolbar. A whole screen of training history deserves better than a
            // 20pt glyph, and it completes the grid.
            QuickActionButton(icon: "calendar.badge.clock",  label: "History",
                              tint: .mHabits) { context.showHistory      = true }
        }
    }

    // On a rest day or with no active split there's nothing planned, so the session starts empty —
    // label it honestly rather than promising "today's workout".
    private var startButtonTitle: String {
        switch trainState {
        case .restDay, .noSplit: return "Start Free Workout"
        default:                 return "Start Today's Workout"
        }
    }

    // MARK: Start Button
    private var startButton: some View {
        VStack(spacing: 10) {
            Button {
                vm.prepareExercisesForToday()
                if vm.todayReadiness == nil {
                    waitingForReadiness = true
                    context.showReadinessSheet = true
                } else {
                    startSessionWithWarmup()
                }
            } label: {
                Label(startButtonTitle, systemImage: "play.fill")
                    .font(.system(.callout, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            if let nudge = context.volumeNudge {
                Text(nudge)
                    .font(.caption)
                    .foregroundStyle(Color.warn)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if vm.activeSplit != nil && !vm.isTodaySkipped {
                Button {
                    showSkipConfirm = true
                } label: {
                    Label("Skip Today", systemImage: "forward.fill")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .confirmationDialog("Skip today's workout?", isPresented: $showSkipConfirm, titleVisibility: .visible) {
                    Button("Skip Today", role: .destructive) {
                        HapticManager.impact(.medium)
                        vm.skipToday()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This advances your split to the next day.")
                }
            }
        }
    }

    // MARK: Exercises
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TODAY'S EXERCISES")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                Button {
                    context.showExercisePicker = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption).foregroundStyle(Color.tint)
                }
            }

            if vm.exercises.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No exercises planned")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("Add a split in Programs or start a free workout.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .elosCard()
            } else {
                ForEach($vm.exercises) { $exercise in
                    ExerciseCard(
                        exercise: $exercise,
                        isExpanded: expandedExercise == exercise.id,
                        unit: vm.weightUnit,
                        allExerciseNames: vm.exercises.map(\.name),
                        onSelect: {
                            withAnimation(.elosStandard) {
                                expandedExercise = expandedExercise == exercise.id ? nil : exercise.id
                                selectedMuscleName = exercise.primaryMuscle
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: Muscle Volume Panel
    private var muscleVolumePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MUSCLE VOLUME · THIS WEEK")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(vm.muscleVolume.enumerated()), id: \.element.id) { idx, mv in
                    let isSelected = selectedMuscleName?.lowercased() == mv.muscle.lowercased()
                    Button {
                        withAnimation { selectedMuscleName = mv.muscle.lowercased() }
                    } label: {
                        MuscleVolumeRow(mv: mv, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    if idx < vm.muscleVolume.count - 1 { Divider().padding(.leading, 80) }
                }
            }
            .elosCard()
        }
    }

    // MARK: Personal Records
    private var personalRecordsCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.elosStandard) { prsExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Color.good)
                    Text("Personal Records").font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Image(systemName: prsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if prsExpanded {
                Divider()
                ForEach(vm.personalRecords) { pr in
                    HStack {
                        Text(pr.lift).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        Text(pr.weight)
                            .font(.elosNumeric(.callout, weight: .bold))
                        Text(pr.reps)
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    Divider().padding(.leading, 16)
                }
            }
        }
        .elosCard()
    }

    // MARK: Weekly Radar Card

    private var weeklyRadarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("THIS WEEK")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                Text(weekRangeLabel())
                    .font(.caption2).foregroundStyle(.secondary)
            }

            let axes = buildMuscleAxes()
            let current = currentMuscleStats()

            HStack {
                Spacer()
                WeeklyRadarChart(axes: axes, size: 200)
                Spacer()
            }

            HStack(spacing: 6) {
                Circle().fill(Color.tint).frame(width: 6, height: 6)
                Text("This week").font(.caption2).foregroundStyle(.secondary)
                Spacer().frame(width: 12)
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 12, height: 1.5)
                Text("Prior week").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    muscleChip("Chest",     sets: current.chest,     target: 12)
                    muscleChip("Back",      sets: current.back,      target: 14)
                    muscleChip("Legs",      sets: current.legs,      target: 14)
                    muscleChip("Shoulders", sets: current.shoulders, target: 10)
                    muscleChip("Arms",      sets: current.arms,      target: 10)
                    muscleChip("Core",      sets: current.core,      target: 8)
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(16)
        .elosCard()
    }

    private func muscleChip(_ label: String, sets: Int, target: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(sets)/\(target)")
                .font(.elosNumeric(.caption, weight: .bold))
                // Three states, so emphasis tracks achievement. This was `met ? .good : .primary`,
                // which made an untrained muscle ("0/14", full-brightness white) the loudest value in
                // the row while a hit target sat quieter in green — the radar above already shows the
                // gap as a dent in the polygon, so the untouched number should recede, not shout.
                .foregroundStyle(sets >= target ? Color.good : sets > 0 ? Color.primary : Color.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: Muscle radar data

    private struct MuscleWeekStats {
        var chest: Int = 0
        var back: Int = 0
        var legs: Int = 0
        var shoulders: Int = 0
        var arms: Int = 0
        var core: Int = 0
    }

    private func isoWeekStart(weeksAgo: Int = 0) -> Date {
        let cal = Calendar(identifier: .iso8601)
        let now = Date()
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let thisMonday = cal.date(from: components) ?? now
        return cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisMonday) ?? thisMonday
    }

    private func muscleCounts(allSets: [ExerciseSetRecord], ownerID: String, weekStart: Date) -> MuscleWeekStats {
        let cal = Calendar.current
        let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
        let doneSets = allSets.filter {
            $0.ownerID == ownerID &&
            $0.isDone &&
            ($0.completedAt ?? .distantPast) >= weekStart &&
            ($0.completedAt ?? .distantPast) < weekEnd
        }
        var s = MuscleWeekStats()
        for set in doneSets {
            // Grouped via the taxonomy rather than a hand-listed switch. The old list matched only
            // "lats"/"rear_delts" for Back and dropped everything else — a set of lower-back or
            // upper-back work counted toward nothing at all.
            switch MuscleTaxonomy.group(forMuscle: trainVM.muscleGroup(for: set)) {
            case .chest:               s.chest += 1
            case .back:                s.back += 1
            case .legs, .glutes:       s.legs += 1
            case .shoulders:           s.shoulders += 1
            case .arms:                s.arms += 1
            case .core:                s.core += 1
            case nil:                  break
            }
        }
        return s
    }

    private func currentMuscleStats() -> MuscleWeekStats {
        let ownerID = vm.currentUserID
        guard !ownerID.isEmpty else { return MuscleWeekStats() }
        let allSets = (try? modelContext.fetch(FetchDescriptor<ExerciseSetRecord>())) ?? []
        return muscleCounts(allSets: allSets, ownerID: ownerID, weekStart: isoWeekStart(weeksAgo: 0))
    }

    private func buildMuscleAxes() -> [RadarAxis] {
        let ownerID = vm.currentUserID
        guard !ownerID.isEmpty else { return [] }
        let allSets = (try? modelContext.fetch(FetchDescriptor<ExerciseSetRecord>())) ?? []
        let current = muscleCounts(allSets: allSets, ownerID: ownerID, weekStart: isoWeekStart(weeksAgo: 0))
        let prior   = muscleCounts(allSets: allSets, ownerID: ownerID, weekStart: isoWeekStart(weeksAgo: 1))
        let t = (chest: 12.0, back: 14.0, legs: 14.0, shoulders: 10.0, arms: 10.0, core: 8.0)
        return [
            RadarAxis(label: "Chest",     current: min(1, Double(current.chest)     / t.chest),     prior: min(1, Double(prior.chest)     / t.chest)),
            RadarAxis(label: "Back",      current: min(1, Double(current.back)      / t.back),      prior: min(1, Double(prior.back)      / t.back)),
            RadarAxis(label: "Legs",      current: min(1, Double(current.legs)      / t.legs),      prior: min(1, Double(prior.legs)      / t.legs)),
            RadarAxis(label: "Shoulders", current: min(1, Double(current.shoulders) / t.shoulders), prior: min(1, Double(prior.shoulders) / t.shoulders)),
            RadarAxis(label: "Arms",      current: min(1, Double(current.arms)      / t.arms),      prior: min(1, Double(prior.arms)      / t.arms)),
            RadarAxis(label: "Core",      current: min(1, Double(current.core)      / t.core),      prior: min(1, Double(prior.core)      / t.core)),
        ]
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let icon: String
    let label: String
    /// Per-destination colour. Four identically tinted orange tiles read as one undifferentiated
    /// block — nothing to aim at. Giving each its own hue (from the existing module palette) makes
    /// them scannable by colour, and the icon carries the tint while the label stays neutral so the
    /// row doesn't shout.
    var tint: Color = .tint
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            VStack(spacing: Space.s) {
                Image(systemName: icon)
                    .font(.system(.title2, weight: .medium))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.vertical, Space.m)
            // Neutral surface, hue on the icon only. Tinting the *background* made these the sole
            // non-neutral surfaces in the app — four competing coloured blocks that sat outside the
            // elevation language every other card follows. The colour coding survives where it does the
            // scanning work (the glyph); the tile itself is a level-1 surface like everything else.
            .elosWell(cornerRadius: Radius.control)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Week Day Card
private struct WeekDayCard: View {
    let day: WeekDay

    var body: some View {
        // Text styles, not fixed sizes: at an accessibility text size these chips stayed at 9–15pt
        // while every card around them grew, so the week strip read as a different app. `elosDenseLayout`
        // caps the growth — seven chips in a row genuinely cannot reflow to the largest sizes — but they
        // now move with the user's setting instead of ignoring it.
        VStack(spacing: 4) {
            Text(day.letter).font(.system(.caption2, weight: .medium))
            Text("\(day.number)").font(.elosNumeric(.subheadline))
            Text(day.title).font(.system(.caption2, weight: .bold)).lineLimit(1)
            Text(day.sublabel).font(.elosMicro).lineLimit(1)
            Circle()
                .fill(day.isPast ? Color.good : Color.clear)
                .frame(width: 5, height: 5)
        }
        .elosDenseLayout()
        .padding(.horizontal, 10).padding(.vertical, 8)
        .foregroundStyle(day.isToday ? Color.white : Color.primary)
        .background(day.isToday ? Color.tint : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            if !day.isToday && !day.isPast {
                RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

// MARK: - Exercise Card
private struct ExerciseCard: View {
    @Binding var exercise: Exercise
    let isExpanded: Bool
    let unit: WeightUnit
    var allExerciseNames: [String] = []
    let onSelect: () -> Void

    @State private var showingSwap = false

    private var doneCount: Int { exercise.sets.filter(\.done).count }
    private var allDone: Bool  { doneCount == exercise.sets.count }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(allDone ? Color.good : (isExpanded ? Color.tint : Color.secondary.opacity(0.3)))
                        .frame(width: 10, height: 10)
                    Text(exercise.name).font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(exercise.setsLabel)
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primary: \(exercise.primaryMuscle)" +
                         (exercise.secondaryMuscles.isEmpty ? "" : " · Last: \(exercise.lastBest)"))
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 14)

                    Divider()
                    HStack {
                        Text("#").frame(width: 20)
                        Text("Weight (\(unit.label))").frame(maxWidth: .infinity)
                        Text("Reps").frame(width: 50)
                        Text("RPE").frame(width: 40)
                        Image(systemName: "checkmark").frame(width: 30)
                    }
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14)

                    ForEach(exercise.sets.indices, id: \.self) { i in
                        HStack {
                            Text("\(i + 1)").font(.caption.monospacedDigit()).frame(width: 20).foregroundStyle(.secondary)
                            Text(exercise.sets[i].weight.isEmpty ? "— \(unit.label)" : "\(exercise.sets[i].weight) \(unit.label)")
                                .font(.elosNumeric(.subheadline, weight: .bold))
                                .foregroundStyle(exercise.sets[i].done ? .secondary : .primary)
                                .frame(maxWidth: .infinity)
                            Text(exercise.sets[i].reps.isEmpty ? "—" : exercise.sets[i].reps)
                                .font(.elosNumeric(.subheadline, weight: .bold))
                                .foregroundStyle(exercise.sets[i].done ? .secondary : .primary)
                                .frame(width: 50)
                            Text(exercise.sets[i].rpe.isEmpty ? "—" : exercise.sets[i].rpe)
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 40)
                            Image(systemName: exercise.sets[i].done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(exercise.sets[i].done ? Color.good : Color.secondary)
                                .frame(width: 30)
                        }
                        .padding(.horizontal, 14)
                        .opacity(exercise.sets[i].done ? 0.55 : 1)
                    }

                    Divider()
                    HStack(spacing: 16) {
                        Button("+ Add set") {
                            exercise.sets.append(WorkSet(weight: "", reps: "", rpe: "", done: false))
                        }
                        .font(.caption).foregroundStyle(Color.tint)
                        Button("Swap") { showingSwap = true }
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.bottom, 10)
                }
            }
        }
        .elosCard()
        .sheet(isPresented: $showingSwap) {
            ExerciseSwapSheet(exercise: $exercise, existingNames: allExerciseNames.filter { $0 != exercise.name })
        }
    }
}

// MARK: - Exercise Swap Sheet

// MARK: - Muscle Volume Row
private struct MuscleVolumeRow: View {
    let mv: MuscleVolume
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Muscle keys are the catalog's snake_case ("front_delts") — render, don't leak the schema.
            Text(mv.muscle.muscleDisplayName)
                .font(.subheadline).fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.tint : Color.primary)
                .frame(width: 72, alignment: .leading)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
            ProgressBar(
                value: mv.target > 0 ? Double(mv.current) / Double(mv.target) : 0,
                color: mv.onTrack ? .mGym : .warn, height: 6
            )
            Text("\(mv.current)/\(mv.target)")
                .font(.elosNumeric(.footnote, weight: .bold)).foregroundStyle(.secondary).frame(width: 42)
            Text(mv.trend)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(mv.trendUp ? Color.good : Color.bad).frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(isSelected ? Color.tintSoft : Color.clear)
    }
}
