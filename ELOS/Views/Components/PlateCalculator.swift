import SwiftUI

// MARK: - PlateCalculator
// Visualizes the plates needed on each side of the bar to hit a target weight,
// using the user's available plate inventory.

struct PlateCalculatorView: View {
    let targetWeightKg: Double
    let barWeightKg: Double
    let availablePlatesKg: [Double]
    let units: WeightUnit

    private var perSideKg: Double {
        max(0, (targetWeightKg - barWeightKg) / 2.0)
    }

    private var plates: [Double] {
        var remaining = perSideKg
        var out: [Double] = []
        // greedy: largest first
        for p in availablePlatesKg.sorted(by: >) {
            while remaining + 0.01 >= p {
                out.append(p)
                remaining -= p
            }
        }
        return out
    }

    private var leftover: Double { max(0, perSideKg - plates.reduce(0, +)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Plates")
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("PER SIDE")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.secondary)
            }

            // Plate stack
            HStack(spacing: 3) {
                Spacer(minLength: 0)
                if plates.isEmpty {
                    Text("Bar only")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 32)
                } else {
                    ForEach(Array(plates.enumerated()), id: \.offset) { _, kg in
                        PlateView(weightKg: kg, units: units)
                    }
                }
                // Bar stub
                Rectangle()
                    .fill(Color.gray.opacity(0.55))
                    .frame(width: 38, height: 6)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                Spacer(minLength: 0)
            }
            .frame(height: 96)

            // Summary line
            HStack(spacing: 6) {
                Text(formatPerSide).font(.system(size: 12, weight: .heavy, design: .rounded))
                Spacer()
                if leftover > 0.01 {
                    Chip(text: "Need \(displayWeight(leftover)) \(units.label) more",
                         icon: "exclamationmark.triangle.fill", color: .brandWarn)
                } else {
                    Chip(text: "Loaded", icon: "checkmark", color: .brandSuccess)
                }
            }
        }
        .padding(14)
        .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    private var formatPerSide: String {
        let perSideDisp = displayWeight(perSideKg)
        let totalDisp = displayWeight(targetWeightKg)
        return "\(perSideDisp) \(units.label) per side · \(totalDisp) total"
    }

    private func displayWeight(_ kg: Double) -> String {
        let v = units.from(kg: kg)
        return v.prettyWeight
    }
}

// MARK: - Single plate view, color-coded IPF style

private struct PlateView: View {
    let weightKg: Double
    let units: WeightUnit

    private var color: Color {
        // Approximate IPF color coding for bumper plates.
        switch weightKg {
        case 25.0:  return Color.red
        case 20.0:  return Color.blue
        case 15.0:  return Color.yellow
        case 10.0:  return Color.green
        case 5.0:   return Color.white
        case 2.5:   return Color.gray.opacity(0.85)
        case 1.25:  return Color.gray.opacity(0.55)
        default:    return Color.gray
        }
    }

    private var height: CGFloat {
        switch weightKg {
        case 25.0:  return 90
        case 20.0:  return 84
        case 15.0:  return 76
        case 10.0:  return 64
        case 5.0:   return 50
        case 2.5:   return 38
        case 1.25:  return 28
        default:    return 22
        }
    }

    var body: some View {
        VStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .overlay(
                    Text(weightKg.prettyWeight)
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(weightKg == 5.0 ? .black : .white)
                        .rotationEffect(.degrees(-90))
                )
                .frame(width: 12, height: height)
                .shadow(color: .black.opacity(0.18), radius: 1, x: 0, y: 1)
        }
    }
}
