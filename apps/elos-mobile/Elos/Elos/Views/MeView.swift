import SwiftUI

struct MeView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var socialVM: SocialViewModel
    @State private var showingSettings   = false
    @State private var showingCanvasSync = false
    @State private var showCrew          = false

    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    profileHero
                    friendsSnippet
                    wellnessCard
                    habitsCard
                    settingsList
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(vm)
                    .environmentObject(authStore)
            }
            .sheet(isPresented: $showingCanvasSync) {
                CanvasSyncSheet()
                    .environmentObject(vm)
            }
            .sheet(isPresented: $showCrew) {
                CrewView()
                    .environmentObject(socialVM)
                    .environmentObject(vm)
            }
        }
        .task {
            let uid = vm.currentUserID
            if !uid.isEmpty { await socialVM.load(ownerID: uid) }
        }
    }

    // MARK: Profile Hero

    private var profileHero: some View {
        let firstName  = vm.userProfile?.firstName ?? ""
        let lastName   = vm.userProfile?.lastName  ?? ""
        let fullName   = firstName.isEmpty ? "Athlete" : "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        let initials   = makeInitials(firstName: firstName, lastName: lastName)
        let schoolYear = vm.userProfile?.schoolYear.capitalized ?? ""
        let schoolName = vm.userProfile?.schoolName ?? ""
        let subtitle   = [schoolYear, schoolName].filter { !$0.isEmpty }.joined(separator: " · ")
        let bestStreak = vm.habits.map(\.streak).max() ?? 0

        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.mSched, .tint],
                                                 startPoint: .topLeading,
                                                 endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                        Text(initials)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.tint.opacity(0.25), radius: 8, y: 3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(fullName)
                            .font(.system(size: 22, weight: .bold))
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 0) {
                    heroStat(value: bestStreak > 0 ? "\(bestStreak)d" : "—", label: "Streak")
                    Divider().frame(height: 32)
                    heroStat(value: "\(socialVM.friends.count)", label: "Crew")
                    Divider().frame(height: 32)
                    heroStat(value: "\(vm.hydration)oz", label: "Today")
                }
            }
            .padding(18)
            .elosCard()

            Button { showingSettings = true } label: {
                Image(systemName: "gear")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .padding(14)
            }
        }
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Friends Snippet

    private var friendsSnippet: some View {
        Button { showCrew = true } label: {
            HStack(spacing: 12) {
                if socialVM.friends.isEmpty {
                    Image(systemName: "person.2")
                        .font(.title3).foregroundStyle(.secondary)
                    Text("No friends yet — find your crew")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: -10) {
                        ForEach(socialVM.friends.prefix(5)) { friend in
                            AvatarCircle(initials: friend.initials, hex: friend.avatarHex, size: 34)
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        }
                    }
                    Text("\(socialVM.friends.count) \(socialVM.friends.count == 1 ? "friend" : "friends")")
                        .font(.subheadline).fontWeight(.semibold)
                }
                Spacer()
                if socialVM.pendingRequests.count > 0 {
                    Text("\(socialVM.pendingRequests.count) pending")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.bad)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .elosCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Wellness Card (Sleep + Hydration + Habits combined)

    private var wellnessCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Today")
                    .font(.subheadline).fontWeight(.bold)
                Spacer()
                Button {
                    vm.showingLogSleep = true
                } label: {
                    Text("+ Log Sleep")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.tint)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.tintSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()

            HStack(spacing: 0) {
                wellnessRing(
                    value: sleepDisplayValue,
                    label: "Sleep",
                    progress: sleepProgress,
                    color: .mHealth
                )
                Divider().frame(height: 72)
                wellnessRing(
                    value: "\(vm.hydration)oz",
                    label: "Hydration",
                    progress: min(Double(vm.hydration) / Double(max(vm.hydGoal, 1)), 1),
                    color: .mNutri
                )
                Divider().frame(height: 72)
                wellnessRing(
                    value: vm.habits.isEmpty ? "—" : "\(vm.doneHabits)/\(vm.habits.count)",
                    label: "Habits",
                    progress: vm.habits.isEmpty ? 0 : Double(vm.doneHabits) / Double(vm.habits.count),
                    color: .mHabits
                )
            }
            .padding(.vertical, 14)

            Divider()

            HStack(spacing: 8) {
                ForEach([8, 16, 32], id: \.self) { oz in
                    Button("+\(oz)oz") { HapticManager.impact(.light); vm.addHydration(oz: oz) }
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.mNutri)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.mNutri.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .elosCard()
    }

    private func wellnessRing(value: String, label: String, progress: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)
            }
            .frame(width: 46, height: 46)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var sleepDisplayValue: String {
        guard let last = vm.sleepLog.first else { return "—" }
        return String(format: "%.1fh", last.duration)
    }

    private var sleepProgress: Double {
        guard let last = vm.sleepLog.first else { return 0 }
        return min(last.duration / 8.0, 1.0)
    }

    // MARK: Habits Card

    private var habitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(Color.mHabits).frame(width: 8, height: 8)
                Text("Habits").font(.subheadline).fontWeight(.bold)
                Spacer()
                let bestStreak = vm.habits.map(\.streak).max() ?? 0
                if bestStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2).foregroundStyle(.orange)
                        Text("\(bestStreak)d best streak")
                            .font(.caption2).fontWeight(.semibold).foregroundStyle(.orange)
                    }
                }
            }

            heatmapGrid

            if vm.habits.isEmpty {
                Button {
                    vm.showingAddHabit = true
                } label: {
                    Label("Add your first habit", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.tint)
                }
                .buttonStyle(.plain)
            } else {
                Divider()
                VStack(spacing: 0) {
                    ForEach(vm.habits.indices, id: \.self) { idx in
                        let habit = vm.habits[idx]
                        HStack(spacing: 12) {
                            Image(systemName: habit.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(habit.done ? Color.mHabits : Color.secondary.opacity(0.35))
                                .font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(habit.label)
                                    .font(.subheadline)
                                    .strikethrough(habit.done, color: .secondary)
                                    .foregroundStyle(habit.done ? .secondary : .primary)
                                Text(habit.category.capitalized)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if habit.streak > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2).foregroundStyle(.orange)
                                    Text("\(habit.streak)d")
                                        .font(.caption2).fontWeight(.semibold).foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding(.vertical, 9)
                        if idx < vm.habits.count - 1 { Divider() }
                    }
                }
            }
        }
        .padding(16)
        .elosCard()
    }

    private var heatmapGrid: some View {
        let cols = 24
        let rows = 7
        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(10), spacing: 2), count: cols),
            spacing: 2
        ) {
            ForEach(0..<(cols * rows), id: \.self) { i in
                let level = (i * 31) % 100 / 25
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(level == 0
                          ? Color.secondary.opacity(0.12)
                          : Color.mHabits.opacity(Double(level) * 0.22))
                    .frame(width: 10, height: 10)
            }
        }
    }

    // MARK: Settings List

    private var settingsList: some View {
        VStack(spacing: 0) {
            ForEach(settingsItems.indices, id: \.self) { i in
                Button {
                    switch settingsItems[i].action {
                    case .settings: showingSettings = true
                    case .canvas:   showingCanvasSync = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(settingsItems[i].bg)
                                .frame(width: 32, height: 32)
                            Image(systemName: settingsItems[i].icon)
                                .font(.system(size: 15))
                                .foregroundStyle(settingsItems[i].iconColor)
                        }
                        Text(settingsItems[i].label)
                            .font(.subheadline).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < settingsItems.count - 1 { Divider().padding(.leading, 60) }
            }
        }
        .elosCard()
    }

    private enum SettingsAction { case settings, canvas }

    private struct SettingItem {
        let label: String
        let icon: String
        let iconColor: Color
        let bg: Color
        let action: SettingsAction
    }

    private var settingsItems: [SettingItem] {[
        SettingItem(label: "Preferences",     icon: "slider.horizontal.3",      iconColor: .secondary, bg: Color.secondary.opacity(0.12), action: .settings),
        SettingItem(label: "Canvas LMS sync", icon: "calendar.badge.checkmark", iconColor: .mSched,    bg: Color.mSched.opacity(0.15),    action: .canvas),
        SettingItem(label: "About ELOS",      icon: "info.circle",              iconColor: .secondary, bg: Color.secondary.opacity(0.12), action: .settings),
    ]}

    // MARK: Helpers

    private func makeInitials(firstName: String, lastName: String) -> String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        let result = (f + l).uppercased()
        return result.isEmpty ? "?" : result
    }
}
