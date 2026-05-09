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
        // Hide the system tab bar — we render our own
        UITabBar.appearance().isHidden = true

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1)
        nav.shadowColor = .clear
        nav.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1),
            .font: UIFont.systemFont(ofSize: 15, weight: .medium)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1),
            .font: UIFont.systemFont(ofSize: 30, weight: .light)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selected) {
                TodayView()
                    .tag(Tab.today)
                    .toolbar(.hidden, for: .tabBar)

                TrainView()
                    .tag(Tab.train)
                    .toolbar(.hidden, for: .tabBar)

                ProgressDashboardView()
                    .tag(Tab.progress)
                    .toolbar(.hidden, for: .tabBar)

                YouView()
                    .tag(Tab.you)
                    .toolbar(.hidden, for: .tabBar)
            }
            .tint(.pearl)

            // Custom floating tab bar
            ObsidianTabBar(selected: $selected)
        }
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

// MARK: - Custom tab bar

private struct ObsidianTabBar: View {
    @Binding var selected: ContentView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                tabItem(tab)
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Color.onyx)
                .edgeHighlight(radius: Theme.Radius.xl)
        )
        .padding(.horizontal, Theme.Space.md)
        .padding(.bottom, 20)
        .glow(active: true, radius: 12, color: .auraCore, intensity: 0.07)
    }

    private func tabItem(_ tab: ContentView.Tab) -> some View {
        let isSelected = selected == tab
        return Button {
            withAnimation(Theme.Motion.silk) { selected = tab }
        } label: {
            VStack(spacing: 5) {
                // Selection indicator
                Rectangle()
                    .fill(Color.pearl)
                    .frame(width: isSelected ? 20 : 0, height: 1.5)
                    .animation(Theme.Motion.silk, value: isSelected)

                Image(systemName: isSelected ? tab.iconActive : tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .regular : .thin))
                    .foregroundStyle(isSelected ? Color.pearl : Color.shadowTxt)
                    .animation(Theme.Motion.silk, value: isSelected)

                Text(tab.label.uppercased())
                    .font(Theme.Font.label)
                    .kerning(0.8)
                    .foregroundStyle(isSelected ? Color.pearl : Color.clear)
                    .frame(height: 12)
                    .animation(Theme.Motion.silk, value: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.pressable(scale: 0.94, haptic: .none, glow: false))
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
