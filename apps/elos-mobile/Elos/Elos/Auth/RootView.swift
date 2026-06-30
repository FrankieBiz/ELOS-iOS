import SwiftUI

struct RootView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if authStore.isLoading {
                ProgressView()
                    .tint(.tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if !authStore.isAuthenticated {
                AuthFlowView()
            } else if !authStore.isOnboardingComplete {
                OnboardingView()
            } else {
                ContentView()
            }
        }
        .onChange(of: authStore.isAuthenticated) { _, isAuth in
            if isAuth {
                vm.loadForUser(id: authStore.currentUserID)
            } else {
                vm.clearData()
            }
        }
        .onChange(of: authStore.isOnboardingComplete) { _, complete in
            if complete {
                vm.loadForUser(id: authStore.currentUserID)
            }
        }
        .onAppear {
            if authStore.isAuthenticated {
                vm.loadForUser(id: authStore.currentUserID)
            }
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await authStore.refreshSessionIfNeeded()
                await vm.refreshHealthMetrics()   // no-op unless Health is connected
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                // Snapshot the in-progress workout draft synchronously so a hard
                // kill while suspended loses nothing. Runs inline (unlike .task,
                // which can be cancelled as the scene deactivates).
                vm.captureSessionDraft(trainVM: trainVM)
            case .active:
                // Returning from a mere suspend (process still alive) — re-check for
                // an unfinished session in case the UI state was dropped.
                vm.recoverActiveSession()
            @unknown default:
                break
            }
        }
    }
}
