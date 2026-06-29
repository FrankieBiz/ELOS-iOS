import SwiftUI

struct TemplateImportSheet: View {
    let shareCode: String
    @EnvironmentObject var appVM: AppViewModel
    @StateObject private var importVM = TemplateImportViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                switch importVM.state {
                case .fetchingTemplate:
                    fetchingView

                case .idle(let template):
                    idleView(template: template)

                case .importing:
                    importingView

                case .success:
                    Color.clear
                        .onAppear {
                            appVM.pendingTemplateShareCode = nil
                            dismiss()
                        }

                case .error(let msg):
                    errorView(message: msg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Dismiss") { dismiss() }
                }
            }
        }
        .onAppear { importVM.fetchTemplate(shareCode: shareCode) }
    }

    // MARK: - States

    private var fetchingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<4) { _ in
                skeletonRow
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
    }

    private var skeletonRow: some View {
        HStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemFill))
                .frame(height: 16)
            Spacer()
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemFill))
                .frame(width: 60, height: 16)
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }

    private func idleView(template: SharedTemplateResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.template_name)
                        .font(.system(size: 26, weight: .bold))
                    Text("by \(template.owner_name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 1) {
                    ForEach(Array(template.exercises.sorted { $0.order_index < $1.order_index }.enumerated()), id: \.offset) { _, ex in
                        HStack {
                            Text(ex.exercise_name)
                                .font(.system(size: 15))
                            Spacer()
                            Text("\(ex.target_sets)×\(ex.target_reps)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            if let rpe = ex.target_rpe, rpe > 0 {
                                Text("RPE \(Int(rpe))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Button {
                    importVM.importTemplate(template: template)
                } label: {
                    Text("Copy to My Templates")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .elosPrimaryButton()
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var importingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Saving to your library…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            if message == "404" {
                Text("This template is no longer available.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 8) {
                    Text("Something went wrong")
                        .font(.headline)
                    Text("Please check your connection and try again.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        importVM.fetchTemplate(shareCode: shareCode)
                    }
                    .elosPrimaryButton()
                    .frame(width: 140)
                    .padding(.top, 4)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Shimmer modifier

private extension View {
    @ViewBuilder
    func shimmering() -> some View {
        self.opacity(0.5)
    }
}
