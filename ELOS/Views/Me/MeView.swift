import SwiftUI
import SwiftData

struct YouView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.skin) private var skin
    @Environment(\.modelContext) private var ctx

    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \PersonalRecord.dateAchieved, order: .reverse) private var prs: [PersonalRecord]

    @State private var showEditProfile = false
    @State private var showPlateSetup = false
    @State private var resetConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileHeader
                        .padding(.horizontal, 16).padding(.top, 8)

                    statsRow
                        .padding(.horizontal, 14)

                    SectionLabel(title: "Preferences")
                    preferencesCard.padding(.horizontal, 14)

                    SectionLabel(title: "Workout")
                    workoutCard.padding(.horizontal, 14)

                    SectionLabel(title: "Body")
                    bodyCard.padding(.horizontal, 14)

                    SectionLabel(title: "Integrations")
                    integrationsCard.padding(.horizontal, 14)

                    SectionLabel(title: "Danger Zone")
                    dangerCard.padding(.horizontal, 14)

                    aboutFooter

                    Spacer(minLength: 50)
                }
            }
            .background(skin.background.ignoresSafeArea())
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEditProfile) { EditProfileSheet() }
            .sheet(isPresented: $showPlateSetup) { PlateSetupSheet() }
        }
    }

    // MARK: Profile header

    private var profileHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.brand, Color.brand.opacity(0.6)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(initials)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.displayName.isEmpty ? "Set your name" : appState.displayName)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Text("\(appState.experience.label.capitalized) lifter")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { showEditProfile = true } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.brand)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 4)
    }

    private var initials: String {
        let parts = appState.displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        let s = letters.joined().uppercased()
        return s.isEmpty ? "ME" : s
    }

    // MARK: Stats row

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(label: "Workouts", value: "\(sessions.count)",
                     icon: "checkmark.circle.fill", accent: .brand)
            StatTile(label: "PRs", value: "\(prs.count)",
                     icon: "trophy.fill", accent: .brandTrophy)
            StatTile(label: "Streak", value: "\(appState.currentStreak)",
                     icon: "flame.fill", accent: .brandWarn)
        }
    }

    // MARK: Cards

    private var preferencesCard: some View {
        @Bindable var s = appState
        return SolidCard(padding: 0) {
            VStack(spacing: 0) {
                row("Theme", icon: "swatchpalette.fill") {
                    HStack(spacing: 10) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            ThemeSwatch(mode: mode, isSelected: s.themeMode == mode) {
                                s.themeMode = mode; Haptic.selection()
                            }
                        }
                    }
                }
                Hairline(inset: 16)
                row("Units", icon: "scalemass") {
                    Picker("", selection: $s.units) {
                        Text("lbs").tag(WeightUnit.imperial)
                        Text("kg").tag(WeightUnit.metric)
                    }
                    .pickerStyle(.segmented).frame(width: 110)
                }
                Hairline(inset: 16)
                row("Haptics", icon: "iphone.radiowaves.left.and.right") {
                    Toggle("", isOn: $s.hapticsEnabled).labelsHidden()
                }
                Hairline(inset: 16)
                row("Sounds", icon: "speaker.wave.2.fill") {
                    Toggle("", isOn: $s.soundsEnabled).labelsHidden()
                }
            }
        }
    }

    private var workoutCard: some View {
        @Bindable var s = appState
        return SolidCard(padding: 0) {
            VStack(spacing: 0) {
                row("Default Rest Timer", icon: "clock.fill") {
                    Stepper(value: $s.defaultRestSeconds, in: 30...300, step: 15) {
                        Text("\(s.defaultRestSeconds)s")
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    }
                    .labelsHidden()
                }
                Hairline(inset: 16)
                row("Plate Setup", icon: "circle.grid.2x2.fill") {
                    Button("Edit") { showPlateSetup = true }
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.brand)
                }
                Hairline(inset: 16)
                row("Bar Weight", icon: "minus.circle.fill") {
                    HStack(spacing: 4) {
                        Text(s.units.from(kg: s.barWeightKg).prettyWeight)
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        Text(s.units.label).font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var bodyCard: some View {
        @Bindable var s = appState
        return SolidCard(padding: 0) {
            VStack(spacing: 0) {
                row("Bodyweight", icon: "figure.stand") {
                    HStack(spacing: 4) {
                        TextField("", value: Binding(
                            get: { s.units.from(kg: s.bodyweightKg) },
                            set: { s.bodyweightKg = s.units.toKg($0) }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        Text(s.units.label).font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.secondary)
                    }
                }
                Hairline(inset: 16)
                row("Height", icon: "ruler") {
                    HStack(spacing: 4) {
                        TextField("", value: $s.heightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("cm").font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.secondary)
                    }
                }
                Hairline(inset: 16)
                row("Experience", icon: "star.fill") {
                    Picker("", selection: $s.experience) {
                        ForEach(Experience.allCases, id: \.self) { e in
                            Text(e.label.capitalized).tag(e)
                        }
                    }
                    .pickerStyle(.menu).labelsHidden()
                }
            }
        }
    }

    private var integrationsCard: some View {
        @Bindable var s = appState
        return SolidCard(padding: 0) {
            VStack(spacing: 0) {
                row("Apple Health", icon: "heart.fill") {
                    Toggle("", isOn: $s.healthKitEnabled).labelsHidden().tint(.pink)
                }
            }
        }
    }

    private var dangerCard: some View {
        SolidCard(padding: 0) {
            VStack(spacing: 0) {
                Button {
                    resetConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .foregroundStyle(.brandDanger)
                        Text("Reset onboarding")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.brandDanger)
                        Spacer()
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
                .alert("Reset onboarding?", isPresented: $resetConfirm) {
                    Button("Reset", role: .destructive) {
                        appState.hasCompletedOnboarding = false
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your data is kept; you'll just see the welcome screens again.")
                }
            }
        }
    }

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Text("ELOS")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.brand)
            Text("Built natively in SwiftUI · v1.0")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 14)
    }

    // MARK: helpers

    @ViewBuilder
    private func row<Trail: View>(_ title: String, icon: String, @ViewBuilder trail: () -> Trail) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.brand.opacity(0.14))
                Image(systemName: icon).font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.brand)
            }
            .frame(width: 30, height: 30)
            Text(title).font(.system(size: 14, weight: .heavy, design: .rounded))
            Spacer()
            trail()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - Theme swatch

