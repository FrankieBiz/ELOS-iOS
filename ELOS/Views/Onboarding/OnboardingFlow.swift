import SwiftUI

struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    @State private var page: Int = 0
    @State private var name: String = ""
    @State private var bodyweightDisplay: Double = 165
    @State private var heightCm: Double = 178
    @State private var experience: Experience = .intermediate
    @State private var units: WeightUnit = .imperial
    @State private var programId: String = "ppl_default"

    var body: some View {
        ZStack {
            Color.obsidian.ignoresSafeArea()

            VStack(spacing: 0) {
                pageIndicator
                    .padding(.top, 60)
                    .padding(.horizontal, Theme.Space.md)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            name = appState.displayName
            units = appState.units
            heightCm = appState.heightCm
            bodyweightDisplay = appState.units.from(kg: appState.bodyweightKg.nonZero ?? 75)
        }
    }

    // MARK: Page indicator — 4 thin rules

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(i <= page ? Color.pearl : Color.mist)
                    .frame(height: 1.5)
                    .animation(Theme.Motion.silk, value: page)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case 0: WelcomePage()
        case 1: NamePage(name: $name)
        case 2: BodyPage(
                    bodyweight: $bodyweightDisplay,
                    height: $heightCm,
                    experience: $experience,
                    units: $units
                )
        default: ProgramPage(programId: $programId)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if page > 0 {
                Button {
                    withAnimation(Theme.Motion.silk) { page -= 1 }
                    Haptic.light()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .thin))
                        .foregroundStyle(.silver)
                        .frame(width: 56, height: 56)
                        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .edgeHighlight(radius: Theme.Radius.md)
                }
                .buttonStyle(.pressable(scale: 0.94, haptic: .none, glow: false))
            }

            Button {
                handleNext()
            } label: {
                HStack(spacing: 10) {
                    Text(page == 3 ? "Get started" : "Continue")
                        .font(Theme.Font.title(17))
                    Image(systemName: page == 3 ? "checkmark" : "arrow.right")
                        .font(.system(size: 14, weight: .thin))
                }
                .foregroundStyle(Color.obsidian)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: [Color.pearl.opacity(0.97), .pearl], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                )
                .breathGlow(minIntensity: 0.10, maxIntensity: 0.28, radius: 16)
            }
            .buttonStyle(.pressable(scale: 0.985, haptic: .none, glow: true, glowRadius: 20))
            .disabled(page == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(page == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1.0)
        }
    }

    private func handleNext() {
        if page < 3 {
            withAnimation(Theme.Motion.silk) { page += 1 }
            Haptic.medium()
        } else {
            appState.displayName = name
            appState.units = units
            appState.heightCm = heightCm
            appState.bodyweightKg = units.toKg(bodyweightDisplay)
            appState.experience = experience
            appState.activeProgramId = programId
            appState.programStartDate = .now
            Haptic.success()
            withAnimation(Theme.Motion.glide) {
                appState.hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Welcome

private struct WelcomePage: View {
    @State private var phase: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 28) {
                // Wordmark
                VStack(alignment: .leading, spacing: 8) {
                    Text("ELOS")
                        .font(.system(size: 72, weight: .ultraLight, design: .default))
                        .foregroundStyle(.pearl)
                        .kerning(6)
                        .opacity(phase >= 1 ? 1 : 0)
                        .offset(y: phase >= 1 ? 0 : 16)

                    Rectangle()
                        .fill(Color.pearl.opacity(0.2))
                        .frame(height: 0.5)
                        .scaleEffect(x: phase >= 2 ? 1 : 0, anchor: .leading)
                }

                // Feature lines
                VStack(alignment: .leading, spacing: 16) {
                    featureLine("Smart progressive overload",   "Personalized weight, every set")
                    featureLine("Personal record detection",    "Captured the moment you break one")
                    featureLine("Performance analytics",        "Volume, streaks, and 1RM trends")
                }
                .opacity(phase >= 3 ? 1 : 0)
                .offset(y: phase >= 3 ? 0 : 12)
            }
            .padding(.horizontal, Theme.Space.md)

            Spacer()
        }
        .onAppear {
            withAnimation(Theme.Motion.silk) { phase = 1 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                withAnimation(Theme.Motion.glide) { phase = 2 }
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(Theme.Motion.silk) { phase = 3 }
            }
        }
    }

    private func featureLine(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.Font.heading(15))
                .foregroundStyle(.pearl)
            Text(sub)
                .font(Theme.Font.body(13))
                .foregroundStyle(.silver)
        }
    }
}

// MARK: - Name

private struct NamePage: View {
    @Binding var name: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("What should we\ncall you?")
                    .font(Theme.Font.display(40))
                    .foregroundStyle(.pearl)
                    .lineSpacing(4)

