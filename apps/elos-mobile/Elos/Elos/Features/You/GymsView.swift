import SwiftUI
import SwiftData

/// Where the lifter names the places they train — "Fairless", "Warminster". A profile-level list,
/// not split-scoped, because more than one screen cares which gym exists (the split detail view's
/// gym switcher, day-variant creation, Phase 3's learned equipment). Local-only, same as
/// `EquipmentPreference`/`VolumeOverrides`: nothing here syncs across devices yet.
struct GymsView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymRecord.createdAt) private var gyms: [GymRecord]
    @State private var newGymName = ""
    @State private var isBackfilling = false
    @State private var backfillNote: String? = nil
    @State private var renamingGym: GymRecord? = nil
    @State private var renameText = ""
    @State private var gymPendingDelete: GymRecord? = nil

    var body: some View {
        List {
            Section {
                Toggle(isOn: $vm.gymEquipmentLearningEnabled) {
                    Label("Learn my equipment", systemImage: "sparkles")
                }
                .tint(Color.tint)
                .onChange(of: vm.gymEquipmentLearningEnabled) { _, isOn in
                    backfillOnEnable(isOn)
                }
                if let note = backfillNote {
                    Text(note)
                        .font(.elosMicro)
                        .foregroundStyle(Color.tint)
                }
            } footer: {
                // Says plainly what turning this on does and what it changes, because it changes
                // what the app recommends — that shouldn't be a surprise discovered later.
                Text("Elos remembers which machines each gym has as you pick them and log sets, then puts those first when you're building a workout there. Off by default; nothing leaves your phone.")
                    .font(.elosMicro)
            }

            Section {
                HStack {
                    TextField("Gym name", text: $newGymName)
                    Button("Add") { addGym() }
                        .disabled(newGymName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if gyms.isEmpty {
                Section {
                    Text("No gyms yet. Add each place you train — a day can then hold a version for each.")
                        .font(.elosCaption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Your gyms") {
                    ForEach(gyms) { gym in
                        NavigationLink {
                            GymEquipmentView(gym: gym).environmentObject(vm)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(gym.name)
                                    if learningEnabled, let count = machineCount(for: gym), count > 0 {
                                        Text("\(count) machine\(count == 1 ? "" : "s") known")
                                            .font(.elosMicro)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if vm.activeGymID == gym.id {
                                    Text("Active")
                                        .font(.elosCaption)
                                        .foregroundStyle(Color.tint)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { gymPendingDelete = gym } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                renameText = gym.name
                                renamingGym = gym
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Gyms")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename gym", isPresented: Binding(
            get: { renamingGym != nil },
            set: { if !$0 { renamingGym = nil } }
        )) {
            TextField("Gym name", text: $renameText)
            Button("Save") {
                guard let gym = renamingGym, !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                gym.name = renameText.trimmingCharacters(in: .whitespaces)
                try? modelContext.save()
                renamingGym = nil
            }
            Button("Cancel", role: .cancel) { renamingGym = nil }
        }
        .confirmationDialog(
            "Delete this gym?",
            isPresented: Binding(get: { gymPendingDelete != nil }, set: { if !$0 { gymPendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let gym = gymPendingDelete else { return }
                if vm.activeGymID == gym.id { vm.activeGymID = "" }
                // Learned equipment is keyed by gym id, so leaving it behind would orphan rows that
                // nothing can ever show or clean up.
                GymEquipmentStore.forgetAll(gymID: gym.id, ownerID: vm.currentUserID, context: modelContext)
                modelContext.delete(gym)
                try? modelContext.save()
                gymPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { gymPendingDelete = nil }
        } message: {
            // Day variants tagged to this gym keep their own stored name and keep working —
            // deleting a gym only removes it from the list and the "which gym am I at" switcher.
            Text("Any day versions you've built for this gym stay as they are — they'll just show their own name instead of the gym's.")
        }
    }

    private var learningEnabled: Bool { vm.gymEquipmentLearningEnabled }

    /// Flipping this on immediately replays existing history so the feature has something to show
    /// straight away — months of logged machine sets already say where you train and on what, and
    /// starting from zero would make a working feature look broken.
    private func backfillOnEnable(_ isOn: Bool) {
        backfillNote = nil
        guard isOn, !isBackfilling else { return }
        isBackfilling = true
        let found = GymEquipmentStore.backfillFromHistory(ownerID: vm.currentUserID,
                                                          context: modelContext)
        isBackfilling = false
        backfillNote = found > 0
            ? "Caught up on your history — check each gym below."
            : "Nothing to catch up on yet. Tag a session with a gym and it'll start learning."
    }

    private func machineCount(for gym: GymRecord) -> Int? {
        let entries = GymEquipmentStore.entries(gymID: gym.id, ownerID: vm.currentUserID,
                                                context: modelContext)
        return entries.filter { !$0.isExcluded }.count
    }

    private func addGym() {
        let trimmed = newGymName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let gym = GymRecord(ownerID: vm.currentUserID, name: trimmed)
        modelContext.insert(gym)
        try? modelContext.save()
        newGymName = ""
    }
}
