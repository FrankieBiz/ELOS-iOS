import SwiftUI

struct MachineSelectionSheet: View {
    let exerciseName: String
    let variants: [EquipmentRecord]
    /// Machine identities the app has learned the lifter's active gym has. Empty means "unknown" —
    /// no gym selected, learning off, or nothing learned yet — and must change nothing about this
    /// sheet, since an unknown gym is not an empty one.
    var gymDedupeKeys: Set<String> = []
    var gymName: String = ""
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

    /// The variants that are actually at the lifter's gym. This is the highest-leverage place the
    /// learned inventory pays off: "Leg Extension" can offer 30 brands, and exactly one of them is
    /// the machine standing in front of you.
    private var atGym: [EquipmentRecord] {
        guard !gymDedupeKeys.isEmpty else { return [] }
        return filtered.filter { gymDedupeKeys.contains($0.dedupeKey) }
    }

    private var elsewhere: [EquipmentRecord] {
        guard !atGym.isEmpty else { return filtered }
        let shown = Set(atGym.map(\.equipmentId))
        return filtered.filter { !shown.contains($0.equipmentId) }
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

                if !atGym.isEmpty {
                    Section(header: Text("At \(gymName.isEmpty ? "your gym" : gymName)")) {
                        ForEach(atGym) { machine in machineButton(machine, atGym: true) }
                    }
                }

                Section(header: Text(atGym.isEmpty
                                     ? "\(variants.count) machine\(variants.count == 1 ? "" : "s") found"
                                     : "Other machines")) {
                    ForEach(elsewhere) { machine in machineButton(machine, atGym: false) }
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

    @ViewBuilder private func machineButton(_ machine: EquipmentRecord, atGym: Bool) -> some View {
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
                if atGym {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.good)
                }
                equipTypeBadge(machine.equipmentType)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
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
