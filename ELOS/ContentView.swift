import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selected: Tab = .today

    enum Tab: Hashable, CaseIterable {
        case today, train, progress, you
        var label: String {
            switch self {
            case .today:    return "Today"
            case .train:    return "Train"
            case .progress: return "Stats"
            case .you:      return "You"
            }
        }
        var icon: String {
            switch self {
            case .today:    return "circle.dotted"
            case .train:    return "dumbbell"
            case .progress: return "chart.bar"
            case .you:      return "person"
            }
        }
        var iconActive: String {
            switch self {
            case .today:    return "circle.inset.filled"
            case .train:    return "dumbbell.fill"
            case .progress: return "chart.bar.fill"
            case .you:      return "person.fill"
            }
        }
    }

    init() {
        // Make the system tab bar opaque pure black with hairline top border
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        appearance.shadowColor = UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1)

        let item = UITabBarItemAppearance()
        let mute = UIColor(red: 0.54, green: 0.54, blue: 0.54, alpha: 1)
        let signal = UIColor(red: 0.961, green: 0.773, blue: 0.094, alpha: 1)
        item.normal.iconColor = mute
        item.normal.titleTextAttributes = [
            .foregroundColor: mute,
            .font: UIFont.systemFont(ofSize: 10, weight: .heavy),
            .kern: 1.0
        ]
        item.selected.iconColor = signal
        item.selected.titleTextAttributes = [
            .foregroundColor: signal,
            .font: UIFont.systemFont(ofSize: 10, weight: .heavy),
            .kern: 1.0
        ]
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Nav bar — flat black
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor.black
        nav.shadowColor = .clear
        nav.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 16, weight: .heavy)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 30, weight: .black)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }

    var body: some View {
        TabView(selection: $selected) {
            TodayView()
                .tabItem {
                    Label(Tab.today.label.uppercased(),
                          systemImage: selected == .today ? Tab.today.iconActive : Tab.today.icon)
                }
                .tag(Tab.today)

            TrainView()
                .tabItem {
                    Label(Tab.train.label.uppercased(),
                          systemImage: selected == .train ? Tab.train.iconActive : Tab.train.icon)
                }
                .tag(Tab.train)

            ProgressDashboardView()
                .tabItem {
                    Label(Tab.progress.label.uppercased(),
                          systemImage: selected == .progress ? Tab.progress.iconActive : Tab.progress.icon)
                }
                .tag(Tab.progress)

            YouView()
                .tabItem {
                    Label(Tab.you.label.uppercased(),
                          systemImage: selected == .you ? Tab.you.iconActive : Tab.you.icon)
                }
                .tag(Tab.you)
        }
        .tint(.vSignal)
        .preferredColorScheme(.dark)
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
