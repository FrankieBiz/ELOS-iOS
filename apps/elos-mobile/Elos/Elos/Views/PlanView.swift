import SwiftUI
import SwiftData

// MARK: - Enums

private enum PlanSegmentExtended: String, CaseIterable {
    case schedule   = "Schedule"
    case assignments = "Assignments"
    case exams      = "Exams"
    case courses    = "Courses"
}

// MARK: - Main View

struct PlanView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var segment: PlanSegmentExtended = .schedule
    @State private var assignFilter: AssignFilter = .all
    @State private var selectedDayOffset = 0
    @State private var showingAddAssignment = false

    private var selectedDate: Date {
        Calendar.current.date(byAdding: .day, value: selectedDayOffset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: Space.xl) {
                    ElosSegmentedControl(
                        tabs: PlanSegmentExtended.allCases,
                        label: \.rawValue,
                        selection: $segment
                    )

                    switch segment {
                    case .schedule:    scheduleTab
                    case .assignments: assignmentsTab
                    case .exams:       examsTab
                    case .courses:     coursesTab
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.m)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Schedule Tab

    private var scheduleTab: some View {
        VStack(spacing: Space.l) {
            dayPicker
            scheduleTimeline
            loadSummaryCard
            thisWeekCard
        }
    }

    /// A rest day's timeline is legitimately short — one line, one card — which used to leave the
    /// rest of the tab a bare black void below it. Real, already-available data instead of padding:
    /// how much training and schoolwork actually lands this week, glanceable without switching tabs.
    private var thisWeekCard: some View {
        let workoutDays = vm.weekLoadMap(daysAhead: 7).filter { $0.loadType == "gym" }.count
        let dueThisWeek = vm.assignments.filter { assign -> Bool in
            guard !assign.done else { return false }
            let daysUntil = Formatters.daysFromToday(toISODay: assign.due)
            return daysUntil >= 0 && daysUntil <= 6
        }.count
        let nextExam = vm.exams.filter { $0.daysAway >= 0 && $0.daysAway <= 7 }
            .min(by: { $0.daysAway < $1.daysAway })

        return VStack(alignment: .leading, spacing: 0) {
            Text("This Week").elosSectionLabel()
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.l)
                .padding(.bottom, Space.m)

            Divider()

            weekStatRow(icon: "dumbbell.fill", tint: .good,
                        text: workoutDays == 0 ? "No workouts scheduled" : "\(workoutDays) workout\(workoutDays == 1 ? "" : "s") scheduled")
            Divider().padding(.leading, 44)

            weekStatRow(icon: "doc.text.fill", tint: .tint,
                        text: dueThisWeek == 0 ? "Nothing due" : "\(dueThisWeek) assignment\(dueThisWeek == 1 ? "" : "s") due")

            if let exam = nextExam {
                Divider().padding(.leading, 44)
                weekStatRow(icon: "exclamationmark.triangle.fill", tint: .warn,
                            text: "\(exam.title) in \(exam.daysAway) day\(exam.daysAway == 1 ? "" : "s")")
            }
        }
        .elosCard()
    }

    private func weekStatRow(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.vertical, 12)
    }

    private var dayPicker: some View {
        // `weekLoadMap` is one call per day inside the loop otherwise — hoisted so the strip
        // computes the week once instead of seven times.
        let loadMap = vm.weekLoadMap(daysAhead: 7)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(0..<7, id: \.self) { offset in
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
                    let comps = Calendar.current.dateComponents([.weekday, .day], from: date)
                    let letters = ["S", "M", "T", "W", "T", "F", "S"]
                    let letter = letters[(comps.weekday ?? 1) - 1]
                    let number = comps.day ?? 0
                    let loadType = loadMap[safe: offset]?.loadType ?? "rest"
                    let isSelected = selectedDayOffset == offset

                    Button {
                        withAnimation(.elosStandard) { selectedDayOffset = offset }
                    } label: {
                        VStack(spacing: 3) {
                            Text(letter)
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                            Text("\(number)")
                                .font(.elosNumeric(.callout, weight: .bold))
                            // On the selected day the dot sat grey-on-orange and read as a
                            // rendering artefact; white keeps the load cue visible there.
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.9) : dotColor(for: loadType))
                                .frame(width: 5, height: 5)
                        }
                        .frame(minWidth: 40)
                        .padding(.horizontal, Space.m).padding(.vertical, Space.s)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background {
                            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                .fill(isSelected ? Color.tint : Color(.secondarySystemGroupedBackground))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month().day()))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, Space.gutter)
        }
        .padding(.horizontal, -Space.gutter)
        .scrollClipDisabled()
    }

    private var scheduleTimeline: some View {
        let rows = vm.buildScheduleRows(for: selectedDate)
        return Group {
            if rows.isEmpty {
                VStack(spacing: Space.s) {
                    Image(systemName: "calendar")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("Nothing scheduled")
                        .font(.elosHeadline).foregroundStyle(.secondary)
                    Text("Set an active split or sync Canvas to see your schedule.")
                        .font(.elosCaption).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32).padding(.horizontal, Space.xxl)
                .elosCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        HStack(spacing: 12) {
                            Text(row.time == "—" ? "  —  " : row.time)
                                .font(.elosNumeric(.caption, weight: .regular))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            ModuleBarView(color: moduleColor(for: row.moduleType), opacity: row.isDone ? 0.5 : 1)
                            Text(row.title)
                                .font(.subheadline)
                                .strikethrough(row.isDone)
                                .foregroundStyle(row.isDone ? Color.secondary : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if row.durationMinutes > 0 {
                                Text("\(row.durationMinutes)m")
                                    .font(.elosNumeric(.caption, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        if i < rows.count - 1 { Divider().padding(.leading, 60) }
                    }
                }
                .elosCard()
            }
        }
    }

    private var loadSummaryCard: some View {
        let loadType = vm.weekLoadMap(daysAhead: 7)[safe: selectedDayOffset]?.loadType ?? "rest"
        let hasExam = vm.exams.contains { examDateString($0) == dayString(selectedDate) }
        let gymDay  = vm.gymDay(for: selectedDate)

        let detail: String = {
            if hasExam {
                if vm.isOrdinalRotationSplit {
                    // This is the one scheduling path that actually holds the rotation index back,
                    // so the workout genuinely lands on a later date instead of being dropped.
                    return "Gym shifted — exam detected. Split advances to next available day."
                }
                if let sd = vm.scheduledGymDayIgnoringExam(for: selectedDate), !sd.isRest {
                    // Fixed-weekday splits have no "next available day" to push into — be honest
                    // that the day is cleared rather than claiming a reschedule that isn't happening.
                    let name = sd.dayName.isEmpty ? "Training" : sd.dayName
                    return "Exam today — \(name) is cleared. No makeup needed."
                }
                return "Exam today."
            } else if let gd = gymDay, !gd.isRest {
                let name = gd.dayName.isEmpty ? "Workout" : gd.dayName
                let variantSuffix = DayVariants.activeVariantName(for: gd).map { " (\($0))" } ?? ""
                return "Training day: \(name)\(variantSuffix). Tap Start in the Train tab when ready."
            } else if vm.activeSplit == nil {
                return "No active split. Set one in Programs to see dynamic gym scheduling."
            } else {
                return "Rest or recovery day."
            }
        }()

        // "Load: Rest" as one run-on subheadline buried the value in the label. Splitting the
        // label off as a section header lets the load itself carry the weight and colour.
        return HStack(alignment: .top, spacing: Space.m) {
            Circle()
                .fill(dotColor(for: loadType).opacity(0.15))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: hasExam ? "exclamationmark.triangle.fill" : "gauge.medium")
                        .font(.elosCaption)
                        .foregroundStyle(dotColor(for: loadType))
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("Load").elosSectionLabel()
                Text(loadLabel(loadType))
                    .font(.elosHeadline)
                    .foregroundStyle(dotColor(for: loadType))
                Text(detail)
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.gutter)
        .elosCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Assignments Tab

    private var assignmentsTab: some View {
        VStack(spacing: Space.l) {
            HStack(spacing: Space.s) {
                ForEach(AssignFilter.allCases, id: \.self) { f in
                    let isSelected = assignFilter == f
                    Button {
                        withAnimation(.elosQuick) { assignFilter = f }
                    } label: {
                        Text(f.rawValue)
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .padding(.horizontal, Space.l).padding(.vertical, 7)
                            .background {
                                Capsule().fill(isSelected ? Color.tint : Color(.secondarySystemGroupedBackground))
                            }
                            .overlay {
                                Capsule().strokeBorder(
                                    isSelected ? .clear : Color.primary.opacity(0.07), lineWidth: 1
                                )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                Spacer()
            }

            let filtered = filteredAssignments
            if filtered.isEmpty {
                VStack(spacing: Space.s) {
                    Image(systemName: assignFilter == .done ? "tray" : "checkmark.circle")
                        .font(.title).foregroundStyle(.tertiary)
                    Text(assignFilter == .done ? "No completed assignments" : "All caught up")
                        .font(.elosHeadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 32)
                .elosCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { i, a in
                        PlanAssignmentRow(assign: a) { vm.toggleAssignment(id: a.id) }
                        if i < filtered.count - 1 { Divider().padding(.leading, 44) }
                    }
                }
                .elosCard()
            }

            Button { showingAddAssignment = true } label: {
                Label("Add assignment", systemImage: "plus")
                    .font(.system(.subheadline, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(ElosSecondaryButtonStyle())
                .sheet(isPresented: $showingAddAssignment) {
                    AddAssignmentSheet { name, subject, due in
                        vm.addAssignment(name: name, subject: subject, due: due)
                    }
                }
        }
    }

    private var filteredAssignments: [Assignment] {
        switch assignFilter {
        case .all:     return vm.assignments
        case .pending: return vm.assignments.filter { !$0.done }
        case .done:    return vm.assignments.filter { $0.done }
        }
    }

    // MARK: - Exams Tab

    private var examsTab: some View {
        VStack(spacing: Space.m) {
            if vm.exams.isEmpty {
                VStack(spacing: Space.s) {
                    Image(systemName: "graduationcap")
                        .font(.title).foregroundStyle(.tertiary)
                    Text("No upcoming exams")
                        .font(.elosHeadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 32)
                .elosCard()
            } else {
                ForEach(vm.exams) { exam in ExamCard(exam: exam) }
            }
        }
    }

    // MARK: - Courses Tab

    private var coursesTab: some View {
        CoursesTabView()
            .environmentObject(vm)
    }

    // MARK: - Helpers

    private func moduleColor(for type: String) -> Color {
        switch type {
        case "gym":        return .mGym
        case "exam":       return .mExams
        case "assignment": return .mAssign
        case "class":      return .mSched
        case "meal":       return .mNutri
        case "sleep":      return .mHealth
        default:           return .secondary
        }
    }

    private func dotColor(for loadType: String) -> Color {
        switch loadType {
        case "gym":  return .mGym
        case "exam": return .mExams
        case "skip": return .secondary
        default:     return .secondary
        }
    }

    private func loadLabel(_ loadType: String) -> String {
        switch loadType {
        case "gym":  return "Training"
        case "exam": return "Exam Day"
        case "skip": return "Skipped"
        default:     return "Rest"
        }
    }

    private func dayString(_ date: Date) -> String {
        Formatters.isoDay.string(from: date)
    }

    private func examDateString(_ exam: Exam) -> String { exam.date }
}

// MARK: - Courses Tab View

private struct CoursesTabView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var allCourses: [CourseRecord]

    private var ownerCourses: [CourseRecord] {
        allCourses.filter { $0.ownerID == vm.currentUserID }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 12) {
            if ownerCourses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical").font(.title).foregroundStyle(.secondary)
                    Text("No courses synced yet")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
                    Text("Sync Canvas in Settings to import your courses and schedule.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(40)
            } else {
                Text("SET COURSE DIFFICULTY")
                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Harder courses push your gym day back further when exams overlap.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    ForEach(Array(ownerCourses.enumerated()), id: \.element.id) { i, course in
                        CourseRow(course: course)
                        if i < ownerCourses.count - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .elosCard()
            }
        }
    }
}

private struct CourseRow: View {
    @Environment(\.modelContext) private var modelContext
    let course: CourseRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                Text(difficultyLabel(course.difficulty))
                    .font(.caption)
                    .foregroundStyle(difficultyColor(course.difficulty))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: Binding(
                get: { course.difficulty },
                set: { val in
                    course.difficulty = val
                    try? modelContext.save()
                }
            )) {
                Text("Easy").tag(0)
                Text("Normal").tag(1)
                Text("Hard").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func difficultyLabel(_ d: Int) -> String {
        switch d { case 0: return "Easy — won't shift gym"; case 2: return "Hard — shifts gym 2 days"; default: return "Normal — shifts gym 1 day" }
    }

    private func difficultyColor(_ d: Int) -> Color {
        switch d { case 0: return .good; case 2: return .bad; default: return .warn }
    }
}

// MARK: - Plan Assignment Row

private struct PlanAssignmentRow: View {
    let assign: Assignment
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(assign.done ? Color.good : Color.secondary.opacity(0.3), lineWidth: 1.5).frame(width: 24, height: 24)
                    if assign.done {
                        Circle().fill(Color.good).frame(width: 24, height: 24)
                        Image(systemName: "checkmark").font(.system(.caption2, weight: .bold)).foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(assign.name)
                        .font(.subheadline)
                        .strikethrough(assign.done)
                        .foregroundStyle(assign.done ? .secondary : .primary)
                    Text("\(assign.subject) · \(DateDisplay.friendly(assign.due))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if assign.urgent && !assign.done {
                    ChipView(label: "Due soon", foreground: .mExams, background: .mExams.opacity(0.15))
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exam Card

private struct ExamCard: View {
    /// The days-away number is the card's hero. `.largeTitle` is 34pt, which visibly shrank it from the
    /// authored 42 — pin the size and scale it instead, so Dynamic Type works without redesigning the card.
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 42

    let exam: Exam

    private var urgencyColor: Color {
        exam.daysAway <= 2 ? .bad : exam.daysAway <= 5 ? .warn : .good
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exam.subject).font(.caption).foregroundStyle(.secondary)
                Text(exam.title).font(.system(.callout, weight: .semibold))
                Text(DateDisplay.friendly(exam.date)).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                Text("\(exam.daysAway)")
                    .font(.system(size: countdownSize, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(urgencyColor)
                Text("days").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .elosCard()
    }
}

// MARK: - Add Assignment Sheet

private struct AddAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, String, String) -> Void

    @State private var name = ""
    @State private var subject = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignment") {
                    TextField("Name (e.g. Essay draft)", text: $name)
                    TextField("Subject (e.g. AP English)", text: $subject)
                    // A date picker can't produce a mistyped date that silently never shows on the schedule.
                    Toggle("Set a due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.isEmpty else { return }
                        let due = hasDueDate ? Formatters.isoDay.string(from: dueDate) : "—"
                        onAdd(name, subject.isEmpty ? "General" : subject, due)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Collection safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
