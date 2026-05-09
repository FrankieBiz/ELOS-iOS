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
                // Refined tab header — segment with underline
                HStack(spacing: 0) {
                    ForEach(Section.allCases, id: \.self) { s in
                        Button {
                            withAnimation(Theme.Motion.silk) { section = s }
                            Haptic.selection()
                        } label: {
                            VStack(spacing: 0) {
                                Text(s.label.uppercased())
                                    .font(Theme.Font.label)
                                    .kerning(1.4)
                                    .foregroundStyle(section == s ? .pearl : .shadowTxt)
                                    .padding(.vertical, 12)
                                Rectangle()
                                    .fill(section == s ? Color.pearl : Color.clear)
                                    .frame(height: 1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Space.md)

                Hairline()

                Group {
                    switch section {
                    case .programs: ProgramsList(search: search)
                    case .library:  LibraryList(search: search, muscleFilter: $muscleFilter)
                    case .history:  HistoryList()
                    }
                }
                .transition(.opacity)
            }
            .background(Color.obsidian.ignoresSafeArea())
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $search,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: section == .history ? "Search workouts" : "Search exercises")
            .toolbar {
                if section == .library {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddCustom = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(.pearl)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddCustom) {
                AddCustomExerciseSheet()
            }
        }
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
            VStack(spacing: 0) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { i, p in
                    NavigationLink {
                        ProgramDetailView(program: p)
                    } label: {
                        ProgramRow(program: p, isActive: p.id == appState.activeProgramId)
                    }
                    .buttonStyle(.pressable(scale: 0.99, haptic: .light, glow: false))

                    if i < filtered.count - 1 {
                        Hairline().padding(.horizontal, Theme.Space.md)
                    }
                }
                Spacer(minLength: 100)
            }
            .padding(.top, 6)
        }
    }
}

private struct ProgramRow: View {
    let program: Program
    let isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Left bar instead of index badge
            Rectangle()
                .fill(isActive ? Color.pearl : Color.mist)
                .frame(width: 2, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(program.name)
                        .font(Theme.Font.heading(15))
                        .foregroundStyle(.pearl)
                    if isActive {
                        Chip(text: "Active", color: .sterling, filled: true)
                    }
                }
                Text(program.subtitle)
                    .font(Theme.Font.body(13))
                    .foregroundStyle(.silver)
                HStack(spacing: 6) {
                    Chip(text: "\(program.daysPerWeek)d / week", color: .shadowTxt)
                    Chip(text: program.level.label, color: .shadowTxt)
                }
                .padding(.top, 2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .thin))
                .foregroundStyle(.shadowTxt)
        }
        .padding(.horizontal, Theme.Space.md).padding(.vertical, 14)
        .background(isActive ? Color.pearl.opacity(0.04) : Color.obsidian)
    }
}

