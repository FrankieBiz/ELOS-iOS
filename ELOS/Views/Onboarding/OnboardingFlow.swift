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
            Color.vBG.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar.padding(.top, 50)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.bottom, 28)
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

    // MARK: top status bar

    private var topBar: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Rectangle().fill(Color.vSignal).frame(width: 12, height: 2)
                    Text("ELOS · VIGIL")
                        .font(.system(size: 10, weight: .black))
                        .kerning(2.0)
                        .foregroundStyle(.vLabelMute)
                }
                Spacer()
                Text(String(format: "%02d / 04", page + 1))
                    .font(Theme.Font.mono(10, .black))
                    .foregroundStyle(.vLabelMute)
            }
            .padding(.horizontal, Theme.Space.md)

            // Progress indicator (segments)
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Rectangle()
                        .fill(i <= page ? Color.vSignal : Color.vSurfaceHigh)
                        .frame(height: 3)
                        .animation(Theme.Motion.snappy, value: page)
                }
            }
            .padding(.horizontal, Theme.Space.md)
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
        HStack(spacing: 8) {
            if page > 0 {
                Button {
                    withAnimation(Theme.Motion.snappy) { page -= 1 }
                    Haptic.light()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.vLabel)
                        .frame(width: 52, height: 52)
                        .background(Color.vSurface)
                        .overlay(Rectangle().strokeBorder(Color.vLineHigh, lineWidth: 0.5))
                }
                .buttonStyle(.pressable(scale: 0.94, haptic: .none))
            }

            Button {
                handleNext()
            } label: {
                HStack(spacing: 8) {
                    Text(page == 3 ? "ENTER" : "CONTINUE")
                        .font(.system(size: 13, weight: .black))
                        .kerning(1.6)
                    Image(systemName: page == 3 ? "checkmark" : "arrow.right")
                        .font(.system(size: 12, weight: .black))
                }
                .foregroundStyle(.vBG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.vSignal)
            }
            .buttonStyle(.pressable(scale: 0.98, haptic: .heavy))
            .disabled(page == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(page == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1.0)
        }
    }

    private func handleNext() {
        if page < 3 {
            withAnimation(Theme.Motion.snappy) { page += 1 }
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
            withAnimation(.easeInOut(duration: 0.4)) {
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

            // Logo block
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Rectangle()
                        .fill(Color.vSignal)
                        .frame(width: 64, height: 64)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.vBG)
                }
                .scaleEffect(phase >= 1 ? 1 : 0.6)
                .opacity(phase >= 1 ? 1 : 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ELOS")
                        .font(Theme.Font.display(72))
                        .foregroundStyle(.vLabel)
                        .kerning(-1)
                    HStack(spacing: 6) {
                        Rectangle().fill(Color.vSignal).frame(width: 12, height: 2)
                        Text("VIGIL EDITION")
                            .font(.system(size: 11, weight: .heavy))
                            .kerning(2.4)
                            .foregroundStyle(.vSignal)
                    }
                }
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: phase >= 2 ? 0 : 14)
            }
            .padding(.horizontal, Theme.Space.lg)

            Spacer().frame(height: 40)

            VStack(alignment: .leading, spacing: 0) {
                bullet(n: 1, title: "Smart Progressive Overload", sub: "Personalized weight suggestions every set")
                Hairline()
                bullet(n: 2, title: "Auto PR Detection", sub: "Captured the moment you break a record")
                Hairline()
                bullet(n: 3, title: "Tactical Analytics", sub: "Volume, streaks, and 1RM trends")
            }
            .background(Color.vSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .strokeBorder(Color.vLine, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .padding(.horizontal, Theme.Space.md)
            .opacity(phase >= 3 ? 1 : 0)
            .offset(y: phase >= 3 ? 0 : 14)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { phase = 1 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { phase = 2 }
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { phase = 3 }
            }
        }
    }

    private func bullet(n: Int, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            IndexBadge(n: n, active: true, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .kerning(0.6)
                    .foregroundStyle(.vLabel)
                Text(sub)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.vLabelMute)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
    }
}

// MARK: - Name

