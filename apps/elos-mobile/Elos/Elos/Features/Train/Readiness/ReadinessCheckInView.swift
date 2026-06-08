import SwiftUI
import SwiftData
import Combine

struct ReadinessCheckInView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var checkInVM = ReadinessCheckInViewModel()

    @State private var sleepQuality: Double = 3
    @State private var soreness: Double     = 3
    @State private var stress: Double       = 3
    @State private var motivation: Double   = 3

    let onDismiss: () -> Void
    var onComplete: ((ReadinessCheckInRecord) -> Void)? = nil

    private var overallScore: Double {
        (sleepQuality + soreness + stress + motivation) / 4.0
    }

    private var scoreColor: Color {
        overallScore >= 4.0 ? .good : overallScore >= 2.5 ? .warn : .bad
    }

    private var scoreEmoji: String {
        overallScore >= 4.0 ? "🟢" : overallScore >= 2.5 ? "🟡" : "🔴"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("Morning Check-In")
                    .font(.title2).fontWeight(.bold)
                Text("How are you feeling today?")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 12)

            // Score
            Text("\(scoreEmoji) \(String(format: "%.1f", overallScore))/5")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(scoreColor)

            // Sliders
            VStack(spacing: 16) {
                ReadinessSlider(label: "Sleep Quality", emoji: "😴",
                                value: $sleepQuality, lowLabel: "Poor", highLabel: "Great")
                ReadinessSlider(label: "Soreness", emoji: "💪",
                                value: $soreness, lowLabel: "Very sore", highLabel: "Fresh")
                ReadinessSlider(label: "Stress", emoji: "🧠",
                                value: $stress, lowLabel: "High stress", highLabel: "Calm")
                ReadinessSlider(label: "Motivation", emoji: "🔥",
                                value: $motivation, lowLabel: "Low", highLabel: "Pumped")
            }
            .padding(.horizontal, 20)

            // Save button
            Button {
                save()
            } label: {
                Group {
                    if checkInVM.saved {
                        Label("Saved!", systemImage: "checkmark.circle.fill")
                    } else if checkInVM.isSaving {
                        ProgressView()
                    } else {
                        Text("Log Check-In")
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(checkInVM.saved ? Color.good : Color.tint)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(checkInVM.isSaving || checkInVM.saved)
            .padding(.horizontal, 20)

            Spacer()
        }
        .presentationDetents([.fraction(0.65)])
    }

    private func save() {
        Task {
            let record = await checkInVM.save(
                ownerID: vm.currentUserID,
                sleepQuality: Int(sleepQuality),
                soreness: Int(soreness),
                stress: Int(stress),
                motivation: Int(motivation),
                context: modelContext
            )
            onComplete?(record)
            try? await Task.sleep(nanoseconds: 800_000_000)
            onDismiss()
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ReadinessCheckInViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var saved    = false

    private struct ReadinessBody: Encodable {
        let log_date: String
        let sleep_quality: Int
        let soreness: Int
        let stress: Int
        let motivation: Int
    }
    private struct ReadinessResponse: Decodable { let id: String }

    func save(ownerID: String, sleepQuality: Int, soreness: Int, stress: Int, motivation: Int,
              context: ModelContext) async -> ReadinessCheckInRecord {
        isSaving = true
        let dateStr = Formatters.isoDay.string(from: Date())

        let record = ReadinessCheckInRecord(
            ownerID: ownerID, logDate: dateStr,
            sleepQuality: sleepQuality, soreness: soreness,
            stress: stress, motivation: motivation
        )
        context.insert(record)
        try? context.save()

        let body = ReadinessBody(
            log_date: dateStr, sleep_quality: sleepQuality,
            soreness: soreness, stress: stress, motivation: motivation
        )
        _ = try? await ApiClient.shared.post("/readiness", body: body) as ReadinessResponse

        isSaving = false
        withAnimation { saved = true }
        return record
    }
}

// MARK: - Readiness Slider

private struct ReadinessSlider: View {
    let label: String
    let emoji: String
    @Binding var value: Double
    let lowLabel: String
    let highLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(emoji) \(label)")
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                Text("\(Int(value))/5")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: 1...5, step: 1)
                .tint(sliderColor)
            HStack {
                Text(lowLabel).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(highLabel).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var sliderColor: Color {
        value >= 4 ? .good : value >= 3 ? .tint : .warn
    }
}
