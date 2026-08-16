import SwiftUI

/// An annulus (ring) via the even-odd fill rule: outer circle minus a smaller concentric circle,
/// leaving a real hole through the shape rather than an opaque disc with a fake centre dot drawn
/// on top — whatever's behind (the card background) shows through correctly.
private struct PlateDiscShape: Shape {
    var holeRatio: CGFloat = 0.32

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        let holeSize = rect.width * holeRatio
        let holeRect = CGRect(
            x: rect.midX - holeSize / 2, y: rect.midY - holeSize / 2,
            width: holeSize, height: holeSize
        )
        path.addEllipse(in: holeRect)
        return path
    }
}

struct PlateCalculatorView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var targetWeight: Double = 135
    @State private var useKg = false
    @State private var didInit = false
    /// Set right before `onAppear` assigns `useKg` from the stored preference, so the unit-change
    /// conversion below doesn't re-derive `targetWeight` from itself and mangle the just-set default.
    @State private var suppressUnitConversion = false

    private let barWeightLbs: Double = 45
    private let barWeightKg: Double  = 20
    private let platesLbs: [Double]  = [45, 35, 25, 10, 5, 2.5]
    private let platesKg:  [Double]  = [20, 15, 10, 5, 2.5, 1.25]

    private var barWeight: Double { useKg ? barWeightKg : barWeightLbs }
    private var availablePlates: [Double] { useKg ? platesKg : platesLbs }
    /// Matches the rest of the app, which says "lb" — this screen was the only place saying "lbs".
    private var unit: String { useKg ? "kg" : "lb" }

    /// Whole numbers plain, halves with one decimal: "60", "62.5".
    static func format(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    static func rounded(_ v: Double, toNearest step: Double) -> Double {
        (v / step).rounded() * step
    }

    /// What the listed plates actually add up to. Shown as the total instead of echoing the target:
    /// a calculator that reports back your own input can't tell you when it failed to hit it.
    private var loadedTotal: Double {
        barWeight + 2 * platesPerSide.reduce(0) { $0 + $1.weight * Double($1.count) }
    }

    /// Non-zero when no combination of available plates reaches the target.
    private var shortfall: Double { max(0, targetWeight - loadedTotal) }

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
            // This is a compact calculator, not a dashboard — a full-height sheet left roughly the
            // bottom third of the screen as bare black space below the last card. `.medium` matches
            // the container to the content; `.large` stays reachable by dragging up.
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear {
                guard !didInit else { return }
                didInit = true
                suppressUnitConversion = true
                useKg = vm.weightUnit == .kg
                targetWeight = useKg ? 60 : 135
            }
            // Convert on unit change. Without this the *number* stayed put, so flipping lbs→kg turned a
            // 135 lb target into a 135 kg one — nearly 300 lb, silently.
            .onChange(of: useKg) { wasKg, nowKg in
                if suppressUnitConversion { suppressUnitConversion = false; return }
                guard wasKg != nowKg else { return }
                let kg = wasKg ? targetWeight : targetWeight / 2.2046226218
                let converted = nowKg ? kg : kg * 2.2046226218
                targetWeight = max(barWeight, Self.rounded(converted, toNearest: nowKg ? 2.5 : 5))
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
                    Text("lb").tag(false)
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
                        .font(.largeTitle)
                        .foregroundStyle(Color.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease target weight")

                // Not `Int(targetWeight)`: kg steps in 2.5s, so 62.5 rendered as "62" while the plate
                // maths below correctly loaded for 62.5 — the headline number disagreed with the plates.
                Text(Self.format(targetWeight))
                    .font(.elosNumeric(.largeTitle))
                    .frame(minWidth: 100)
                    .contentTransition(.numericText())

                Button {
                    HapticManager.impact(.light)
                    targetWeight += (useKg ? 2.5 : 5)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase target weight")
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
                HStack(spacing: -14) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 22, height: 12)
                        .zIndex(1)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 8, height: 30)
                        .zIndex(1)
                    ForEach(Array(platesPerSide.flatMap { pair in
                        Array(repeating: pair.weight, count: pair.count)
                    }.enumerated()), id: \.offset) { i, plate in
                        plateBlock(plate).zIndex(Double(-i))
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
            }
        }
        .padding(16)
        .elosCard()
    }

    private func plateBlock(_ weight: Double) -> some View {
        let diameter: CGFloat = {
            switch weight {
            case 45, 20:    return 76
            case 35, 15:    return 66
            case 25, 10:    return 56
            case 5:         return 46
            case 2.5:       return 38
            default:        return 32
            }
        }()
        let color: Color = {
            switch weight {
            case 45, 20:    return .bad
            case 35, 15:    return .mSched
            case 25, 10:    return .mGym
            case 5:         return .mHabits
            default:        return .mNutri
            }
        }()
        let label = weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weight))" : String(weight)
        return VStack(spacing: 4) {
            // A real plate viewed edge-on is a disc with a hole through its centre for the bar —
            // the old flat coloured bar read as a UI placeholder, not a weight plate. The even-odd
            // fill rule punches a true hole through to whatever's behind (the card background),
            // rather than faking it with an opaque circle that'd mismatch against any card texture.
            PlateDiscShape()
                .fill(color.gradient, style: FillStyle(eoFill: true))
                .overlay(PlateDiscShape().stroke(color.opacity(0.5), lineWidth: 1))
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            Text(label)
                .font(.system(.caption2, weight: .bold))
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
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if i < platesPerSide.count - 1 { Divider().padding(.leading, 16) }
                }
                Divider()
                HStack {
                    Text("Total")
                        .font(.system(.subheadline, weight: .semibold))
                    Spacer()
                    Text("\(Self.format(loadedTotal)) \(unit)")
                        .font(.elosNumeric(.subheadline))
                        .foregroundStyle(Color.tint)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                if shortfall > 0 {
                    // The smallest plate can't close the gap. Say so — silently loading less than
                    // asked for is the one thing a plate calculator must never do.
                    Divider()
                    Label("\(Self.format(shortfall)) \(unit) short — no plate small enough to close the gap.",
                          systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.elosCaption)
                        .foregroundStyle(Color.warn)
                        .padding(.horizontal, 16).padding(.bottom, 12)
                }
            }
        }
        .elosCard()
    }
}
