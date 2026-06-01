import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    @EnvironmentObject var vm: AppViewModel

    let exercise: ExerciseDefinitionRecord

    @State private var e1rmHistory: [(day: String, e1rm: Double)] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                infoCard
                if !e1rmHistory.isEmpty { e1rmChart }
            }
            .padding(16)
            .padding(.bottom, 60)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear { loadE1RMHistory() }
    }

    // MARK: Info Card
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            InfoRow(label: "Primary muscle", value: exercise.primaryMuscle.capitalized)
            if !exercise.secondaryMuscles.isEmpty {
                InfoRow(label: "Secondary", value: exercise.secondaryMuscles.map { $0.capitalized }.joined(separator: ", "))
            }
            if !exercise.equipment.isEmpty {
                InfoRow(label: "Equipment", value: exercise.equipment.capitalized)
            }
            if !exercise.movementPattern.isEmpty {
                InfoRow(label: "Pattern", value: exercise.movementPattern.capitalized)
            }
        }
        .padding(16)
        .elosCard()
    }

    // MARK: e1RM Chart
    private var e1rmChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Estimated 1RM Trend")
                .font(.subheadline).fontWeight(.semibold)

            Chart(e1rmHistory, id: \.day) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("e1RM (kg)", point.e1rm)
                )
                .foregroundStyle(Color.tint)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", point.day),
                    y: .value("e1RM (kg)", point.e1rm)
                )
                .foregroundStyle(Color.tint)
            }
            .frame(height: 160)
            .chartYAxisLabel("kg")
        }
        .padding(16)
        .elosCard()
    }

    private func loadE1RMHistory() {
        let name = exercise.name
        Task {
            isLoading = true
            defer { isLoading = false }
            if let response = try? await ApiClient.shared.get("/analytics/e1rm/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)") as E1RMResponse {
                await MainActor.run {
                    e1rmHistory = response.e1rm.map { (day: $0.day, e1rm: $0.e1rm) }
                }
            }
        }
    }
}

private struct E1RMResponse: Decodable {
    let e1rm: [E1RMPoint]
}
private struct E1RMPoint: Decodable {
    let day: String
    let e1rm: Double
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline).fontWeight(.semibold)
        }
    }
}
