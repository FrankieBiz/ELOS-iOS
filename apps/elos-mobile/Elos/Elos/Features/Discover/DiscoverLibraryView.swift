import SwiftUI
import SwiftData

struct DiscoverLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var discoverVM: DiscoverViewModel
    @State private var searchText = ""
    @State private var showCreators = false
    @State private var showMachines = false

    init(modelContext: ModelContext) {
        _discoverVM = StateObject(wrappedValue: DiscoverViewModel(context: modelContext))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !searchText.isEmpty {
                        searchResultsSection
                    } else {
                        sectionCards
                        if discoverVM.isLoading && discoverVM.featuredCreators.isEmpty && discoverVM.featuredMachines.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        } else if discoverVM.syncFailed {
                            syncFailedNotice
                        } else {
                            if !discoverVM.featuredCreators.isEmpty { featuredCreatorsRow }
                            if !discoverVM.featuredMachines.isEmpty { featuredMachinesRow }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            // Presented as a sheet, and every other sheet in the app offers an explicit way out —
            // swipe-to-dismiss alone is invisible and unavailable to Switch Control / VoiceOver users.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .searchable(text: $searchText, prompt: "Search creators, programs, machines")
            .onChange(of: searchText) { _, new in discoverVM.search(query: new) }
            .onAppear { discoverVM.load() }
            .navigationDestination(isPresented: $showCreators) {
                CreatorLibraryView()
                    .environmentObject(discoverVM)
            }
            .navigationDestination(isPresented: $showMachines) {
                MachineLibraryView()
                    .environmentObject(discoverVM)
            }
        }
    }

    // MARK: Section Cards

    private var sectionCards: some View {
        VStack(spacing: 12) {
            Button { showCreators = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.tint.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(Color.tint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Creator Programs")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("Bodybuilders, coaches, educators")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            .elosCard()

            Button { showMachines = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.good.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(Color.good)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Machine & Equipment")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("How to use every gym machine")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            .elosCard()
        }
    }

    private var syncFailedNotice: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.secondary)
            Text("Couldn't load featured content")
                .font(.subheadline).fontWeight(.semibold)
            Text("Check your connection and try again.")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                discoverVM.load()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.tint)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: Featured Creators

    private var featuredCreatorsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Featured Creators").font(.subheadline).fontWeight(.semibold)
                Spacer()
                Button("See all") { showCreators = true }
                    .font(.caption).foregroundStyle(Color.tint)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(discoverVM.featuredCreators.prefix(6)) { creator in
                        NavigationLink(destination: CreatorProfileView(slug: creator.slug)
                            .environmentObject(discoverVM)) {
                            CreatorCardCompact(creator: creator)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Featured Machines

    private var featuredMachinesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Popular Machines").font(.subheadline).fontWeight(.semibold)
                Spacer()
                Button("See all") { showMachines = true }
                    .font(.caption).foregroundStyle(Color.tint)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(discoverVM.featuredMachines.prefix(6)) { machine in
                        NavigationLink(destination: MachineDetailView(slug: machine.slug)) {
                            MachineCardCompact(machine: machine)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if discoverVM.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            } else if discoverVM.searchResults.isEmpty {
                Text("No results for \"\(searchText)\"")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            } else {
                if !discoverVM.searchResults.creators.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Creators").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                        VStack(spacing: 0) {
                            ForEach(discoverVM.searchResults.creators, id: \.id) { c in
                                NavigationLink(destination: CreatorProfileView(slug: c.slug)
                                    .environmentObject(discoverVM)) {
                                    HStack {
                                        Text(c.name).font(.subheadline)
                                        Spacer()
                                        CategoryBadge(category: c.category)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 14)
                            }
                        }
                        .elosCard()
                    }
                }

                if !discoverVM.searchResults.workouts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Programs").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                        VStack(spacing: 0) {
                            ForEach(discoverVM.searchResults.workouts, id: \.id) { w in
                                NavigationLink(destination: WorkoutDetailView(workoutId: w.id)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(w.title).font(.subheadline)
                                            Text(w.creator_name ?? "").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        DifficultyBadge(difficulty: w.difficulty)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 14)
                            }
                        }
                        .elosCard()
                    }
                }

                if !discoverVM.searchResults.machines.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Machines").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                        VStack(spacing: 0) {
                            ForEach(discoverVM.searchResults.machines, id: \.id) { m in
                                NavigationLink(destination: MachineDetailView(slug: m.slug)) {
                                    HStack {
                                        Text(m.name).font(.subheadline)
                                        Spacer()
                                        Text(m.category.capitalized)
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 14)
                            }
                        }
                        .elosCard()
                    }
                }
            }
        }
    }
}

// MARK: - Compact Cards

struct CreatorCardCompact: View {
    let creator: CreatorRecord
    /// Scaled: at 80pt fixed, every full name truncated.
    @ScaledMetric(relativeTo: .caption) private var creatorCardWidth: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteThumbnail(urlString: creator.imageURL, shape: .circle, size: 48, tint: .tint, fallbackSystemImage: "person.fill")
            // The whole name. Showing only the last component rendered "Schwarzene…" — the surname,
            // truncated — while the avatar beside it already carried both initials.
            Text(creator.name)
                .font(.system(.caption, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            CategoryBadge(category: creator.category)
        }
        .frame(width: creatorCardWidth, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct MachineCardCompact: View {
    let machine: MachineRecord
    /// Scaled: 90pt fitted almost no real machine name.
    @ScaledMetric(relativeTo: .caption) private var machineCardWidth: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteThumbnail(urlString: machine.imageURL, shape: .rounded(8), size: 48, tint: .good, fallbackSystemImage: "dumbbell")
            // The whole name, truncated by the layout if it must be — not chopped to its first two
            // *words*, which turned "Iso-Lateral Wide Chest Press" into "Iso-Lateral Wide" and made
            // machines that differ only in their later words indistinguishable.
            Text(machine.name)
                .font(.system(.caption, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(machine.category.capitalized)
                .font(.elosMicro).foregroundStyle(.secondary)
        }
        .frame(width: machineCardWidth, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Shared Badge Components

struct CategoryBadge: View {
    let category: String

    private var color: Color {
        switch category {
        case "bodybuilder": return .tint
        case "educator": return .good
        case "athlete": return .warn
        default: return .secondary
        }
    }

    var body: some View {
        Text(category.capitalized)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct DifficultyBadge: View {
    let difficulty: String

    private var color: Color {
        switch difficulty {
        case "beginner":     return .good
        case "intermediate": return .warn
        case "advanced":     return .bad
        default: return .secondary
        }
    }

    var body: some View {
        Text(difficulty.capitalized)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
