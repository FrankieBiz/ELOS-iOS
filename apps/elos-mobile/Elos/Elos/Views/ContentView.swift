import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @EnvironmentObject var trainingContext: TrainingContext

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: vm.selectedTab)

            ElosTabBar()

            if vm.recoverableSession != nil && !vm.showingSession {
                ResumeSessionPrompt()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(15)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay {
            if vm.showingSession {
                ActiveSessionView()
                    .transition(.move(edge: .trailing))
                    .zIndex(10)
            }
        }
        .animation(.spring(duration: 0.32), value: vm.recoverableSession != nil)
        .overlay(alignment: .top) {
            if let message = vm.errorBanner {
                ErrorBanner(message: message) { vm.dismissError() }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .animation(.spring(duration: 0.32), value: vm.showingSession)
        .animation(.easeInOut(duration: 0.25), value: vm.errorBanner)
        .sheet(isPresented: $vm.showingLogSleep) {
            LogSleepSheet()
                .environmentObject(vm)
        }
        .sheet(isPresented: $vm.showingAddHabit) {
            AddHabitSheet()
                .environmentObject(vm)
        }
        .preferredColorScheme(vm.forceDark.map { $0 ? .dark : .light })
    }

    @ViewBuilder
    private var tabContent: some View {
        switch vm.selectedTab {
        case .today: TodayView()
        case .train: TrainView()
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
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 14)
        .padding(.bottom, 96)   // clear the tab bar
    }
}

// MARK: - Custom Tab Bar
private struct ElosTabBar: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button {
                        HapticManager.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: vm.selectedTab == tab ? tab.selectedIcon : tab.icon)
                                .font(.system(size: 20, weight: vm.selectedTab == tab ? .bold : .regular))
                                .foregroundStyle(vm.selectedTab == tab ? Color.tint : Color.secondary)

                            Text(tab.label.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .kerning(0.5)
                                .foregroundStyle(vm.selectedTab == tab ? Color.tint : Color.secondary)
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
            .background(Color(.systemBackground))
            .safeAreaPadding(.bottom)
        }
    }
}