struct ProgramDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let program: Program

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        StatusDot(color: program.accent, size: 5)
                        Text(program.level.label.uppercased())
                            .font(Theme.Font.label)
                            .kerning(1.4)
                            .foregroundStyle(.silver)
                    }
                    Text(program.name)
                        .font(Theme.Font.display(40))
                        .foregroundStyle(.pearl)
                    Text(program.subtitle)
                        .font(Theme.Font.body(14))
                        .foregroundStyle(.silver)
                    Text(program.description)
                        .font(Theme.Font.body(14))
                        .foregroundStyle(.silver)
                        .padding(.top, 4)
                    HStack(spacing: 6) {
                        Chip(text: "\(program.daysPerWeek)d / week", color: .silver)
                        Chip(text: program.level.label, color: .silver)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Space.md)
                .background(Color.onyx)
                .edgeHighlight(radius: 0)

                Hairline()

                Button { setActive() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: appState.activeProgramId == program.id ? "checkmark" : "arrow.right")
                            .font(.system(size: 14, weight: .thin))
                        Text(appState.activeProgramId == program.id ? "Active program" : "Set as my program")
                            .font(Theme.Font.title(17))
                    }
                    .foregroundStyle(.obsidian)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(colors: [Color.pearl.opacity(0.97), .pearl], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    )
                }
                .buttonStyle(.pressable(scale: 0.985, haptic: .heavy, glow: true, glowRadius: 18))
                .padding(Theme.Space.md)
                .disabled(appState.activeProgramId == program.id)

                SectionLabel(title: "Schedule")

                VStack(spacing: 0) {
                    ForEach(Array(program.days.enumerated()), id: \.offset) { i, day in
                        DayRow(index: i + 1, day: day, accent: program.accent)
                        if i < program.days.count - 1 {
                            Hairline().padding(.horizontal, Theme.Space.md)
                        }
                    }
                }
                .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .edgeHighlight(radius: Theme.Radius.md)
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, 30)
            }
        }
        .background(Color.obsidian.ignoresSafeArea())
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
        HStack(spacing: 14) {
            Rectangle()
                .fill(day.isRest ? Color.mist : Color.pearl)
                .frame(width: 2, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(day.title)
                    .font(Theme.Font.heading(14))
                    .foregroundStyle(.pearl)
                Text(day.focus)
                    .font(Theme.Font.body(12))
                    .foregroundStyle(.silver)
            }
            Spacer()
            if !day.isRest {
                Text("\(day.exerciseIds.count) exercises")
                    .font(Theme.Font.body(12))
                    .foregroundStyle(.shadowTxt)
            }
        }
        .padding(.horizontal, Theme.Space.md).padding(.vertical, 12)
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
                HStack(spacing: 6) {
                    LibFilterChip(label: "All", selected: muscleFilter == nil) { muscleFilter = nil }
                    ForEach(ExerciseDefinition.muscleGroups, id: \.self) { m in
                        LibFilterChip(label: m, selected: muscleFilter == m) {
                            muscleFilter = muscleFilter == m ? nil : m
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.md).padding(.vertical, 10)
            }
            Hairline()

            ScrollView {
                VStack(spacing: 0) {
                    let customFiltered = customExercises.filter { c in
                        (muscleFilter == nil || c.muscleGroup == muscleFilter) &&
                        (search.isEmpty || c.name.lowercased().contains(search.lowercased()))
                    }
                    if !customFiltered.isEmpty {
                        SectionLabel(title: "Custom")
                        VStack(spacing: 0) {
                            ForEach(Array(customFiltered.enumerated()), id: \.element.id) { i, c in
                                CustomExerciseRow(exercise: c)
                                if i < customFiltered.count - 1 {
                                    Hairline().padding(.horizontal, Theme.Space.md)
                                }
                            }
                        }
                        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .edgeHighlight(radius: Theme.Radius.md)
                        .padding(.horizontal, Theme.Space.md)
                    }

                    SectionLabel(title: "Standard Library")
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, ex in
                            NavigationLink {
                                ExerciseDetailView(exercise: ex)
                            } label: {
                                LibraryRow(exercise: ex)
                            }
                            .buttonStyle(.plain)
                            if i < filtered.count - 1 {
                                Hairline().padding(.horizontal, Theme.Space.md)
                            }
                        }
                    }
                    .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .edgeHighlight(radius: Theme.Radius.md)
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, 100)
                }
            }
        }
    }
}

private struct LibFilterChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { Haptic.selection(); action() }) {
            Text(label.uppercased())
                .font(Theme.Font.label)
                .kerning(0.8)
                .foregroundStyle(selected ? Color.obsidian : Color.silver)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(selected ? Color.pearl : Color.graphite, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct LibraryRow: View {
    let exercise: ExerciseDefinition

    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(exercise.color.opacity(0.7))
                .frame(width: 2, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(Theme.Font.heading(14))
                    .foregroundStyle(.pearl)
                    .lineLimit(1)
                Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                    .font(Theme.Font.body(12))
                    .foregroundStyle(.silver)
            }
            Spacer()
            if exercise.isCompound { Chip(text: "Compound", color: .silver) }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .thin))
                .foregroundStyle(.shadowTxt)
        }
        .padding(.horizontal, Theme.Space.md).padding(.vertical, 12)
    }
}

