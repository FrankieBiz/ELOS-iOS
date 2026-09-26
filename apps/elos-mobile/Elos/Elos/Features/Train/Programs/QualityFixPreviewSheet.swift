import SwiftUI

/// Preview for a single auto-fixable suggestion — before/after score, what changes, and why —
/// with Confirm/Deny and an escape hatch to the manual picker. Nothing here touches builder state;
/// `onConfirm` hands the operations back to the caller, which applies them in its own types.
struct QualityFixPreviewSheet: View {
    @State private var proposal: FixProposal
    let onConfirm: ([FixOperation]) -> Void
    let onDeny: () -> Void
    /// Re-proposes the same fix with a specific alternate candidate. `nil` means the alternate
    /// couldn't produce a valid proposal (stays on the current one).
    let onTryAnother: (ExerciseCandidate) -> FixProposal?
    let onChooseManually: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(proposal: FixProposal, onConfirm: @escaping ([FixOperation]) -> Void, onDeny: @escaping () -> Void,
         onTryAnother: @escaping (ExerciseCandidate) -> FixProposal?, onChooseManually: @escaping () -> Void) {
        _proposal = State(initialValue: proposal)
        self.onConfirm = onConfirm
        self.onDeny = onDeny
        self.onTryAnother = onTryAnother
        self.onChooseManually = onChooseManually
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(proposal.tip.message)
                        .font(.elosCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    scoreComparison

                    if !proposal.dimensionDeltas.isEmpty {
                        dimensionDeltaList
                    }

                    changeCard

                    if let caveat = proposal.summary.caveat {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.elosCaption)
                            Text(caveat)
                                .font(.elosCaption)
                        }
                        .foregroundStyle(Color.warn)
                    }

                    if !proposal.alternates.isEmpty {
                        Menu {
                            ForEach(proposal.alternates, id: \.id) { candidate in
                                Button(candidate.name) {
                                    if let updated = onTryAnother(candidate) {
                                        proposal = updated
                                    }
                                }
                            }
                        } label: {
                            Text("Use a different exercise")
                                .font(.system(.footnote, weight: .semibold))
                        }
                    }

                    Button("Choose manually instead") {
                        dismiss()
                        onChooseManually()
                    }
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                            onDeny()
                        } label: {
                            Text("Deny").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            let ops = proposal.operations
                            dismiss()
                            onConfirm(ops)
                        } label: {
                            Text("Confirm").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .navigationTitle("Fix Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss(); onDeny() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var scoreComparison: some View {
        HStack(spacing: 20) {
            VStack(spacing: 2) {
                Text("\(proposal.before.overall)")
                    .font(.elosNumeric(.title2, weight: .bold))
                Text("NOW").font(.elosMicro).foregroundStyle(.secondary)
            }
            Image(systemName: "arrow.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            VStack(spacing: 2) {
                Text("\(proposal.after.overall)")
                    .font(.elosNumeric(.title2, weight: .bold))
                    .foregroundStyle(proposal.scoreDelta >= 0 ? Color.good : Color.bad)
                Text("AFTER").font(.elosMicro)
                    .foregroundStyle(proposal.scoreDelta >= 0 ? Color.good : Color.bad)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score \(proposal.before.overall) now, \(proposal.after.overall) after this fix")
    }

    private var dimensionDeltaList: some View {
        VStack(spacing: 4) {
            ForEach(proposal.dimensionDeltas, id: \.dimension) { entry in
                HStack {
                    Text(entry.dimension.label)
                        .font(.elosCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.delta > 0 ? "+\(entry.delta)" : "\(entry.delta)")
                        .font(.elosNumeric(.caption, weight: .semibold))
                        .foregroundStyle(entry.delta > 0 ? Color.good : Color.bad)
                }
            }
        }
        .padding(Space.card)
        .elosCard()
    }

    private var changeCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(proposal.summary.headline)
                .font(.system(.subheadline, weight: .semibold))
            if !proposal.summary.detail.isEmpty {
                Text(proposal.summary.detail)
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
            }
            if let placement = proposal.summary.placement {
                Text(placement)
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.card)
        .elosCard()
    }
}
