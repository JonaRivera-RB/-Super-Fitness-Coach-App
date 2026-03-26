//
//  ContentView.swift
//  Super Fitness Coach App
//
//  Created by Jonathan Rivera on 22/03/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasCompletedOnboarding: Bool = false
    @State private var isCheckingOnboarding: Bool = true

    // Shared services
    @State private var healthKitManager = HealthKitManager()
    @State private var notificationService = NotificationService()

    // Lazy-initialized services (depend on modelContext)
    @State private var servicesReady = false
    @State private var gamificationEngine: GamificationEngine?
    @State private var exerciseService: ExerciseService?
    @State private var exerciseImageLoader: ExerciseImageLoader?
    @State private var detoxManager: DetoxManager?
    @State private var userProfile: UserProfile?
    @State private var trainingPlanRepository: TrainingPlanRepository?

    // Cached ViewModels (prevent recreation on every render)
    @State private var homeViewModel: HomeViewModel?
    @State private var statsViewModel: StatsViewModel?
    @State private var profileViewModel: ProfileViewModel?
    @State private var trainingPreferencesViewModel: TrainingPreferencesViewModel?
    @State private var trainingPlanViewModel: TrainingPlanViewModel?

    // Tab selection
    @State private var selectedTab: Tab = .home

    // Navigation state for workout
    @State private var showingWorkout = false
    @State private var showingRoutineEditor = false

    // Navigation state for training plan flow
    @State private var showingTrainingPreferences = false
    @State private var showingFeedback = false
    @State private var feedbackLogs: [WorkoutLog] = []
    @State private var selectedDayIndex: Int?
    @State private var cachedExecutorViewModel: WorkoutExecutorViewModel?

    // Wrapper to make WorkoutExecutorViewModel identifiable for sheet(item:)
    struct ExecutorItem: Identifiable {
        let id = UUID()
        let viewModel: WorkoutExecutorViewModel
        /// `nil` = entreno del plan; si no, día de la semana (1...7) de Mi rutina.
        let routineDayOfWeek: Int?
    }
    @State private var executorItem: ExecutorItem?

    enum Tab: Hashable {
        case home, workout, stats, profile
    }

    var body: some View {
        Group {
            if isCheckingOnboarding {
                ProgressView()
            } else if !hasCompletedOnboarding {
                onboardingView
            } else if servicesReady {
                mainTabView
            } else {
                ProgressView()
            }
        }
        .task {
            initializeServices()
            healthKitManager.configureObserverRefresh {
                let repo = UserProfileRepository(context: modelContext)
                return (try? repo.fetch())?.effectiveFitnessConfig ?? .default
            }
            // Start observing HealthKit for new sleep data (auto-refresh on wake)
            // Only starts observers if already authorized — no permission prompt
            healthKitManager.startSleepMonitoring()
            // Start observing key health metrics (HR, HRV, steps, calories) for real-time updates
            healthKitManager.startHealthObservers()
            // Request notification permission on launch (no-op if already granted)
            let _ = await notificationService.requestPermission()
            // Now check onboarding and show UI
            checkOnboarding()
        }
    }

    // MARK: - Onboarding

    private var onboardingView: some View {
        OnboardingView(
            viewModel: OnboardingViewModel(
                profileRepository: UserProfileRepository(context: modelContext),
                healthKitManager: healthKitManager
            ),
            onComplete: { [self] in
                initializeServices()
                checkOnboarding()
            }
        )
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            homeTab
            workoutTab
            statsTab
            profileTab
        }
        .onChange(of: trainingPlanViewModel == nil) { _, isNil in
            if !isNil {
                // ViewModel just became available — load plan
                Task { @MainActor in
                    trainingPlanViewModel?.loadPlan()
                }
            }
        }
    }

    private var homeTab: some View {
        Group {
            if let vm = homeViewModel {
                HomeView(
                    viewModel: vm,
                    onStartRoutine: { selectedTab = .workout }
                )
            }
        }
        .tabItem {
            Label("Inicio", systemImage: "house.fill")
        }
        .tag(Tab.home)
    }

    private var workoutTab: some View {
        Group {
            WorkoutView(
                trainingPlanVM: trainingPlanViewModel,
                onNewTrainingPlan: { showingTrainingPreferences = true },
                onStartTrainingWorkout: { dayIndex in
                    selectedDayIndex = dayIndex
                    if let vm = buildWorkoutExecutorViewModel(for: dayIndex) {
                        executorItem = ExecutorItem(viewModel: vm, routineDayOfWeek: nil)
                    }
                },
                onEditRoutine: { showingRoutineEditor = true },
                onStartRoutineWorkout: { planned, dayOfWeek in
                    selectedDayIndex = nil
                    if let vm = buildRoutineExecutorViewModel(plannedExercises: planned) {
                        executorItem = ExecutorItem(viewModel: vm, routineDayOfWeek: dayOfWeek)
                    }
                }
            )
            .task {
                trainingPlanViewModel?.loadPlan()
            }
        }
        .sheet(isPresented: $showingRoutineEditor) {
            RoutineEditorView()
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .workout {
                // Re-load every time user switches to workout tab
                trainingPlanViewModel?.loadPlan()
            }
        }
        .sheet(isPresented: $showingTrainingPreferences, onDismiss: {
            if let generated = trainingPreferencesViewModel?.generatedPlan {
                trainingPlanViewModel?.setPlan(generated)
            } else {
                trainingPlanViewModel?.loadPlan()
            }
            trainingPreferencesViewModel?.resetState()
        }) {
            if let vm = trainingPreferencesViewModel {
                TrainingPreferencesView(viewModel: vm)
            }
        }
        .sheet(item: $executorItem) { item in
            WorkoutExecutorView(
                viewModel: item.viewModel,
                onWorkoutComplete: { logs in
                    feedbackLogs = logs
                    if let dow = item.routineDayOfWeek {
                        markRoutineDayCompleted(dayOfWeek: dow)
                    } else if let idx = selectedDayIndex {
                        // Apply performance-based updates before completing the day
                        if let repo = trainingPlanRepository {
                            try? repo.applyPerformanceUpdates(workoutLogs: logs)
                        }
                        trainingPlanViewModel?.completeDay(at: idx)
                    }
                    selectedDayIndex = nil
                    executorItem = nil
                    showingFeedback = true
                }
            )
        }
        .sheet(isPresented: $showingFeedback) {
            if let repo = trainingPlanRepository,
               let ge = gamificationEngine {
                FeedbackView(viewModel: FeedbackViewModel(
                    workoutLogs: feedbackLogs,
                    repository: repo,
                    gamificationEngine: ge
                ))
            }
        }
        .tabItem {
            Label("Entrenamiento", systemImage: "figure.run")
        }
        .tag(Tab.workout)
    }

    private func markRoutineDayCompleted(dayOfWeek: Int) {
        do {
            let repo = UserRoutineRepository(context: modelContext)
            try repo.markRoutineDayCompleted(dayOfWeek: dayOfWeek)
        } catch {
            print("❌ markRoutineDayCompleted: \(error.localizedDescription)")
        }
    }

    // MARK: - Build WorkoutExecutorViewModel

    private func buildWorkoutExecutorViewModel(for dayIndex: Int) -> WorkoutExecutorViewModel? {
        guard let repo = trainingPlanRepository else {
            print("❌ buildExecutorVM: no repository")
            return nil
        }

        guard let plan = try? repo.fetchActivePlan() else {
            print("❌ buildExecutorVM: no active plan")
            return nil
        }

        print("✅ buildExecutorVM: plan found, weeks=\(plan.weeks.count), currentWeek=\(plan.currentWeek)")

        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else {
            print("❌ buildExecutorVM: weekIndex \(weekIndex) out of range (weeks=\(plan.weeks.count))")
            return nil
        }

        let sortedDays = plan.weeks[weekIndex].days.sorted { $0.dayOfWeek < $1.dayOfWeek }
        print("✅ buildExecutorVM: days=\(sortedDays.count), dayIndex=\(dayIndex)")

        guard dayIndex >= 0, dayIndex < sortedDays.count else {
            print("❌ buildExecutorVM: dayIndex \(dayIndex) out of range (days=\(sortedDays.count))")
            return nil
        }

        let day = sortedDays[dayIndex]
        print("✅ buildExecutorVM: day dow=\(day.dayOfWeek), exercises=\(day.exercises.count), isRest=\(day.isRestDay)")

        guard !day.exercises.isEmpty else {
            print("❌ buildExecutorVM: exercises empty for day \(day.dayOfWeek)")
            return nil
        }

        let setLogger = SetLogger(repository: repo)
        return WorkoutExecutorViewModel(
            currentWeek: plan.currentWeek,
            plannedExercises: day.exercises,
            setLogger: setLogger,
            healthKitManager: healthKitManager,
            goal: plan.preferences.goal
        )
    }

    private func buildRoutineExecutorViewModel(plannedExercises: [PlannedExercise]) -> WorkoutExecutorViewModel? {
        guard let repo = trainingPlanRepository else { return nil }
        let setLogger = SetLogger(repository: repo)
        return WorkoutExecutorViewModel(
            currentWeek: 1,
            plannedExercises: plannedExercises,
            setLogger: setLogger,
            healthKitManager: healthKitManager,
            goal: .beHealthy
        )
    }

    private var statsTab: some View {
        Group {
            if let vm = statsViewModel {
                StatsView(viewModel: vm)
            }
        }
        .tabItem {
            Label("Estadísticas", systemImage: "chart.bar.fill")
        }
        .tag(Tab.stats)
    }

    private var profileTab: some View {
        Group {
            if let vm = profileViewModel {
                ProfileView(viewModel: vm)
            }
        }
        .tabItem {
            Label("Perfil", systemImage: "person.fill")
        }
        .tag(Tab.profile)
    }

    // MARK: - Initialization

    private func checkOnboarding() {
        let repo = UserProfileRepository(context: modelContext)
        if let profile = try? repo.fetchCompleted() {
            userProfile = profile
            hasCompletedOnboarding = true
            createViewModels()
        } else {
            hasCompletedOnboarding = false
        }
        isCheckingOnboarding = false
    }

    private func initializeServices() {
        guard !servicesReady else { return }

        let gamificationRepo = GamificationRepository(context: modelContext)
        let detoxRepo = DetoxRepository(context: modelContext)

        let ge = GamificationEngine(repository: gamificationRepo)
        let es = ExerciseService(apiKey: "655b0c38d3msh1d4ac5d7c628530p1eda67jsn147154d940a5")
        let eil = ExerciseImageLoader(apiKey: "655b0c38d3msh1d4ac5d7c628530p1eda67jsn147154d940a5")
        let dm = DetoxManager(repository: detoxRepo, gamificationEngine: ge)

        gamificationEngine = ge
        exerciseService = es
        exerciseImageLoader = eil
        detoxManager = dm
        trainingPlanRepository = TrainingPlanRepository(context: modelContext)
        servicesReady = true
    }

    private func createViewModels() {
        guard let ge = gamificationEngine,
              let es = exerciseService,
              let dm = detoxManager,
              let repo = trainingPlanRepository else { return }

        if homeViewModel == nil {
            homeViewModel = HomeViewModel(
                healthKitManager: healthKitManager,
                trainingPlanRepository: repo,
                gamificationEngine: ge,
                detoxManager: dm,
                notificationService: notificationService,
                userProfileRepository: UserProfileRepository(context: modelContext),
                recoverySnapshotRepository: RecoverySnapshotRepository(context: modelContext),
                userName: userProfile?.name ?? ""
            )
        }
        if statsViewModel == nil {
            statsViewModel = StatsViewModel(
                gamificationEngine: ge,
                trainingPlanRepository: repo,
                exerciseService: es
            )
        }
        if profileViewModel == nil {
            profileViewModel = ProfileViewModel(
                userProfileRepository: UserProfileRepository(context: modelContext),
                healthKitManager: healthKitManager,
                notificationService: notificationService
            )
        }
        if trainingPreferencesViewModel == nil {
            trainingPreferencesViewModel = TrainingPreferencesViewModel(
                exerciseService: es,
                repository: repo,
                userProfileRepository: UserProfileRepository(context: modelContext)
            )
        }
        if trainingPlanViewModel == nil {
            let dayMgr = DayManager(repository: repo)
            let tpvm = TrainingPlanViewModel(repository: repo, dayManager: dayMgr)
            trainingPlanViewModel = tpvm
            Task { @MainActor in tpvm.loadPlan() }
        }
    }

    // MARK: - Weekly Plan Auto-Regeneration removed (legacy system eliminated)
}

#Preview {
    ContentView()
        .modelContainer(for: [
            UserProfile.self,
            GamificationState.self,
            DetoxProgress.self,
            TrainingPlan.self,
            TrainingWeek.self,
            TrainingDayPlan.self,
            WorkoutLog.self,
            RecoverySnapshot.self,
            UserRoutine.self,
            UserRoutineDay.self
        ])
}