private struct ThemeSwatch: View {
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let sk = ThemeSkin.forMode(mode)
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(sk.background == Color(hex: "#F5F5F7") ? sk.background : Color(hex: "#1C1C1E"))
                Circle()
                    .fill(sk.accent)
                    .scaleEffect(0.45)
                if isSelected {
                    Circle().strokeBorder(sk.accent, lineWidth: 2)
                } else {
                    Circle().strokeBorder(Color(hex: "#48484A"), lineWidth: 0.5)
                }
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit profile sheet

struct EditProfileSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") {
                    TextField("Your name", text: $name)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.displayName = name
                        Haptic.success()
                        dismiss()
                    }
                }
            }
            .onAppear { name = appState.displayName }
        }
    }
}

// MARK: - Plate setup sheet

struct PlateSetupSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let allPlatesKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25, 1.0, 0.5]

    var body: some View {
        @Bindable var s = appState
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $s.barWeightKg, in: 5...30, step: 2.5) {
                        HStack {
                            Text("Bar Weight")
                            Spacer()
                            Text(formatKg(s.barWeightKg))
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: { Text("Olympic Bar") }

                Section {
                    ForEach(allPlatesKg, id: \.self) { kg in
                        Toggle(formatKg(kg), isOn: Binding(
                            get: { appState.availablePlatesKg.contains(kg) },
                            set: { isOn in
                                if isOn {
                                    if !appState.availablePlatesKg.contains(kg) {
                                        appState.availablePlatesKg = (appState.availablePlatesKg + [kg]).sorted(by: >)
                                    }
                                } else {
                                    appState.availablePlatesKg.removeAll { $0 == kg }
                                }
                            }
                        ))
                    }
                } header: { Text("Plates Available (per side)") }
                  footer: { Text("These are used to calculate the plates you need to load on the bar.") }
            }
            .navigationTitle("Plate Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func formatKg(_ kg: Double) -> String {
        let v = appState.units.from(kg: kg)
        return "\(v.prettyWeight) \(appState.units.label)"
    }
}
