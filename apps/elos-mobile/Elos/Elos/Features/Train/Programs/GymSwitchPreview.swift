import SwiftUI

/// One day's outcome if the pending gym switch is confirmed.
struct GymSwitchDayChange: Identifiable {
    let id: Int   // day index
    let dayName: String
    /// `nil` = this day has no version for the target gym and stays exactly as it is.
    let newVariantName: String?
}

/// Shown before a gym switch actually touches anything — which days change to a different
/// version, which stay as they are (no version exists for this gym yet), and how the split's
/// score moves. Matches the auto-fix preview's shape (show the delta, Confirm/Cancel) rather than
/// inventing a second confirmation pattern.
struct GymSwitchPreview: View {
    let gymName: String
    let changes: [GymSwitchDayChange]
    let beforeScore: Int?
    let afterScore: Int?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var changing: [GymSwitchDayChange] { changes.filter { $0.newVariantName != nil } }
    private var unchanged: [GymSwitchDayChange] { changes.filter { $0.newVariantName == nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Switch to \(gymName)?")
                        .font(.elosTitle)

                    if let before = beforeScore, let after = afterScore {
                        HStack(spacing: 20) {
                            scoreColumn(label: "NOW", score: before, color: .secondary)
                            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                            scoreColumn(label: "AFTER", score: after,
                                       color: after >= before ? Color.good : Color.warn)
                        }
                    }

                    if !changing.isEmpty {
                        changeSection(title: "SWITCHES TO A DIFFERENT VERSION", rows: changing) { change in
                            Text(change.newVariantName ?? "")
                                .font(.elosCaption).foregroundStyle(Color.tint)
                        }
                    }

                    if !unchanged.isEmpty {
                        changeSection(title: "STAYS AS IT IS — NO VERSION FOR \(gymName.uppercased()) YET",
                                     rows: unchanged) { _ in
                            Text("Unchanged").font(.elosCaption).foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            dismiss(); onCancel()
                        } label: {
                            Text("Cancel").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            dismiss(); onConfirm()
                        } label: {
                            Text("Switch").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Gym Switch")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func scoreColumn(label: String, score: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(score)").font(.elosNumeric(.title2, weight: .bold)).foregroundStyle(color)
            Text(label).font(.elosMicro).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func changeSection<Trailing: View>(title: String, rows: [GymSwitchDayChange],
                                               @ViewBuilder trailing: @escaping (GymSwitchDayChange) -> Trailing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).elosSectionLabel()
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, change in
                    if i > 0 { Divider() }
                    HStack {
                        Text(change.dayName).font(.elosBody)
                        Spacer()
                        trailing(change)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
