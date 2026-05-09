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
                        .padding(.top, Theme.Space.xs)

                    Hairline().padding(.top, Theme.Space.sm)

                    statRow
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

                    SectionLabel(title: "Danger Zone")
                    dangerCard.padding(.horizontal, Theme.Space.md)

                    aboutFooter

                    Spacer(minLength: 80)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vBG.ignoresSafeArea())
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
                Rectangle()
                    .fill(Color.vSignal)
                    .frame(width: 64, height: 64)
                Text(initials)
                    .font(Theme.Font.mono(22, .black))
                    .foregroundStyle(.vBG)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.displayName.isEmpty ? "SET YOUR NAME" : appState.displayName.uppercased())
                    .font(.system(size: 18, weight: .black))
                    .kerning(0.6)
                    .foregroundStyle(.vLabel)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    StatusDot(color: .vSignal, size: 5)
                    Text("\(appState.experience.label.uppercased()) · OPERATOR")
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(1.0)
                        .foregroundStyle(.vLabelMute)
                }
            }
            Spacer()
            Button { showEditProfile = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.vSignal)
                    .frame(width: 36, height: 36)
                    .overlay(Rectangle().strokeBorder(Color.vLineHigh, lineWidth: 0.5))
            }
            .buttonStyle(.pressable(scale: 0.92, haptic: .light))
        }
    }

    private var initials: String {
        let parts = appState.displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        let s = letters.joined().uppercased()
        return s.isEmpty ? "OP" : s
    }

    // MARK: Stats row

    private var statRow: some View {
        HStack(spacing: 8) {
            StatTile(label: "Workouts", value: "\(sessions.count)", icon: "checkmark")
            StatTile(label: "PRs", value: "\(prs.count)", icon: "rosette")
            StatTile(label: "Streak", value: "\(appState.currentStreak)", icon: "bolt")
        }
    }

    // MARK: Preferences

    private var preferencesCard: some View {
        @Bindable var s = appState
        return VStack(spacing: 0) {
            row("Units", icon: "scalemass") {
                Picker("", selection: $s.units) {
                    Text("LBS").tag(WeightUnit.imperial)
                    Text("KG").tag(WeightUnit.metric)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            Hairline().padding(.leading, 44)
            row("Haptics", icon: "iphone.radiowaves.left.and.right") {
                Toggle("", isOn: $s.hapticsEnabled).labelsHidden().tint(.vSignal)
            }
            Hairline().padding(.leading, 44)
            row("Sounds", icon: "speaker.wave.2") {
                Toggle("", isOn: $s.soundsEnabled).labelsHidden().tint(.vSignal)
            }
        }
        .background(Color.vSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    private var workoutCard: some View {
        @Bindable var s = appState
        return VStack(spacing: 0) {
            row("Default Rest", icon: "clock") {
                Stepper(value: $s.defaultRestSeconds, in: 30...300, step: 15) {
                    Text("\(s.defaultRestSeconds)s")
                        .font(Theme.Font.mono(13, .black))
                        .foregroundStyle(.vLabel)
                }
                .labelsHidden()
            }
            Hairline().padding(.leading, 44)
            row("Plate Setup", icon: "circle.grid.2x2") {
                Button {
                    showPlateSetup = true
                } label: {
                    Text("EDIT")
                        .font(.system(size: 10, weight: .black))
                        .kerning(1.0)
                        .foregroundStyle(.vSignal)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .overlay(Rectangle().strokeBorder(Color.vSignal, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Hairline().padding(.leading, 44)
            row("Bar Weight", icon: "minus") {
                Text("\(s.units.from(kg: s.barWeightKg).prettyWeight) \(s.units.label.uppercased())")
                    .font(Theme.Font.mono(13, .black))
                    .foregroundStyle(.vLabel)
            }
        }
        .background(Color.vSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
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
                    .font(Theme.Font.mono(13, .black))
                    .foregroundStyle(.vLabel)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    Text(s.units.label.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.vLabelMute)
                }
            }
            Hairline().padding(.leading, 44)
            row("Height", icon: "ruler") {
                HStack(spacing: 4) {
                    TextField("", value: $s.heightCm, format: .number)
                        .keyboardType(.decimalPad)
                        .font(Theme.Font.mono(13, .black))
                        .foregroundStyle(.vLabel)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("CM")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.vLabelMute)
                }
            }
            Hairline().padding(.leading, 44)
            row("Experience", icon: "star") {
                Picker("", selection: $s.experience) {
                    ForEach(Experience.allCases, id: \.self) { e in
                        Text(e.label.capitalized).tag(e)
                    }
                }
                .pickerStyle(.menu).labelsHidden().tint(.vSignal)
            }
        }
        .background(Color.vSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    private var integrationsCard: some View {
        @Bindable var s = appState
        return VStack(spacing: 0) {
            row("Apple Health", icon: "heart") {
                Toggle("", isOn: $s.healthKitEnabled).labelsHidden().tint(.vSignal)
            }
        }
        .background(Color.vSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .strokeBorder(Color.vLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    private var dangerCard: some View {
        Button {
            resetConfirm = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.vDanger)
                    .frame(width: 30, height: 30)
                    .background(Color.vDanger.opacity(0.10))
                Text("RESET ONBOARDING")
                    .font(.system(size: 11, weight: .black))
                    .kerning(1.0)
                    .foregroundStyle(.vDanger)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 14)
            .background(Color.vSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .strokeBorder(Color.vDanger.opacity(0.3), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(.pressable(scale: 0.98, haptic: .warning))
        .alert("Reset onboarding?", isPresented: $resetConfirm) {
            Button("Reset", role: .destructive) { appState.hasCompletedOnboarding = false }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data is kept; you'll just see the welcome screens again.")
        }
    }

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Rectangle().fill(Color.vSignal).frame(width: 24, height: 2)
                .padding(.bottom, 6)
            Text("ELOS · VIGIL")
                .font(.system(size: 11, weight: .black))
                .kerning(2.0)
                .foregroundStyle(.vLabel)
            Text("BUILT NATIVELY IN SWIFTUI · V1.0")
                .font(.system(size: 9, weight: .heavy))
                .kerning(1.4)
                .foregroundStyle(.vLabelFaint)
        }
        .padding(.top, 30)
    }

    // MARK: helper

    @ViewBuilder
    private func row<Trail: View>(_ title: String, icon: String, @ViewBuilder trail: () -> Trail) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Rectangle().fill(Color.vSurfaceHigh)
                Image(systemName: icon).font(.system(size: 11, weight: .black))
                    .foregroundStyle(.vLabelMute)
            }
            .frame(width: 26, height: 26)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black))
                .kerning(0.6)
                .foregroundStyle(.vLabel)
            Spacer()
            trail()
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
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
            .background(Color.vBG)
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
                                .font(Theme.Font.mono(13, .black))
                                .foregroundStyle(.vLabelMute)
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
            .scrollContentBackground(.hidden)
            .background(Color.vBG)
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
