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
        NavigationView {
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    Picker("", selection: $segment) {
                        ForEach(PlanSegmentExtended.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch segment {
                    case .schedule:    scheduleTab
                    case .assignments: assignmentsTab
                    case .exams:       examsTab
                    case .courses:     coursesTab
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Schedule Tab

    private var scheduleTab: some View {
        VStack(spacing: 16) {
            dayPicker
            scheduleTimeline
            loadSummaryCard
        }
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { offset in
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
                    let comps = Calendar.current.dateComponents([.weekday, .day], from: date)
                    let letters = ["S", "M", "T", "W", "T", "F", "S"]
                    let letter = letters[(comps.weekday ?? 1) - 1]
                    let number = comps.day ?? 0
                    let loadType = vm.weekLoadMap(daysAhead: 7)[safe: offset]?.loadType ?? "rest"
                    let dotColor = dotColor(for: loadType)

                    Button {
                        withAnimation { selectedDayOffset = offset }
                    } label: {
                        VStack(spacing: 2) {
                            Text(letter).font(.system(size: 10))
                            Text("\(number)").font(.system(size: 15, weight: .bold))
                            Circle().fill(dotColor).frame(width: 5, height: 5)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(selectedDayOffset == offset ? Color.white : Color.primary)
                        .background(selectedDayOffset == offset ? Color.tint : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scheduleTimeline: some View {
        let rows = vm.buildScheduleRows(for: selectedDate)
        return Group {
            if rows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar").font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("Nothing scheduled")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Set an active split or sync Canvas to see your schedule.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .elosCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        HStack(spacing: 12) {
                            Text(row.time == "—" ? "  —  " : row.time)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
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
                                    .font(.system(size: 11, design: .monospaced))
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

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Load: \(loadLabel(loadType))").font(.subheadline).fontWeight(.semibold)
                Spacer()
            }
            if hasExam {
                Text("Gym shifted — exam detected. Split advances to next available day.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let gd = gymDay, !gd.isRest {
                Text("Training day: \(gd.dayName.isEmpty ? "Workout" : gd.dayName). Tap Start in the Train tab when ready.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if vm.activeSplit == nil {
                Text("No active split. Set one in Programs to see dynamic gym scheduling.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Rest or recovery day.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .elosCard()
    }

    // MARK: - Assignments Tab

    private var assignmentsTab: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(AssignFilter.allCases, id: \.self) { f in
                    Button { assignFilter = f } label: {
                        Text(f.rawValue)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(assignFilter == f ? .white : .primary)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(assignFilter == f ? Color.tint : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            let filtered = filteredAssignments
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Text(assignFilter == .done ? "No completed assignments." : "All caught up!")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { i, a in
                        PlanAssignmentRow(assign: a) { vm.toggleAssignment(id: a.id) }
                        if i < filtered.count - 1 { Divider().padding(.leading, 44) }
                    }
                }
                .elosCard()
            }

            Button("+ Add assignment") { showingAddAssignment = true }
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
        VStack(spacing: 12) {
            if vm.exams.isEmpty {
                Text("No upcoming exams")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(40)
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
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
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
                    Image(systemName: "books.vertical").font(.system(size: 32)).foregroundStyle(.secondary)
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
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(assign.name)
                        .font(.subheadline)
                        .strikethrough(assign.done)
                        .foregroundStyle(assign.done ? .secondary : .primary)
                    Text("\(assign.subject) · \(assign.due)")
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
    let exam: Exam

    private var urgencyColor: Color {
        exam.daysAway <= 2 ? .bad : exam.daysAway <= 5 ? .warn : .good
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exam.subject).font(.caption).foregroundStyle(.secondary)
                Text(exam.title).font(.system(size: 17, weight: .semibold))
                Text(exam.date).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                Text("\(exam.daysAway)")
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
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
    @State private var due = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Assignment") {
                    TextField("Name (e.g. Essay draft)", text: $name)
                    TextField("Subject (e.g. AP English)", text: $subject)
                    TextField("Due (e.g. 2026-05-20)", text: $due)
                }
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.isEmpty else { return }
                        onAdd(name, subject.isEmpty ? "General" : subject, due.isEmpty ? "—" : due)
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
