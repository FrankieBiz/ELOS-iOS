import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let session: WorkoutSessionRecord

    @State private var sets: [ExerciseSetRecord] = []

    private var durationText: String {
        guard let finished = session.finishedAt else { return "—" }
        let mins = Int(finished.timeIntervalSince(session.startedAt) / 60)
        return "\(mins) min"
    }

    private var grouped: [(exercise: String, sets: [ExerciseSetRecord])] {
        let dict = Dictionary(grouping: sets, by: { $0.exerciseName })
        return dict.sorted { $0.key < $1.key }
            .map { (exercise: $0.key, sets: $0.value.sorted { $0.setIndex < $1.setIndex }) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsCard
                ForEach(grouped, id: \.exercise) { group in
                    exerciseCard(group)
                }
            }
            .padding(16).padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadSets() }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(value: durationText, label: "Duration")
            Divider().frame(height: 40)
            statItem(value: String(format: "%.0f kg", session.totalVolume), label: "Volume")
            Divider().frame(height: 40)
            statItem(value: session.sessionRPE > 0 ? "\(session.sessionRPE)" : "—", label: "Session RPE")
        }
        .padding(16)
        .elosCard()
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseCard(_ group: (exercise: String, sets: [ExerciseSetRecord])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.exercise)
                .font(.subheadline).fontWeight(.semibold)
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            Divider()
            HStack {
                Text("#").frame(width: 24)
                Text("Weight (kg)").frame(maxWidth: .infinity)
                Text("Reps").frame(width: 50)
                Text("RPE").frame(width: 40)
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.vertical, 6)

            ForEach(group.sets) { s in
                HStack {
                    Text("\(s.setIndex + 1)").font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 24)
                    Text(String(format: "%.1f", s.weightKg)).font(.system(size: 14, design: .monospaced)).frame(maxWidth: .infinity)
                    Text("\(s.reps)").font(.system(size: 14, design: .monospaced)).frame(width: 50)
                    Text(s.rpe > 0 ? String(format: "%.1f", s.rpe) : "—")
                        .font(.caption.monospaced()).foregroundStyle(.secondary).frame(width: 40)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                Divider().padding(.leading, 14)
            }
        }
        .elosCard()
    }

    private func loadSets() {
        let sessionID = session.id
        let desc = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.setIndex)]
        )
        sets = (try? modelContext.fetch(desc)) ?? []
    }
}