                Text("Shown on your dashboard.")
                    .font(Theme.Font.body(14))
                    .foregroundStyle(.silver)
            }
            .padding(.horizontal, Theme.Space.md)

            Spacer().frame(height: 32)

            // Underline-only input
            VStack(spacing: 0) {
                TextField("", text: $name, prompt: Text("Your name").foregroundStyle(Color.shadowTxt))
                    .font(Theme.Font.title(28))
                    .foregroundStyle(.pearl)
                    .focused($focused)
                    .submitLabel(.done)
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, 12)

                Rectangle()
                    .fill(focused ? Color.pearl : Color.mist)
                    .frame(height: 0.75)
                    .padding(.horizontal, Theme.Space.md)
                    .animation(Theme.Motion.silk, value: focused)
            }

            Spacer()
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                focused = true
            }
        }
    }
}

// MARK: - Body / experience / units

private struct BodyPage: View {
    @Binding var bodyweight: Double
    @Binding var height: Double
    @Binding var experience: Experience
    @Binding var units: WeightUnit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configure\nyour profile")
                        .font(Theme.Font.display(36))
                        .foregroundStyle(.pearl)
                        .lineSpacing(4)
                    Text("Used for plate calculations and analytics.")
                        .font(Theme.Font.body(13))
                        .foregroundStyle(.silver)
                }
                .padding(.top, 20)

                // Units
                fieldLabel("Units")
                HStack(spacing: 0) {
                    unitChip("lbs", selected: units == .imperial) { units = .imperial }
                    unitChip("kg",  selected: units == .metric)   { units = .metric }
                }
                .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .edgeHighlight(radius: Theme.Radius.md)

                // Bodyweight
                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("Bodyweight (\(units.label))")
                    underlineField(value: $bodyweight)
                }

                // Height
                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("Height (cm)")
                    underlineField(value: $height)
                }

                // Experience
                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("Experience")
                    VStack(spacing: 0) {
                        ForEach(Array(Experience.allCases.enumerated()), id: \.offset) { i, e in
                            expRow(e)
                            if i < Experience.allCases.count - 1 {
                                Hairline().padding(.horizontal, Theme.Space.md)
                            }
                        }
                    }
                    .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    .edgeHighlight(radius: Theme.Radius.md)
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.bottom, 30)
        }
    }

    private func fieldLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(Theme.Font.label)
            .kerning(1.4)
            .foregroundStyle(.silver)
    }

    private func unitChip(_ s: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); Haptic.selection() } label: {
            Text(s)
                .font(Theme.Font.body(14, .medium))
                .foregroundStyle(selected ? Color.obsidian : Color.silver)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? Color.pearl : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func expRow(_ e: Experience) -> some View {
        Button { experience = e; Haptic.selection() } label: {
            HStack(spacing: 14) {
                Rectangle()
                    .fill(experience == e ? Color.pearl : Color.clear)
                    .frame(width: 2, height: 36)
                    .animation(Theme.Motion.silk, value: experience == e)

                VStack(alignment: .leading, spacing: 3) {
                    Text(e.label)
                        .font(Theme.Font.heading(14))
                        .foregroundStyle(.pearl)
                    Text(e.description)
                        .font(Theme.Font.body(12))
                        .foregroundStyle(.silver)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .background(experience == e ? Color.pearl.opacity(0.04) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func underlineField(value: Binding<Double>) -> some View {
        VStack(spacing: 0) {
            TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .font(Theme.Font.title(26))
                .foregroundStyle(.pearl)
                .padding(.bottom, 10)

            Rectangle()
                .fill(Color.mist)
                .frame(height: 0.75)
        }
    }
}

// MARK: - Program selection

private struct ProgramPage: View {
    @Binding var programId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pick a\nprogram")
                        .font(Theme.Font.display(36))
                        .foregroundStyle(.pearl)
                        .lineSpacing(4)
                    Text("Change anytime in the Train tab.")
                        .font(Theme.Font.body(13))
                        .foregroundStyle(.silver)
                }
                .padding(.top, 20)

                VStack(spacing: 0) {
                    ForEach(Array(Program.library.enumerated()), id: \.element.id) { i, p in
                        Button { programId = p.id; Haptic.selection() } label: {
                            programRow(p, selected: programId == p.id)
                        }
                        .buttonStyle(.pressable(scale: 0.99, haptic: .none, glow: false))
                        if i < Program.library.count - 1 {
                            Hairline().padding(.horizontal, Theme.Space.md)
                        }
                    }
                }
                .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .edgeHighlight(radius: Theme.Radius.md)
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.bottom, 30)
        }
    }

    private func programRow(_ p: Program, selected: Bool) -> some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(selected ? Color.pearl : Color.clear)
                .frame(width: 2, height: 38)
                .animation(Theme.Motion.silk, value: selected)

            VStack(alignment: .leading, spacing: 3) {
                Text(p.name)
                    .font(Theme.Font.heading(14))
                    .foregroundStyle(.pearl)
                Text(p.subtitle)
                    .font(Theme.Font.body(12))
                    .foregroundStyle(.silver)
            }
            Spacer()
            Image(systemName: selected ? "checkmark" : "circle")
                .font(.system(size: 13, weight: .thin))
                .foregroundStyle(selected ? Color.pearl : Color.shadowTxt)
        }
        .padding(.vertical, 16)
        .background(selected ? Color.pearl.opacity(0.04) : Color.clear)
    }
}
