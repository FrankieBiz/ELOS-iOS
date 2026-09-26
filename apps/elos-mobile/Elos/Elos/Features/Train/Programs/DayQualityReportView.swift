import SwiftUI

/// A single day's own quality report — reached by tapping a "BY DAY" row in the weekly report.
/// This is where a per-day muscle skip actually becomes visible: the aggregate weekly bars are
/// deliberately blind to a single day's own focus (and only honor a skip when every training day
/// agrees), but this view isn't — it renders exactly what that day's own report says.
struct DayQualityReportView: View {
    let dayName: String
    let report: QualityReport

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        QualityScoreRing(score: report.overall, size: 64, lineWidth: 6)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.tier.rawValue)
                                .font(.elosTitle)
                                .foregroundStyle(QualityPalette.color(forScore: report.overall))
                            Text(dayName)
                                .font(.elosBody)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(dayName) quality \(report.overall) out of 100, \(report.tier.rawValue)")
                    .padding(Space.card)
                    .elosCard()

                    if !report.dimensions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("BREAKDOWN").elosSectionLabel()
                            QualityDimensionBars(dimensions: report.dimensions(for: .singleSession), labelWidth: 86)
                        }
                        .padding(Space.card)
                        .elosCard()
                    }

                    // hidesUnexpected: true — for one focused day, a group the day doesn't target
                    // isn't a finding, unlike the weekly report where an empty group *is* the finding.
                    MuscleCoverageBars(report: report.volume, title: "MUSCLE COVERAGE",
                                       hidesUnexpected: true, showsLegend: true)
                        .padding(Space.card)
                        .elosCard()

                    if !report.tips.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SUGGESTIONS").elosSectionLabel()
                            VStack(spacing: 0) {
                                ForEach(Array(report.tips.enumerated()), id: \.element.id) { i, tip in
                                    if i > 0 { Divider().padding(.vertical, 9) }
                                    TipRow(tip: tip)
                                }
                            }
                        }
                        .padding(Space.card)
                        .elosCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(dayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
