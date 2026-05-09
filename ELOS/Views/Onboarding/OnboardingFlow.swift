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
            background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                progressDots.padding(.top, 50)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
                    .padding(.horizontal, 18)
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

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(hex: "#1A0E0A"), Color(hex: "#2A0F08")],
                startPoint: .top, endPoint: .bottom
            )
            // Big radial glow that follows the page
            RadialGradient(
                colors: [Color.brand.opacity(0.45), .clear],
                center: page == 0 ? .topLeading : (page == 1 ? .center : .bottomTrailing),
                startRadius: 0, endRadius: 380
            )
            .blur(radius: 20)
            .animation(.easeInOut(duration: 0.6), value: page)
        }
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.brand : Color.white.opacity(0.25))
                    .frame(width: i == page ? 28 : 10, height: 6)
                    .animation(Theme.Motion.snappy, value: page)
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
                    withAnimation(Theme.Motion.snappy) { page -= 1 }
                    Haptic.light()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.12), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                }
                .buttonStyle(.pressable(scale: 0.92, haptic: .none))
            }

            Button {
                handleNext()
            } label: {
                HStack(spacing: 8) {
                    Text(page == 3 ? "Get Started" : "Continue")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                    Image(systemName: page == 3 ? "checkmark" : "arrow.right")
                        .font(.system(size: 14, weight: .black))
                }
                .foregroundStyle(.brand)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.pressable(scale: 0.97, haptic: .heavy))
            .disabled(page == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(page == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
        }
    }

    private func handleNext() {
        if page < 3 {
            withAnimation(Theme.Motion.snappy) { page += 1 }
            Haptic.medium()
        } else {
            // Finalize
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
    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.15))
                    .frame(width: 200, height: 200)
                Circle()
                    .fill(Color.brand.opacity(0.25))
                    .frame(width: 150, height: 150)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(.brand)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
            }
            VStack(spacing: 10) {
                Text("ELOS")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .kerning(2)
                Text("Train. Track. Transcend.")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                bullet(icon: "bolt.fill", title: "Smart progressive overload",
                       sub: "Personalized weight suggestions every set")
                bullet(icon: "trophy.fill", title: "Auto PR detection",
                       sub: "Confetti-worthy moments, captured")
                bullet(icon: "chart.line.uptrend.xyaxis", title: "Beautiful analytics",
                       sub: "See your strength compound, week by week")
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                iconScale = 1.0; iconOpacity = 1.0
            }
        }
    }

    private func bullet(icon: String, title: String, sub: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.brand.opacity(0.18))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.brand)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(sub)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
    }
}

// MARK: - Name

private struct NamePage: View {
    @Binding var name: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("What should we\ncall you?")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("This is shown on your dashboard and home screen.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
            TextField("", text: $name, prompt: Text("Your first name").foregroundStyle(Color.white.opacity(0.4)))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.vertical, 14).padding(.horizontal, 16)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                )
                .focused($focused)
                .submitLabel(.done)
            Spacer()
        }
        .padding(.horizontal, 24)
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
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tell us about\nyourself")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Used for plate calculations and analytics.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                }

                VStack(alignment: .leading, spacing: 8) {
                    label("Units")
                    HStack(spacing: 6) {
                        unitChip("Pounds (lbs)", selected: units == .imperial) { units = .imperial }
                        unitChip("Kilograms (kg)", selected: units == .metric) { units = .metric }
                    }
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
                    VStack(spacing: 6) {
                        ForEach(Experience.allCases, id: \.self) { e in
                            expRow(e)
                        }
                    }
                }
            }
            .padding(.horizontal, 24).padding(.top, 30)
        }
    }

    private func label(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .kerning(0.6)
            .foregroundStyle(.white.opacity(0.5))
    }

    private func unitChip(_ s: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); Haptic.selection() } label: {
            Text(s)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(selected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.white : Color.white.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func expRow(_ e: Experience) -> some View {
        Button { experience = e; Haptic.selection() } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(e.label.capitalized)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(e.description)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: experience == e ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(experience == e ? .brand : .white.opacity(0.3))
            }
            .padding(14)
            .background(.white.opacity(experience == e ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(experience == e ? Color.brand.opacity(0.6) : .white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func onboardingNumberField(value: Binding<Double>) -> some View {
        TextField("", value: value, format: .number.precision(.fractionLength(0...1)))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.leading)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 14).padding(.horizontal, 16)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
    }
}

// MARK: - Program selection

private struct ProgramPage: View {
    @Binding var programId: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pick a starting\nprogram")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Change anytime in the Train tab.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.bottom, 8)

                ForEach(Program.library) { p in
                    Button { programId = p.id; Haptic.selection() } label: {
                        ProgramCard(program: p, selected: programId == p.id)
                    }
                    .buttonStyle(.pressable(scale: 0.97, haptic: .none))
                }
            }
            .padding(.horizontal, 24).padding(.top, 30)
        }
    }
}

private struct ProgramCard: View {
    let program: Program
    let selected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [program.accent, program.accent.opacity(0.6)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: program.icon)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(program.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(selected ? .brand : .white.opacity(0.3))
        }
        .padding(14)
        .background(.white.opacity(selected ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? Color.brand.opacity(0.6) : .white.opacity(0.1), lineWidth: 1)
        )
    }
}
