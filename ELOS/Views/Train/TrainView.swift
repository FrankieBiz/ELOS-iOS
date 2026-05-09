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
                tabHeader
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, 6)
                    .padding(.bottom, 4)

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
            .background(Color.vBG.ignoresSafeArea())
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
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.vSignal)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddCustom) {
                AddCustomExerciseSheet()
            }
        }
    }

    private var tabHeader: some View {
        HStack(spacing: 0) {
            ForEach(Section.allCases, id: \.self) { s in
                Button {
                    withAnimation(Theme.Motion.snappy) { section = s }
                    Haptic.selection()
                } label: {
                    VStack(spacing: 6) {
                        Text(s.label.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .kerning(1.4)
                            .foregroundStyle(section == s ? .vSignal : .vLabelMute)
                            .padding(.vertical, 10)
                        Rectangle()
                            .fill(section == s ? Color.vSignal : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
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
                        ProgramRow(
                            index: i + 1,
                            program: p,
                            isActive: p.id == appState.activeProgramId
                        )
                    }
                    .buttonStyle(.pressable(scale: 0.99, haptic: .light))

                    if i < filtered.count - 1 {
                        Hairline().padding(.leading, 50)
                    }
                }
                Spacer(minLength: 60)
            }
            .padding(.top, 6)
        }
    }
}

private struct ProgramRow: View {
    let index: Int
    let program: Program
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            IndexBadge(n: index, active: isActive, size: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(program.name.uppercased())
                        .font(.system(size: 13, weight: .black))
                        .kerning(0.4)
                        .foregroundStyle(.vLabel)
                    if isActive {
                        Chip(text: "Active", color: .vSuccess, filled: true)
                    }
                }
                Text(program.subtitle.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.vLabelMute)
                HStack(spacing: 6) {
                    Chip(text: "\(program.daysPerWeek)D/WK", color: .vLabelMute)
                    Chip(text: program.level.label, color: .vLabelMute)
                }
                .padding(.top, 1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.vLabelFaint)
        }
        .padding(.horizontal, Theme.Space.md).padding(.vertical, 12)
        .background(Color.vBG)
    }
}

