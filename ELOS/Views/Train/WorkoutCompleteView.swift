import SwiftUI

struct WorkoutCompleteView: View {
    let data: WorkoutCompleteData
    let units: WeightUnit
    let onDone: () -> Void

    @State private var phase: Int = 0
    @State private var confettiTrigger = 0

    private var formattedVolume: String {
        let v = units.from(kg: data.totalVolumeKg)
        if v >= 10000 { return String(format: "%.1fk %@", v/1000, units.label) }
        if v >= 1000  { return String(format: "%.1fk %@", v/1000, units.label) }
        return String(format: "%.0f %@", v, units.label)
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.brand,
                    Color.brand.opacity(0.55),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 30)
                checkmark
                    .padding(.top, 40)
                titleBlock
                    .padding(.top, 22)
                Spacer(minLength: 16)
                statGrid
                    .padding(.horizontal, 16)
                if !data.newPRs.isEmpty {
                    prSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
                Spacer()
                Button {
                    Haptic.success(); onDone()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.pressable(scale: 0.97, haptic: .none))
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }

            ConfettiOverlay(trigger: confettiTrigger).ignoresSafeArea()
        }
        .onAppear {
            Haptic.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { phase = 1 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { phase = 2 }
                if !data.newPRs.isEmpty { confettiTrigger += 1 }
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { phase = 3 }
            }
        }
    }

    // MARK: Pieces

    private var checkmark: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 168, height: 168)
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 130, height: 130)
            Image(systemName: "checkmark")
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(.white)
                .scaleEffect(phase >= 1 ? 1 : 0.3)
                .opacity(phase >= 1 ? 1 : 0)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Workout complete")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? 0 : 14)
            Text(data.title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? 0 : 14)
            Text(data.subtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? 0 : 14)
        }
    }

    private var statGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: cols, spacing: 10) {
            CompletionTile(label: "DURATION", value: "\(data.durationMinutes) min", icon: "clock.fill")
            CompletionTile(label: "SETS",     value: "\(data.totalSets)",            icon: "list.number")
            CompletionTile(label: "VOLUME",   value: formattedVolume,                icon: "scalemass.fill")
            CompletionTile(label: "EXERCISES", value: "\(data.exerciseCount)",       icon: "dumbbell.fill")
        }
        .opacity(phase >= 3 ? 1 : 0)
        .offset(y: phase >= 3 ? 0 : 24)
    }

    private var prSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.brandTrophy)
                Text("\(data.newPRs.count) New \(data.newPRs.count == 1 ? "PR" : "PRs")")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.brandTrophy)
                Spacer()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 6) {
                ForEach(data.newPRs, id: \.self) { name in
                    HStack(spacing: 8) {
                        Image(systemName: "rosette")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.brandTrophy)
                        Text(name)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                    )
                }
            }
        }
        .opacity(phase >= 3 ? 1 : 0)
        .offset(y: phase >= 3 ? 0 : 24)
    }
}

private struct CompletionTile: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(0.6)
            }
            .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        )
    }
}
