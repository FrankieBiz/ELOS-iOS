import SwiftUI

// MARK: - WeightStepper
// Compact +/- pill with editable center value. Long-press accelerates.

struct WeightStepper: View {
    @Binding var value: Double      // in user's display units
    var step: Double = 5
    var fineStep: Double = 2.5
    var unit: String = "lbs"
    var color: Color = .brand

    @State private var holdTask: Task<Void, Never>? = nil
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            stepButton(symbol: "minus", delta: -step, deltaFine: -fineStep)

            // Center display (tap to edit)
            Button {
                editText = value.prettyWeight
                isEditing = true
                Haptic.selection()
            } label: {
                VStack(spacing: 0) {
                    Text(value.prettyWeight)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: value))
                        .animation(Theme.Motion.snappy, value: value)
                    Text(unit.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(0.8)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.surfaceInset)
                )
            }
            .buttonStyle(.plain)

            stepButton(symbol: "plus", delta: step, deltaFine: fineStep)
        }
        .sheet(isPresented: $isEditing) {
            VStack(spacing: 16) {
                Text("Set Weight").font(.headline)
                TextField("Weight", text: $editText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .focused($fieldFocused)
                    .padding()
                    .background(Color.surfaceInset, in: RoundedRectangle(cornerRadius: 12))
                HStack(spacing: 10) {
                    GhostCTA(title: "Cancel", color: .secondary) { isEditing = false }
                    PrimaryCTA(title: "Save", color: color) {
                        if let v = Double(editText.replacingOccurrences(of: ",", with: ".")) {
                            value = max(0, v)
                        }
                        isEditing = false
                    }
                }
            }
            .padding()
            .presentationDetents([.height(260)])
            .onAppear { fieldFocused = true }
        }
    }

    @ViewBuilder
    private func stepButton(symbol: String, delta: Double, deltaFine: Double) -> some View {
        Button {} label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .black))
                .frame(width: 52, height: 56)
                .foregroundStyle(color)
                .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                value = max(0, value + delta)
                Haptic.light()
            }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.3).onEnded { _ in
                Haptic.medium()
                holdTask?.cancel()
                holdTask = Task { @MainActor in
                    while !Task.isCancelled {
                        value = max(0, value + deltaFine)
                        Haptic.soft()
                        try? await Task.sleep(nanoseconds: 90_000_000)
                    }
                }
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onEnded { _ in
                holdTask?.cancel()
                holdTask = nil
            }
        )
    }
}

// MARK: - RepStepper

struct RepStepper: View {
    @Binding var value: Int
    var color: Color = .brand
    var minVal: Int = 0
    var maxVal: Int = 99

    var body: some View {
        HStack(spacing: 8) {
            Button {
                value = max(minVal, value - 1); Haptic.light()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .black))
                    .frame(width: 44, height: 56)
                    .foregroundStyle(color)
                    .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                Text("\(value)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(Theme.Motion.snappy, value: value)
                Text("REPS")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.surfaceInset, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                value = min(maxVal, value + 1); Haptic.light()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .frame(width: 44, height: 56)
                    .foregroundStyle(color)
                    .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - RPE Selector (1-10 scale, color-graded)

struct RPESelector: View {
    @Binding var value: Double?       // 1.0...10.0 in 0.5 steps

    private let stops: [Double] = stride(from: 6.0, through: 10.0, by: 0.5).map { $0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RPE")
                .font(.system(size: 11, weight: .heavy))
                .kerning(0.6)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("—") {
                        value = nil; Haptic.selection()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(value == nil ? Color.white : Color.secondary)
                    .frame(width: 42, height: 36)
                    .background(value == nil ? Color.secondary : Color.surfaceInset, in: Capsule())

                    ForEach(stops, id: \.self) { v in
                        let selected = value == v
                        Button {
                            value = v; Haptic.selection()
                        } label: {
                            Text(v.truncatingRemainder(dividingBy: 1) == 0
                                 ? "\(Int(v))" : String(format: "%.1f", v))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .frame(width: 42, height: 36)
                                .foregroundStyle(selected ? .white : rpeColor(v))
                                .background(selected ? rpeColor(v) : rpeColor(v).opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func rpeColor(_ v: Double) -> Color {
        switch v {
        case ..<7:   return .brandSuccess
        case 7..<8.5: return .brand
        case 8.5..<9.5: return .brandWarn
        default: return .brandDanger
        }
    }
}
