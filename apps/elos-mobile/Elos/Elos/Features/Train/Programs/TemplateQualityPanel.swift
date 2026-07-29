import SwiftUI

/// Live, inline quality coach shared by the template and split builders. Score ring, tier, the
/// dimension sub-bars that apply at this scope, and ranked science-based tips. Collapses to just the
/// score for intermediate/advanced lifters (via `GuidanceLevel`); beginners see it expanded.
///
/// Rendering pieces (`QualityScoreRing`, `QualityDimensionBars`, `TipRow`) are shared with
/// `SplitQualityReportView` rather than duplicated, so the inline and full views stay consistent.
struct TemplateQualityPanel: View {
    let report: QualityReport
    let guidance: GuidanceLevel
    var title: String = "Workout Quality"
    /// Filters which dimensions are shown — frequency is meaningless for one session.
    var scope: QualityScope = .singleSession
    /// Optional follow-up when an actionable tip is tapped (e.g. open the Add-Exercise sheet).
    var onTapTip: ((QualityTip) -> Void)? = nil
    /// When set, shows a "See full report" row (the split builder's bigger screen).
    var onSeeFullReport: (() -> Void)? = nil

    @State private var userExpanded: Bool? = nil
    @State private var showAllTips = false

    private var isExpanded: Bool { userExpanded ?? (guidance == .full) }
    private var shownDimensions: [DimensionScore] { report.dimensions(for: scope) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isExpanded {
                QualityDimensionBars(dimensions: shownDimensions)
                tipsSection
                if let onSeeFullReport { fullReportRow(onSeeFullReport) }
            }
        }
        .padding(Space.card)
        .elosCard()
    }

    // MARK: Header (score ring + tier)

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { userExpanded = !isExpanded }
        } label: {
            HStack(spacing: 12) {
                QualityScoreRing(score: report.overall)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(report.tier.rawValue)
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(QualityPalette.color(forScore: report.overall))
                }

                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(report.overall) out of 100, \(report.tier.rawValue)")
        .accessibilityHint(isExpanded ? "Collapse details" : "Expand details")
    }

    // MARK: Tips

    @ViewBuilder private var tipsSection: some View {
        if report.tips.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.elosBody)
                    .foregroundStyle(Color.good)
                Text("Looking dialed in — no issues to flag.")
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        } else {
            let shown = showAllTips ? report.tips : Array(report.tips.prefix(3))
            VStack(alignment: .leading, spacing: 8) {
                Divider().padding(.vertical, 1)
                ForEach(shown) { tip in TipRow(tip: tip, onTap: onTapTip) }
                if report.tips.count > 3 {
                    Button {
                        withAnimation { showAllTips.toggle() }
                    } label: {
                        Text(showAllTips ? "Show less"
                                         : "+\(report.tips.count - 3) more tip\(report.tips.count - 3 == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(Color.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func fullReportRow(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(.caption, weight: .semibold))
                Text("See full report")
                    .font(.system(.footnote, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(Color.tint)
            .padding(.vertical, 9).padding(.horizontal, 11)
            .background(Color.tintSoft)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens muscle coverage, movement quality and frequency")
    }
}
