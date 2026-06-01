import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingSignOutAlert    = false
    @State private var showingCanvasSync     = false
    @State private var showingEditProfile    = false
    @State private var showingPlateCalc      = false
    @State private var showingBodyMetrics    = false

    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    if let profile = vm.userProfile {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.mSched, .tint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                                Text(initials(from: profile))
                                    .font(.system(size: 16, weight: .bold))
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
                }

                Section("App") {
                    HStack {
                        Label("Theme", systemImage: "circle.lefthalf.filled")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { vm.forceDark.map { $0 ? "dark" : "light" } ?? "system" },
                            set: { val in
                                switch val {
                                case "dark":  vm.forceDark = true
                                case "light": vm.forceDark = false
                                default:      vm.forceDark = nil
                                }
                            }
                        )) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }

                Section("Training") {
                    Button {
                        showingBodyMetrics = true
                    } label: {
                        Label("Body Metrics", systemImage: "figure.stand")
                            .foregroundStyle(.primary)
                    }
                    Button {
                        showingPlateCalc = true
                    } label: {
                        Label("Plate Calculator", systemImage: "scalemass")
                            .foregroundStyle(.primary)
                    }
                }

                Section("Canvas LMS") {
                    Button {
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

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("ELOS · 2026").foregroundStyle(.secondary)
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
            }
            .sheet(isPresented: $showingBodyMetrics) {
                BodyMetricsView()
                    .environmentObject(vm)
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
}

// MARK: - Canvas Sync Sheet

struct CanvasSyncSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("canvasBaseURL") private var baseURL = ""
    @AppStorage("canvasToken")   private var token   = ""

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
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - GoalRow

private struct GoalRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(color)
        }
    }
}
