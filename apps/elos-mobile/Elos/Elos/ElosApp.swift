import SwiftUI
import SwiftData
import Supabase

private struct InviteTarget: Identifiable {
    let userId: String
    var id: String { userId }
}

private struct TemplateShareTarget: Identifiable {
    let shareCode: String
    var id: String { shareCode }
}

@main
struct ElosApp: App {
    @StateObject private var authStore = AuthStore()
    private let container: ModelContainer
    private let launchError: String?
    @StateObject private var viewModel: AppViewModel
    @StateObject private var trainViewModel: TrainViewModel
    @StateObject private var socialViewModel: SocialViewModel
    @StateObject private var feedViewModel = FeedViewModel()
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
            PendingSetDeletion.self,
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
        let (c, err) = Self.makeContainer(schema: schema)
        container = c
        launchError = err
        _viewModel = StateObject(wrappedValue: AppViewModel(context: c.mainContext))
        _trainViewModel = StateObject(wrappedValue: TrainViewModel(context: c.mainContext))
        _socialViewModel = StateObject(wrappedValue: SocialViewModel(context: c.mainContext))
    }

    private static func makeContainer(schema: Schema) -> (ModelContainer, String?) {
        let config = ModelConfiguration("ElosStore", schema: schema)
        do {
            return (try ModelContainer(for: schema, configurations: config), nil)
        } catch {
            print("SwiftData container init failed: \(error). Attempting recovery by deleting store.")
            Self.deleteStoreFiles()
            do {
                return (try ModelContainer(for: schema, configurations: config), nil)
            } catch {
                print("SwiftData store delete + retry failed: \(error). Falling back to in-memory store.")
                let memoryConfig = ModelConfiguration("ElosStoreMemory", schema: schema, isStoredInMemoryOnly: true)
                do {
                    let c = try ModelContainer(for: schema, configurations: memoryConfig)
                    return (c, "Elos could not restore your database. Your data is safe but won't be saved this session. Please reinstall the app.")
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
            if let error = launchError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Something went wrong")
                        .font(.title2).fontWeight(.bold)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                RootView()
                    .environmentObject(authStore)
                    .environmentObject(viewModel)
                    .environmentObject(trainViewModel)
                    .environmentObject(socialViewModel)
                    .environmentObject(feedViewModel)
                    .environmentObject(trainingContext)
                    .modelContainer(container)
                    .onAppear {
                        NotificationManager.requestAuthorization()
                        NotificationManager.scheduleDailyNotifications(
                            viewModel.upcomingNotificationDays(), hour: 20, minute: 0
                        )
                        Task { await ApiClient.shared.warmup() }
                        Task { await viewModel.refreshHealthMetrics() }
                        let ctx = container.mainContext
                        Task { ExerciseCatalog.seedIfNeeded(context: ctx) }
                    }
                    .onChange(of: viewModel.activeSplit?.id) { _, _ in
                        NotificationManager.scheduleDailyNotifications(
                            viewModel.upcomingNotificationDays(), hour: 20, minute: 0
                        )
                    }
                    .onOpenURL { url in
                        guard url.scheme == "elos",
                              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        else { return }
                        switch url.host {
                        case "auth-callback":
                            // Email confirmation / password recovery link. The SDK
                            // exchanges the URL for a live session; AuthStore's
                            // authStateChanges then routes into the app signed in.
                            let isRecovery = (components.queryItems?.contains { $0.name == "type" && $0.value == "recovery" } ?? false)
                                || (url.fragment?.contains("type=recovery") ?? false)
                            Task {
                                do {
                                    _ = try await SupabaseManager.shared.client.auth.session(from: url)
                                    if isRecovery {
                                        viewModel.pendingPasswordReset = true
                                    }
                                } catch {
                                    viewModel.showError("That link has expired. Request a new one and try again.")
                                }
                            }
                        case "add-friend":
                            if let userId = components.queryItems?.first(where: { $0.name == "userId" })?.value,
                               !userId.isEmpty {
                                viewModel.pendingFriendInviteUserId = userId
                            }
                        case "template":
                            if let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                               !code.isEmpty {
                                viewModel.pendingTemplateShareCode = code
                            }
                        default:
                            break
                        }
                    }
                    .sheet(item: Binding(
                        get: { viewModel.pendingFriendInviteUserId.map { InviteTarget(userId: $0) } },
                        set: { if $0 == nil { viewModel.pendingFriendInviteUserId = nil } }
                    )) { target in
                        FriendInviteSheet(inviterUserId: target.userId)
                            .environmentObject(socialViewModel)
                    }
                    .sheet(item: Binding(
                        get: { viewModel.pendingTemplateShareCode.map { TemplateShareTarget(shareCode: $0) } },
                        set: { if $0 == nil { viewModel.pendingTemplateShareCode = nil } }
                    )) { target in
                        TemplateImportSheet(shareCode: target.shareCode)
                            .environmentObject(viewModel)
                    }
                    .sheet(isPresented: $viewModel.pendingPasswordReset) {
                        NewPasswordSheet()
                    }
            }
        }
    }
}
