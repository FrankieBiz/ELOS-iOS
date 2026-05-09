import SwiftUI

struct WorkoutCompleteView: View {
    let data: WorkoutCompleteData
    let units: WeightUnit
    let onDone: () -> Void

    @State private var phase: Int = 0

    private var formattedVolume: String {
        let v = units.from(kg: data.totalVolumeKg)
        if v >= 10000 { return String(format: "%.0fK", v / 1000) }
        if v >= 1000  { return String(format: "%.1fK", v / 1000) }
        return String(format: "%.0f", v)
    }

    var body: some View {
        ZStack {
            Color.obsidian.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Hero text — typography IS the celebration
                VStack(spacing: 6) {
                    Text("Session complete".uppercased())
                        .font(Theme.Font.label)
                        .kerning(2.0)
                        .foregroundStyle(.silver)
                        .opacity(phase >= 1 ? 1 : 0)

                    Text("Well done.")
                        .font(Theme.Font.display(64))
                        .foregroundStyle(.pearl)
                        .breathGlow(minIntensity: 0.10, maxIntensity: 0.30, radius: 24)
                        .scaleEffect(phase >= 1 ? 1 : 0.92)
                        .opacity(phase >= 1 ? 1 : 0)

                    Text(data.title)
                        .font(Theme.Font.body(16))
                        .foregroundStyle(.silver)
                        .opacity(phase >= 2 ? 1 : 0)
                }
                .multilineTextAlignment(.center)
                .animation(Theme.Motion.glide, value: phase)

                Spacer().frame(height: 48)

                // Stat grid — 2×2
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statTile(label: "Duration", value: "\(data.durationMinutes)", suffix: "min")
                    statTile(label: "Sets", value: "\(data.totalSets)", suffix: nil)
                    statTile(label: "Volume", value: formattedVolume, suffix: units.label)
                    statTile(label: "Exercises", value: "\(data.exerciseCount)", suffix: nil)
                }
                .padding(.horizontal, Theme.Space.md)
                .opacity(phase >= 3 ? 1 : 0)
                .offset(y: phase >= 3 ? 0 : 16)
                .animation(Theme.Motion.glide, value: phase)

                // New PRs
                if !data.newPRs.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel(title: "\(data.newPRs.count) New Record\(data.newPRs.count == 1 ? "" : "s")")
                        VStack(spacing: 0) {
                            ForEach(Array(data.newPRs.enumerated()), id: \.offset) { i, name in
                                HStack(spacing: 12) {
                                    Rectangle().fill(Color.pearl).frame(width: 2, height: 28)
                                    Text(name)
                                        .font(Theme.Font.heading(14))
                                        .foregroundStyle(.pearl)
                                    Spacer()
                                    Image(systemName: "rosette")
                                        .font(.system(size: 13, weight: .thin))
                                        .foregroundStyle(.silver)
                                }
                                .padding(.horizontal, Theme.Space.md).padding(.vertical, 12)
                                if i < data.newPRs.count - 1 {
                                    Hairline().padding(.horizontal, Theme.Space.md)
                                }
                            }
                        }
                        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .edgeHighlight(radius: Theme.Radius.md)
                        .padding(.horizontal, Theme.Space.md)
                    }
                    .opacity(phase >= 3 ? 1 : 0)
                    .offset(y: phase >= 3 ? 0 : 14)
                    .animation(Theme.Motion.glide.delay(0.1), value: phase)
                }

                Spacer()

                // CTA
                Button {
                    Haptic.success(); onDone()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .thin))
                        Text("Return home")
                            .font(Theme.Font.title(17))
                    }
                    .foregroundStyle(.obsidian)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: [Color.pearl.opacity(0.97), .pearl], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    )
                    .breathGlow(minIntensity: 0.10, maxIntensity: 0.28, radius: 16)
                }
                .buttonStyle(.pressable(scale: 0.985, haptic: .none, glow: true, glowRadius: 20))
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, 32)
                .opacity(phase >= 3 ? 1 : 0)
                .animation(Theme.Motion.glide.delay(0.2), value: phase)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Haptic.success()
            withAnimation(Theme.Motion.glide) { phase = 1 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                withAnimation(Theme.Motion.glide) { phase = 2 }
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                withAnimation(Theme.Motion.glide) { phase = 3 }
            }
        }
    }

    private func statTile(label: String, value: String, suffix: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(Theme.Font.label)
                .kerning(1.4)
                .foregroundStyle(.silver)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(Theme.Font.display(40))
                    .foregroundStyle(.pearl)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let suffix {
                    Text(suffix)
                        .font(Theme.Font.body(12))
                        .foregroundStyle(.shadowTxt)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.md)
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
    }
}
