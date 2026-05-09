import SwiftUI

struct WorkoutCompleteView: View {
    let data: WorkoutCompleteData
    let units: WeightUnit
    let onDone: () -> Void

    @State private var phase: Int = 0

    private var formattedVolume: String {
        let v = units.from(kg: data.totalVolumeKg)
        if v >= 10000 { return String(format: "%.0fK", v/1000) }
        if v >= 1000  { return String(format: "%.1fK", v/1000) }
        return String(format: "%.0f", v)
    }

    var body: some View {
        ZStack {
            Color.vBG.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Big mark
                ZStack {
                    Rectangle()
                        .fill(Color.vSignal)
                        .frame(width: 96, height: 96)
                        .scaleEffect(phase >= 1 ? 1 : 0.6)
                        .opacity(phase >= 1 ? 1 : 0)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(.vBG)
                        .scaleEffect(phase >= 1 ? 1 : 0.4)
                        .opacity(phase >= 1 ? 1 : 0)
                }

                VStack(spacing: 6) {
                    Text("MISSION COMPLETE")
                        .font(.system(size: 11, weight: .heavy))
                        .kerning(2.4)
                        .foregroundStyle(.vSignal)
                    Text(data.title.uppercased())
                        .font(Theme.Font.display(40))
                        .foregroundStyle(.vLabel)
                        .kerning(-0.5)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                    Text(data.subtitle.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(1.4)
                        .foregroundStyle(.vLabelMute)
                }
                .padding(.top, 24)
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? 0 : 14)

                Spacer().frame(height: 40)

                // Stat grid
                HStack(spacing: 0) {
                    statCol(label: "Duration", value: "\(data.durationMinutes)", suffix: "MIN")
                    Rectangle().fill(Color.vLine).frame(width: 0.5, height: 56)
                    statCol(label: "Sets", value: "\(data.totalSets)", suffix: nil)
                    Rectangle().fill(Color.vLine).frame(width: 0.5, height: 56)
                    statCol(label: "Volume", value: formattedVolume, suffix: units.label.uppercased())
                    Rectangle().fill(Color.vLine).frame(width: 0.5, height: 56)
                    statCol(label: "Exercises", value: "\(data.exerciseCount)", suffix: nil)
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, 14)
                .background(Color.vSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .strokeBorder(Color.vLine, lineWidth: 0.5)
                )
                .padding(.horizontal, Theme.Space.md)
                .opacity(phase >= 3 ? 1 : 0)
                .offset(y: phase >= 3 ? 0 : 14)

                if !data.newPRs.isEmpty {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Rectangle().fill(Color.vSignal).frame(width: 12, height: 2)
                            Text("\(data.newPRs.count) NEW PR\(data.newPRs.count == 1 ? "" : "S")")
                                .font(.system(size: 11, weight: .heavy))
                                .kerning(1.4)
                                .foregroundStyle(.vSignal)
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.lg)

                        VStack(spacing: 0) {
                            ForEach(Array(data.newPRs.enumerated()), id: \.offset) { i, name in
                                HStack(spacing: 10) {
                                    IndexBadge(n: i + 1, active: true, size: 22)
                                    Text(name.uppercased())
                                        .font(.system(size: 12, weight: .black))
                                        .kerning(0.4)
                                        .foregroundStyle(.vLabel)
                                    Spacer()
                                    Image(systemName: "rosette")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(.vSignal)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                if i < data.newPRs.count - 1 { Hairline().padding(.leading, 38) }
                            }
                        }
                        .background(Color.vSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .strokeBorder(Color.vSignal.opacity(0.3), lineWidth: 0.5)
                        )
                        .padding(.horizontal, Theme.Space.md)
                    }
                    .opacity(phase >= 3 ? 1 : 0)
                    .offset(y: phase >= 3 ? 0 : 14)
                }

                Spacer()

                Button {
                    Haptic.success(); onDone()
                } label: {
                    Text("RETURN TO BASE")
                        .font(.system(size: 13, weight: .black))
                        .kerning(1.6)
                        .foregroundStyle(.vBG)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.vSignal)
                }
                .buttonStyle(.pressable(scale: 0.98, haptic: .none))
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Haptic.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { phase = 1 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { phase = 2 }
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { phase = 3 }
            }
        }
    }

    private func statCol(label: String, value: String, suffix: String?) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .kerning(1.2)
                .foregroundStyle(.vLabelMute)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.Font.mono(20, .black))
                    .foregroundStyle(.vLabel)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.vLabelFaint)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
