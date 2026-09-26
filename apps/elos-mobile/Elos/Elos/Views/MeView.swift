import SwiftUI
import SwiftData

struct MeView: View {
    @EnvironmentObject var vm: AppViewModel
    @Query private var allSessions: [WorkoutSessionRecord]
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var socialVM: SocialViewModel
    @EnvironmentObject var feedVM: FeedViewModel
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var layout: LayoutStore
    @State private var showingSettings   = false
    @State private var settingsScrollToAbout = false
    @State private var showingCanvasSync = false
    @State private var showCrew          = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                SectionStack(screen: .me, spacing: 16) { section in
                    switch section {
                    case .meProfile:  profileHero
                    case .meFriends:  friendsSnippet
                    case .meWellness: wellnessCard
                    case .meHabits:   habitsCard
                    case .meSettings: settingsList
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .elosPageBackground()
            // Was `.navigationBarHidden(true)`, which left the scroll content running under the
            // status bar with nothing behind it — scrolled down, the profile card collided with the
            // clock and the Dynamic Island. An inline title restores the bar's blur, and matches
            // Train and Plan, which already use inline titles.
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CustomizeScreenButton(screen: .me)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(scrollToAbout: settingsScrollToAbout)
                    .environmentObject(vm)
                    .environmentObject(authStore)
                    .environmentObject(theme)
                    .environmentObject(layout)
            }
            .sheet(isPresented: $showingCanvasSync) {
                CanvasSyncSheet()
                    .environmentObject(vm)
            }
            .sheet(isPresented: $showCrew) {
                CrewView()
                    .environmentObject(socialVM)
                    .environmentObject(vm)
                    .environmentObject(feedVM)
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
        // The training streak, matching the Train tab's rank card. This used to be the best *habit*
        // streak under the same "Streak" label, so the two tabs disagreed about the same athlete —
        // Train said "0d" while this said "—".
        let streak = GamificationEngine.workoutStreak(
            sessions: allSessions.filter { $0.ownerID == vm.currentUserID }
        )

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
                            .font(.system(.title, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.tint.opacity(0.25), radius: 8, y: 3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(fullName)
                            .font(.system(.title2, weight: .bold))
                        if let uname = vm.userProfile?.username, !uname.isEmpty {
                            Text("@\(uname)")
                                .font(.subheadline).fontWeight(.medium)
                                .foregroundStyle(Color.tint)
                        }
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
                    heroStat(value: "\(streak)d", label: "Streak")
                    Divider().frame(height: 32)
                    heroStat(value: "\(socialVM.friends.count)", label: "Crew")
                    Divider().frame(height: 32)
                    heroStat(value: "\(vm.hydration)oz", label: "Today")
                }
            }
            .padding(18)
            .elosCard()

            Button {
                HapticManager.impact(.light)
                settingsScrollToAbout = false
                showingSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(14)
            }
            .accessibilityLabel("Settings")
        }
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.elosNumeric(.callout, weight: .bold))
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
                Text("Today").font(.elosHeadline)
                Spacer()
                Button {
                    vm.showingLogSleep = true
                } label: {
                    Label("Log Sleep", systemImage: "plus")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(Color.tint)
                        .padding(.horizontal, Space.m).padding(.vertical, Space.xs + 2)
                        .background(Color.tintSoft, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.l)
            .padding(.bottom, Space.m)

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

            // Two equal-weight 3-button rows meant six large tap targets dominated the card, and the
            // subtract row — a correction affordance, used far less than logging a drink — carried the
            // same visual weight as the primary action. Adding stays prominent; subtracting drops to a
            // compact borderless row. All six amounts remain available.
            VStack(spacing: Space.s) {
                HStack(spacing: Space.s) {
                    ForEach([8, 16, 32], id: \.self) { oz in
                        Button {
                            HapticManager.impact(.light); vm.addHydration(oz: oz)
                        } label: {
                            Text("+\(oz)oz")
                                .font(.system(.footnote, weight: .semibold))
                                .foregroundStyle(Color.mNutri)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.mNutri.opacity(0.12), in:
                                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add \(oz) ounces")
                    }
                }
                HStack(spacing: Space.s) {
                    Spacer(minLength: 0)
                    ForEach([8, 16, 32], id: \.self) { oz in
                        Button {
                            HapticManager.impact(.light); vm.removeHydration(oz: oz)
                        } label: {
                            Text("−\(oz)oz")
                                .font(.elosCaption)
                                .foregroundStyle(.secondary)
                                // Borderless text alone read as a caption, not a control, and the
                                // hit area fell well under 44pt. A hairline capsule plus real
                                // padding restores both without competing with the add buttons.
                                .padding(.horizontal, Space.m)
                                .padding(.vertical, 7)
                                .overlay {
                                    Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(oz) ounces")
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.m)
            .padding(.bottom, Space.m)
        }
        .elosCard()
    }

    private func wellnessRing(value: String, label: String, progress: Double, color: Color) -> some View {
        VStack(spacing: Space.s) {
            ProgressRing(progress: progress, color: color, lineWidth: 5, size: 46)

            Text(value)
                .font(.elosNumeric(.caption, weight: .bold))
            Text(label)
                .font(.elosMicro)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
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
                // A bare filled dot beside the title read as an unread/status badge rather than
                // decoration; a glyph matches how every other card labels itself.
                Image(systemName: "checklist")
                    .font(.elosCaption)
                    .foregroundStyle(Color.mHabits)
                Text("Habits").font(.elosHeadline)
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
                                .font(.title2)
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

    // MARK: Settings List

    private var settingsList: some View {
        VStack(spacing: 0) {
            ForEach(settingsItems.indices, id: \.self) { i in
                Button {
                    switch settingsItems[i].action {
                    case .settings: settingsScrollToAbout = false; showingSettings = true
                    case .about:    settingsScrollToAbout = true; showingSettings = true
                    case .canvas:   showingCanvasSync = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(settingsItems[i].bg)
                                .frame(width: 32, height: 32)
                            Image(systemName: settingsItems[i].icon)
                                .font(.subheadline)
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

    private enum SettingsAction { case settings, about, canvas }

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
        SettingItem(label: "About ELOS",      icon: "info.circle",              iconColor: .secondary, bg: Color.secondary.opacity(0.12), action: .about),
    ]}

    // MARK: Helpers

    private func makeInitials(firstName: String, lastName: String) -> String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        let result = (f + l).uppercased()
        return result.isEmpty ? "?" : result
    }
}
