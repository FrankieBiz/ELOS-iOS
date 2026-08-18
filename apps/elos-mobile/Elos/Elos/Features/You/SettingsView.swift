import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var layout: LayoutStore
    @EnvironmentObject var feedVM: FeedViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authVM = AuthViewModel()
    @State private var showingSignOutAlert      = false
    @State private var showingDeleteAlert       = false
    @State private var showingCanvasSync        = false
    @State private var showingEditProfile       = false
    @State private var showingPlateCalc         = false
    @State private var showingBodyMetrics       = false
    /// When opened via MeView's "About ELOS" row specifically (as opposed to "Preferences" or the
    /// gear icon, which both land at the top), jump straight to the About section on appear.
    var scrollToAbout: Bool = false

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
            List {
                Section("Account") {
                    if let profile = vm.userProfile {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.mSched, .tint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                                Text(initials(from: profile))
                                    .font(.system(.callout, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(profile.firstName) \(profile.lastName)".trimmingCharacters(in: .whitespaces))
                                    .font(.subheadline).fontWeight(.semibold)
                                Text(profile.email.isEmpty ? "No email" : profile.email)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        HapticManager.impact(.light)
                        showingEditProfile = true
                    } label: {
                        Label("Edit Profile", systemImage: "person.crop.circle")
                            .foregroundStyle(.primary)
                    }

                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                }

                Section {
                    // Opens at the app root rather than pushing here, and closes this sheet on the
                    // way. Changing the theme re-identifies the tab content underneath — which is
                    // what hosts this sheet — so a nested customizer would dismiss itself the first
                    // time you touched a colour. Handing off sidesteps that entirely.
                    Button {
                        HapticManager.impact(.light)
                        dismiss()
                        layout.customizingScreen = nil
                        layout.showingCustomizeSheet = true
                    } label: {
                        HStack {
                            Label("Appearance & Layout", systemImage: "paintbrush")
                                .foregroundStyle(.primary)
                            Spacer()
                            if theme.config != ThemeConfig() || layout.isAnyScreenCustomized {
                                Text("Custom")
                                    .font(.elosCaption)
                                    .foregroundStyle(Color.tint)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("App")
                } footer: {
                    Text("Colours, shapes, spacing, type — and what each screen shows, in what order.")
                        .font(.elosMicro)
                }

                Section {
                    HStack {
                        Label("Units", systemImage: "scalemass")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { vm.weightUnit },
                            set: { vm.setWeightUnit($0) }
                        )) {
                            Text("kg").tag(WeightUnit.kg)
                            Text("lb").tag(WeightUnit.lb)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }

                Section {
                    Button {
                        HapticManager.impact(.light)
                        showingBodyMetrics = true
                    } label: {
                        Label("Body Metrics", systemImage: "figure.stand")
                            .foregroundStyle(.primary)
                    }
                    Button {
                        HapticManager.impact(.light)
                        showingPlateCalc = true
                    } label: {
                        Label("Plate Calculator", systemImage: "scalemass")
                            .foregroundStyle(.primary)
                    }
                    NavigationLink {
                        VolumeTargetsView().environmentObject(vm)
                    } label: {
                        HStack {
                            Label("Volume Targets", systemImage: "chart.bar")
                            if vm.volumeOverrides.isCustomized {
                                Spacer()
                                Text("Custom")
                                    .font(.elosCaption)
                                    .foregroundStyle(Color.tint)
                            }
                        }
                    }
                    NavigationLink {
                        GymsView().environmentObject(vm)
                    } label: {
                        Label("Gyms", systemImage: "building.2")
                    }
                    Toggle(isOn: $vm.showQualityRater) {
                        Label("Show Quality Rating", systemImage: "gauge.medium")
                    }
                    .tint(Color.tint)
                } header: {
                    Text("Training")
                } footer: {
                    // Gyms tracks WHERE you train, not WHAT equipment you generally have — that's a
                    // separate setting, cross-linked here so checking one screen surfaces the other.
                    Text("General equipment access is set in Edit Profile.")
                        .font(.elosMicro)
                }

                Section {
                    // Reads and writes the same three-state preference the post-session prompt
                    // sets. Answering here counts as being asked: switching it off from `unasked`
                    // stores an explicit `off`, so the prompt won't come back later.
                    Toggle(isOn: Binding(
                        get: { feedVM.autoShare.isOn },
                        set: { feedVM.autoShare = $0 ? .on : .off }
                    )) {
                        Label("Auto-share workouts", systemImage: "square.stack.3d.up")
                    }
                    .tint(Color.tint)
                } header: {
                    Text("Feed")
                } footer: {
                    Text("Posts your workout and any PRs to the Feed when you finish a session. Friends only — nothing is public.")
                        .font(.elosMicro)
                }

                Section("Canvas LMS") {
                    Button {
                        HapticManager.impact(.light)
                        showingCanvasSync = true
                    } label: {
                        HStack {
                            Label("Canvas Sync", systemImage: "calendar.badge.checkmark")
                                .foregroundStyle(.primary)
                            Spacer()
                            if vm.canvasSyncing {
                                ProgressView().scaleEffect(0.8)
                            } else if let lastSync = vm.canvasLastSynced {
                                Text(lastSyncLabel(lastSync))
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Not synced")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { vm.healthKitEnabled },
                        set: { on in
                            if on { Task { await vm.connectHealth() } }
                            else { vm.disconnectHealth() }
                        }
                    )) {
                        Label("Apple Health", systemImage: "heart.fill")
                    }
                    .tint(Color.tint)

                    if vm.healthKitEnabled {
                        if let w = vm.healthSnapshot.bodyWeightKg {
                            healthRow("Body weight", value: vm.weightUnit.formatWeight(kg: w))
                        }
                        if let rhr = vm.healthSnapshot.restingHeartRate {
                            healthRow("Resting heart rate", value: "\(Int(rhr)) bpm")
                        }
                        if let steps = vm.healthSnapshot.steps {
                            healthRow("Steps today", value: "\(steps)")
                        }
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text(vm.healthKitEnabled
                         ? "Workouts are saved to Apple Health; your weight, resting heart rate, and steps are read to tailor recovery."
                         : "Save your workouts to Apple Health and read body weight, resting heart rate, and steps.")
                }

                Section("About") {
                    Color.clear.frame(height: 0).id("about")
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://elos.onrender.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                            .foregroundStyle(.primary)
                    }
                    Link(destination: URL(string: "https://elos.onrender.com/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    dismiss()
                    vm.signOut(authStore: authStore)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to access your data.")
            }
            .alert("Delete Account", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        let ok = await authVM.deleteAccount(authStore: authStore)
                        if ok {
                            vm.eraseAllLocalData()
                            dismiss()
                        } else {
                            vm.showError(authVM.errorMessage ?? "Could not delete account. Please try again.")
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all your data. This cannot be undone.")
            }
            .sheet(isPresented: $showingCanvasSync) {
                CanvasSyncSheet()
                    .environmentObject(vm)
            }
            .sheet(isPresented: $showingEditProfile) {
                ProfileEditView()
                    .environmentObject(vm)
                    .environmentObject(authStore)
            }
            .sheet(isPresented: $showingPlateCalc) {
                PlateCalculatorView()
                    .environmentObject(vm)
            }
            .sheet(isPresented: $showingBodyMetrics) {
                BodyMetricsView()
                    .environmentObject(vm)
            }
            .onAppear {
                if scrollToAbout {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation { proxy.scrollTo("about", anchor: .top) }
                    }
                }
            }
            }
        }
    }

    private func initials(from profile: UserProfileSnapshot) -> String {
        let f = profile.firstName.first.map(String.init) ?? ""
        let l = profile.lastName.first.map(String.init) ?? ""
        return (f + l).uppercased().isEmpty ? "?" : (f + l).uppercased()
    }

    private func lastSyncLabel(_ date: Date) -> String {
        let mins = Int(-date.timeIntervalSinceNow / 60)
        if mins < 1 { return "Just now" }
        if mins < 60 { return "\(mins)m ago" }
        let hrs = mins / 60
        return "\(hrs)h ago"
    }

    private func healthRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Canvas Sync Sheet

struct CanvasSyncSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("canvasBaseURL") private var baseURL = ""
    @State private var token = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Enter your Canvas LMS URL and personal access token to sync your courses, assignments, and exams.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section("Canvas URL") {
                    TextField("school.instructure.com", text: $baseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section("Access Token") {
                    SecureField("Paste your Canvas access token", text: $token)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Button {
                        Task { await vm.syncCanvas(baseURL: baseURL, token: token) }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.canvasSyncing {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Syncing…")
                                    .fontWeight(.semibold)
                            } else {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(baseURL.isEmpty || token.isEmpty ? Color.secondary : Color.tint)
                            }
                            Spacer()
                        }
                    }
                    .disabled(baseURL.isEmpty || token.isEmpty || vm.canvasSyncing)
                }

                if let error = vm.canvasError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let lastSync = vm.canvasLastSynced {
                    Section {
                        HStack {
                            Text("Last synced")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Canvas Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                token = KeychainHelper.load(forKey: "canvasToken") ?? ""
            }
            // Persist on dismiss regardless of how the sheet closed — tapping Done previously was the
            // only save path, so swiping down to close silently dropped whatever the user just pasted.
            .onDisappear {
                KeychainHelper.save(token, forKey: "canvasToken")
            }
        }
    }
}

