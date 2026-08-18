import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @EnvironmentObject var trainingContext: TrainingContext
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var layout: LayoutStore
    @Environment(\.dynamicTypeSize) private var systemTypeSize

    @State private var didApplyLaunchTab = false

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Re-identified on every appearance change, which forces the whole tab subtree to
                // re-read the design tokens (`Color.tint`, `Space`, `Radius`, `elosCard`). Those are
                // statics — they can't publish — and making them observable would have meant
                // rewriting a thousand-odd call sites. This is the seam that avoids that.
                //
                // Scoped tightly to the tab content on purpose: the active workout, the error banner
                // and the customizer sheet all sit outside it, so changing a colour can never tear
                // down a session in progress or dismiss the sheet doing the changing.
                .id(theme.revision)
                .animation(.elosQuick, value: vm.selectedTab)

            ElosTabBar()

            if vm.recoverableSession != nil && !vm.showingSession {
                ResumeSessionPrompt()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(15)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .bottom) {
            if layout.editingScreen != nil {
                LayoutEditBar()
                    .padding(.bottom, 96)   // clear the tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(16)
            }
        }
        .overlay {
            if vm.showingSession {
                ActiveSessionView()
                    .transition(.move(edge: .trailing))
                    .zIndex(10)
            }
        }
        .animation(.elosEmphasis, value: vm.recoverableSession != nil)
        .overlay(alignment: .top) {
            if let message = vm.errorBanner {
                ErrorBanner(message: message) { vm.dismissError() }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .animation(.elosEmphasis, value: vm.showingSession)
        .animation(.elosStandard, value: vm.errorBanner)
        .animation(.elosStandard, value: layout.editingScreen)
        .sheet(isPresented: $vm.showingLogSleep) {
            LogSleepSheet()
                .environmentObject(vm)
        }
        .sheet(isPresented: $vm.showingAddHabit) {
            AddHabitSheet()
                .environmentObject(vm)
        }
        // Hosted here rather than inside Settings so a theme change can't dismiss the screen that
        // made it — see the `.id` note above.
        .sheet(isPresented: $layout.showingCustomizeSheet) {
            CustomizeView()
                .environmentObject(theme)
                .environmentObject(layout)
        }
        .preferredColorScheme(theme.colorScheme)
        // Relative to the system setting, never instead of it.
        .dynamicTypeSize(systemTypeSize.shifted(by: theme.config.textScale.steps))
        .fontDesign(theme.fontDesign)
        .onAppear {
            guard !didApplyLaunchTab else { return }
            didApplyLaunchTab = true
            vm.selectedTab = layout.config.tabs.launchTab
        }
        .onChange(of: vm.selectedTab) { _, _ in
            // Rearranging is per-screen; walking to another tab ends it rather than leaving the
            // edit chrome hanging over a screen you didn't ask to edit.
            if layout.editingScreen != nil { layout.editingScreen = nil }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch vm.selectedTab {
        case .today: TodayView()
        case .train: TrainView()
        case .feed:  FeedTabView()
        case .stats: StatsView()
        case .plan:  PlanView()
        case .me:    MeView()
        }
    }
}

// MARK: - Error Banner
private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.red.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}

// MARK: - Resume Session Prompt
private struct ResumeSessionPrompt: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @EnvironmentObject var trainingContext: TrainingContext
    /// Sits outside the tab content, which is what gets rebuilt on a theme change — so it subscribes
    /// directly rather than keeping a stale accent on its Resume button.
    @ObservedObject private var theme = ThemeStore.shared

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private var subtitle: String {
        guard let s = vm.recoverableSession else { return "" }
        let when = Self.relativeFormatter.localizedString(for: s.startedAt, relativeTo: Date())
        let count = vm.loggedSetCount(for: s)
        let setsLabel = count == 1 ? "1 set logged" : "\(count) sets logged"
        return "Started \(when) · \(setsLabel)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3).foregroundStyle(Color.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout in progress")
                        .font(.subheadline).fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button {
                    HapticManager.warning()
                    vm.discardRecoveredSession(trainVM: trainVM)
                } label: {
                    Text("Discard")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.success()
                    vm.resumeRecoveredSession(trainVM: trainVM, context: trainingContext)
                } label: {
                    Text("Resume")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .elosCard()
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 14)
        .padding(.bottom, 96)   // clear the tab bar
    }
}

// MARK: - Custom Tab Bar
private struct ElosTabBar: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var layout: LayoutStore
    @EnvironmentObject var theme: ThemeStore

    /// The tabs the user kept, in the order they put them. `LayoutStore` guarantees this is
    /// non-empty and duplicate-free however mangled the stored value gets — this is the app's only
    /// navigation, so it can't be allowed to render nothing.
    private var tabs: [AppTab] { layout.visibleTabs }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    Button {
                        HapticManager.selection()
                        withAnimation(.elosQuick) {
                            vm.selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            // Fixed on purpose: this is the tab bar. The system's own tab icons don't
                            // grow with Dynamic Type either — five of them share one row, and scaling
                            // the glyphs would push the labels out before it helped anyone.
                            Image(systemName: vm.selectedTab == tab ? tab.selectedIcon : tab.icon)
                                .font(.system(size: theme.config.compactTabBar ? 23 : 20,
                                              weight: vm.selectedTab == tab ? .bold : .regular))
                                .foregroundStyle(vm.selectedTab == tab ? Color.tint : Color.secondary)

                            // Five labels share one row and cannot reflow, so they shrink rather than
                            // wrap. Left to scale freely, "TODAY" hyphenated to "TO-DAY" and
                            // "TRAIN"/"STATS" collided with no gap between them.
                            if !theme.config.compactTabBar {
                                Text(tab.label.uppercased())
                                    .font(.system(.caption2, weight: .semibold))
                                    .kerning(0.5)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(vm.selectedTab == tab ? Color.tint : Color.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tab.label)
                    .accessibilityAddTraits(vm.selectedTab == tab ? [.isButton, .isSelected] : .isButton)
                }
            }
            // A tab bar is the canonical layout that cannot reflow: fixed columns, always visible.
            // Cap the ramp here rather than let it break the app's primary navigation.
            .elosDenseLayout()
            .background(Color(.systemBackground))
            .safeAreaPadding(.bottom)
        }
        .onChange(of: layout.revision) { _, _ in
            // Hiding the tab you're standing on would otherwise leave the bar with nothing
            // highlighted and no obvious way back.
            if !tabs.contains(vm.selectedTab), let first = tabs.first {
                withAnimation(.elosQuick) { vm.selectedTab = first }
            }
        }
    }
}
