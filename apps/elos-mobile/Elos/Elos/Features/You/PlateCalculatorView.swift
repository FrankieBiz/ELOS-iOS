import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targetWeight: Double = 135
    @State private var useKg = false

    private let barWeightLbs: Double = 45
    private let barWeightKg: Double  = 20
    private let platesLbs: [Double]  = [45, 35, 25, 10, 5, 2.5]
    private let platesKg:  [Double]  = [20, 15, 10, 5, 2.5, 1.25]

    private var barWeight: Double { useKg ? barWeightKg : barWeightLbs }
    private var availablePlates: [Double] { useKg ? platesKg : platesLbs }
    private var unit: String { useKg ? "kg" : "lbs" }

    private var platesPerSide: [(weight: Double, count: Int)] {
        var remaining = max(0, (targetWeight - barWeight) / 2)
        var result: [(Double, Int)] = []
        for plate in availablePlates {
            let count = Int(remaining / plate)
            if count > 0 {
                result.append((plate, count))
                remaining -= Double(count) * plate
            }
        }
        return result
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    weightInput
                    if targetWeight >= barWeight {
                        plateVisual
                        plateList
                    } else {
                        Text("Target must be at least \(Int(barWeight)) \(unit) (bar weight).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Weight Input

    private var weightInput: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Target Weight")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Picker("Unit", selection: $useKg) {
                    Text("lbs").tag(false)
                    Text("kg").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }

            HStack(spacing: 20) {
                Button {
                    HapticManager.impact(.light)
                    targetWeight = max(barWeight, targetWeight - (useKg ? 2.5 : 5))
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.tint)
                }
                .buttonStyle(.plain)

                Text("\(Int(targetWeight))")
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .frame(minWidth: 100)

                Button {
                    HapticManager.impact(.light)
                    targetWeight += (useKg ? 2.5 : 5)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.tint)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            Text("Bar: \(Int(barWeight)) \(unit)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .elosCard()
    }

    // MARK: - Plate Visual

    private var plateVisual: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Each side")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 16, height: 10)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 28)
                    ForEach(Array(platesPerSide.flatMap { pair in
                        Array(repeating: pair.weight, count: pair.count)
                    }.enumerated()), id: \.offset) { _, plate in
                        plateBlock(plate)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(16)
        .elosCard()
    }

    private func plateBlock(_ weight: Double) -> some View {
        let height: CGFloat = {
            switch weight {
            case 45, 20:    return 72
            case 35, 15:    return 62
            case 25, 10:    return 52
            case 10, 5:     return 42
            case 5, 2.5:    return 34
            default:        return 28
            }
        }()
        let color: Color = {
            switch weight {
            case 45, 20:    return .bad
            case 35, 15:    return .mSched
            case 25, 10:    return .mGym
            case 10, 5:     return .mHabits
            default:        return .mNutri
            }
        }()
        let label = weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weight))" : String(weight)
        return VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 20, height: height)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Plate List

    private var plateList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Per side")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("Total plates")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            Divider()

            if platesPerSide.isEmpty {
                Text("Just the bar — no plates needed.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(16)
            } else {
                ForEach(platesPerSide.indices, id: \.self) { i in
                    let pair = platesPerSide[i]
                    let wLabel = pair.weight.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(pair.weight))" : String(pair.weight)
                    HStack {
                        Text("\(pair.count) × \(wLabel) \(unit)")
                            .font(.subheadline)
                        Spacer()
                        Text("\(pair.count * 2)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if i < platesPerSide.count - 1 { Divider().padding(.leading, 16) }
                }
                Divider()
                HStack {
                    Text("Total")
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(targetWeight)) \(unit)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.tint)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
        .elosCard()
    }
}
