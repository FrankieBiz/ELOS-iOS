import SwiftUI
import SwiftData

@main
struct ElosApp: App {
    @StateObject private var authStore = AuthStore()
    private let container: ModelContainer
    @StateObject private var viewModel: AppViewModel
    @StateObject private var trainViewModel: TrainViewModel
    @StateObject private var socialViewModel: SocialViewModel
    @StateObject private var trainingContext = TrainingContext()

    init() {
        let schema = Schema([
            HabitRecord.self,
            MealEntryRecord.self,
            SleepRecord.self,
            HydrationRecord.self,
            AssignmentRecord.self,
            ExamRecord.self,
            UserProfileRecord.self,
            WorkoutSessionRecord.self,
            ExerciseSetRecord.self,
            ExerciseDefinitionRecord.self,
            WorkoutTemplateRecord.self,
            TemplateExerciseRecord.self,
            ReadinessCheckInRecord.self,
            CreatorRecord.self,
            LibraryWorkoutRecord.self,
            MachineRecord.self,
            SavedLibraryWorkoutRecord.self,
            FriendRecord.self,
            LeaderboardEntryRecord.self,
            UserSplitRecord.self,
            UserSplitDayRecord.self,
            ScheduleEventRecord.self,
            CourseRecord.self,
        ])
        let c = Self.makeContainer(schema: schema)
        container = c
        ExerciseCatalog.seedIfNeeded(context: c.mainContext)
        _viewModel = StateObject(wrappedValue: AppViewModel(context: c.mainContext))
        _trainViewModel = StateObject(wrappedValue: TrainViewModel(context: c.mainContext))
        _socialViewModel = StateObject(wrappedValue: SocialViewModel(context: c.mainContext))
    }

    private static func makeContainer(schema: Schema) -> ModelContainer {
        let config = ModelConfiguration("ElosStore", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("SwiftData container init failed: \(error). Attempting recovery by deleting store.")
            Self.deleteStoreFiles()
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                print("SwiftData store delete + retry failed: \(error). Falling back to in-memory store.")
                let memoryConfig = ModelConfiguration("ElosStoreMemory", schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: memoryConfig)
                } catch {
                    fatalError("SwiftData in-memory fallback also failed: \(error)")
                }
            }
        }
    }

    private static func deleteStoreFiles() {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        let storeNames = ["ElosStore.store", "ElosStore.store-shm", "ElosStore.store-wal", "default.store"]
        for name in storeNames {
            let url = appSupport.appendingPathComponent(name)
            try? fm.removeItem(at: url)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authStore)
                .environmentObject(viewModel)
                .environmentObject(trainViewModel)
                .environmentObject(socialViewModel)
                .environmentObject(trainingContext)
                .modelContainer(container)
                .onAppear {
                    NotificationManager.requestAuthorization()
                    NotificationManager.scheduleHabitReminder(hour: 20, minute: 0)
                }
        }
    }
}
