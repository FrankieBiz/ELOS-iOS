import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: vm.selectedTab)

            ElosTabBar()
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay {
            if vm.showingSession {
                ActiveSessionView()
                    .transition(.move(edge: .trailing))
                    .zIndex(10)
            }
        }
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

// MARK: - Custom Tab Bar
private struct ElosTabBar: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button {
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
                }
            }
            .background(Color(.systemBackground))
            .safeAreaPadding(.bottom)
        }
    }
}
