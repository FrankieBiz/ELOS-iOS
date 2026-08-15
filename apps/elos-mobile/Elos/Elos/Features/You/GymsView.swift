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
    @State private var renamingGym: GymRecord? = nil
    @State private var renameText = ""
    @State private var gymPendingDelete: GymRecord? = nil

    var body: some View {
        List {
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
                        HStack {
                            Text(gym.name)
                            Spacer()
                            if vm.activeGymID == gym.id {
                                Text("Active")
                                    .font(.elosCaption)
                                    .foregroundStyle(Color.tint)
                            }
                        }
                        .contentShape(Rectangle())
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

    private func addGym() {
        let trimmed = newGymName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let gym = GymRecord(ownerID: vm.currentUserID, name: trimmed)
        modelContext.insert(gym)
        try? modelContext.save()
        newGymName = ""
    }
}
