import SwiftUI
import Combine

@MainActor
class CreatorLibraryViewModel: ObservableObject {
    @Published var creators: [CreatorResponse] = []
    @Published var isLoading = false
    @Published var selectedCategory = "all"

    func load() {
        Task {
            isLoading = true
            defer { isLoading = false }
            if let response = try? await ApiClient.shared.get("/library/creators") as CreatorsListResponse {
                creators = response.creators
            }
        }
    }

    var filtered: [CreatorResponse] {
        guard selectedCategory != "all" else { return creators }
        return creators.filter { $0.category == selectedCategory }
    }
}

private struct CreatorsListResponse: Decodable { let creators: [CreatorResponse] }

// MARK: - View

struct CreatorLibraryView: View {
    @EnvironmentObject var discoverVM: DiscoverViewModel
    @StateObject private var vm = CreatorLibraryViewModel()
    @State private var searchText = ""

    private let categories = ["all", "bodybuilder", "educator", "youtuber", "coach", "athlete"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            let isSelected = cat == vm.selectedCategory
                            Button(cat == "all" ? "All" : cat.capitalized) {
                                vm.selectedCategory = cat
                            }
                            .font(.caption).fontWeight(isSelected ? .semibold : .regular)
                            .foregroundStyle(isSelected ? .white : Color.primary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(isSelected ? Color.tint : Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 1)
                }

                if vm.isLoading && vm.creators.isEmpty {
                    ProgressView().padding(.top, 40)
                } else if filtered.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No Creators Yet")
                            .font(.headline)
                        Text("Creator programs will appear here once added by the Elos team.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, creator in
                            NavigationLink(destination: CreatorProfileView(slug: creator.slug)
                                .environmentObject(discoverVM)) {
                                CreatorRow(creator: creator)
                            }
                            .buttonStyle(.plain)
                            if i < filtered.count - 1 { Divider().padding(.leading, 60) }
                        }
                    }
                    .elosCard()
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Creator Programs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search creators")
        .onAppear { vm.load() }
    }

    private var filtered: [CreatorResponse] {
        let base = vm.filtered
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct CreatorRow: View {
    let creator: CreatorResponse

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.tint.opacity(0.15)).frame(width: 44, height: 44)
                Text(creator.name.prefix(2).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(creator.name).font(.subheadline).fontWeight(.semibold)
                    if creator.is_verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2).foregroundStyle(Color.tint)
                    }
                }
                HStack(spacing: 6) {
                    CategoryBadge(category: creator.category)
                    if let wc = creator.workout_count, wc > 0 {
                        Text("\(wc) program\(wc == 1 ? "" : "s")")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
