import SwiftUI
import SwiftData
import Combine

/// Pre-session readiness capture.
///
/// Redesigned away from an emoji-driven layout: 😴/💪/🧠/🔥 stood in for icons and 🟢/🟡/🔴 for a
/// status light, which was the only place in the app not using SF Symbols and read as a mock-up.
/// The score was printed as the literal string "🟡 3.0/5"; it is now a ring gauge with a plain-word
/// verdict, since "Ready" is what the user actually wants to know and "3.0/5" is not self-evident.
/// The four stock `Slider`s — five discrete stops each, dragged to snap — became tap-anywhere level
/// meters, which are quicker, more precise, and stop the sheet looking like a settings screen.
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

    /// The number alone doesn't tell you what to do with it. A verdict does.
    private var verdict: String {
        switch overallScore {
        case 4.5...:    return "Primed"
        case 3.5..<4.5: return "Ready"
        case 2.5..<3.5: return "Moderate"
        case 1.5..<2.5: return "Depleted"
        default:        return "Run down"
        }
    }

    private var guidance: String {
        switch overallScore {
        case 4.0...:    return "Good day to push for a PR."
        case 3.0..<4.0: return "Train as planned."
        case 2.0..<3.0: return "Hold intensity, trim volume."
        default:        return "Consider a light or recovery session."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                header
                gauge
                if vm.healthKitEnabled, vm.healthSnapshot.hasAnyMetric {
                    healthMetricsCard
                }
                metrics
                saveButton
            }
            .padding(.bottom, Space.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                // Was hardcoded "Morning Check-In" — shown at 12:41pm during testing, which is the
                // kind of detail that makes an app feel unfinished. The name is time-neutral now.
                Text("Readiness")
                    .font(.title2).fontWeight(.bold)
                Text("Before you train")
                    .font(.elosCaption).foregroundStyle(.secondary)
            }
            Spacer(minLength: Space.s)
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip check-in")
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.l)
    }

    // MARK: Gauge

    private var gauge: some View {
        HStack(spacing: Space.xl) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: max(0.02, overallScore / 5))
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%.1f", overallScore))
                    .font(.elosNumeric(.title2, weight: .bold))
                    .contentTransition(.numericText())
            }
            .frame(width: 86, height: 86)
            .animation(.snappy(duration: 0.25), value: overallScore)

            VStack(alignment: .leading, spacing: 4) {
                Text(verdict)
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(scoreColor)
                    .contentTransition(.opacity)
                Text(guidance)
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .animation(.snappy(duration: 0.25), value: verdict)
        .padding(.horizontal, Space.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Readiness \(String(format: "%.1f", overallScore)) of 5, \(verdict)")
    }

    // MARK: Metrics

    private var metrics: some View {
        VStack(spacing: Space.l) {
            ReadinessMetricRow(
                label: "Sleep", icon: "moon.zzz.fill", value: $sleepQuality,
                scale: ["Poor", "Fair", "Average", "Good", "Great"])
            ReadinessMetricRow(
                label: "Soreness", icon: "figure.cooldown", value: $soreness,
                scale: ["Very sore", "Sore", "Manageable", "Mostly fresh", "Fresh"])
            ReadinessMetricRow(
                label: "Stress", icon: "brain.head.profile", value: $stress,
                scale: ["High", "Elevated", "Moderate", "Low", "Calm"])
            ReadinessMetricRow(
                label: "Motivation", icon: "flame.fill", value: $motivation,
                scale: ["Low", "Flat", "Steady", "Keen", "Pumped"])
        }
        .padding(Space.gutter)
        .elosCard()
        .padding(.horizontal, Space.gutter)
    }

    // MARK: Save

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Group {
                if checkInVM.saved {
                    Label("Logged", systemImage: "checkmark")
                } else if checkInVM.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Log Check-In")
                }
            }
            .font(.system(.headline, weight: .semibold))
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
        .animation(.snappy(duration: 0.2), value: checkInVM.saved)
        .padding(.horizontal, Space.xl)
    }

    @ViewBuilder private var healthMetricsCard: some View {
        let snap = vm.healthSnapshot
        VStack(spacing: Space.s) {
            HStack(spacing: 0) {
                if let rhr = snap.restingHeartRate {
                    metricStat("Resting HR", "\(Int(rhr))", unit: "bpm", icon: "heart.fill", tint: .bad)
                }
                if let steps = snap.steps {
                    metricStat("Steps", "\(steps)", unit: "", icon: "shoeprints.fill", tint: .tint)
                }
                if let w = snap.bodyWeightKg {
                    metricStat("Weight", vm.weightUnit.formatValue(kg: w, decimals: 1),
                               unit: vm.weightUnit.label, icon: "scalemass.fill", tint: .good)
                }
            }
            if let hint = snap.recoveryHint {
                Text(hint)
                    .font(.elosCaption).foregroundStyle(Color.warn)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Space.gutter)
        .frame(maxWidth: .infinity)
        .elosCard()
        .padding(.horizontal, Space.gutter)
    }

    private func metricStat(_ label: String, _ value: String, unit: String,
                            icon: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.elosMicro).foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.elosNumeric(.subheadline, weight: .bold))
                if !unit.isEmpty {
                    Text(unit).font(.elosMicro).foregroundStyle(.secondary)
                }
            }
            Text(label).font(.elosMicro).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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

// MARK: - Metric Row

/// One readiness dimension as a five-stop level meter.
///
/// Replaces a `Slider(in: 1...5, step: 1)`: a continuous control faking five discrete stops meant
/// dragging and waiting for a snap to set a value the user already knew. Here every level is a
/// direct tap, and the filled-bar shape reads as a level at a glance rather than needing its number.
private struct ReadinessMetricRow: View {
    let label: String
    let icon: String
    @Binding var value: Double
    /// One word per level, low to high.
    ///
    /// A "Poor … Great" pair at the ends of the track only reads as a direction, and an earlier cut
    /// that hid those ends unless the value was extreme left the default midpoint with no cue at all
    /// about which way the scale ran. Naming the *current* level instead is unambiguous at every
    /// position, and costs no extra row.
    let scale: [String]

    private var level: Int { Int(value) }
    private var levelName: String { scale[min(max(level, 1), scale.count) - 1] }

    private var color: Color {
        level >= 4 ? .good : level >= 3 ? .tint : level >= 2 ? .warn : .bad
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                Image(systemName: icon)
                    .font(.elosCaption)
                    .foregroundStyle(color)
                    .frame(width: 18)
                Text(label)
                    .font(.system(.subheadline, weight: .semibold))
                Spacer()
                Text(levelName)
                    .font(.elosCaption)
                    .foregroundStyle(color)
                    .contentTransition(.opacity)
            }

            HStack(spacing: Space.xs + 2) {
                ForEach(1...5, id: \.self) { step in
                    let filled = step <= level
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(filled ? color : Color.secondary.opacity(0.16))
                        .frame(height: 10)
                        .frame(maxWidth: .infinity)
                        // The 10pt bar is the drawn height, not the target — a taller transparent
                        // overlay keeps every stop comfortably tappable.
                        .overlay {
                            Rectangle()
                                .fill(.clear)
                                .frame(height: 40)
                                .contentShape(.rect)
                                .onTapGesture {
                                    HapticManager.impact(.light)
                                    withAnimation(.snappy(duration: 0.18)) { value = Double(step) }
                                }
                        }
                }
            }
        }
        .animation(.snappy(duration: 0.18), value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(levelName), \(level) of 5")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if level < 5 { value = Double(level + 1) }
            case .decrement: if level > 1 { value = Double(level - 1) }
            @unknown default: break
            }
        }
    }
}
