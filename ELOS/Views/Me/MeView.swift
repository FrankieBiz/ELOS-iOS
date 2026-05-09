import SwiftUI
import SwiftData

struct YouView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var ctx

    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \PersonalRecord.dateAchieved, order: .reverse) private var prs: [PersonalRecord]

    @State private var showEditProfile = false
    @State private var showPlateSetup = false
    @State private var resetConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                        .padding(.horizontal, Theme.Space.md)
                        .padding(.top, Theme.Space.md)

                    Hairline()
                        .padding(.top, Theme.Space.md)

                    HStack(spacing: 10) {
                        StatTile(label: "Sessions", value: "\(sessions.count)")
                        StatTile(label: "Records", value: "\(prs.count)")
                        StatTile(label: "Streak", value: "\(appState.currentStreak)")
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, Theme.Space.md)

                    SectionLabel(title: "Preferences")
                    preferencesCard.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Workout")
                    workoutCard.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Body")
                    bodyCard.padding(.horizontal, Theme.Space.md)

                    SectionLabel(title: "Integrations")
                    integrationsCard.padding(.horizontal, Theme.Space.md)

                    // Danger — understated, tertiary
                    VStack(spacing: 0) {
                        Button {
                            resetConfirm = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12, weight: .thin))
                                    .foregroundStyle(.crimson)
                                Text("Reset onboarding")
                                    .font(Theme.Font.body(14))
                                    .foregroundStyle(.crimson)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.pressable(scale: 0.99, haptic: .none, glow: false))
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.top, Theme.Space.xl)
                    .alert("Reset onboarding?", isPresented: $resetConfirm) {
                        Button("Reset", role: .destructive) { appState.hasCompletedOnboarding = false }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Your data is kept. You'll just see the welcome screens again.")
                    }

                    aboutFooter
                    Spacer(minLength: 100)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.obsidian.ignoresSafeArea())
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEditProfile) { EditProfileSheet() }
            .sheet(isPresented: $showPlateSetup) { PlateSetupSheet() }
        }
    }

    // MARK: Profile header

    private var profileHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.graphite)
                    .frame(width: 60, height: 60)
                    .edgeHighlight(radius: 30)
                Text(initials)
                    .font(Theme.Font.mono(20, .regular))
                    .foregroundStyle(.pearl)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.displayName.isEmpty ? "Set your name" : appState.displayName)
                    .font(Theme.Font.title(22))
                    .foregroundStyle(.pearl)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    StatusDot(color: .pearl, size: 4)
                    Text("\(appState.experience.label) · Member".uppercased())
                        .font(Theme.Font.label)
                        .kerning(1.0)
                        .foregroundStyle(.silver)
                }
            }
            Spacer()
            Button { showEditProfile = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .thin))
                    .foregroundStyle(.silver)
                    .frame(width: 36, height: 36)
                    .background(Color.graphite, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .edgeHighlight(radius: Theme.Radius.sm)
            }
            .buttonStyle(.pressable(scale: 0.92, haptic: .light, glow: false))
        }
    }

    private var initials: String {
        let parts = appState.displayName.split(separator: " ")
        let s = parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
        return s.isEmpty ? "ME" : s
    }

    // MARK: Settings cards

    private var preferencesCard: some View {
        @Bindable var s = appState
        return VStack(spacing: 0) {
            row("Units", icon: "scalemass") {
                Picker("", selection: $s.units) {
                    Text("lbs").tag(WeightUnit.imperial)
                    Text("kg").tag(WeightUnit.metric)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            Hairline().padding(.horizontal, Theme.Space.md)
            row("Haptics", icon: "iphone.radiowaves.left.and.right") {
                Toggle("", isOn: $s.hapticsEnabled).labelsHidden().tint(.pearl)
            }
            Hairline().padding(.horizontal, Theme.Space.md)
            row("Sounds", icon: "speaker.wave.2") {
                Toggle("", isOn: $s.soundsEnabled).labelsHidden().tint(.pearl)
            }
        }
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
    }

    private var workoutCard: some View {
        @Bindable var s = appState
        return VStack(spacing: 0) {
            row("Default rest", icon: "clock") {
                Stepper(value: $s.defaultRestSeconds, in: 30...300, step: 15) {
                    Text("\(s.defaultRestSeconds)s")
                        .font(Theme.Font.mono(13, .regular))
                        .foregroundStyle(.pearl)
                }
                .labelsHidden()
            }
            Hairline().padding(.horizontal, Theme.Space.md)
            row("Plate setup", icon: "circle.grid.2x2") {
                Button { showPlateSetup = true } label: {
                    Text("Edit")
                        .font(Theme.Font.body(13))
                        .foregroundStyle(.silver)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.graphite, in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                        .edgeHighlight(radius: Theme.Radius.sm)
                }
                .buttonStyle(.plain)
            }
            Hairline().padding(.horizontal, Theme.Space.md)
            row("Bar weight", icon: "minus") {
                Text("\(s.units.from(kg: s.barWeightKg).prettyWeight) \(s.units.label)")
                    .font(Theme.Font.mono(13, .regular))
                    .foregroundStyle(.silver)
            }
        }
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
    }

    private var bodyCard: some View {
        @Bindable var s = appState
        return VStack(spacing: 0) {
            row("Bodyweight", icon: "figure.stand") {
                HStack(spacing: 4) {
                    TextField("", value: Binding(
                        get: { s.units.from(kg: s.bodyweightKg) },
                        set: { s.bodyweightKg = s.units.toKg($0) }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .font(Theme.Font.mono(13, .regular))
                    .foregroundStyle(.pearl)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    Text(s.units.label)
                        .font(Theme.Font.label)
                        .foregroundStyle(.silver)
                }
            }
            Hairline().padding(.horizontal, Theme.Space.md)
            row("Height", icon: "ruler") {
                HStack(spacing: 4) {
                    TextField("", value: $s.heightCm, format: .number)
                        .keyboardType(.decimalPad)
                        .font(Theme.Font.mono(13, .regular))
                        .foregroundStyle(.pearl)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("cm")
                        .font(Theme.Font.label)
                        .foregroundStyle(.silver)
                }
            }
            Hairline().padding(.horizontal, Theme.Space.md)
            row("Experience", icon: "star") {
                Picker("", selection: $s.experience) {
                    ForEach(Experience.allCases, id: \.self) { e in
                        Text(e.label).tag(e)
                    }
                }
                .pickerStyle(.menu).labelsHidden().tint(.pearl)
            }
        }
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
    }

    private var integrationsCard: some View {
        @Bindable var s = appState
        return VStack(spacing: 0) {
            row("Apple Health", icon: "heart") {
                Toggle("", isOn: $s.healthKitEnabled).labelsHidden().tint(.pearl)
            }
        }
        .background(Color.onyx, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .edgeHighlight(radius: Theme.Radius.md)
    }

    private var aboutFooter: some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(Color.pearl.opacity(0.15))
                .frame(width: 28, height: 1)
                .padding(.bottom, 4)
            Text("ELOS · Member · v1.0".uppercased())
                .font(Theme.Font.label)
                .kerning(1.6)
                .foregroundStyle(.shadowTxt)
        }
        .padding(.top, 36)
    }

    @ViewBuilder
    private func row<Trail: View>(_ title: String, icon: String, @ViewBuilder trail: () -> Trail) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .thin))
                .foregroundStyle(.silver)
                .frame(width: 20)
            Text(title)
                .font(Theme.Font.body(14))
                .foregroundStyle(.pearl)
            Spacer()
            trail()
        }
        .padding(.horizontal, Theme.Space.md).padding(.vertical, 13)
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
            .scrollContentBackground(.hidden)
            .background(Color.obsidian)
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
                            Text("Bar weight")
                            Spacer()
                            Text(formatKg(s.barWeightKg))
                                .font(Theme.Font.mono(13, .regular))
                                .foregroundStyle(.silver)
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
                        .tint(.pearl)
                    }
                } header: { Text("Plates (per side)") }
                  footer: { Text("Used to calculate the plates you load on the bar.") }
            }
            .scrollContentBackground(.hidden)
            .background(Color.obsidian)
            .navigationTitle("Plate Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func formatKg(_ kg: Double) -> String {
        "\(appState.units.from(kg: kg).prettyWeight) \(appState.units.label)"
    }
}
