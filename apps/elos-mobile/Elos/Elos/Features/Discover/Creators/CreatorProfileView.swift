import SwiftUI
import Combine

// MARK: - Response Types

fileprivate struct CreatorDetailResponse: Decodable {
    let id: String
    let name: String
    let slug: String
    let bio: String?
    let category: String
    let training_style: String?
    let goals: [String]
    let split_types: [String]
    let difficulty: String
    let image_url: String?
    let is_verified: Bool
    let source_urls: [String]
    let workouts: [WorkoutSummaryResponse]
}

// MARK: - ViewModel

@MainActor
class CreatorProfileViewModel: ObservableObject {
    @Published fileprivate var creator: CreatorDetailResponse?
    @Published var isLoading = false

    func load(slug: String) {
        Task {
            isLoading = true
            defer { isLoading = false }
            creator = try? await ApiClient.shared.get("/library/creators/\(slug)") as CreatorDetailResponse
        }
    }
}

// MARK: - View

struct CreatorProfileView: View {
    let slug: String
    @EnvironmentObject var discoverVM: DiscoverViewModel
    @StateObject private var vm = CreatorProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if let creator = vm.creator {
                    creatorHeader(creator)
                    infoRow(creator)
                    if !creator.workouts.isEmpty {
                        programsSection(creator.workouts)
                    }
                    if !creator.source_urls.isEmpty {
                        sourcesCard(creator.source_urls)
                    }
                } else {
                    Text("Could not load creator.").foregroundStyle(.secondary).padding(.top, 40)
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(vm.creator?.name ?? "Creator")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.load(slug: slug) }
    }

    private func creatorHeader(_ c: CreatorDetailResponse) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.tint.opacity(0.15)).frame(width: 72, height: 72)
                Text(c.name.prefix(2).uppercased())
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.tint)
            }
            HStack(spacing: 6) {
                Text(c.name).font(.title3).fontWeight(.bold)
                if c.is_verified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.tint)
                }
            }
            CategoryBadge(category: c.category)
            if let bio = c.bio, !bio.isEmpty {
                Text(bio).font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .elosCard()
    }

    private func infoRow(_ c: CreatorDetailResponse) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                infoItem(label: "Level", value: c.difficulty.capitalized)
                Divider().frame(height: 32)
                infoItem(label: "Style", value: c.training_style ?? "—")
                Divider().frame(height: 32)
                infoItem(label: "Programs", value: "\(c.workouts.count)")
            }

            if !c.split_types.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Split Types").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(c.split_types, id: \.self) { split in
                            Text(split.replacingOccurrences(of: "_", with: "/").uppercased())
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(Color.tint)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.tint.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }

            if !c.goals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Goals").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(c.goals, id: \.self) { goal in
                            Text(goal.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .elosCard()
    }

    private func infoItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline).fontWeight(.semibold).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func programsSection(_ workouts: [WorkoutSummaryResponse]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Programs").font(.subheadline).fontWeight(.semibold)
            ForEach(Array(workouts.enumerated()), id: \.element.id) { i, w in
                NavigationLink(destination: WorkoutDetailView(workoutId: w.id)) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(w.title).font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                            HStack(spacing: 6) {
                                if let days = w.days_per_week {
                                    Text("\(days)d/wk").font(.caption2).foregroundStyle(.secondary)
                                }
                                if let goal = w.goal {
                                    Text("·").font(.caption2).foregroundStyle(.secondary)
                                    Text(goal.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        DifficultyBadge(difficulty: w.difficulty)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if i < workouts.count - 1 { Divider().padding(.leading, 14) }
            }
        }
        .padding(16)
        .elosCard()
    }

    private func sourcesCard(_ urls: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sources").font(.caption).foregroundStyle(.secondary)
            ForEach(urls, id: \.self) { url in
                Text(url)
                    .font(.caption).foregroundStyle(Color.tint)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
