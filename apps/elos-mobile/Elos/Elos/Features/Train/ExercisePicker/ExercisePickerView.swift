import SwiftUI
import SwiftData
import Combine

// MARK: - Public API

struct PickedExercise: Hashable {
    let id: String
    let name: String
    var equipmentId: String? = nil
    var equipmentDedupeKey: String? = nil
    var equipmentBrandName: String? = nil
    var isGenericExercise: Bool = true
}

struct ExercisePickerView: View {
    // Callbacks (exactly one should be provided; presence determines mode)
    var onPickSingle: ((PickedExercise) -> Void)? = nil
    var onConfirmMulti: (([PickedExercise]) -> Void)? = nil
    var prefilterBrandSlug: String? = nil
    var prefilterMachineName: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = ExercisePickerViewModel()
    @Query(sort: \ExerciseDefinitionRecord.name) private var dbExercises: [ExerciseDefinitionRecord]

    @State private var tab: Tab = .all
    @State private var query = ""
    @State private var equipFilter: EquipmentFilter = .all
    @State private var bodyPartFilter: BodyPartFilter = .all
    @State private var muscleFilter: String = "All"
    @State private var movementFilter: MovementFilter = .all
    @State private var localBrandFilter: String? = nil   // uses local EquipmentDatabase brands
    @State private var showAdvancedFilters = false
    @State private var selectedIDs: Set<String> = []
    @State private var selectedItems: [PickedExercise] = []
    @State private var machinePick: MachinePick? = nil

    private struct MachinePick: Identifiable {
        let id = UUID()
        let row: Row
        let variants: [EquipmentRecord]
        var isMultiPick: Bool = false   // true when triggered from multi-select
    }

    private var isMultiSelect: Bool { onConfirmMulti != nil }

    enum Tab: String, CaseIterable { case all = "All", recent = "Recent", favorites = "Favorites" }

    // MARK: - Local brand data (always available, no network needed)

    private var localBrands: [String] {
        Array(Set(EquipmentDatabase.all.map(\.brandName))).sorted()
    }

    // EquipmentDatabase records are ONLY shown for Machine filter or when a brand is selected.
    // Cable, Free Weight, and Bodyweight filters use the generic exercise list instead.
    private var prominentMachineResults: [EquipmentRecord] {
        guard equipFilter == .machine || equipFilter == .all || localBrandFilter != nil else { return [] }
        guard localBrandFilter != nil || equipFilter == .machine || !query.isEmpty else { return [] }

        var pool = EquipmentDatabase.all.filter {
            !Self.excludedEquipmentTypes.contains($0.equipmentType)
        }

        // When Machine filter: exclude cable machines (cable has its own exercise list)
        if equipFilter == .machine {
            pool = pool.filter { !$0.equipmentType.lowercased().contains("cable") }
        }

        // Apply brand filter
        if let brand = localBrandFilter {
            pool = pool.filter { $0.brandName == brand }
        }

        // Apply body part filter
        if bodyPartFilter != .all {
            let keywords = Self.bodyPartKeywords(bodyPartFilter)
            pool = pool.filter { record in
                record.bodyParts.contains { part in
                    keywords.contains { part.lowercased().contains($0) }
                }
            }
        }

        // Apply search query
        if !query.isEmpty {
            pool = pool.filter {
                $0.machineName.localizedCaseInsensitiveContains(query) ||
                $0.brandName.localizedCaseInsensitiveContains(query) ||
                $0.modelSeries.localizedCaseInsensitiveContains(query)
            }
        }

        return pool.sorted {
            $0.brandName == $1.brandName
                ? $0.machineName < $1.machineName
                : $0.brandName < $1.brandName
        }
    }

    private static func bodyPartKeywords(_ filter: BodyPartFilter) -> [String] {
        switch filter {
        case .all:       return []
        case .chest:     return ["chest", "pec"]
        case .back:      return ["back", "lat", "trap", "rhomboid", "row"]
        case .shoulders: return ["shoulder", "delt", "lateral raise"]
        case .arms:      return ["bicep", "tricep", "arm", "forearm", "curl"]
        case .legs:      return ["quad", "hamstring", "calf", "calves", "leg", "squat"]
        case .glutes:    return ["glute", "hip", "adductor", "abductor", "posterior"]
        case .core:      return ["ab", "core", "oblique", "rotation"]
        }
    }

