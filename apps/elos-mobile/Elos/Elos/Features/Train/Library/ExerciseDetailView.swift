import SwiftUI
import SwiftData
import Combine
import Charts

struct ExerciseDetailView: View {
    @EnvironmentObject var vm: AppViewModel
    @StateObject private var detailVM = ExerciseDetailViewModel()

    let exercise: ExerciseDefinitionRecord

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                infoCard
                if !detailVM.e1rmHistory.isEmpty { e1rmChart }
            }
            .padding(16)
            .padding(.bottom, 60)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .task { await detailVM.loadE1RMHistory(exerciseName: exercise.name) }
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

            Chart(detailVM.e1rmHistory, id: \.day) { point in
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

}

// MARK: - ViewModel

@MainActor
final class ExerciseDetailViewModel: ObservableObject {
    @Published var e1rmHistory: [(day: String, e1rm: Double)] = []
    @Published var isLoading = false

    private struct E1RMResponse: Decodable { let e1rm: [E1RMPoint] }
    private struct E1RMPoint: Decodable { let day: String; let e1rm: Double }

    func loadE1RMHistory(exerciseName name: String) async {
        isLoading = true
        defer { isLoading = false }
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        if let response = try? await ApiClient.shared.get("/analytics/e1rm/\(encoded)") as E1RMResponse {
            e1rmHistory = response.e1rm.map { (day: $0.day, e1rm: $0.e1rm) }
        }
    }
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