private struct CustomExerciseRow: View {
    let exercise: CustomExercise

    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(Color.pearl)
                .frame(width: 2, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(Theme.Font.heading(14))
                    .foregroundStyle(.pearl)
                Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                    .font(Theme.Font.body(12))
                    .foregroundStyle(.silver)
            }
            Spacer()
            Chip(text: "Custom", color: .pearl, filled: false)
        }
        .padding(.horizontal, Theme.Space.md).padding(.vertical, 12)
    }
}

struct ExerciseDetailView: View {
    let exercise: ExerciseDefinition
    @Query(sort: \WorkoutSet.completedAt, order: .reverse) private var allSets: [WorkoutSet]
    @Environment(AppState.self) private var appState

    private var setsForThis: [WorkoutSet] { allSets.filter { $0.exerciseName == exercise.name } }
    private var bestE1RMKg: Double { setsForThis.compactMap(\.estimated1RMKg).max() ?? 0 }
    private var bestSet: WorkoutSet? {
        setsForThis.max { ($0.estimated1RMKg ?? 0) < ($1.estimated1RMKg ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        StatusDot(color: exercise.color, size: 5)
                        Text(exercise.muscleGroup.uppercased())
                            .font(Theme.Font.label)
                            .kerning(1.4)
                            .foregroundStyle(.silver)
                    }
                    Text(exercise.name)
                        .font(Theme.Font.display(36))
                        .foregroundStyle(.pearl)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 6) {
                        Chip(text: exercise.equipment, color: .silver)
                        if exercise.isCompound { Chip(text: "Compound", color: .silver) }
                    }
                }
                .padding(Theme.Space.md)

                if !exercise.description.isEmpty {
                    Text(exercise.description)
                        .font(Theme.Font.body(14))
                        .foregroundStyle(.silver)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.bottom, Theme.Space.md)
                }

                if !exercise.secondaryMuscles.isEmpty {
                    HStack(spacing: 6) {
                        Text("Also works".uppercased())
                            .font(Theme.Font.label)
                            .kerning(1.2)
                            .foregroundStyle(.shadowTxt)
                        ForEach(exercise.secondaryMuscles, id: \.self) { m in
                            Chip(text: m, color: .shadowTxt)
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, Theme.Space.md)
                }

                if !setsForThis.isEmpty {
                    SectionLabel(title: "Stats")
                    HStack(spacing: 10) {
                        StatTile(label: "Best set", value: bestSetLabel)
                        StatTile(label: "Est 1RM", value: e1rmLabel)
                        StatTile(label: "Total sets", value: "\(setsForThis.count)")
                    }
                    .padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Recent Sets")
                    VStack(spacing: 0) {
                        ForEach(Array(setsForThis.prefix(10).enumerated()), id: \.element.id) { i, s in
                            SetHistoryRow(set: s, units: appState.units)
                            if i < min(setsForThis.count, 10) - 1 {
                                Hairline().padding(.horizontal, Theme.Space.md)
                            }
                        }
                    }
                    .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .edgeHighlight(radius: Theme.Radius.md)
                    .padding(.horizontal, Theme.Space.md)
                } else {
                    EmptyStateCard(icon: "chart.line.uptrend.xyaxis",
                                   title: "No history yet",
                                   subtitle: "Log this exercise in a session to start tracking.")
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color.obsidian.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bestSetLabel: String {
        guard let s = bestSet else { return "—" }
        return "\(appState.units.from(kg: s.weightKg).prettyWeight)×\(s.reps)"
    }
    private var e1rmLabel: String {
        guard bestE1RMKg > 0 else { return "—" }
        return appState.units.from(kg: bestE1RMKg).prettyWeight
    }
}

private struct SetHistoryRow: View {
    let set: WorkoutSet
    let units: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(set.completedAt.shortDate)
                    .font(Theme.Font.heading(13))
                    .foregroundStyle(.pearl)
                Text("Set \(set.setNumber)")
                    .font(Theme.Font.body(12))
                    .foregroundStyle(.silver)
            }
            Spacer()
            Text("\(units.from(kg: set.weightKg).prettyWeight) \(units.label) × \(set.reps)")
                .font(Theme.Font.mono(13, .regular))
                .foregroundStyle(.pearl)
            if let rpe = set.rpe { Chip(text: "RPE \(rpe.prettyWeight)", color: .amber) }
        }
        .padding(.horizontal, Theme.Space.md).padding(.vertical, 12)
    }
}

