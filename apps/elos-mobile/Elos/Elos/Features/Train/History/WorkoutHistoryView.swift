import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var sessions: [WorkoutSessionRecord] = []
    @State private var sessionExerciseNames: [String: [String]] = [:]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    // MARK: Summary stats

    private var totalVolumeKg: Double {
        sessions.reduce(0) { $0 + $1.totalVolume }
    }

    private var weeksActive: Int {
        guard let earliest = sessions.last?.startedAt else { return 0 }
        let weeks = Calendar.current.dateComponents([.weekOfYear], from: earliest, to: Date()).weekOfYear ?? 0
        return max(1, weeks)
    }

    var body: some View {
        NavigationView {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48)).foregroundStyle(.secondary)
                        Text("No Workouts Yet")
                            .font(.title3).fontWeight(.semibold)
                        Text("Your completed sessions will appear here.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(32)
                } else {
                    List {
                        // Summary stats header
                        Section {
                            HStack(spacing: 0) {
                                summaryCell(
                                    value: "\(sessions.count)",
                                    label: "Sessions"
                                )
                                Divider().frame(height: 32)
                                summaryCell(
                                    value: totalVolumeKg >= 1000
                                        ? String(format: "%.1fk", totalVolumeKg / 1000)
                                        : String(format: "%.0f", totalVolumeKg),
                                    label: "kg lifted"
                                )
                                Divider().frame(height: 32)
                                summaryCell(
                                    value: "\(weeksActive)",
                                    label: "Weeks"
                                )
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                        // Session rows
                        ForEach(sessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                SessionRow(
                                    session: session,
                                    formatter: dateFormatter,
                                    exerciseNames: sessionExerciseNames[session.id] ?? []
                                )
                            }
                        }
                        .onDelete { offsets in
                            for idx in offsets {
                                let session = sessions[idx]
                                let sessionID = session.id
                                let setsDesc = FetchDescriptor<ExerciseSetRecord>(
                                    predicate: #Predicate { $0.sessionID == sessionID }
                                )
                                if let orphanSets = try? modelContext.fetch(setsDesc) {
                                    for set in orphanSets { modelContext.delete(set) }
                                }
                                modelContext.delete(session)
                            }
                            sessions.remove(atOffsets: offsets)
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadSessions() }
        }
    }

    private func summaryCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
            Text(label)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadSessions() {
        let uid = vm.currentUserID
        var desc = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == uid }
        )
        desc.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]
        sessions = (try? modelContext.fetch(desc)) ?? []
        loadExerciseNames()
    }

    private func loadExerciseNames() {
        for session in sessions {
            let sessionID = session.id
            let setsDesc = FetchDescriptor<ExerciseSetRecord>(
                predicate: #Predicate { $0.sessionID == sessionID }
            )
            let sets = (try? modelContext.fetch(setsDesc)) ?? []
            var seen: [String] = []
            for s in sets where !seen.contains(s.exerciseName) {
                seen.append(s.exerciseName)
            }
            sessionExerciseNames[session.id] = seen
        }
    }
}

private struct SessionRow: View {
    let session: WorkoutSessionRecord
    let formatter: DateFormatter
    let exerciseNames: [String]

    private var durationText: String {
        guard let finished = session.finishedAt else { return "In progress" }
        let mins = Int(finished.timeIntervalSince(session.startedAt) / 60)
        return "\(mins) min"
    }

    private var exerciseSubtitle: String {
        let prefix = exerciseNames.prefix(3).joined(separator: " · ")
        if exerciseNames.count > 3 {
            return "\(prefix) +\(exerciseNames.count - 3)"
        }
        return prefix
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatter.string(from: session.startedAt))
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text(durationText)
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !exerciseSubtitle.isEmpty {
                Text(exerciseSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 12) {
                Label(String(format: "%.0f kg", session.totalVolume), systemImage: "scalemass")
                    .font(.caption).foregroundStyle(.secondary)
                if session.sessionRPE > 0 {
                    Label("RPE \(session.sessionRPE)", systemImage: "heart.text.square")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
