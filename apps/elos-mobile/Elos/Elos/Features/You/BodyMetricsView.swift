import SwiftUI
import SwiftData

struct BodyMetricsView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfileRecord]

    private var profile: UserProfileRecord? {
        profiles.first { $0.ownerID == vm.currentUserID }
    }

    private var weightKg: Double { profile?.weightKg ?? 0 }
    private var heightCm: Double { profile?.heightCm ?? 0 }
    private var ageYears: Int    { profile?.ageYears ?? 0 }

    private var bmi: Double? {
        guard weightKg > 0, heightCm > 0 else { return nil }
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    private var bmiCategory: (label: String, color: Color) {
        guard let b = bmi else { return ("—", .secondary) }
        switch b {
        case ..<18.5: return ("Underweight", .mNutri)
        case 18.5..<25: return ("Healthy", .mGym)
        case 25..<30: return ("Overweight", .mHabits)
        default:      return ("Obese", .bad)
        }
    }

    private var avgSleep: Double? {
        guard !vm.sleepLog.isEmpty else { return nil }
        let r = vm.sleepLog.prefix(14)
        return r.map(\.duration).reduce(0, +) / Double(r.count)
    }

    private var sleepQualityAvg: Double? {
        guard !vm.sleepLog.isEmpty else { return nil }
        let r = vm.sleepLog.prefix(14)
        return Double(r.map(\.quality).reduce(0, +)) / Double(r.count)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    biometricsCard
                    trainingCard
                    sleepCard
                    nutritionCard
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Body Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Biometrics

    private var biometricsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Biometrics", systemImage: "figure.stand")
                .font(.subheadline).fontWeight(.bold)

            Divider()

            HStack(spacing: 0) {
                metricBlock(
                    value: weightKg > 0 ? String(format: "%.1f", weightKg) : "—",
                    unit: "kg",
                    label: "Weight"
                )
                Divider().frame(height: 52)
                metricBlock(
                    value: heightCm > 0 ? "\(Int(heightCm))" : "—",
                    unit: "cm",
                    label: "Height"
                )
                Divider().frame(height: 52)
                metricBlock(
                    value: ageYears > 0 ? "\(ageYears)" : "—",
                    unit: "yr",
                    label: "Age"
                )
            }

            if let b = bmi {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BMI")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(String(format: "%.1f", b))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                    }
                    Spacer()
                    Text(bmiCategory.label)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(bmiCategory.color)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(bmiCategory.color.opacity(0.12))
                        .clipShape(Capsule())
                }

                GeometryReader { geo in
                    let w = geo.size.width
                    let pct = min(max((b - 15) / (40 - 15), 0), 1)
                    ZStack(alignment: .leading) {
                        LinearGradient(
                            colors: [.mNutri, .mGym, .mHabits, .bad],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(height: 8)
                        .clipShape(Capsule())

                        Circle()
                            .fill(Color.white)
                            .shadow(radius: 2)
                            .frame(width: 14, height: 14)
                            .offset(x: w * pct - 7)
                    }
                }
                .frame(height: 14)
            }
        }
        .padding(16)
        .elosCard()
    }

    private func metricBlock(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                Text(unit)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Training Profile

    private var trainingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Training Profile", systemImage: "dumbbell")
                .font(.subheadline).fontWeight(.bold)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Experience")
                        .font(.caption).foregroundStyle(.secondary)
                    Text((profile?.trainingExperience ?? "—").capitalized)
                        .font(.subheadline).fontWeight(.semibold)
                }
                Spacer()
                experienceDots
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Goal")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(goalLabel(profile?.trainingGoal ?? ""))
                        .font(.subheadline).fontWeight(.semibold)
                }
                Spacer()
                Image(systemName: goalIcon(profile?.trainingGoal ?? ""))
                    .font(.title2)
                    .foregroundStyle(Color.mGym)
            }
        }
        .padding(16)
        .elosCard()
    }

    private var experienceDots: some View {
        let level = experienceLevel(profile?.trainingExperience ?? "")
        return HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i < level ? Color.mGym : Color.secondary.opacity(0.2))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private func experienceLevel(_ exp: String) -> Int {
        switch exp.lowercased() {
        case "beginner": return 1
        case "intermediate": return 2
        case "advanced": return 3
        default: return 1
        }
    }

    private func goalLabel(_ goal: String) -> String {
        switch goal.lowercased() {
        case "strength":     return "Strength"
        case "hypertrophy":  return "Muscle Growth"
        case "endurance":    return "Endurance"
        case "weight_loss", "weight loss": return "Fat Loss"
        default:             return goal.capitalized
        }
    }

    private func goalIcon(_ goal: String) -> String {
        switch goal.lowercased() {
        case "strength":     return "bolt.fill"
        case "hypertrophy":  return "flame.fill"
        case "endurance":    return "figure.run"
        default:             return "target"
        }
    }

    // MARK: - Sleep Insights

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sleep Insights", systemImage: "moon.stars.fill")
                .font(.subheadline).fontWeight(.bold)

            Divider()

            if vm.sleepLog.isEmpty {
                Text("Log sleep entries to see insights here.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 0) {
                    metricBlock(
                        value: avgSleep.map { String(format: "%.1f", $0) } ?? "—",
                        unit: "h",
                        label: "Avg Duration"
                    )
                    Divider().frame(height: 52)
                    metricBlock(
                        value: sleepQualityAvg.map { String(format: "%.1f", $0) } ?? "—",
                        unit: "/5",
                        label: "Avg Quality"
                    )
                    Divider().frame(height: 52)
                    metricBlock(
                        value: "\(vm.sleepLog.count)",
                        unit: "",
                        label: "Entries"
                    )
                }

                if let last = vm.sleepLog.first {
                    Divider()
                    HStack {
                        Text("Last night")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(last.bed) → \(last.wake)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                        Text(String(format: "%.1fh", last.duration))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.mHealth)
                    }
                }
            }
        }
        .padding(16)
        .elosCard()
    }

    // MARK: - Nutrition Goals

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Nutrition Goals", systemImage: "fork.knife")
                .font(.subheadline).fontWeight(.bold)

            Divider()

            HStack(spacing: 0) {
                metricBlock(value: profile.map { "\($0.calGoal)" } ?? "—", unit: "kcal", label: "Calories")
                Divider().frame(height: 52)
                metricBlock(value: profile.map { "\($0.proteinGoal)g" } ?? "—", unit: "", label: "Protein")
                Divider().frame(height: 52)
                metricBlock(value: profile.map { "\($0.carbGoal)g" } ?? "—", unit: "", label: "Carbs")
                Divider().frame(height: 52)
                metricBlock(value: profile.map { "\($0.fatGoal)g" } ?? "—", unit: "", label: "Fat")
            }
        }
        .padding(16)
        .elosCard()
    }
}
