import SwiftUI

struct RootView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var vm: AppViewModel
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
            }
        }
    }
}
