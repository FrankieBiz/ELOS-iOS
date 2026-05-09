import SwiftUI
import SwiftData

@main
struct ELOSApp: App {
    @State private var appState = AppState()

    let container: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            WorkoutSet.self,
            CustomExercise.self,
            PersonalRecord.self,
            WorkoutTemplate.self,
            BodyMetric.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do { return try ModelContainer(for: schema, configurations: [config]) }
        catch { fatalError("ModelContainer error: \(error)") }
    }()

    var body: some Scene {
        WindowGroup {
            RootShell()
                .environment(appState)
                .modelContainer(container)
                .preferredColorScheme(appState.colorScheme)
                .tint(.brand)
                .onAppear { appState.touchStreakOnLaunch() }
        }
    }
}

// MARK: - Root shell — chooses between onboarding and the main tab bar.

struct RootShell: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
    }
}