private struct NamePage: View {
    @Binding var name: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            Text("CALL SIGN")
                .font(.system(size: 10, weight: .heavy))
                .kerning(2.4)
                .foregroundStyle(.vSignal)
            Text("WHAT SHOULD\nWE CALL YOU?")
                .font(Theme.Font.display(40))
                .foregroundStyle(.vLabel)
                .kerning(-0.5)
                .lineSpacing(-4)
            Text("Shown on your dashboard.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.vLabelMute)

            Spacer().frame(height: 16)

            TextField("", text: $name, prompt: Text("YOUR NAME").foregroundStyle(Color.vLabelFaint))
                .font(Theme.Font.mono(22, .black))
                .foregroundStyle(.vLabel)
                .padding(.horizontal, 14).padding(.vertical, 16)
                .background(Color.vSurface)
                .overlay(Rectangle().strokeBorder(Color.vSignal, lineWidth: 1))
                .focused($focused)
                .submitLabel(.done)

            Spacer()
        }
        .padding(.horizontal, Theme.Space.md)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
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
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROFILE")
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(2.4)
                        .foregroundStyle(.vSignal)
                    Text("CONFIGURE\nLOADOUT")
                        .font(Theme.Font.display(36))
                        .foregroundStyle(.vLabel)
                        .kerning(-0.5)
                        .lineSpacing(-4)
                    Text("Used for plate calc and analytics.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.vLabelMute)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 8) {
                    label("Units")
                    HStack(spacing: 0) {
                        unitChip("LBS", selected: units == .imperial) { units = .imperial }
                        unitChip("KG",  selected: units == .metric)   { units = .metric   }
                    }
                    .overlay(Rectangle().strokeBorder(Color.vLine, lineWidth: 0.5))
                }

                VStack(alignment: .leading, spacing: 8) {
                    label("Bodyweight (\(units.label))")
                    onboardingNumberField(value: $bodyweight)
                }

                VStack(alignment: .leading, spacing: 8) {
                    label("Height (cm)")
                    onboardingNumberField(value: $height)
                }

                VStack(alignment: .leading, spacing: 8) {
                    label("Experience")
                    VStack(spacing: 0) {
                        ForEach(Array(Experience.allCases.enumerated()), id: \.offset) { i, e in
                            expRow(e, last: i == Experience.allCases.count - 1)
                            if i < Experience.allCases.count - 1 { Hairline() }
                        }
                    }
                    .background(Color.vSurface)
                    .overlay(Rectangle().strokeBorder(Color.vLine, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.bottom, 30)
        }
    }

    private func label(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .kerning(1.4)
            .foregroundStyle(.vLabelMute)
    }

    private func unitChip(_ s: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); Haptic.selection() } label: {
            Text(s)
                .font(.system(size: 12, weight: .black))
                .kerning(1.4)
                .foregroundStyle(selected ? Color.vBG : Color.vLabelMute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected ? Color.vSignal : Color.vSurface)
        }
        .buttonStyle(.plain)
    }

    private func expRow(_ e: Experience, last: Bool) -> some View {
        Button { experience = e; Haptic.selection() } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.label.uppercased())
                        .font(.system(size: 12, weight: .black))
                        .kerning(0.6)
                        .foregroundStyle(.vLabel)
                    Text(e.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.vLabelMute)
                }
                Spacer()
                Image(systemName: experience == e ? "checkmark" : "circle")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(experience == e ? Color.vSignal : Color.vLabelFaint)
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(experience == e ? Color.vSignal.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func onboardingNumberField(value: Binding<Double>) -> some View {
        TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.leading)
            .font(Theme.Font.mono(22, .black))
            .foregroundStyle(.vLabel)
            .padding(.horizontal, 14).padding(.vertical, 14)
            .background(Color.vSurface)
            .overlay(Rectangle().strokeBorder(Color.vLineHigh, lineWidth: 0.5))
    }
}

// MARK: - Program selection

private struct ProgramPage: View {
    @Binding var programId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MISSION")
                        .font(.system(size: 10, weight: .heavy))
                        .kerning(2.4)
                        .foregroundStyle(.vSignal)
                    Text("PICK A\nPROGRAM")
                        .font(Theme.Font.display(36))
                        .foregroundStyle(.vLabel)
                        .kerning(-0.5)
                        .lineSpacing(-4)
                    Text("Change anytime in the Train tab.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.vLabelMute)
                }
                .padding(.top, 20)

                VStack(spacing: 0) {
                    ForEach(Array(Program.library.enumerated()), id: \.element.id) { i, p in
                        Button { programId = p.id; Haptic.selection() } label: {
                            ProgramCard(index: i + 1, program: p, selected: programId == p.id)
                        }
                        .buttonStyle(.pressable(scale: 0.99, haptic: .none))
                        if i < Program.library.count - 1 { Hairline().padding(.leading, 50) }
                    }
                }
                .background(Color.vSurface)
                .overlay(Rectangle().strokeBorder(Color.vLine, lineWidth: 0.5))
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.bottom, 30)
        }
    }
}

private struct ProgramCard: View {
    let index: Int
    let program: Program
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            IndexBadge(n: index, active: selected, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .kerning(0.6)
                    .foregroundStyle(.vLabel)
                Text(program.subtitle.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(.vLabelMute)
            }
            Spacer()
            Image(systemName: selected ? "checkmark" : "circle")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(selected ? Color.vSignal : Color.vLabelFaint)
        }
        .padding(.horizontal, 10).padding(.vertical, 12)
        .background(selected ? Color.vSignal.opacity(0.06) : Color.clear)
    }
}
