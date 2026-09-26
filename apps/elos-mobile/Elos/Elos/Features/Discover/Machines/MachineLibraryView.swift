import SwiftUI
import Combine

// MARK: - Response types

private struct MachinesListResponse: Decodable { let machines: [MachineResponse] }
private struct BrandsResponse: Decodable { let brands: [MachineBrandResponse] }

struct MachineBrandResponse: Decodable {
    let id: String
    let name: String
    let slug: String
    let website_url: String?
}

private struct CategoriesResponse: Decodable {
    // Returns dict: { "chest": [...], "back": [...] }
}

// MARK: - ViewModel

@MainActor
class MachineLibraryViewModel: ObservableObject {
    @Published var machines: [MachineResponse] = []
    @Published var brands: [MachineBrandResponse] = []
    @Published var selectedCategory = "all"
    @Published var selectedBrand: String?
    @Published var isLoading = false
    @Published var hasLoadedOnce = false
    @Published var loadFailed = false

    let categoryOrder = ["all", "chest", "back", "shoulders", "legs", "arms", "glutes", "core", "cable", "smith"]

    func load() {
        Task {
            isLoading = true
            defer { isLoading = false; hasLoadedOnce = true }
            do {
                let r: MachinesListResponse = try await ApiClient.shared.get("/machines")
                machines = r.machines
                loadFailed = false
            } catch {
                loadFailed = machines.isEmpty
            }
            if let r = try? await ApiClient.shared.get("/machines/brands") as BrandsResponse {
                brands = r.brands
            }
        }
    }

    func loadByCategory(_ category: String) {
        guard category != "all" else { reload(); return }
        Task {
            isLoading = true
            defer { isLoading = false; hasLoadedOnce = true }
            let url = brandQueryParam(prefix: "/machines?category=\(category)")
            do {
                let r: MachinesListResponse = try await ApiClient.shared.get(url)
                machines = r.machines
                loadFailed = false
            } catch { loadFailed = machines.isEmpty }
        }
    }

    func reload() {
        Task {
            isLoading = true
            defer { isLoading = false; hasLoadedOnce = true }
            let base = selectedCategory == "all" ? "/machines" : "/machines?category=\(selectedCategory)"
            let url = brandQueryParam(prefix: base)
            do {
                let r: MachinesListResponse = try await ApiClient.shared.get(url)
                machines = r.machines
                loadFailed = false
            } catch { loadFailed = machines.isEmpty }
        }
    }

    private func brandQueryParam(prefix: String) -> String {
        guard let slug = selectedBrand else { return prefix }
        let sep = prefix.contains("?") ? "&" : "?"
        return "\(prefix)\(sep)brand=\(slug)"
    }

    var filtered: [MachineResponse] {
        selectedCategory == "all" ? machines : machines.filter { $0.category == selectedCategory }
    }
}

// MARK: - View

struct MachineLibraryView: View {
    @EnvironmentObject var discoverVM: DiscoverViewModel
    @StateObject private var vm = MachineLibraryViewModel()
    @State private var searchText = ""
    @State private var showBrandsBrowse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.categoryOrder, id: \.self) { cat in
                            let isSelected = cat == vm.selectedCategory
                            Button(cat == "all" ? "All" : cat.capitalized) {
                                vm.selectedCategory = cat
                                vm.loadByCategory(cat)
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

                // Brand filter
                if !vm.brands.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button("All Brands") {
                                vm.selectedBrand = nil
                                vm.reload()
                            }
                            .font(.caption).fontWeight(vm.selectedBrand == nil ? .semibold : .regular)
                            .foregroundStyle(vm.selectedBrand == nil ? .white : Color.primary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(vm.selectedBrand == nil ? Color.tint : Color(.secondarySystemBackground))
                            .clipShape(Capsule())

                            ForEach(vm.brands, id: \.id) { brand in
                                let isSelected = vm.selectedBrand == brand.slug
                                Button(brand.name) {
                                    vm.selectedBrand = isSelected ? nil : brand.slug
                                    vm.reload()
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
                }

                if vm.isLoading && vm.machines.isEmpty {
                    ProgressView().padding(.top, 40)
                } else if vm.machines.isEmpty && vm.loadFailed {
                    errorState
                } else if filtered.isEmpty {
                    Text("No machines found.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, machine in
                            NavigationLink(destination: MachineDetailView(slug: machine.slug)) {
                                MachineRow(machine: machine)
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
        .navigationTitle("Machine Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showBrandsBrowse = true } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .accessibilityLabel("Browse by brand")
            }
        }
        .sheet(isPresented: $showBrandsBrowse) {
            BrandsBrowseView()
        }
        .searchable(text: $searchText, prompt: "Search machines")
        .onAppear { vm.load() }
    }

    private var errorState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Couldn't load machines")
                .font(.headline)
            Text("Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                vm.load()
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
        .padding(.top, 40)
    }

    private var filtered: [MachineResponse] {
        let base = vm.filtered
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct MachineRow: View {
    let machine: MachineResponse

    var body: some View {
        HStack(spacing: 12) {
            RemoteThumbnail(urlString: machine.image_url, shape: .rounded(8), size: 44, tint: .good, fallbackSystemImage: "dumbbell")
            VStack(alignment: .leading, spacing: 3) {
                Text(machine.name).font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(machine.equipment_type.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption2).foregroundStyle(.secondary)
                    if let first = machine.primary_muscles.first {
                        Text("· \(first.replacingOccurrences(of: "_", with: " ").capitalized)")
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