    private var machineSectionHeader: String {
        if let brand = localBrandFilter {
            return equipFilter == .cable ? "\(brand) Cable" : "\(brand) Machines"
        }
        if equipFilter == .machine { return "All Machines" }
        if equipFilter == .cable   { return "All Cable Machines" }
        return "Machines by Brand"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                tabPicker
                filterArea
                Divider()
                exerciseList
                if isMultiSelect && !selectedItems.isEmpty {
                    multiSelectFooter
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .task {
                async let r: Void = vm.loadRecent()
                async let f: Void = vm.loadFavorites()
                async let s: Void = vm.syncExercises(into: modelContext)
                _ = await (r, f, s)
                if let preBrand = prefilterBrandSlug {
                    localBrandFilter = preBrand
                }
                if let preMachine = prefilterMachineName {
                    query = preMachine
                }
            }
            .sheet(item: $machinePick) { pick in
                MachineSelectionSheet(
                    exerciseName: pick.row.name,
                    variants: pick.variants
                ) { machine in
                    if pick.isMultiPick {
                        confirmMultiPick(row: pick.row, machine: machine)
                    } else {
                        confirmPick(row: pick.row, machine: machine)
                    }
                }
            }
        }
    }

    // MARK: Tab Picker

    private var tabPicker: some View {
        Picker("Tab", selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: Filter Area

    private var filterArea: some View {
        VStack(spacing: 0) {
            // Equipment type — always visible
            filterRow(label: "Equipment") {
                ForEach(EquipmentFilter.allCases, id: \.self) { tag in
                    chip(tag.rawValue, selected: equipFilter == tag) {
                        equipFilter = tag
                        muscleFilter = "All"
                        if tag != .machine && tag != .all { localBrandFilter = nil }
                    }
                }
            }
            Divider().padding(.leading, 16)

            // Brand — always visible, powered by local EquipmentDatabase
            filterRow(label: "Brand  (optional)") {
                chip("All Brands", selected: localBrandFilter == nil) { localBrandFilter = nil }
                ForEach(localBrands, id: \.self) { brand in
                    chip(brand, selected: localBrandFilter == brand) { localBrandFilter = brand }
                }
            }
            Divider().padding(.leading, 16)

            // Body part — always visible
            filterRow(label: "Body Part") {
                ForEach(BodyPartFilter.allCases, id: \.self) { tag in
                    chip(tag.rawValue, selected: bodyPartFilter == tag) { bodyPartFilter = tag; muscleFilter = "All" }
                }
            }
            if bodyPartFilter != .all && availableMuscles.count > 1 {
                Divider().padding(.leading, 16)
                filterRow(label: "Muscle") {
                    ForEach(availableMuscles, id: \.self) { muscle in
                        chip(muscle, selected: muscleFilter == muscle) { muscleFilter = muscle }
                    }
                }
            }
            if showAdvancedFilters {
                Divider().padding(.leading, 16)
                filterRow(label: "Movement") {
                    ForEach(MovementFilter.allCases, id: \.self) { tag in
                        chip(tag.rawValue, selected: movementFilter == tag) { movementFilter = tag }
                    }
                }
            }
            HStack {
                Spacer()
                Button(showAdvancedFilters ? "Fewer filters" : "More filters") {
                    withAnimation { showAdvancedFilters.toggle() }
                }
                .font(.caption)
                .foregroundStyle(Color.tint)
                .padding(.trailing, 16)
                .padding(.vertical, 6)
            }
        }
        .background(Color(.systemBackground))
    }

    private func filterRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.caption2).fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
                .padding(.top, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) { content() }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption).fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(selected ? .white : Color.primary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selected ? Color.tint : Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Data shaping

    private var availableMuscles: [String] {
        guard bodyPartFilter != .all else { return [] }
        let muscles = dbExercises
            .filter { BodyPartFilter.from(primaryMuscle: $0.primaryMuscle) == bodyPartFilter }
            .map { $0.primaryMuscle.capitalized }
        return ["All"] + Array(Set(muscles)).sorted()
    }

    private struct Row: Identifiable, Hashable {
        let id: String
        let name: String
        let primaryMuscle: String
        let equipment: String
        let movementPattern: String
        let isCustom: Bool
    }

    private var allRows: [Row] {
        dbExercises.map {
            Row(id: $0.id, name: $0.name, primaryMuscle: $0.primaryMuscle,
                equipment: $0.equipment, movementPattern: $0.movementPattern,
                isCustom: $0.isCustom)
        }
    }

    private var rowsForCurrentTab: [Row] {
        switch tab {
        case .all:
            return allRows
        case .recent:
            return vm.recent.map {
                Row(id: $0.id, name: $0.name, primaryMuscle: $0.primary_muscle,
                    equipment: $0.equipment, movementPattern: $0.movement_pattern,
                    isCustom: $0.is_custom)
            }
        case .favorites:
            return vm.favorites.map {
                Row(id: $0.id, name: $0.name, primaryMuscle: $0.primary_muscle,
                    equipment: $0.equipment, movementPattern: $0.movement_pattern,
                    isCustom: $0.is_custom)
            }
        }
    }

    private var filtered: [Row] {
        var result = rowsForCurrentTab
        if equipFilter != .all {
            result = result.filter { EquipmentFilter.matches(equipFilter, dbEquipment: $0.equipment) }
        }
        if bodyPartFilter != .all {
            result = result.filter { BodyPartFilter.from(primaryMuscle: $0.primaryMuscle) == bodyPartFilter }
        }
        if muscleFilter != "All" {
            result = result.filter { $0.primaryMuscle.capitalized == muscleFilter }
        }
        if movementFilter != .all {
            result = result.filter { $0.movementPattern.lowercased() == movementFilter.rawValue.lowercased() }
        }
        if !query.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        return result
    }

    private static let excludedEquipmentTypes: Set<String> = [
        "Storage", "Storage / Accessory", "Storage / Storage / Accessory", "Cardio"
    ]

    // Search-based machine results (fallback when no brand selected)
    private var machineResults: [EquipmentRecord] {
        guard query.count >= 2, tab == .all else { return [] }
        let q = query.lowercased()
        let results = EquipmentDatabase.all.filter {
            ($0.machineName.lowercased().contains(q) ||
             $0.brandName.lowercased().contains(q) ||
             $0.modelSeries.lowercased().contains(q)) &&
            !Self.excludedEquipmentTypes.contains($0.equipmentType)
        }
        return results.sorted {
            let aExact = $0.machineName.lowercased() == q
            let bExact = $1.machineName.lowercased() == q
            if aExact != bExact { return aExact }
            let aEnd = $0.machineName.lowercased().hasSuffix(q)
            let bEnd = $1.machineName.lowercased().hasSuffix(q)
            if aEnd != bEnd { return aEnd }
            return $0.brandName < $1.brandName
        }.prefix(30).map { $0 }
    }

    // MARK: Exercise List

    private var exerciseList: some View {
        Group {
            if tab == .recent && vm.recent.isEmpty && !vm.isLoadingRecent {
                emptyState(icon: "clock", title: "No recent exercises", subtitle: "Log a set to see exercises here.")
            } else if tab == .favorites && vm.favorites.isEmpty && !vm.isLoadingFavorites {
                emptyState(icon: "star", title: "No favorites yet", subtitle: "Tap the star on any exercise to add it here.")
            } else if (filtered.isEmpty || localBrandFilter != nil) && prominentMachineResults.isEmpty && query.isEmpty {
                emptyState(
                    icon: "magnifyingglass",
                    title: "No exercises match your filters.",
                    subtitle: "Try clearing filters or searching by name."
                )
            } else if (filtered.isEmpty || localBrandFilter != nil) && prominentMachineResults.isEmpty && !query.isEmpty {
                emptyState(
                    icon: "magnifyingglass",
                    title: "No results for \"\(query)\"",
                    subtitle: "Try a different name or clear the search."
                )
            } else {
                List {
                    // Machine filter = EquipmentDatabase only; all other filters = generic exercises
                    let machineMode = equipFilter == .machine
                    let hasMachines = !prominentMachineResults.isEmpty

                    // Generic exercise rows (cable/free weight/bodyweight/all modes)
                    // Hidden when a brand is selected — brand mode shows only that brand's machines.
                    if !machineMode && !filtered.isEmpty && localBrandFilter == nil {
                        if hasMachines {
                            Section {
                                ForEach(filtered) { row in rowView(row) }
                            } header: {
                                Text("EXERCISES")
                                    .font(.caption2).fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .textCase(nil)
                            }
                        } else {
                            ForEach(filtered) { row in rowView(row) }
                        }
                    }

                    // Equipment records (Machine filter, or brand selected in any mode)
                    if hasMachines {
                        Section {
                            ForEach(prominentMachineResults) { machine in
                                machineRowView(machine)
                            }
                        } header: {
                            HStack(spacing: 4) {
                                Image(systemName: "dumbbell")
                                Text(machineSectionHeader)
                            }
                            .font(.caption2).fontWeight(.semibold)
                            .foregroundStyle(localBrandFilter != nil ? Color.tint : .secondary)
                            .textCase(nil)
                        }
                    }

                    // In machine mode, also show matching generic exercises when searching
                    if machineMode && !filtered.isEmpty && !query.isEmpty && localBrandFilter == nil {
                        Section {
                            ForEach(filtered) { row in rowView(row) }
                        } header: {
                            Text("EXERCISES")
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.immediately)
            }
        }
    }

    private func machineRowView(_ machine: EquipmentRecord) -> some View {
        Button {
            let picked = PickedExercise(
                id: machine.equipmentId,
                name: "\(machine.brandName) \(machine.machineName)",
                equipmentId: machine.equipmentId,
                equipmentDedupeKey: machine.dedupeKey,
                equipmentBrandName: machine.brandName,
                isGenericExercise: false
            )
            if isMultiSelect {
                if selectedIDs.contains(machine.equipmentId) {
                    selectedIDs.remove(machine.equipmentId)
                    selectedItems.removeAll { $0.id == machine.equipmentId }
                } else {
                    selectedIDs.insert(machine.equipmentId)
                    selectedItems.append(picked)
                }
            } else {
                onPickSingle?(picked)
                dismiss()
            }
        } label: {
            HStack(spacing: 10) {
                if isMultiSelect {
                    Image(systemName: selectedIDs.contains(machine.equipmentId) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDs.contains(machine.equipmentId) ? Color.tint : Color.secondary)
                        .font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(machine.brandName) \(machine.machineName)")
                        .foregroundStyle(.primary)
                        .font(.subheadline)
                    HStack(spacing: 6) {
                        machineBadge(machine.equipmentType)
                        if !machine.modelSeries.isEmpty {
                            Text(machine.modelSeries)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }

    private func machineBadge(_ type: String) -> some View {
        let label = type.components(separatedBy: " / ").first ?? type
        return Text(label)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(Color.tint)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func rowView(_ row: Row) -> some View {
        let isSelected = selectedIDs.contains(row.id)
        let isFav = vm.favoriteIDs.contains(row.id)
        return Button {
            handleTap(row: row)
        } label: {
            HStack(spacing: 10) {
                if isMultiSelect {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.tint : Color.secondary)
                        .font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .foregroundStyle(.primary)
                        .font(.subheadline)
                    HStack(spacing: 6) {
                        equipmentBadge(row.equipment)
                        Text(row.primaryMuscle.capitalized)
                            .font(.caption2).foregroundStyle(.secondary)
                        if row.isCustom {
                            Text("Custom")
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(Color.tint)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Color.tint.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer()
                Button {
                    Task { await vm.toggleFavorite(exerciseID: row.id) }
                } label: {
                    Image(systemName: isFav ? "star.fill" : "star")
                        .foregroundStyle(isFav ? .yellow : .secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }

    private func handleTap(row: Row) {
        let variants = EquipmentDatabase.variants(forExercise: row.name)

        if isMultiSelect {
            if selectedIDs.contains(row.id) {
                // Deselect
                selectedIDs.remove(row.id)
                selectedItems.removeAll { $0.id == row.id }
            } else if !variants.isEmpty {
                // Show brand picker before adding to multi-selection
                machinePick = MachinePick(row: row, variants: variants, isMultiPick: true)
            } else {
                // No brand variants — add generic directly
                let picked = PickedExercise(id: row.id, name: row.name)
                selectedIDs.insert(row.id)
                selectedItems.append(picked)
            }
        } else {
            if !variants.isEmpty {
                machinePick = MachinePick(row: row, variants: variants, isMultiPick: false)
            } else {
                confirmPick(row: row, machine: nil)
            }
        }
    }

    private func confirmPick(row: Row, machine: EquipmentRecord?) {
        var picked = PickedExercise(id: row.id, name: row.name)
        if let m = machine {
            picked.equipmentId        = m.equipmentId
            picked.equipmentDedupeKey = m.dedupeKey
            picked.equipmentBrandName = m.brandName
            picked.isGenericExercise  = false
        }
        onPickSingle?(picked)
        dismiss()
    }

    private func confirmMultiPick(row: Row, machine: EquipmentRecord?) {
        var picked = PickedExercise(id: row.id, name: row.name)
        if let m = machine {
            picked.equipmentId        = m.equipmentId
            picked.equipmentDedupeKey = m.dedupeKey
            picked.equipmentBrandName = m.brandName
            picked.isGenericExercise  = false
        }
        selectedIDs.insert(picked.id)
        selectedItems.append(picked)
    }

    private var multiSelectFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("\(selectedItems.count) selected")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button {
                    onConfirmMulti?(selectedItems)
                    dismiss()
                } label: {
                    Text("Add \(selectedItems.count)")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.tint)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func equipmentBadge(_ equipment: String) -> some View {
        let normalized = equipment.lowercased()
        let label: String
        let color: Color
        if normalized.contains("machine") { label = "Machine"; color = Color.tint }
        else if normalized.contains("cable") { label = "Cable"; color = Color.good }
        else if normalized.contains("barbell") || normalized.contains("dumbbell") || normalized.contains("free") { label = "Free Weight"; color = Color.warn }
        else if normalized.contains("body") || normalized.isEmpty { label = "Bodyweight"; color = Color.secondary }
        else { label = equipment.capitalized; color = Color.secondary }
        return Text(label)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Filter taxonomies

enum EquipmentFilter: String, CaseIterable {
    case all         = "All"
    case machine     = "Machine"
    case cable       = "Cable"
    case freeWeight  = "Free Weight"
    case bodyweight  = "Bodyweight"

    static func matches(_ filter: EquipmentFilter, dbEquipment: String) -> Bool {
        if filter == .all { return true }
        let normalized = dbEquipment.lowercased()
        switch filter {
        case .all:        return true
        case .machine:    return normalized.contains("machine")
        case .cable:      return normalized.contains("cable")
        case .freeWeight: return normalized.contains("barbell") || normalized.contains("dumbbell") || normalized.contains("free")
        case .bodyweight: return normalized.contains("body") || normalized.isEmpty
        }
    }
}

enum BodyPartFilter: String, CaseIterable {
    case all       = "All"
    case chest     = "Chest"
    case back      = "Back"
    case shoulders = "Shoulders"
    case arms      = "Arms"
    case legs      = "Legs"
    case glutes    = "Glutes"
    case core      = "Core"

    static func from(primaryMuscle: String) -> BodyPartFilter {
        let m = primaryMuscle.lowercased()
        if m.contains("pec") || m.contains("chest") { return .chest }
        if m.contains("lat") || m.contains("back") || m.contains("trap") || m.contains("rhomboid") || m.contains("rear delt") || m.contains("rear_delt") { return .back }
        if m.contains("delt") || m.contains("shoulder") { return .shoulders }
        if m.contains("bicep") || m.contains("tricep") || m.contains("forearm") || m.contains("brachialis") || m.contains("arm") { return .arms }
        if m.contains("quad") || m.contains("hamstring") || m.contains("calf") || m.contains("calves") || m.contains("leg") || m.contains("tibialis") { return .legs }
        if m.contains("glute") || m.contains("hip") || m.contains("adductor") { return .glutes }
        if m.contains("ab") || m.contains("oblique") || m.contains("core") { return .core }
        return .all
    }
}

enum MovementFilter: String, CaseIterable {
    case all        = "All"
    case push       = "Push"
    case pull       = "Pull"
    case squat      = "Squat"
    case hinge      = "Hinge"
    case carry      = "Carry"
    case rotation   = "Rotation"
    case isolation  = "Isolation"
}
