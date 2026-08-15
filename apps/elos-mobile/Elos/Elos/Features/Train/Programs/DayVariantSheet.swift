import SwiftUI
import SwiftData

/// Lists a day's versions (one per gym, plus its original), lets you switch/rename/delete them,
/// and start a new one. "Add version" seeds the new variant from the day's CURRENT content — a
/// Warminster leg day starts as a copy of the Fairless one with a few machines swapped, not a
/// blank slate — then hands off to the split editor so you can make those swaps immediately.
struct DayVariantSheet: View {
    let day: UserSplitDayRecord
    let defaultVariantName: String
    let gyms: [GymRecord]
    /// Called after a new version is created and switched to, so the caller can open the split
    /// editor for it. There's no single-day editor in this app — the full builder is where any
    /// day's exercises get edited — so this is the natural next step, not a placeholder.
    var onStartEditingNewVersion: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var variantSet: DayVariantSet
    @State private var renamingVariant: DayVariant? = nil
    @State private var renameText = ""

    init(day: UserSplitDayRecord, defaultVariantName: String, gyms: [GymRecord],
        onStartEditingNewVersion: @escaping () -> Void = {}) {
        self.day = day
        self.defaultVariantName = defaultVariantName
        self.gyms = gyms
        self.onStartEditingNewVersion = onStartEditingNewVersion
        _variantSet = State(initialValue: DayVariants.seeded(for: day, defaultName: defaultVariantName))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(variantSet.variants) { variant in
                        variantRow(variant)
                    }
                }

                Section {
                    Menu {
                        Button("No specific gym") { addVariant(gymID: nil, name: "New version") }
                        ForEach(gyms) { gym in
                            Button(gym.name) { addVariant(gymID: gym.id, name: gym.name) }
                        }
                    } label: {
                        Label("Add a version for a gym", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Day Versions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert("Rename version", isPresented: Binding(
            get: { renamingVariant != nil },
            set: { if !$0 { renamingVariant = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Save") {
                guard let variant = renamingVariant, !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                DayVariants.renameVariant(id: variant.id, to: renameText.trimmingCharacters(in: .whitespaces), day: day)
                try? modelContext.save()
                variantSet = DayVariants.seeded(for: day, defaultName: defaultVariantName)
                renamingVariant = nil
            }
            Button("Cancel", role: .cancel) { renamingVariant = nil }
        }
    }

    @ViewBuilder private func variantRow(_ variant: DayVariant) -> some View {
        let isActive = variant.id == variantSet.activeID
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(variant.name).font(.subheadline).fontWeight(.semibold)
                if let gymID = variant.gymID, let gym = gyms.first(where: { $0.id == gymID }) {
                    Text(gym.name).font(.elosCaption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.tint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isActive else { return }
            DayVariants.switchTo(variantID: variant.id, day: day)
            try? modelContext.save()
            dismiss()
        }
        .swipeActions(edge: .trailing) {
            if variantSet.variants.count > 1 {
                Button(role: .destructive) {
                    DayVariants.deleteVariant(id: variant.id, day: day)
                    try? modelContext.save()
                    variantSet = DayVariants.seeded(for: day, defaultName: defaultVariantName)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            Button {
                renameText = variant.name
                renamingVariant = variant
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    private func addVariant(gymID: String?, name: String) {
        let variant = DayVariants.createVariant(named: name, gymID: gymID, from: day)
        DayVariants.addVariant(variant, to: day, defaultNameForSeed: defaultVariantName, makeActive: true)
        try? modelContext.save()
        dismiss()
        onStartEditingNewVersion()
    }
}
