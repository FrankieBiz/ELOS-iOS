import SwiftUI
import SwiftData

/// What the app has learned one gym has — and the place to correct it.
///
/// Nothing here is typed in up front. Rows arrive by themselves as machines get picked into plans
/// and sets get logged; this screen exists so the lifter can see what the app believes, and say "no,
/// we don't have that" when it's wrong. Correction matters more than collection: a wrong inventory
/// that can't be fixed would quietly skew every suggestion built on it.
struct GymEquipmentView: View {
    let gym: GymRecord

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var records: [GymEquipmentRecord] = []
    @State private var showingAddMachine = false
    @State private var showingForgetConfirm = false

    private var learningEnabled: Bool { vm.gymEquipmentLearningEnabled }
    private var known: [GymEquipmentRecord] { records.filter { !$0.isExcluded } }
    private var excluded: [GymEquipmentRecord] { records.filter(\.isExcluded) }

    /// Grouped for reading, not for logic — `GymEquipmentTaxonomy.displayCategory` is a label, and
    /// the coarse tokens the engines act on come from `coarseTypes` instead.
    private var grouped: [(category: String, items: [GymEquipmentRecord])] {
        Dictionary(grouping: known) { GymEquipmentTaxonomy.displayCategory(forCatalogType: $0.equipmentType) }
            .map { (category: $0.key, items: $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.category < $1.category }
    }

    var body: some View {
        List {
            if !learningEnabled {
                Section {
                    Label("Equipment learning is off", systemImage: "moon.zzz")
                        .font(.elosCaption)
                        .foregroundStyle(.secondary)
                    Text("Turn it on under Gyms to let Elos build this list as you train.")
                        .font(.elosMicro)
                        .foregroundStyle(.secondary)
                }
            }

            if known.isEmpty {
                Section {
                    Text(learningEnabled
                         ? "Nothing learned yet. Pick a specific machine when you add an exercise here, or log a set on one, and it'll show up."
                         : "Nothing learned yet.")
                        .font(.elosCaption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    HStack {
                        Text("\(known.count) machine\(known.count == 1 ? "" : "s") known")
                            .font(.subheadline).fontWeight(.semibold)
                        Spacer()
                        Text("\(Set(known.map(\.brandName)).filter { !$0.isEmpty }.count) brands")
                            .font(.elosCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(grouped, id: \.category) { group in
                    Section(group.category) {
                        ForEach(group.items) { record in
                            machineRow(record)
                        }
                    }
                }
            }

            if !excluded.isEmpty {
                Section {
                    ForEach(excluded) { record in
                        HStack {
                            Text(record.displayName.isEmpty ? record.equipmentDedupeKey : record.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Restore") {
                                GymEquipmentStore.unexclude(record, context: modelContext)
                                reload()
                            }
                            .font(.elosCaption)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.tint)
                        }
                    }
                } header: {
                    Text("Marked not here")
                } footer: {
                    Text("These stay hidden even if they turn up in a plan again.")
                        .font(.elosMicro)
                }
            }

            if !known.isEmpty {
                Section {
                    Button(role: .destructive) { showingForgetConfirm = true } label: {
                        Label("Forget everything learned here", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(gym.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddMachine = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAddMachine) {
            MachineSearchSheet { machine in
                GymEquipmentStore.addManually(machine, gymID: gym.id,
                                              ownerID: vm.currentUserID, context: modelContext)
                reload()
            }
        }
        .confirmationDialog("Forget learned equipment?", isPresented: $showingForgetConfirm,
                            titleVisibility: .visible) {
            Button("Forget all", role: .destructive) {
                GymEquipmentStore.forgetAll(gymID: gym.id, ownerID: vm.currentUserID, context: modelContext)
                reload()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This clears what Elos has learned about \(gym.name). It'll start learning again from your next session here.")
        }
        .onAppear(perform: reload)
    }

    @ViewBuilder private func machineRow(_ record: GymEquipmentRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.displayName.isEmpty ? record.equipmentDedupeKey : record.displayName)
                .font(.subheadline)
            HStack(spacing: 6) {
                Text(GymEquipmentSource.from(record.source).label)
                if record.timesSeen > 1 {
                    Text("· \(record.timesSeen)×")
                }
            }
            .font(.elosMicro)
            .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                GymEquipmentStore.exclude(record, context: modelContext)
                reload()
            } label: {
                Label("Not here", systemImage: "xmark.circle")
            }
        }
    }

    /// Held in `@State` and refreshed explicitly rather than fetched with `@Query`: the rows are
    /// written by `GymEquipmentStore` from several places (logging, the picker, backfill), and a
    /// plain snapshot with an explicit reload is easier to reason about than a live query whose
    /// predicate has to be rebuilt for whichever gym this view was handed.
    private func reload() {
        records = GymEquipmentStore.records(gymID: gym.id, ownerID: vm.currentUserID,
                                            context: modelContext)
    }
}

/// A minimal brand/machine search over the equipment catalog, for adding a machine by hand.
///
/// Deliberately not `ExercisePickerView`: that view records what it picks against the *active* gym,
/// which is the wrong gym whenever you're editing a different one's list.
struct MachineSearchSheet: View {
    let onPick: (EquipmentRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [EquipmentRecord] {
        guard query.count >= 2 else { return [] }
        let tokens = ExerciseSearch.tokens(from: query)
        guard !tokens.isEmpty else { return [] }
        return EquipmentDatabase.all
            .filter { GymEquipmentTaxonomy.isTrainingRelevant(catalogType: $0.equipmentType) }
            .filter { record in
                let haystack = ExerciseSearch.normalize(
                    "\(record.brandName) \(record.machineName) \(record.modelSeries) \(record.equipmentType)")
                return tokens.allSatisfy { haystack.contains($0) }
            }
            .prefix(40)
            .map { $0 }
    }

    var body: some View {
        NavigationView {
            List {
                if query.count < 2 {
                    Text("Search by brand or machine — \"Hammer Strength row\", \"leg extension\".")
                        .font(.elosCaption)
                        .foregroundStyle(.secondary)
                } else if results.isEmpty {
                    Text("No machines match \"\(query)\".")
                        .font(.elosCaption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { machine in
                        Button {
                            onPick(machine)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(machine.displayName).font(.subheadline).foregroundStyle(.primary)
                                Text(machine.equipmentType).font(.elosMicro).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Brand or machine")
            .navigationTitle("Add machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
