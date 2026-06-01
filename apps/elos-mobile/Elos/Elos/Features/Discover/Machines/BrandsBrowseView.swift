import SwiftUI
import Combine

// MARK: - Response types

private struct BrandsGroupedResponse: Decodable { let groups: [BrandGroup] }

private struct BrandGroup: Decodable, Identifiable {
    var id: String { brand.id }
    let brand: BrandInfo
    let machines: [BrandMachine]
}

private struct BrandInfo: Decodable {
    let id: String
    let name: String
    let slug: String
    let website_url: String?
}

private struct BrandMachine: Decodable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let category: String
    let equipment_type: String
    let primary_muscles: [String]
    let image_url: String?
}

// MARK: - ViewModel

@MainActor
private final class BrandsBrowseViewModel: ObservableObject {
    @Published var groups: [BrandGroup] = []
    @Published var isLoading = false

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: BrandsGroupedResponse = try await ApiClient.shared.get("/machines/by-brand")
            groups = response.groups.sorted { $0.brand.name < $1.brand.name }
        } catch {}
    }
}

// MARK: - View

struct BrandsBrowseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = BrandsBrowseViewModel()

    var body: some View {
        NavigationView {
            Group {
                if vm.isLoading && vm.groups.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.groups.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.stack").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("No brands yet").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(vm.groups) { group in
                                NavigationLink(destination: BrandDetailView(group: group)) {
                                    BrandCard(group: group)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Browse by Brand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await vm.load() }
        }
    }
}

// MARK: - Brand card

private struct BrandCard: View {
    let group: BrandGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.brand.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(group.machines.count) machines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 4) {
                ForEach(group.machines.prefix(4)) { m in
                    Text(m.category.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
                if group.machines.count > 4 {
                    Text("+\(group.machines.count - 4)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Brand detail (list of brand's machines)

private struct BrandDetailView: View {
    let group: BrandGroup

    var body: some View {
        List {
            ForEach(group.machines) { m in
                NavigationLink(destination: MachineDetailView(slug: m.slug)) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.good.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: "dumbbell").foregroundStyle(Color.good)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name).font(.subheadline).fontWeight(.semibold)
                            HStack(spacing: 4) {
                                Text(m.category.capitalized).font(.caption2).foregroundStyle(.secondary)
                                if let muscle = m.primary_muscles.first {
                                    Text("· \(muscle.replacingOccurrences(of: "_", with: " ").capitalized)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(group.brand.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