struct ProgramDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let program: Program

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero — flat
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        StatusDot(color: program.accent)
                        Text(program.level.label.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .kerning(1.2)
                            .foregroundStyle(.vLabelMute)
                    }
                    Text(program.name.uppercased())
                        .font(Theme.Font.display(36))
                        .foregroundStyle(.vLabel)
                        .kerning(-0.3)
                    Text(program.subtitle.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .kerning(1.0)
                        .foregroundStyle(.vLabelMute)
                    Text(program.description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.vLabelMute)
                        .padding(.top, 6)
                    HStack(spacing: 6) {
                        Chip(text: "\(program.daysPerWeek)D/WEEK", color: .vSignal)
                        Chip(text: program.level.label, color: .vSignal)
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Space.md)
                .background(Color.vSurface)

                Hairline()

                Button { setActive() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: appState.activeProgramId == program.id ? "checkmark" : "play.fill")
                            .font(.system(size: 13, weight: .black))
                        Text(appState.activeProgramId == program.id ? "ACTIVE PROGRAM" : "MAKE THIS MY PROGRAM")
                            .font(.system(size: 12, weight: .black))
                            .kerning(1.4)
                    }
                    .foregroundStyle(appState.activeProgramId == program.id ? Color.vBG : Color.vBG)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(appState.activeProgramId == program.id ? Color.vSuccess : Color.vSignal)
                }
                .buttonStyle(.pressable(scale: 0.98, haptic: .heavy))
                .padding(Theme.Space.md)
                .disabled(appState.activeProgramId == program.id)

                SectionLabel(title: "Schedule")

                VStack(spacing: 0) {
                    ForEach(Array(program.days.enumerated()), id: \.offset) { i, day in
                        DayRow(index: i + 1, day: day, accent: program.accent)
                        if i < program.days.count - 1 {
                            Hairline().padding(.leading, 50)
                        }
                    }
                }
                .background(Color.vSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .strokeBorder(Color.vLine, lineWidth: 0.5)
                )
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, 30)
            }
        }
        .background(Color.vBG.ignoresSafeArea())
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
            IndexBadge(n: index, active: !day.isRest, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(day.title.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .kerning(0.6)
                    .foregroundStyle(.vLabel)
                Text(day.focus)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.vLabelMute)
            }
            Spacer()
            if !day.isRest {
                Text("\(day.exerciseIds.count) EX")
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.vLabelMute)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
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
                        SectionLabel(title: "Custom Exercises")
                        VStack(spacing: 0) {
                            ForEach(Array(customFiltered.enumerated()), id: \.element.id) { i, c in
                                CustomExerciseRow(index: i + 1, exercise: c)
                                if i < customFiltered.count - 1 { Hairline().padding(.leading, 50) }
                            }
                        }
                        .background(Color.vSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .strokeBorder(Color.vLine, lineWidth: 0.5)
                        )
                        .padding(.horizontal, Theme.Space.md)
                    }

                    SectionLabel(title: "Standard Library")
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, ex in
                            NavigationLink {
                                ExerciseDetailView(exercise: ex)
                            } label: {
                                LibraryRow(index: i + 1, exercise: ex)
                            }
                            .buttonStyle(.plain)
                            if i < filtered.count - 1 { Hairline().padding(.leading, 50) }
                        }
                    }
                    .background(Color.vSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .strokeBorder(Color.vLine, lineWidth: 0.5)
                    )
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, 30)
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
                .font(.system(size: 10, weight: .black))
                .kerning(1.0)
                .foregroundStyle(selected ? Color.vBG : Color.vLabelMute)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(selected ? Color.vSignal : Color.vSurfaceHigh)
                .overlay(Rectangle().strokeBorder(selected ? Color.clear : Color.vLine, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

private struct LibraryRow: View {
    let index: Int
    let exercise: ExerciseDefinition

    var body: some View {
        HStack(spacing: 12) {
            IndexBadge(n: index, active: false, size: 22)
            Rectangle().fill(exercise.color).frame(width: 3, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .kerning(0.4)
                    .foregroundStyle(.vLabel)
                    .lineLimit(1)
                Text("\(exercise.muscleGroup.uppercased()) · \(exercise.equipment.uppercased())")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.vLabelMute)
            }
            Spacer()
            if exercise.isCompound { Chip(text: "Compound", color: .vSignal) }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.vLabelFaint)
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
    }
}

private struct CustomExerciseRow: View {
    let index: Int
    let exercise: CustomExercise

    var body: some View {
        HStack(spacing: 12) {
            IndexBadge(n: index, active: false, size: 22)
            Rectangle().fill(Color.vSignal).frame(width: 3, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .kerning(0.4)
                    .foregroundStyle(.vLabel)
                Text("\(exercise.muscleGroup.uppercased()) · \(exercise.equipment.uppercased())")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.vLabelMute)
            }
            Spacer()
            Chip(text: "Custom", color: .vSignal, filled: true)
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
    }
}

struct ExerciseDetailView: View {
    let exercise: ExerciseDefinition
    @Query(sort: \WorkoutSet.completedAt, order: .reverse) private var allSets: [WorkoutSet]
    @Environment(AppState.self) private var appState

    private var setsForThis: [WorkoutSet] {
        allSets.filter { $0.exerciseName == exercise.name }
    }
    private var bestE1RMKg: Double { setsForThis.compactMap(\.estimated1RMKg).max() ?? 0 }
    private var bestSet: WorkoutSet? {
        setsForThis.max { ($0.estimated1RMKg ?? 0) < ($1.estimated1RMKg ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        StatusDot(color: exercise.color)
                        Text(exercise.muscleGroup.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .kerning(1.2)
                            .foregroundStyle(.vLabelMute)
                    }
                    Text(exercise.name.uppercased())
                        .font(Theme.Font.display(34))
                        .foregroundStyle(.vLabel)
                        .kerning(-0.3)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 6) {
                        Chip(text: exercise.equipment, color: .vLabelMute)
                        if exercise.isCompound { Chip(text: "Compound", color: .vSignal) }
                    }
                    .padding(.top, 4)
                }
                .padding(Theme.Space.md)

                if !exercise.description.isEmpty {
                    Text(exercise.description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.vLabelMute)
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.bottom, Theme.Space.md)
                }

                if !exercise.secondaryMuscles.isEmpty {
                    HStack(spacing: 4) {
                        Text("ALSO HITS")
                            .font(.system(size: 9, weight: .heavy))
                            .kerning(1.2)
                            .foregroundStyle(.vLabelFaint)
                        ForEach(exercise.secondaryMuscles, id: \.self) { m in
                            Chip(text: m, color: .vLabelMute)
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, Theme.Space.md)
                }

                if !setsForThis.isEmpty {
                    SectionLabel(title: "Stats")
                    HStack(spacing: 8) {
                        StatTile(label: "Best Set", value: bestSetLabel, icon: "rosette")
                        StatTile(label: "Est 1RM", value: e1rmLabel, icon: "chart.line.uptrend.xyaxis")
                        StatTile(label: "Total Sets", value: "\(setsForThis.count)", icon: "list.number")
                    }
                    .padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Recent Sets")
                    VStack(spacing: 0) {
                        ForEach(Array(setsForThis.prefix(10).enumerated()), id: \.element.id) { i, s in
                            SetHistoryRow(index: i + 1, set: s, units: appState.units)
                            if i < min(setsForThis.count, 10) - 1 { Hairline().padding(.leading, 50) }
                        }
                    }
                    .background(Color.vSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .strokeBorder(Color.vLine, lineWidth: 0.5)
                    )
                    .padding(.horizontal, Theme.Space.md)
                } else {
                    EmptyStateCard(icon: "chart.line.uptrend.xyaxis",
                                   title: "No history yet",
                                   subtitle: "Log this exercise in a workout to start tracking.")
                }

                Spacer(minLength: 30)
            }
        }
        .background(Color.vBG.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bestSetLabel: String {
        guard let s = bestSet else { return "—" }
        let v = appState.units.from(kg: s.weightKg)
        return "\(v.prettyWeight)×\(s.reps)"
    }
    private var e1rmLabel: String {
        guard bestE1RMKg > 0 else { return "—" }
        let v = appState.units.from(kg: bestE1RMKg)
        return "\(v.prettyWeight)"
    }
}

private struct SetHistoryRow: View {
    let index: Int
    let set: WorkoutSet
    let units: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            IndexBadge(n: index, active: false, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(set.completedAt.shortDate.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.4)
                    .foregroundStyle(.vLabel)
                Text("SET \(set.setNumber)")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.vLabelMute)
            }
            Spacer()
            Text("\(units.from(kg: set.weightKg).prettyWeight) \(units.label.uppercased()) × \(set.reps)")
                .font(Theme.Font.mono(12, .black))
                .foregroundStyle(.vLabel)
            if let rpe = set.rpe { Chip(text: "RPE \(rpe.prettyWeight)", color: .vWarn) }
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
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
                    EmptyStateCard(
                        icon: "clock.arrow.circlepath",
                        title: "No workouts yet",
                        subtitle: "Your completed sessions will appear here."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { i, session in
                            NavigationLink {
                                SessionDetailView(session: session)
                            } label: {
                                SessionRow(index: i + 1, session: session, units: appState.units)
                            }
                            .buttonStyle(.plain)
                            if i < sessions.count - 1 { Hairline().padding(.leading, 50) }
                        }
                    }
                    .background(Color.vSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .strokeBorder(Color.vLine, lineWidth: 0.5)
                    )
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, Theme.Space.sm)
                }
                Spacer(minLength: 60)
            }
        }
    }
}