// MARK: - History

private struct HistoryList: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if sessions.isEmpty {
                    EmptyStateCard(icon: "clock.arrow.circlepath",
                                   title: "No sessions yet",
                                   subtitle: "Your completed workouts will appear here.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { i, session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                SessionRow(session: session, units: appState.units)
                            }
                            .buttonStyle(.plain)
                            if i < sessions.count - 1 {
                                Hairline().padding(.horizontal, Theme.Space.md)
                            }
                        }
                    }
                    .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .edgeHighlight(radius: Theme.Radius.md)
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, Theme.Space.sm)
                }
                Spacer(minLength: 100)
            }
        }
    }
}

private struct SessionRow: View {
    let session: WorkoutSession
    let units: WeightUnit

    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(Color.mist)
                .frame(width: 2, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.name)
                        .font(Theme.Font.heading(14))
                        .foregroundStyle(.pearl)
                    Spacer()
                    Text(session.date.shortDate)
                        .font(Theme.Font.body(12))
                        .foregroundStyle(.silver)
                }
                HStack(spacing: 12) {
                    Label("\(session.sets.count) sets", systemImage: "list.bullet")
                    Label("\(session.durationMinutes) min", systemImage: "clock")
                }
                .font(Theme.Font.body(12))
                .foregroundStyle(.silver)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .thin))
                .foregroundStyle(.shadowTxt)
        }
        .padding(.horizontal, Theme.Space.md).padding(.vertical, 14)
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
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    StatTile(label: "Duration", value: "\(session.durationMinutes)m")
                    StatTile(label: "Sets", value: "\(session.sets.count)")
                    StatTile(label: "Volume", value: appState.units.from(kg: session.totalVolumeKg).prettyWeight)
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.md)

                ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                    SectionLabel(title: group.name)
                    VStack(spacing: 0) {
                        ForEach(Array(group.sets.enumerated()), id: \.element.id) { idx, s in
                            HStack {
                                Text("Set \(s.setNumber)")
                                    .font(Theme.Font.body(13))
                                    .foregroundStyle(.silver)
                                Spacer()
                                Text("\(appState.units.from(kg: s.weightKg).prettyWeight) \(appState.units.label) × \(s.reps)")
                                    .font(Theme.Font.mono(13, .regular))
                                    .foregroundStyle(.pearl)
                                if let rpe = s.rpe { Chip(text: "RPE \(rpe.prettyWeight)", color: .amber) }
                            }
                            .padding(.horizontal, Theme.Space.md).padding(.vertical, 12)
                            if idx < group.sets.count - 1 {
                                Hairline().padding(.horizontal, Theme.Space.md)
                            }
                        }
                    }
                    .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .edgeHighlight(radius: Theme.Radius.md)
                    .padding(.horizontal, Theme.Space.md)
                }
                Spacer(minLength: 40)
            }
        }
        .background(Color.obsidian.ignoresSafeArea())
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
                    TextField("Cues, setup, form notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.obsidian)
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
