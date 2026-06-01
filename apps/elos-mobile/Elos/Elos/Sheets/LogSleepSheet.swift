import SwiftUI

struct LogSleepSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var bedTime  = Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: Date()) ?? Date()
    @State private var wakeTime = Calendar.current.date(bySettingHour: 6,  minute: 15, second: 0, of: Date()) ?? Date()
    @State private var quality  = 4
    @State private var notes    = ""
    @FocusState private var notesFocused: Bool

    private var duration: Double {
        var diff = wakeTime.timeIntervalSince(bedTime) / 3600
        if diff < 0 { diff += 24 }
        return diff
    }

    private var durationLabel: String {
        String(format: "%.1fh", duration)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Drag indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 36, height: 4)
                        .padding(.top, 4)

                    // Duration display
                    VStack(spacing: 6) {
                        Text(durationLabel)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                        Text("Estimated duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Time pickers
                    VStack(spacing: 0) {
                        HStack {
                            Label("Bedtime", systemImage: "moon.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.mHealth)
                            Spacer()
                            DatePicker("", selection: $bedTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        .padding(16)

                        Divider().padding(.leading, 16)

                        HStack {
                            Label("Wake time", systemImage: "sun.rise.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.mGym)
                            Spacer()
                            DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        .padding(16)
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Quality picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SLEEP QUALITY")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { q in
                                Button {
                                    quality = q
                                } label: {
                                    Text(qualityLabel(q))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(quality == q ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(quality == q ? qualityColor(q) : Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        TextField("Notes (optional)…", text: $notes, axis: .vertical)
                            .focused($notesFocused)
                            .font(.subheadline)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Log Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSleep()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.tint)
                }
            }
        }
    }

    private func saveSleep() {
        let bedStr  = formatted(bedTime)
        let wakeStr = formatted(wakeTime)
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let dateStr = df.string(from: Date())
        vm.logSleep(SleepEntry(date: dateStr, bed: bedStr, wake: wakeStr, duration: duration, quality: quality))
        HapticManager.success()
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func qualityLabel(_ q: Int) -> String {
        switch q { case 1: return "Terrible"; case 2: return "Poor"; case 3: return "Okay"; case 4: return "Good"; case 5: return "Great"; default: return "—" }
    }

    private func qualityColor(_ q: Int) -> Color {
        switch q { case 1: return .bad; case 2: return .mHealth; case 3: return .warn; case 4: return .mSched; case 5: return .mGym; default: return .secondary }
    }
}
