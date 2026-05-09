import SwiftUI
import SwiftData

struct TrainView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var ctx

    @State private var section: Section = .programs
    @State private var search = ""
    @State private var muscleFilter: String? = nil
    @State private var showAddCustom = false

    enum Section: Hashable, CaseIterable {
        case programs, library, history
        var label: String {
            switch self {
            case .programs: return "Programs"
            case .library:  return "Library"
            case .history:  return "History"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                segmentedHeader
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                Group {
                    switch section {
                    case .programs: ProgramsList(search: search)
                    case .library:  LibraryList(search: search, muscleFilter: $muscleFilter)
                    case .history:  HistoryList()
                    }
                }
                .transition(.opacity)
            }
            .background(Color.surfaceBG.ignoresSafeArea())
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $search,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: section == .history ? "Search workouts" : "Search exercises")
            .toolbar {
                if section == .library {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddCustom = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .heavy))
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddCustom) {
                AddCustomExerciseSheet()
            }
        }
    }

    private var segmentedHeader: some View {
        HStack(spacing: 6) {
            ForEach(Section.allCases, id: \.self) { s in
                Button {
                    withAnimation(Theme.Motion.snappy) { section = s }
                    Haptic.selection()
                } label: {
                    Text(s.label)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(section == s ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if section == s {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.brand)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Programs

private struct ProgramsList: View {
    @Environment(AppState.self) private var appState
    let search: String

    private var filtered: [Program] {
        guard !search.isEmpty else { return Program.library }
        return Program.library.filter {
            $0.name.lowercased().contains(search.lowercased()) ||
            $0.subtitle.lowercased().contains(search.lowercased())
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(filtered) { p in
                    NavigationLink {
                        ProgramDetailView(program: p)
                    } label: {
                        ProgramRow(program: p, isActive: p.id == appState.activeProgramId)
                    }
                    .buttonStyle(.pressable(scale: 0.98, haptic: .light))
                }
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
        }
    }
}

private struct ProgramRow: View {
    let program: Program
    let isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(colors: [program.accent, program.accent.opacity(0.65)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Image(systemName: program.icon)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(program.name)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    if isActive {
                        Chip(text: "ACTIVE", icon: "checkmark.circle.fill",
                             color: .brandSuccess, filled: false)
                    }
                }
                Text(program.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Chip(text: "\(program.daysPerWeek)d/wk", color: .secondary)
                    Chip(text: program.level.label.capitalized, color: .secondary)
                }
                .padding(.top, 2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .strokeBorder(isActive ? Color.brandSuccess.opacity(0.5) : Color.hairline.opacity(0.4),
                              lineWidth: isActive ? 1.5 : 0.5)
        )
    }
}

struct ProgramDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let program: Program

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero
                ZStack {
                    LinearGradient(colors: [program.accent, program.accent.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: program.icon)
                                .font(.system(size: 22, weight: .black))
                            Text(program.name)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .minimumScaleFactor(0.7).lineLimit(1)
                            Spacer()
                        }
                        Text(program.subtitle)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(program.description)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 4)
                        HStack(spacing: 6) {
                            Chip(text: "\(program.daysPerWeek)d/week", color: .white, filled: false)
                            Chip(text: program.level.label.capitalized, color: .white, filled: false)
                        }
                        .padding(.top, 6)
                    }
                    .padding(20)
                    .foregroundStyle(.white)
                }

                Button {
                    setActive()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: appState.activeProgramId == program.id ? "checkmark" : "play.fill")
                        Text(appState.activeProgramId == program.id ? "Active program" : "Make this my program")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(appState.activeProgramId == program.id ? Color.brandSuccess : Color.brand,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.pressable(scale: 0.97, haptic: .heavy))
                .padding(16)
                .disabled(appState.activeProgramId == program.id)

                // Days
                VStack(spacing: 10) {
                    ForEach(Array(program.days.enumerated()), id: \.offset) { i, day in
                        DayRow(index: i, day: day, accent: program.accent)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 30)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func setActive() {
        appState.activeProgramId = program.id
        appState.programStartDate = .now
        Haptic.success()
    }
}

private struct DayRow: View {
    let index: Int
    let day: ProgramDay
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(day.isRest ? .secondary : .white)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(day.isRest ? Color.surfaceInset : accent)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(day.title).font(.system(size: 15, weight: .heavy, design: .rounded))
                Text(day.focus).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            Spacer()
            if !day.isRest {
                Text("\(day.exerciseIds.count) ex").font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Library

private struct LibraryList: View {
    @Query private var customExercises: [CustomExercise]
    let search: String
    @Binding var muscleFilter: String?

    private var filtered: [ExerciseDefinition] {
        var r = ExerciseDefinition.search(search)
        if let m = muscleFilter { r = r.filter { $0.muscleGroup == m } }
        return r
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    LibFilterChip(label: "All", selected: muscleFilter == nil) { muscleFilter = nil }
                    ForEach(ExerciseDefinition.muscleGroups, id: \.self) { m in
                        LibFilterChip(label: m, selected: muscleFilter == m) {
                            muscleFilter = muscleFilter == m ? nil : m
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }

            List {
                if !customExercises.isEmpty && (muscleFilter == nil || customExercises.contains { $0.muscleGroup == muscleFilter }) {
                    Section("Your Custom Exercises") {
                        ForEach(customExercises.filter { c in
                            (muscleFilter == nil || c.muscleGroup == muscleFilter) &&
                            (search.isEmpty || c.name.lowercased().contains(search.lowercased()))
                        }) { c in
                            CustomExerciseRow(exercise: c)
                        }
                    }
                }

                ForEach(filtered) { ex in
                    NavigationLink {
                        ExerciseDetailView(exercise: ex)
                    } label: {
                        LibraryRow(exercise: ex)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct LibFilterChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { Haptic.selection(); action() }) {
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(selected ? Color.brand : Color.surfaceRaised, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct LibraryRow: View {
    let exercise: ExerciseDefinition

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(exercise.color.opacity(0.18))
                Image(systemName: exercise.icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(exercise.color)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.system(size: 15, weight: .heavy, design: .rounded))
                Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if exercise.isCompound { Chip(text: "Compound", color: .brand) }
        }
        .padding(.vertical, 4)
    }
}

private struct CustomExerciseRow: View {
    let exercise: CustomExercise

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.brandInfo.opacity(0.18))
                Image(systemName: "person.fill.badge.plus")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.brandInfo)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.system(size: 15, weight: .heavy, design: .rounded))
                Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Chip(text: "Custom", color: .brandInfo)
        }
        .padding(.vertical, 4)
    }
}

struct ExerciseDetailView: View {
    let exercise: ExerciseDefinition
    @Query(sort: \WorkoutSet.completedAt, order: .reverse) private var allSets: [WorkoutSet]
    @Environment(AppState.self) private var appState

    private var setsForThis: [WorkoutSet] {
        allSets.filter { $0.exerciseName == exercise.name }
    }

    private var bestE1RMKg: Double {
        setsForThis.compactMap(\.estimated1RMKg).max() ?? 0
    }

    private var bestSet: WorkoutSet? {
        setsForThis.max { ($0.estimated1RMKg ?? 0) < ($1.estimated1RMKg ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hero
                ZStack(alignment: .leading) {
                    LinearGradient(colors: [exercise.color, exercise.color.opacity(0.65)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.muscleGroup.uppercased())
                                .font(.system(size: 11, weight: .heavy))
                                .kerning(0.6)
                                .foregroundStyle(.white.opacity(0.85))
                            Text(exercise.name)
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.7)
                            HStack(spacing: 6) {
                                Chip(text: exercise.equipment, color: .white, filled: false)
                                if exercise.isCompound { Chip(text: "Compound", color: .white, filled: false) }
                            }
                            .padding(.top, 4)
                        }
                        Spacer()
                        Image(systemName: exercise.icon)
                            .font(.system(size: 70, weight: .black))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .padding(20)
                }
                .frame(minHeight: 170)

                if !exercise.description.isEmpty {
                    Text(exercise.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }

                if !exercise.secondaryMuscles.isEmpty {
                    HStack(spacing: 6) {
                        Text("ALSO WORKS")
                            .font(.system(size: 10, weight: .heavy))
                            .kerning(0.6)
                            .foregroundStyle(.secondary)
                        ForEach(exercise.secondaryMuscles, id: \.self) { m in
                            Chip(text: m, color: .secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if !setsForThis.isEmpty {
                    SectionLabel(title: "Stats")
                    HStack(spacing: 10) {
                        StatTile(label: "Best Set", value: bestSetLabel, icon: "trophy.fill", accent: .brandTrophy)
                        StatTile(label: "Est 1RM", value: e1rmLabel, icon: "chart.line.uptrend.xyaxis", accent: .brand)
                        StatTile(label: "Total Sets", value: "\(setsForThis.count)", icon: "list.number", accent: .brandInfo)
                    }
                    .padding(.horizontal, 16)

                    SectionLabel(title: "Recent Sets")
                    VStack(spacing: 0) {
                        ForEach(setsForThis.prefix(10).enumerated().map { ($0, $1) }, id: \.1.id) { i, s in
                            SetHistoryRow(set: s, units: appState.units)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                            if i < min(setsForThis.count, 10) - 1 { Hairline(inset: 16) }
                        }
                    }
                    .background(Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                } else {
                    EmptyStateCard(icon: "chart.line.uptrend.xyaxis",
                                   title: "No history yet",
                                   subtitle: "Log this exercise in a workout to start tracking your progress.")
                }

                Spacer(minLength: 30)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var bestSetLabel: String {
        guard let s = bestSet else { return "—" }
        let v = appState.units.from(kg: s.weightKg)
        return "\(v.prettyWeight)×\(s.reps)"
    }

    private var e1rmLabel: String {
        guard bestE1RMKg > 0 else { return "—" }
        let v = appState.units.from(kg: bestE1RMKg)
        return "\(v.prettyWeight) \(appState.units.label)"
    }
}

private struct SetHistoryRow: View {
    let set: WorkoutSet
    let units: WeightUnit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(set.completedAt.shortDate)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                Text("Set \(set.setNumber)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(units.from(kg: set.weightKg).prettyWeight) \(units.label) × \(set.reps)")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
            if let rpe = set.rpe {
                Chip(text: "RPE \(rpe.prettyWeight)", color: .brandWarn)
            }
        }
    }
}

// MARK: - History

private struct HistoryList: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if sessions.isEmpty {
                EmptyStateCard(
                    icon: "clock.arrow.circlepath",
                    title: "No workouts yet",
                    subtitle: "Your completed sessions will appear here."
                )
            } else {
                List {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRow(session: session, units: appState.units)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

private struct SessionRow: View {
    let session: WorkoutSession
    let units: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Spacer()
                Text(session.date.shortDate)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                Label("\(session.sets.count) sets", systemImage: "list.number")
                Label("\(session.durationMinutes)m", systemImage: "clock")
                let v = units.from(kg: session.totalVolumeKg)
                Label(v >= 1000 ? String(format: "%.1fk %@", v/1000, units.label)
                                : String(format: "%.0f %@", v, units.label),
                      systemImage: "scalemass")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession
    @Environment(AppState.self) private var appState

    private var grouped: [(name: String, sets: [WorkoutSet])] {
        let dict = Dictionary(grouping: session.sets, by: \.exerciseName)
        return dict.map { (name: $0.key, sets: $0.value.sorted { $0.setNumber < $1.setNumber }) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    StatTile(label: "Duration", value: "\(session.durationMinutes)m",
                             icon: "clock.fill", accent: .brand)
                    StatTile(label: "Sets", value: "\(session.sets.count)",
                             icon: "list.number", accent: .brandInfo)
                    StatTile(label: "Volume",
                             value: appState.units.from(kg: session.totalVolumeKg).prettyWeight + " " + appState.units.label,
                             icon: "scalemass.fill", accent: .brandTrophy)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }
            ForEach(grouped, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.sets) { s in
                        HStack {
                            Text("Set \(s.setNumber)")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(appState.units.from(kg: s.weightKg).prettyWeight) \(appState.units.label) × \(s.reps)")
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            if let rpe = s.rpe { Chip(text: "RPE \(rpe.prettyWeight)", color: .brandWarn) }
                        }
                    }
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Add Custom Exercise

struct AddCustomExerciseSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var muscleGroup = "Chest"
    @State private var equipment = "Barbell"
    @State private var isCompound = true
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("e.g. Cable Crossover", text: $name) }
                Section("Details") {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(ExerciseDefinition.muscleGroups, id: \.self) { Text($0) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(["Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Other"], id: \.self) { Text($0) }
                    }
                    Toggle("Compound movement", isOn: $isCompound)
                }
                Section("Notes (optional)") {
                    TextField("Cues / setup / form notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let ex = CustomExercise(
                            name: name, muscleGroup: muscleGroup, equipment: equipment,
                            isCompound: isCompound, notes: notes
                        )
                        ctx.insert(ex)
                        Haptic.success()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
