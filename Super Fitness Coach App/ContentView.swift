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
    @State private var workoutEngine: WorkoutEngine?
    @State private var gamificationEngine: GamificationEngine?
    @State private var exerciseService: ExerciseService?
    @State private var exerciseImageLoader: ExerciseImageLoader?
    @State private var detoxManager: DetoxManager?
    @State private var userProfile: UserProfile?
    @State private var trainingPlanRepository: TrainingPlanRepository?

    // Cached ViewModels (prevent recreation on every render)
    @State private var homeViewModel: HomeViewModel?
    @State private var workoutViewModel: WorkoutViewModel?
    @State private var statsViewModel: StatsViewModel?
    @State private var profileViewModel: ProfileViewModel?
    @State private var trainingPreferencesViewModel: TrainingPreferencesViewModel?
    @State private var trainingPlanViewModel: TrainingPlanViewModel?

    // Tab selection
    @State private var selectedTab: Tab = .home

    // Navigation state for workout
    @State private var showingWorkout = false

    // Navigation state for training plan flow
    @State private var showingTrainingPreferences = false
    @State private var showingWorkoutExecutor = false
    @State private var selectedDayIndex: Int?

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
                workoutEngine: workoutEngine ?? WorkoutEngine(repository: WorkoutRepository(context: modelContext)),
                healthKitManager: healthKitManager
            ),
            onComplete: { [self] in
                // Re-initialize services if needed
                initializeServices()
                // Check onboarding status and transition UI
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
            Label("Home", systemImage: "house.fill")
        }
        .tag(Tab.home)
    }

    private var workoutTab: some View {
        Group {
            if let vm = workoutViewModel {
                WorkoutView(
                    viewModel: vm,
                    imageLoader: exerciseImageLoader,
                    trainingPlanVM: trainingPlanViewModel,
                    onNewTrainingPlan: { showingTrainingPreferences = true },
                    onStartTrainingWorkout: { dayIndex in
                        selectedDayIndex = dayIndex
                        showingWorkoutExecutor = true
                    }
                )
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
        .sheet(isPresented: $showingWorkoutExecutor) {
            if let executorVM = buildWorkoutExecutorViewModel() {
                WorkoutExecutorView(viewModel: executorVM)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("Couldn't load workout")
                        .font(.headline)
                    Text("No exercises found for today. Try regenerating your plan.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Close") { showingWorkoutExecutor = false }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .tabItem {
            Label("Workout", systemImage: "figure.run")
        }
        .tag(Tab.workout)
    }

    // MARK: - Build WorkoutExecutorViewModel

    private func buildWorkoutExecutorViewModel() -> WorkoutExecutorViewModel? {
        guard let repo = trainingPlanRepository,
              let dayIndex = selectedDayIndex else { return nil }

        guard let planVM = trainingPlanViewModel,
              let plan = planVM.plan,
              dayIndex >= 0, dayIndex < planVM.currentWeekDays.count else { return nil }

        // Use the value-type exercises snapshot — avoids SwiftData deserialization issues
        let exercises = dayIndex < planVM.dayExercises.count ? planVM.dayExercises[dayIndex] : []

        let setLogger = SetLogger(repository: repo)
        return WorkoutExecutorViewModel(
            plan: plan,
            plannedExercises: exercises,
            setLogger: setLogger,
            healthKitManager: healthKitManager
        )
    }

    private var statsTab: some View {
        Group {
            if let vm = statsViewModel {
                StatsView(viewModel: vm)
            }
        }
        .tabItem {
            Label("Stats", systemImage: "chart.bar.fill")
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
            Label("Profile", systemImage: "person.fill")
        }
        .tag(Tab.profile)
    }

    // MARK: - Initialization

    private func checkOnboarding() {
        let repo = UserProfileRepository(context: modelContext)
        if let profile = try? repo.fetch(), profile.onboardingCompleted {
            userProfile = profile
            hasCompletedOnboarding = true
            checkWeeklyPlanRegeneration()
            createViewModels()
        } else {
            hasCompletedOnboarding = false
        }
        isCheckingOnboarding = false
    }

    private func initializeServices() {
        guard !servicesReady else { return }
        
        let workoutRepo = WorkoutRepository(context: modelContext)
        let gamificationRepo = GamificationRepository(context: modelContext)
        let detoxRepo = DetoxRepository(context: modelContext)

        let we = WorkoutEngine(repository: workoutRepo)
        let ge = GamificationEngine(repository: gamificationRepo)
        let es = ExerciseService(apiKey: "655b0c38d3msh1d4ac5d7c628530p1eda67jsn147154d940a5")
        let eil = ExerciseImageLoader(apiKey: "655b0c38d3msh1d4ac5d7c628530p1eda67jsn147154d940a5")
        let dm = DetoxManager(repository: detoxRepo, gamificationEngine: ge)

        workoutEngine = we
        gamificationEngine = ge
        exerciseService = es
        exerciseImageLoader = eil
        detoxManager = dm
        trainingPlanRepository = TrainingPlanRepository(context: modelContext)
        servicesReady = true
    }

    private func createViewModels() {
        guard let we = workoutEngine,
              let ge = gamificationEngine,
              let es = exerciseService,
              let dm = detoxManager else { return }

        if homeViewModel == nil {
            homeViewModel = HomeViewModel(
                healthKitManager: healthKitManager,
                workoutEngine: we,
                gamificationEngine: ge,
                detoxManager: dm,
                notificationService: notificationService,
                userProfileRepository: UserProfileRepository(context: modelContext),
                userName: userProfile?.name ?? ""
            )
        }
        if workoutViewModel == nil {
            let bmiCategory: BMICategory?
            if let w = userProfile?.weightKg, let h = userProfile?.heightCm, h > 0 {
                let bmi = WorkoutEngine.calculateBMI(weightKg: w, heightCm: h)
                bmiCategory = WorkoutEngine.bmiCategory(bmi: bmi)
            } else {
                bmiCategory = nil
            }
            workoutViewModel = WorkoutViewModel(
                workoutEngine: we,
                exerciseService: es,
                gamificationEngine: ge,
                healthKitManager: healthKitManager,
                bmiCategory: bmiCategory
            )
        }
        if statsViewModel == nil {
            statsViewModel = StatsViewModel(gamificationEngine: ge)
        }
        if profileViewModel == nil {
            profileViewModel = ProfileViewModel(
                userProfileRepository: UserProfileRepository(context: modelContext),
                healthKitManager: healthKitManager,
                workoutEngine: we,
                notificationService: notificationService
            )
        }
        if trainingPreferencesViewModel == nil, let repo = trainingPlanRepository {
            trainingPreferencesViewModel = TrainingPreferencesViewModel(
                exerciseService: es,
                repository: repo
            )
        }
        if trainingPlanViewModel == nil, let repo = trainingPlanRepository {
            let dayMgr = DayManager(repository: repo)
            let tpvm = TrainingPlanViewModel(
                repository: repo,
                dayManager: dayMgr
            )
            tpvm.loadPlan()
            trainingPlanViewModel = tpvm
        }
    }

    // MARK: - Weekly Plan Auto-Regeneration

    /// Check if a new week has started (Monday 00:00) and regenerate the plan if needed.
    private func checkWeeklyPlanRegeneration() {
        guard let we = workoutEngine, let profile = userProfile else { return }

        let workoutRepo = WorkoutRepository(context: modelContext)
        let currentMonday = WorkoutEngine.currentWeekMonday()

        if let existingPlan = try? workoutRepo.fetchCurrentWeekPlan() {
            let calendar = Calendar.current
            let planMonday = calendar.startOfDay(for: existingPlan.weekStartDate)
            if planMonday < currentMonday {
                // New week — regenerate with body metrics
                let _ = we.generateWeeklyPlan(goal: profile.fitnessGoal, weightKg: profile.weightKg, heightCm: profile.heightCm)
            }
        } else {
            // No plan exists — generate one with body metrics
            let _ = we.generateWeeklyPlan(goal: profile.fitnessGoal, weightKg: profile.weightKg, heightCm: profile.heightCm)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            UserProfile.self,
            WeeklyPlan.self,
            WorkoutSession.self,
            GamificationState.self,
            DetoxProgress.self,
            TrainingPlan.self,
            TrainingWeek.self,
            TrainingDayPlan.self,
            WorkoutLog.self
        ])
}
