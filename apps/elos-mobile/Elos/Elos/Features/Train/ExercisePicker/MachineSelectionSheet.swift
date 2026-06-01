import SwiftUI

struct MachineSelectionSheet: View {
    let exerciseName: String
    let variants: [EquipmentRecord]
    let onPick: (EquipmentRecord?) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [EquipmentRecord] {
        guard !query.isEmpty else { return variants }
        let q = query.lowercased()
        return variants.filter {
            $0.brandName.localizedCaseInsensitiveContains(q) ||
            $0.modelSeries.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Picking a specific machine keeps your PRs and overload tracking consistent — different brands have different weight stacks and strength curves.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section(header: Text("\(variants.count) machine\(variants.count == 1 ? "" : "s") found")) {
                    ForEach(filtered) { machine in
                        Button {
                            onPick(machine)
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(machine.brandName)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    if !machine.modelSeries.isEmpty {
                                        Text(machine.modelSeries)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                equipTypeBadge(machine.equipmentType)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Button {
                        onPick(nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                            Text("Use Generic – don't specify machine")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Filter by brand or model")
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func equipTypeBadge(_ type: String) -> some View {
        let label = type.components(separatedBy: " / ").first ?? type
        return Text(label)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(Color.tint)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.tint.opacity(0.1))
            .clipShape(Capsule())
    }
}
