import SwiftUI
import SwiftData

struct ProgramsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSplitRecord.createdAt, order: .reverse) private var userSplits: [UserSplitRecord]
    @Query private var allSplitDays: [UserSplitDayRecord]
    @EnvironmentObject var vm: AppViewModel

    @State private var showCreateSplit = false
    @State private var showSplitFinder = false
    @State private var selectedSplit: UserSplitRecord?

    private let categoryOrder: [SplitCategory] = [
        .creatorInspired, .olympiaBodybuilding, .sportPerformance,
        .foundation, .homeMinimal, .specialization
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    activeSplitCard
                    if !vm.favoriteSplitKeys.isEmpty {
                        libraryCategoryRow(
                            title: "Favorites",
                            icon: "heart.fill",
                            color: .red,
                            splits: WorkoutSplitLibrary.all.filter { vm.favoriteSplitKeys.contains($0.id) }
                        )
                        Divider().padding(.horizontal, 16)
                    }
                    ForEach(categoryOrder, id: \.self) { category in
                        let splits = WorkoutSplitLibrary.all.filter { $0.category == category }
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
                }
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
                UserSplitDetailView(split: split, splitDays: daysFor(split: split))
                    .environmentObject(vm)
            }
        }
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

    // MARK: Library Category Row

    private func libraryCategoryRow(title: String, icon: String, color: Color, splits: [WorkoutSplit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 17, weight: .bold))
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
                    .font(.system(size: 17, weight: .bold))
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
                            else { vm.setActiveSplit(split) }
                        } label: {
                            mySplitRow(split)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { selectedSplit = split } label: {
                                Label("View Details", systemImage: "list.bullet")
                            }
                            if !split.isActive {
                                Button { vm.setActiveSplit(split) } label: {
                                    Label("Set as Active", systemImage: "checkmark.circle")
                                }
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
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(split.name)
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                HStack(spacing: 4) {
                    ForEach(days.prefix(7), id: \.id) { day in
                        Text(day.isRest ? "—" : String(day.dayLabel.prefix(1)))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(day.isRest ? Color.secondary : Color.tint)
                            .frame(width: 16, height: 16)
                            .background((day.isRest ? Color.secondary : Color.tint).opacity(0.1))
                            .clipShape(Circle())
                    }
                }
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

struct UserSplitDetailView: View {
    @EnvironmentObject var vm: AppViewModel
    let split: UserSplitRecord
    let splitDays: [UserSplitDayRecord]

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
            if !splitDays.isEmpty {
                let arrays = weeklyTargetArrays(from: splitDays)
                Section {
                    MuscleGroupPanelWeekly(
                        dayTemplateIDs: arrays.templateIDs,
                        dayIsRest: arrays.isRest,
                        dayExerciseNames: arrays.exerciseNames
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
    }

    private func weeklyTargetArrays(from days: [UserSplitDayRecord]) -> (
        templateIDs: [String], isRest: [Bool], exerciseNames: [[String]]
    ) {
        var templateIDs = Array(repeating: "", count: 7)
        var isRest = Array(repeating: false, count: 7)
        var exerciseNames = Array(repeating: [String](), count: 7)
        for day in days.sorted(by: { $0.orderIndex < $1.orderIndex }) where day.orderIndex < 7 {
            templateIDs[day.orderIndex] = day.templateID
            isRest[day.orderIndex] = day.isRest
            let exs = (try? JSONDecoder().decode([DayExercise].self,
                       from: Data(day.exercisesJSON.utf8))) ?? []
            exerciseNames[day.orderIndex] = exs.map { $0.name }
        }
        return (templateIDs, isRest, exerciseNames)
    }

    private func dayRow(_ day: UserSplitDayRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(day.dayLabel)
                    .font(.caption).foregroundStyle(.secondary)
                Text(day.isRest ? "Rest" : (day.dayName.isEmpty ? day.dayLabel : day.dayName))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(day.isRest ? .secondary : .primary)
            }
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
    }
}
