import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selected: Tab = .today

    enum Tab: Hashable { case today, train, progress, you }

    var body: some View {
        TabView(selection: $selected) {

            TodayView()
                .tabItem {
                    Label("Today",
                          systemImage: selected == .today ? "flame.fill" : "flame")
                }
                .tag(Tab.today)

            TrainView()
                .tabItem {
                    Label("Train",
                          systemImage: selected == .train ? "dumbbell.fill" : "dumbbell")
                }
                .tag(Tab.train)

            ProgressDashboardView()
                .tabItem {
                    Label("Progress",
                          systemImage: selected == .progress ? "chart.line.uptrend.xyaxis.circle.fill"
                                                              : "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.progress)

            YouView()
                .tabItem {
                    Label("You",
                          systemImage: selected == .you ? "person.crop.circle.fill" : "person.crop.circle")
                }
                .tag(Tab.you)
        }
        .tint(.brand)
        .fullScreenCover(isPresented: Binding(
            get: { appState.isWorkoutActive },
            set: { if !$0 { appState.activeWorkout = nil } }
        )) {
            if appState.activeWorkout != nil {
                ActiveWorkoutView()
            }
        }
        .onChange(of: selected) { _, _ in Haptic.selection() }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [
            WorkoutSession.self, WorkoutSet.self, CustomExercise.self,
            PersonalRecord.self, WorkoutTemplate.self, BodyMetric.self
        ], inMemory: true)
}
