import SwiftUI
import Charts
import Combine

// MARK: - AnalyticsViewModel

@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var e1rmHistory: [E1RMPoint] = []
    @Published var volumeData:  [VolumePoint] = []
    @Published var prs:         [PREntry] = []
    @Published var selectedLift = "Barbell Bench Press"
    @Published var isLoading   = false
    @Published var loadError:   String?

    struct E1RMPoint: Identifiable {
        let id = UUID(); let day: String; let e1rm: Double
    }
    struct VolumePoint: Identifiable {
        let id = UUID(); let muscle: String; let week: String; let sets: Int
    }
    struct PREntry: Identifiable {
        let id = UUID(); let exerciseName: String; let weightKg: Double; let reps: Int; let e1rm: Double
    }

    func loadE1RM(liftName: String) {
        Task {
            isLoading = true; defer { isLoading = false }
            let encoded = liftName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? liftName
            do {
                let r: E1RMResponse = try await ApiClient.shared.get("/analytics/e1rm/\(encoded)")
                e1rmHistory = r.e1rm.map { E1RMPoint(day: $0.day, e1rm: $0.e1rm) }
                loadError = nil
            } catch { loadError = "Couldn't load e1RM history." }
        }
    }

    func loadVolume() {
        Task {
            do {
                let r: VolumeResponse = try await ApiClient.shared.get("/analytics/volume")
                volumeData = r.volume.map { VolumePoint(muscle: $0.muscle, week: $0.week, sets: $0.hard_sets) }
                loadError = nil
            } catch { loadError = "Couldn't load weekly volume." }
        }
    }

    func loadPRs() {
        Task {
            do {
                let r: PRResponse = try await ApiClient.shared.get("/analytics/prs")
                prs = r.prs.map { PREntry(exerciseName: $0.exercise_name, weightKg: $0.weight_kg, reps: $0.reps, e1rm: $0.e1rm) }
                loadError = nil
            } catch { loadError = "Couldn't load personal records." }
        }
    }
}

private struct E1RMResponse: Decodable {
    let e1rm: [P]; struct P: Decodable { let day: String; let e1rm: Double }
}
private struct VolumeResponse: Decodable {
    let volume: [P]; struct P: Decodable { let muscle: String; let week: String; let hard_sets: Int; let tonnage: Double }
}
private struct PRResponse: Decodable {
    let prs: [P]; struct P: Decodable { let exercise_name: String; let weight_kg: Double; let reps: Int; let e1rm: Double; let achieved_at: String }
}

// MARK: - AnalyticsView (chart sheet — used from TrainView)

struct AnalyticsView: View {
    @StateObject private var vm = AnalyticsViewModel()

    private let commonLifts = [
        "Barbell Back Squat", "Barbell Bench Press", "Conventional Deadlift",
        "Barbell Overhead Press", "Barbell Row",
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    liftPicker
                    e1rmCard
                    volumeCard
                    prCard
                    if let err = vm.loadError {
                        Text(err).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                vm.loadE1RM(liftName: vm.selectedLift)
                vm.loadVolume()
                vm.loadPRs()
            }
        }
    }

    // MARK: Lift Picker

    private var liftPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(commonLifts, id: \.self) { lift in
                    let sel = lift == vm.selectedLift
                    Button(lift.components(separatedBy: " ").last ?? lift) {
                        vm.selectedLift = lift; vm.loadE1RM(liftName: lift)
                    }
                    .font(.caption).fontWeight(sel ? .semibold : .regular)
                    .foregroundStyle(sel ? .white : Color.primary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(sel ? Color.tint : Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: e1RM Card

    private var e1rmCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated 1RM").font(.subheadline).fontWeight(.semibold)
                    Text(vm.selectedLift).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if vm.isLoading { ProgressView().scaleEffect(0.7) }
                if let last = vm.e1rmHistory.last {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f kg", last.e1rm))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                        Text("current").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if vm.e1rmHistory.count >= 2 {
                Chart(vm.e1rmHistory) { p in
                    LineMark(x: .value("Day", p.day), y: .value("e1RM", p.e1rm))
                        .foregroundStyle(Color.tint).interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Day", p.day), y: .value("e1RM", p.e1rm))
                        .foregroundStyle(Color.tint.opacity(0.12)).interpolationMethod(.catmullRom)
                }
                .frame(height: 160).chartXAxis(.hidden).chartYAxisLabel("kg")
            } else {
                Text("Log a few sessions to see your e1RM trend.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            }
        }
        .padding(16).elosCard()
    }

    // MARK: Volume Card

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Volume (Sets by Muscle)").font(.subheadline).fontWeight(.semibold)
            if vm.volumeData.isEmpty {
                Text("No completed sets in the last 8 weeks yet.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                let data = Dictionary(grouping: vm.volumeData.prefix(20), by: { $0.muscle })
                    .mapValues { $0.map(\.sets).reduce(0, +) }
                    .sorted { $0.value > $1.value }.prefix(8)
                Chart(data, id: \.key) { item in
                    BarMark(
                        x: .value("Sets", item.value),
                        y: .value("Muscle", item.key.capitalized.replacingOccurrences(of: "_", with: " "))
                    )
                    .foregroundStyle(Color.tint.gradient)
                    .annotation(position: .trailing) {
                        Text("\(item.value)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 200).chartXAxis(.hidden)
            }
        }
        .padding(16).elosCard()
    }

    // MARK: PR Board

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Personal Records").font(.subheadline).fontWeight(.semibold)
            if vm.prs.isEmpty {
                Text("Log a few working sets to build your PR board.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                ForEach(vm.prs.prefix(8)) { pr in
                    HStack {
                        Text(pr.exerciseName).font(.subheadline).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.1f kg", pr.weightKg)).font(.system(size: 15, weight: .bold, design: .monospaced))
                        Text("×\(pr.reps)").font(.caption).foregroundStyle(.secondary).frame(width: 30)
                        Text(String(format: "e1RM %.0f", pr.e1rm)).font(.caption2).foregroundStyle(Color.good)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.good.opacity(0.12)).clipShape(Capsule())
                    }
                    if pr.id != vm.prs.prefix(8).last?.id { Divider() }
                }
            }
        }
        .padding(16).elosCard()
    }
}