private struct SessionRow: View {
    let index: Int
    let session: WorkoutSession
    let units: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            IndexBadge(n: index, active: false, size: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.name.uppercased())
                        .font(.system(size: 12, weight: .black))
                        .kerning(0.4)
                        .foregroundStyle(.vLabel)
                    Spacer()
                    Text(session.date.shortDate.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(0.6)
                        .foregroundStyle(.vLabelMute)
                }
                HStack(spacing: 12) {
                    Label("\(session.sets.count) SETS", systemImage: "list.number")
                    Label("\(session.durationMinutes)M", systemImage: "clock")
                    let v = units.from(kg: session.totalVolumeKg)
                    Label(v >= 1000 ? String(format: "%.1fK %@", v/1000, units.label.uppercased())
                                    : String(format: "%.0f %@", v, units.label.uppercased()),
                          systemImage: "scalemass")
                }
                .font(.system(size: 9, weight: .heavy))
                .kerning(0.4)
                .foregroundStyle(.vLabelMute)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.vLabelFaint)
        }
        .padding(.horizontal, 10).padding(.vertical, 12)
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
                HStack(spacing: 8) {
                    StatTile(label: "Duration", value: "\(session.durationMinutes)m", icon: "clock")
                    StatTile(label: "Sets", value: "\(session.sets.count)", icon: "list.number")
                    StatTile(label: "Volume",
                             value: appState.units.from(kg: session.totalVolumeKg).prettyWeight,
                             icon: "scalemass")
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.sm)

                ForEach(Array(grouped.enumerated()), id: \.offset) { i, group in
                    SectionLabel(title: group.name)
                    VStack(spacing: 0) {
                        ForEach(Array(group.sets.enumerated()), id: \.element.id) { idx, s in
                            HStack {
                                Text("SET \(s.setNumber)")
                                    .font(.system(size: 10, weight: .heavy))
                                    .kerning(0.8)
                                    .foregroundStyle(.vLabelMute)
                                Spacer()
                                Text("\(appState.units.from(kg: s.weightKg).prettyWeight) \(appState.units.label.uppercased()) × \(s.reps)")
                                    .font(Theme.Font.mono(12, .black))
                                    .foregroundStyle(.vLabel)
                                if let rpe = s.rpe { Chip(text: "RPE \(rpe.prettyWeight)", color: .vWarn) }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            if idx < group.sets.count - 1 { Hairline().padding(.leading, 12) }
                        }
                    }
                    .background(Color.vSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .strokeBorder(Color.vLine, lineWidth: 0.5)
                    )
                    .padding(.horizontal, Theme.Space.md)
                }
                Spacer(minLength: 40)
            }
        }
        .background(Color.vBG.ignoresSafeArea())
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
            .scrollContentBackground(.hidden)
            .background(Color.vBG)
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
