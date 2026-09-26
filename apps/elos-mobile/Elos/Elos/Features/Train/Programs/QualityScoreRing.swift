import SwiftUI

/// The 0–100 score ring. One component shared by the inline panel and the full report, so the two
/// can't drift apart visually.
struct QualityScoreRing: View {
    let score: Int
    var size: CGFloat = 52
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.elosProgress, value: score)
            Text("\(score)")
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)   // the surrounding row speaks the score
    }

    private var color: Color { QualityPalette.color(forScore: score) }
}

enum QualityPalette {
    static func color(forScore score: Int) -> Color {
        switch score {
        case 75...:   return .good
        case 55..<75: return .tint
        default:      return .warn
        }
    }

    static func color(for severity: TipSeverity) -> Color {
        switch severity {
        case .warn: return .warn
        case .info: return .tint
        case .good: return .good
        }
    }

    static func icon(for severity: TipSeverity) -> String {
        switch severity {
        case .warn: return "exclamationmark.triangle.fill"
        case .info: return "lightbulb.fill"
        case .good: return "checkmark.circle.fill"
        }
    }
}

/// The four/five dimension sub-bars, shared by the panel and the report.
struct QualityDimensionBars: View {
    let dimensions: [DimensionScore]
    var labelWidth: CGFloat = 78

    var body: some View {
        VStack(spacing: 8) {
            ForEach(dimensions) { dim in
                HStack(spacing: 10) {
                    Text(dim.dimension.label)
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: labelWidth, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemGroupedBackground))
                            Capsule().fill(QualityPalette.color(forScore: dim.score))
                                .frame(width: max(6, geo.size.width * CGFloat(dim.score) / 100))
                        }
                    }
                    .frame(height: 6)
                    Text("\(dim.score)")
                        .font(.elosNumeric(.caption, weight: .semibold))
                        .foregroundStyle(QualityPalette.color(forScore: dim.score))
                        .frame(width: 26, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(dim.dimension.label)
                .accessibilityValue("\(dim.score) out of 100")
            }
        }
    }
}
