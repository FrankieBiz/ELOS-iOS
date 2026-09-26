import SwiftUI

/// Small ⓘ affordance that opens a certainty-rated science explanation. Shared by every feature
/// that makes a "backed by science" claim — one place to render this, not one sheet per feature.
struct EvidenceBadge: View {
    let topic: EvidenceTopic
    @State private var showingSheet = false

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            Label("Why", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showingSheet) {
            EvidenceSheet(entry: EvidenceLibrary.entry(for: topic))
        }
    }
}

private struct EvidenceSheet: View {
    let entry: EvidenceEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(entry.certainty.displayLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.15), in: Capsule())
                    Text(entry.claim)
                        .font(.headline)
                    Text(entry.explanation)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("The science")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    EvidenceBadge(topic: .exerciseSubstitution)
        .padding()
}
