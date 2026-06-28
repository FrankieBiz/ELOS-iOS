import SwiftUI

/// Live, inline quality coach shared by the template and split builders. Shows a 0–100 score
/// ring, tier, the four dimension sub-bars, and ranked science-based tips. Collapses to just the
/// score for intermediate/advanced lifters (via `GuidanceLevel`); beginners see it expanded.
struct TemplateQualityPanel: View {
    let report: QualityReport
    let guidance: GuidanceLevel
    var title: String = "Workout Quality"
    /// Optional follow-up when an actionable tip is tapped (e.g. open the Add-Exercise sheet).
    var onTapTip: ((QualityTip) -> Void)? = nil

    @State private var userExpanded: Bool? = nil
    @State private var showAllTips = false

    private var isExpanded: Bool { userExpanded ?? (guidance == .full) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isExpanded {
                dimensionBars
                tipsSection
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Header (score ring + tier)

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { userExpanded = !isExpanded }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(scoreColor.opacity(0.18), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: CGFloat(report.overall) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(report.overall)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(report.tier.rawValue)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(scoreColor)
                }

                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Dimension sub-bars

    private var dimensionBars: some View {
        VStack(spacing: 8) {
            ForEach(report.dimensions) { dim in
                HStack(spacing: 10) {
                    Text(dim.dimension.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 78, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemGroupedBackground))
                            Capsule().fill(barColor(dim.score))
                                .frame(width: max(6, geo.size.width * CGFloat(dim.score) / 100))
                        }
                    }
                    .frame(height: 6)
                    Text("\(dim.score)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(barColor(dim.score))
                        .frame(width: 26, alignment: .trailing)
                }
            }
        }
    }

    // MARK: Tips

    @ViewBuilder private var tipsSection: some View {
        if report.tips.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.good)
                Text("Looking dialed in — no issues to flag.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        } else {
            let shown = showAllTips ? report.tips : Array(report.tips.prefix(3))
            VStack(alignment: .leading, spacing: 8) {
                Divider().padding(.vertical, 1)
                ForEach(shown) { tip in tipRow(tip) }
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

    private func tipRow(_ tip: QualityTip) -> some View {
        let canTap = tip.action.isActionable && onTapTip != nil
        return Button {
            if canTap { onTapTip?(tip) }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: tipIcon(tip.severity))
                    .font(.system(size: 12))
                    .foregroundStyle(tipColor(tip.severity))
                    .padding(.top, 1)
                Text(tip.message)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if canTap {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canTap)
    }

    // MARK: Colors

    private var scoreColor: Color { barColor(report.overall) }

    private func barColor(_ score: Int) -> Color {
        switch score {
        case 75...:   return .good
        case 55..<75: return .tint
        default:      return .warn
        }
    }

    private func tipIcon(_ severity: TipSeverity) -> String {
        switch severity {
        case .warn: return "exclamationmark.triangle.fill"
        case .info: return "lightbulb.fill"
        case .good: return "checkmark.circle.fill"
        }
    }

    private func tipColor(_ severity: TipSeverity) -> Color {
        switch severity {
        case .warn: return .warn
        case .info: return .tint
        case .good: return .good
        }
    }
}
