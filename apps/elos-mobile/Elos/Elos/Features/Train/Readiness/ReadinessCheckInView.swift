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
        // The content is taller than the 0.65 detent it was pinned to and had no ScrollView, so the
        // "Morning Check-In" title was clipped off the top — and at larger Dynamic Type sizes the Log
        // button itself would have been unreachable, stranding anyone who opened this sheet.
        ScrollView {
        VStack(spacing: Space.xl) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Morning Check-In")
                        .font(.title2).fontWeight(.bold)
                    Text("How are you feeling today?")
                        .font(.elosBody).foregroundStyle(.secondary)
                }
                Spacer(minLength: Space.s)
                // Starting a free workout opened this with no way out but a swipe. An explicit
                // close means the check-in is skippable, which it always was in intent.
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip check-in")
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.m)

            // Score
            Text("\(scoreEmoji) \(String(format: "%.1f", overallScore))/5")
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(scoreColor)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: overallScore)

            // Apple Health recovery context (resting HR / steps / weight + hint)
            if vm.healthKitEnabled, vm.healthSnapshot.hasAnyMetric {
                healthMetricsCard
            }

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
                .font(.system(.headline, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.l)
                .background(
                    checkInVM.saved ? Color.good : Color.tint,
                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(checkInVM.isSaving || checkInVM.saved)
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var healthMetricsCard: some View {
        let snap = vm.healthSnapshot
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if let rhr = snap.restingHeartRate { metricStat("Resting HR", "\(Int(rhr)) bpm") }
                if let steps = snap.steps { metricStat("Steps", "\(steps)") }
                if let w = snap.bodyWeightKg { metricStat("Weight", vm.weightUnit.formatWeight(kg: w)) }
            }
            if let hint = snap.recoveryHint {
                Text(hint)
                    .font(.caption2).foregroundStyle(Color.warn)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func metricStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
                    .font(.elosNumeric(.subheadline, weight: .semibold))
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
