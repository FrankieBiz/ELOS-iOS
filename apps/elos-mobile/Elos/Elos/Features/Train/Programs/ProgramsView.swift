import SwiftUI
import SwiftData

struct ProgramsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSplitRecord.createdAt, order: .reverse) private var userSplits: [UserSplitRecord]
    @Query private var allSplitDays: [UserSplitDayRecord]
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var feedVM: FeedViewModel

    @StateObject private var communityVM = CommunitySplitsViewModel()

    @State private var showCreateSplit = false
    @State private var showSplitFinder = false
    @State private var selectedSplit: UserSplitRecord?
    @State private var splitPendingDelete: UserSplitRecord?
    @State private var splitPendingActivate: UserSplitRecord?
    @State private var splitPendingPublish: UserSplitRecord?
    @State private var splitShared = false
    @State private var splitPublished = false

    private let categoryOrder: [SplitCategory] = [
        .creatorInspired, .olympiaBodybuilding, .sportPerformance,
        .foundation, .homeMinimal, .specialization
    ]

    var body: some View {
        NavigationStack {
            libraryWithDialogs
        }
    }

    /// Scroll content + navigation chrome. Split out of `body` (and further
    /// into per-section builders below) to keep each expression small enough
    /// for the type-checker.
    private var libraryScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                activeSplitCard
                favoritesSection
                communitySection
                ForEach(categoryOrder, id: \.self) { category in
                    categorySection(category)
                }
                mySplitsSection
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Programs")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSplitFinder = true } label: {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(Color.tint)
                }
                .accessibilityLabel("Find a split")
            }
        }
        .task { await communityVM.load() }
    }

    @ViewBuilder
    private var favoritesSection: some View {
        if !vm.favoriteSplitKeys.isEmpty {
            let favorites: [WorkoutSplit] = WorkoutSplitLibrary.all.filter { vm.favoriteSplitKeys.contains($0.id) }
            libraryCategoryRow(title: "Favorites", icon: "heart.fill", color: .red, splits: favorites)
            Divider().padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func categorySection(_ category: SplitCategory) -> some View {
        let splits: [WorkoutSplit] = WorkoutSplitLibrary.all.filter { $0.category == category }
        if !splits.isEmpty {
            libraryCategoryRow(
                title: category.rawValue,
                icon: categoryIcon(category),
                color: categoryColor(category),
                splits: splits
            )
            Divider().padding(.horizontal, 16)
        }
    }

    /// Sheets attached in a separate expression from the dialogs below —
    /// one flat chain here is too large for the type-checker.
    private var libraryWithSheets: some View {
        libraryScroll
            .sheet(item: $splitPendingPublish) { split in
                PublishSplitSheet(
                    split: split,
                    days: daysFor(split: split),
                    communityVM: communityVM,
                    onPublished: { splitPublished = true }
                )
                .environmentObject(vm)
            }
            .alert("Published to the community", isPresented: $splitPublished) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Everyone on Elos can now see and import this split.")
            }
            .sheet(isPresented: $showCreateSplit) {
                CreateSplitView { showCreateSplit = false }
                    .environmentObject(vm)
            }
            .sheet(isPresented: $showSplitFinder) {
                SplitFinderView(dismissAll: { showSplitFinder = false })
                    .environmentObject(vm)
            }
            .navigationDestination(item: $selectedSplit) { split in
                UserSplitDetailView(split: split)
                    .environmentObject(vm)
            }
    }

    private var libraryWithDialogs: some View {
        libraryWithSheets
            .confirmationDialog(
                "Delete this split?",
                isPresented: Binding(
                    get: { splitPendingDelete != nil },
                    set: { if !$0 { splitPendingDelete = nil } }
                ),
                presenting: splitPendingDelete
            ) { split in
                Button("Delete", role: .destructive) { deleteSplit(split) }
                Button("Cancel", role: .cancel) {}
            } message: { split in
                Text("\"\(split.name)\" will be permanently removed.")
            }
            .alert("Shared to your feed", isPresented: $splitShared) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Friends can now import this split.")
            }
            .confirmationDialog(
                "Switch active program?",
                isPresented: Binding(
                    get: { splitPendingActivate != nil },
                    set: { if !$0 { splitPendingActivate = nil } }
                ),
                presenting: splitPendingActivate
            ) { split in
                Button("Switch to \"\(split.name)\"") { activate(split) }
                Button("Cancel", role: .cancel) {}
            } message: { split in
                Text("\(vm.activeSplit?.name ?? "Your current program") will be replaced and its progress reset.")
            }
    }

    /// Activate a split, confirming first when one is already active so a tap
    /// can't silently replace an in-progress program.
    private func requestActivate(_ split: UserSplitRecord) {
        if vm.activeSplit != nil {
            splitPendingActivate = split
        } else {
            activate(split)
        }
    }

    private func activate(_ split: UserSplitRecord) {
        vm.setActiveSplit(split)
    }

    private func deleteSplit(_ split: UserSplitRecord) {
        let serverID = split.serverID
        let days = daysFor(split: split)
        for day in days { modelContext.delete(day) }
        modelContext.delete(split)
        try? modelContext.save()
        Task { await vm.deleteSplitOnServer(serverID: serverID) }
    }

    // MARK: Active Split Card

    @ViewBuilder
    private var activeSplitCard: some View {
        if let split = vm.activeSplit {
            let cal = Calendar.current
            let weeksIn = max(1, (cal.dateComponents([.weekOfYear],
                from: split.activatedAt ?? Date(), to: Date()).weekOfYear ?? 0) + 1)
            let dayIdx = vm.currentSplitDayIndex + 1
            let dayCount = vm.activeSplitDays.count
            let progress = dayCount > 0 ? Double(dayIdx) / Double(dayCount) : 0.0

            Button { selectedSplit = split } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(split.name)
                                .font(.subheadline).fontWeight(.bold)
                            Text("Week \(weeksIn) · Day \(dayIdx) of \(dayCount)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.15)).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.tint)
                                .frame(width: geo.size.width * CGFloat(progress), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(14)
                .background(Color.tintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.tint.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
    }

    // MARK: Community Section

    @ViewBuilder
    private var communitySection: some View {
        if !communityVM.splits.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                    Text("Community")
                        .font(.system(.callout, weight: .bold))
                    Text("\(communityVM.splits.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                    Spacer()
                    NavigationLink {
                        CommunityBrowseView(communityVM: communityVM)
                            .environmentObject(vm)
                    } label: {
                        Text("See All")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color.tint)
                    }
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(communityVM.splits.prefix(10)) { split in
                            NavigationLink {
                                CommunitySplitDetailView(split: split, communityVM: communityVM)
                                    .environmentObject(vm)
                            } label: {
                                CommunitySplitCard(split: split)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
            Divider().padding(.horizontal, 16)
        }
    }

    // MARK: Library Category Row

    private func libraryCategoryRow(title: String, icon: String, color: Color, splits: [WorkoutSplit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.callout, weight: .bold))
                Text("\(splits.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(splits) { split in
                        NavigationLink(
                            destination: WorkoutSplitDetailView(split: split).environmentObject(vm)
                        ) {
                            SplitLibraryCard(
                                split: split,
                                isFavorite: vm.favoriteSplitKeys.contains(split.id),
                                showsCategory: false,
                                onFavoriteTap: { vm.toggleFavorite(split.id) }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: My Splits

    private var mySplitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("My Splits")
                    .font(.system(.callout, weight: .bold))
                Spacer()
                Button { showCreateSplit = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.caption2.weight(.bold))
                        Text("Create").font(.caption).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.tint)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            if userSplits.isEmpty {
                Text("No custom splits yet. Tap Create or subscribe to a library split above.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.bottom, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(userSplits) { split in
                        Button {
                            if split.isActive { selectedSplit = split }
                            else { requestActivate(split) }
                        } label: {
                            mySplitRow(split)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { selectedSplit = split } label: {
                                Label("View Details", systemImage: "list.bullet")
                            }
                            if !split.isActive {
                                Button { requestActivate(split) } label: {
                                    Label("Set as Active", systemImage: "checkmark.circle")
                                }
                            }
                            Button {
                                guard !split.serverID.isEmpty else { return }
                                let serverID = split.serverID
                                Task {
                                    if await feedVM.shareSplit(serverID: serverID) {
                                        splitShared = true
                                    } else {
                                        vm.showError("Could not share this split. Please try again.")
                                    }
                                }
                            } label: {
                                Label(
                                    split.serverID.isEmpty ? "Saving… try again in a moment" : "Share to Friends",
                                    systemImage: "person.2.fill"
                                )
                            }
                            .disabled(split.serverID.isEmpty)
                            Button {
                                splitPendingPublish = split
                            } label: {
                                Label(
                                    split.serverID.isEmpty ? "Saving… try again in a moment" : "Publish to Community",
                                    systemImage: "person.3.fill"
                                )
                            }
                            .disabled(split.serverID.isEmpty)
                            Divider()
                            Button(role: .destructive) {
                                splitPendingDelete = split
                            } label: {
                                Label("Delete Split", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
    }

    private func mySplitRow(_ split: UserSplitRecord) -> some View {
        let days = daysFor(split: split)
        let isActive = split.isActive
        let descriptor = SplitDescriptor.describe(dayRecords: days)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(split.name)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                Text(descriptor.summaryLine)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                SplitPatternStrip(descriptor: descriptor, compact: true)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.tint)
            } else {
                Text("Set Active")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(Color.tint)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.tint.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(isActive ? Color.tint.opacity(0.08) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 12).stroke(Color.tint.opacity(0.4), lineWidth: 1)
            }
        }
    }

    // MARK: Helpers

    private func daysFor(split: UserSplitRecord) -> [UserSplitDayRecord] {
        allSplitDays.filter { $0.splitID == split.id }.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func categoryIcon(_ cat: SplitCategory) -> String {
        switch cat {
        case .foundation:          return "building.columns"
        case .creatorInspired:     return "play.rectangle.fill"
        case .olympiaBodybuilding: return "trophy.fill"
        case .sportPerformance:    return "figure.run"
        case .homeMinimal:         return "house.fill"
        case .specialization:      return "star.fill"
        }
    }

    private func categoryColor(_ cat: SplitCategory) -> Color {
        switch cat {
        case .foundation:          return .tint
        case .creatorInspired:     return .orange
        case .olympiaBodybuilding: return .purple
        case .sportPerformance:    return .green
        case .homeMinimal:         return .brown
        case .specialization:      return .pink
        }
    }
}

// MARK: - User Split Detail

/// Wraps a plain string for `.alert(item:)`, which needs `Identifiable`.
private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

struct UserSplitDetailView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext
    let split: UserSplitRecord

    @Query private var splitDays: [UserSplitDayRecord]
    @Query(sort: \ExerciseDefinitionRecord.name) private var exerciseDefs: [ExerciseDefinitionRecord]
    @Query private var profiles: [UserProfileRecord]
    @State private var showEdit = false
    @State private var showFullReport = false
    @State private var selectedDaySummary: SplitDaySummary? = nil
    @State private var pendingFix: FixProposal? = nil
    @State private var declinedFixMessage: IdentifiableString? = nil

    init(split: UserSplitRecord) {
        self.split = split
        let id = split.id
        _splitDays = Query(
            filter: #Predicate<UserSplitDayRecord> { $0.splitID == id },
            sort: \.orderIndex
        )
    }

    private var sortedDays: [UserSplitDayRecord] { splitDays.sorted { $0.orderIndex < $1.orderIndex } }
    private var exerciseCatalog: [ExerciseCandidate] { exerciseDefs.map(ExerciseCandidate.init(record:)) }
    private var guidanceLevel: GuidanceLevel { GuidanceLevel(trainingExperience: profiles.first?.trainingExperience ?? "") }
    private var equipmentPreference: EquipmentPreference { profiles.first?.equipmentPreference ?? .fullGym }

    /// `UserSplitRecord.intent` is nil for a split saved before intents existed — same fallback
    /// `CreateSplitView.onAppear` uses when seeding its own `@State` intent.
    private var splitIntent: TrainingIntent {
        split.intent ?? TrainingIntent(profile: TrainingProfile(record: profiles.first))
    }

    /// Same construction as `CreateSplitView.scoringProfile` — dropping `volumeOverrides` here
    /// would make the Volume Targets screen silently stop affecting this split's score.
    private var scoringProfile: TrainingProfile {
        TrainingProfile(goal: splitIntent.goal,
                        experience: TrainingProfile(record: profiles.first).experience,
                        volumeOverrides: vm.volumeOverrides)
    }

    private var qualityReport: QualityReport {
        SavedSplitScoring.report(days: sortedDays,
                                 templateExercises: { vm.fetchTemplateExercises(templateID: $0) },
                                 catalog: exerciseCatalog,
                                 profile: scoringProfile,
                                 intent: splitIntent)
    }

    /// Also the definition of "populated days" for the panel's gate — a day only appears here
    /// once it actually resolves to exercises, matching `CreateSplitView`'s own gate.
    private var daySummaries: [SplitDaySummary] {
        SavedSplitScoring.daySummaries(days: sortedDays,
                                       templateExercises: { vm.fetchTemplateExercises(templateID: $0) },
                                       catalog: exerciseCatalog,
                                       profile: scoringProfile,
                                       splitGoal: splitIntent.goal)
    }

    var body: some View {
        List {
            if !split.isActive {
                Section {
                    Button {
                        vm.setActiveSplit(split)
                    } label: {
                        Label("Set as Active Split", systemImage: "checkmark.circle.fill")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.tint)
                    }
                }
            } else {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.tint)
                        Text("Active split").font(.subheadline).foregroundStyle(Color.tint)
                    }
                }
            }

            if vm.showQualityRater {
                qualityPanelSection
            }

            if !splitDays.isEmpty {
                let arrays = weeklyTargetArrays(from: splitDays)
                Section {
                    MuscleGroupPanelWeekly(
                        dayTemplateIDs: arrays.templateIDs,
                        dayIsRest: arrays.isRest,
                        dayExercises: arrays.exercises
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("WEEKLY TARGETS")
                }
            }

            Section("Days") {
                ForEach(splitDays, id: \.id) { day in
                    dayRow(day)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(split.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
                    .foregroundStyle(Color.tint)
            }
        }
        .sheet(isPresented: $showEdit) {
            CreateSplitView(editSplit: split, editDays: splitDays) { showEdit = false }
                .environmentObject(vm)
        }
        .sheet(isPresented: $showFullReport) {
            SplitQualityReportView(
                report: qualityReport,
                days: daySummaries,
                onAutoFix: { tip in
                    showFullReport = false
                    startAutoFix(for: tip)
                },
                onSelectDay: { selectedDaySummary = $0 })
        }
        .sheet(item: $selectedDaySummary) { day in
            DayQualityReportView(dayName: day.name, report: day.report)
        }
        .sheet(item: $pendingFix) { proposal in
            QualityFixPreviewSheet(
                proposal: proposal,
                onConfirm: { apply($0) },
                onDeny: {},
                onTryAnother: { candidate in
                    QualityFixEngine.propose(for: proposal.tip, context: currentContext(), using: candidate)
                },
                // No manual-add UI in this read-mostly view (that's what Edit is for) — route
                // there instead of a dead button. The sheet already dismissed itself before this
                // runs (its own Button calls `dismiss()` then `onChooseManually()`).
                onChooseManually: { showEdit = true })
        }
        .alert(item: $declinedFixMessage) { item in
            Alert(title: Text("Can't auto-fix this"), message: Text(item.value))
        }
    }

    // MARK: - Quality panel

    @ViewBuilder private var qualityPanelSection: some View {
        // Same gate as the builder — a half-built week reads as nagging, not coaching.
        if daySummaries.count >= 2 && qualityReport.isScored {
            Section {
                TemplateQualityPanel(report: qualityReport, guidance: guidanceLevel,
                                     title: "Split Quality", scope: .weeklySplit,
                                     onAutoFix: { startAutoFix(for: $0) },
                                     onSeeFullReport: { showFullReport = true })
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: - Auto-fix
    //
    // Unlike the builder, there is no Save button here — Confirm writes straight to SwiftData.
    // There is also no manual-add UI in this view (that's what Edit is for), so a fix that can't
    // be auto-applied is declined outright rather than falling back to a manual path.

    private func currentContext() -> QualityFixEngine.Context {
        QualityFixEngine.Context(
            days: sortedDays.map { SavedSplitScoring.dayExercises(for: $0) { vm.fetchTemplateExercises(templateID: $0) } .map(ScoredExercise.init(day:)) },
            dayNames: sortedDays.map(\.dayName),
            dayIsRest: sortedDays.map(\.isRest),
            dayExcludedMuscles: sortedDays.map(\.excludedMuscles),
            scope: .weeklySplit, profile: scoringProfile, intent: splitIntent, catalog: exerciseCatalog,
            personalization: PersonalizationProvider(signals: .init()),
            equipmentPreference: equipmentPreference)
    }

    private func startAutoFix(for tip: QualityTip) {
        guard let proposal = QualityFixEngine.propose(for: tip, context: currentContext()) else {
            // No eligible day / no candidate / nothing worth offering. There's no manual
            // fallback in this view (unlike the builder), so this is simply a dead end here —
            // the tip stays visible as information; fixing it means opening Edit.
            return
        }
        // "Template-backed" per SavedSplitScoring.isTemplateBacked, not a bare `!templateID.isEmpty`
        // check — a day can carry both a templateID and its own exercisesJSON, and ad-hoc wins.
        let touchedTemplateBackedDay = proposal.operations
            .map(\.dayIndex)
            .contains { sortedDays.indices.contains($0) && SavedSplitScoring.isTemplateBacked(sortedDays[$0]) }
        guard !touchedTemplateBackedDay else {
            declinedFixMessage = IdentifiableString(
                "This day's exercises come from a shared template. Edit the split to change them.")
            return
        }
        pendingFix = proposal
    }

    /// Writes fix operations straight into the affected days' `exercisesJSON` — there is no
    /// `@State` copy to mutate and no Save button, so this IS the save. Operations are grouped by
    /// day so each day's exercises are decoded, mutated, and re-encoded exactly once.
    private func apply(_ operations: [FixOperation]) {
        let byDay = Dictionary(grouping: operations, by: \.dayIndex)
        for (dayIndex, ops) in byDay {
            guard sortedDays.indices.contains(dayIndex) else { continue }
            let day = sortedDays[dayIndex]
            guard !SavedSplitScoring.isTemplateBacked(day) else { continue }
            var exercises = SavedSplitScoring.dayExercises(for: day) { vm.fetchTemplateExercises(templateID: $0) }
            for op in ops {
                switch op {
                case .insertExercise(let spec):
                    let insertAt = min(max(0, spec.insertAt), exercises.count)
                    let new = DayExercise(id: spec.candidate.id, name: spec.candidate.name,
                                         sets: spec.sets, reps: spec.reps)
                    exercises.insert(new, at: insertAt)
                case .reorderDay(_, let permutation):
                    guard permutation.count == exercises.count,
                          Set(permutation) == Set(0..<exercises.count) else { continue }
                    exercises = permutation.map { exercises[$0] }
                case .setReps(_, let exerciseIndex, let reps):
                    guard exercises.indices.contains(exerciseIndex) else { continue }
                    exercises[exerciseIndex].reps = reps
                case .setRest:
                    // DayExercise has no rest field, and rr-rest only fires at single-session
                    // scope on exercises with non-nil rest — a split day always has restSeconds
                    // nil, so this case is unreachable here. Intentional no-op.
                    continue
                }
            }
            guard let data = try? JSONEncoder().encode(exercises),
                  let json = String(data: data, encoding: .utf8) else { continue }
            day.exercisesJSON = json
        }
        split.syncPending = true
        try? modelContext.save()
        let record = split
        Task.detached {
            if !record.serverID.isEmpty {
                await vm.updateSplitOnServer(serverID: record.serverID, record: record)
            } else {
                await vm.pushSplitToServer(record)
            }
        }
    }

    private func weeklyTargetArrays(from days: [UserSplitDayRecord]) -> (
        templateIDs: [String], isRest: [Bool], exercises: [[DayExercise]]
    ) {
        var templateIDs = Array(repeating: "", count: 7)
        var isRest = Array(repeating: false, count: 7)
        var exercises = Array(repeating: [DayExercise](), count: 7)
        for day in days.sorted(by: { $0.orderIndex < $1.orderIndex }) where day.orderIndex < 7 {
            templateIDs[day.orderIndex] = day.templateID
            isRest[day.orderIndex] = day.isRest
            let exs = (try? JSONDecoder().decode([DayExercise].self,
                       from: Data(day.exercisesJSON.utf8))) ?? []
            exercises[day.orderIndex] = exs
        }
        return (templateIDs, isRest, exercises)
    }

    /// The day's own report, if it resolves to any exercises — a rest day or a day that hasn't
    /// been built out yet has none, and the row stays non-interactive for "look at this."
    private func summary(for day: UserSplitDayRecord) -> SplitDaySummary? {
        daySummaries.first { $0.id == day.orderIndex }
    }

    private func dayRow(_ day: UserSplitDayRecord) -> some View {
        let daySummary = summary(for: day)

        return HStack(spacing: 12) {
            Button {
                guard let daySummary else { return }
                selectedDaySummary = daySummary
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(day.dayLabel)
                            .font(.caption).foregroundStyle(.secondary)
                        Text(day.isRest ? "Rest" : (day.dayName.isEmpty ? day.dayLabel : day.dayName))
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(day.isRest ? .secondary : .primary)
                    }
                    if let score = daySummary?.score {
                        Text("\(score)")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(QualityPalette.color(forScore: score))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(daySummary == nil)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !day.isRest {
                Button {
                    vm.prepareExercises(for: day)
                    vm.showingSession = true
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.tint)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint(daySummary != nil ? "Double tap to view this day's coverage" : "")
    }
}
