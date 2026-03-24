//
//  HomeViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation

@Observable
final class HomeViewModel {
    private(set) var recoveryScore: HealthDataStatus<Int> = .loading
    private(set) var activityScore: HealthDataStatus<Int> = .loading
    private(set) var statusIndicator: StatusIndicator = .yellow
    private(set) var recommendationText: String = ""
    private(set) var totalPoints: Int = 0
    private(set) var todayWorkoutType: WorkoutType = .rest
    private(set) var detoxActive: Bool = false
    private(set) var detoxCurrentDay: Int = 0
    private(set) var isLoading: Bool = false
    private(set) var recoveryBreakdown: ScoreBreakdown?
    private(set) var activityBreakdown: ScoreBreakdown?
    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    // MARK: - Smart Dashboard properties
    private(set) var coachSummary: String = ""
    private(set) var coachEmoji: String = "🟡"
    private(set) var actionCardTitle: String = ""
    private(set) var actionCardIntensity: ActionIntensity = .medium
    private(set) var recoveryLabel: String = ""
    private(set) var activityLabel: String = ""
    private(set) var recoveryInsights: [MetricInsight] = []
    private(set) var activityInsights: [MetricInsight] = []

    private let healthKitManager: HealthKitManager
    private let workoutEngine: WorkoutEngine
    private let gamificationEngine: GamificationEngine
    private let detoxManager: DetoxManager
    private let notificationService: NotificationService
    private let userProfileRepository: UserProfileRepository
    private let userName: String

    enum StatusIndicator: String {
        case red, yellow, green

        var emoji: String {
            switch self {
            case .red: return "🔴"
            case .yellow: return "🟡"
            case .green: return "🟢"
            }
        }

        var label: String {
            switch self {
            case .red: return "Fatigued"
            case .yellow: return "Medium"
            case .green: return "Optimal"
            }
        }

        static func from(score: Int) -> StatusIndicator {
            if score <= 39 { return .red }
            if score <= 69 { return .yellow }
            return .green
        }
    }

    enum ActionIntensity {
        case low, medium, high

        var label: String {
            switch self {
            case .low: return "Baja"
            case .medium: return "Media"
            case .high: return "Alta"
            }
        }

        var systemColor: String {
            switch self {
            case .low: return "red"
            case .medium: return "orange"
            case .high: return "green"
            }
        }
    }

    init(
        healthKitManager: HealthKitManager,
        workoutEngine: WorkoutEngine,
        gamificationEngine: GamificationEngine,
        detoxManager: DetoxManager,
        notificationService: NotificationService,
        userProfileRepository: UserProfileRepository,
        userName: String
    ) {
        self.healthKitManager = healthKitManager
        self.workoutEngine = workoutEngine
        self.gamificationEngine = gamificationEngine
        self.detoxManager = detoxManager
        self.notificationService = notificationService
        self.userProfileRepository = userProfileRepository
        self.userName = userName
    }

    /// Called when the Dashboard appears.
    func onAppear() async {
        await refreshData(showLoading: true)
    }

    /// Pull-to-refresh: re-reads profile config and re-queries HealthKit.
    func refresh() async {
        await refreshData(showLoading: false)
    }

    private func refreshData(showLoading: Bool = false) async {
        if showLoading { isLoading = true }
        defer { if showLoading { isLoading = false } }

        // Re-read FitnessConfig from profile every time (picks up changes from Profile tab)
        let config: FitnessConfig
        if let profile = try? userProfileRepository.fetch() {
            config = profile.effectiveFitnessConfig
        } else {
            config = .default
        }

        // Refresh HealthKit data with user's config
        await healthKitManager.refreshHealthData(config: config)
        recoveryScore = healthKitManager.recoveryScore
        activityScore = healthKitManager.activityScore
        recoveryBreakdown = healthKitManager.recoveryBreakdown
        activityBreakdown = healthKitManager.activityBreakdown
        authorizationStatus = healthKitManager.authorizationStatus

        let recoveryValue = recoveryScore.value ?? 50
        let activityValue = activityScore.value ?? 0
        statusIndicator = StatusIndicator.from(score: recoveryValue)

        // Get today's scheduled workout type from the weekly plan
        todayWorkoutType = todayScheduledWorkoutType()

        // Generate AI Coach recommendation with both scores and breakdown
        recommendationText = AICoach.generateMessage(
            userName: userName,
            recoveryScore: recoveryValue,
            activityScore: activityValue,
            recoveryBreakdown: recoveryBreakdown,
            streakDays: gamificationEngine.currentStreak,
            recentWorkoutCount: gamificationEngine.workoutsCompleted
        )

        // Smart Dashboard: coach summary and emoji
        coachSummary = recommendationText
        if recoveryValue < 40 {
            coachEmoji = "🔴"
        } else if recoveryValue < 70 {
            coachEmoji = "🟡"
        } else {
            coachEmoji = "🟢"
        }

        // Smart Dashboard: descriptive labels
        recoveryLabel = generateRecoveryLabel(score: recoveryValue)
        activityLabel = generateActivityLabel(score: activityValue)

        // Smart Dashboard: action card
        generateActionCard(recoveryScore: recoveryValue, workoutType: todayWorkoutType)

        // Smart Dashboard: metric insights
        if let rb = recoveryBreakdown {
            recoveryInsights = MetricInsightGenerator.generateInsights(from: rb, config: config)
        } else {
            recoveryInsights = []
        }
        if let ab = activityBreakdown {
            activityInsights = MetricInsightGenerator.generateInsights(from: ab, config: config)
        } else {
            activityInsights = []
        }

        // Update points
        totalPoints = gamificationEngine.totalPoints

        // Update detox status
        if let progress = detoxManager.currentProgress, progress.isActive, !progress.isCompleted {
            detoxActive = true
            detoxCurrentDay = progress.currentDay
        } else {
            detoxActive = false
            detoxCurrentDay = 0
        }

        // Schedule daily notification
        let workoutLabel = todayWorkoutType.rawValue.capitalized
        await notificationService.scheduleDailyNotification(
            recoveryScore: recoveryValue,
            statusEmoji: statusIndicator.emoji,
            recommendation: "\(workoutLabel) is ready"
        )
    }

    /// Determine today's workout type from the current weekly plan.
    private func todayScheduledWorkoutType() -> WorkoutType {
        workoutEngine.todayWorkoutType()
    }

    // MARK: - Smart Dashboard helpers

    private func generateRecoveryLabel(score: Int) -> String {
        switch score {
        case 0...39: return "Necesitas descanso"
        case 40...69: return "Recuperación moderada"
        case 70...84: return "Buena recuperación"
        default: return "Recuperación óptima"
        }
    }

    private func generateActivityLabel(score: Int) -> String {
        switch score {
        case 0...39: return "Día tranquilo"
        case 40...69: return "En progreso"
        case 70...84: return "Muy activo"
        default: return "Excelente actividad"
        }
    }

    private func generateActionCard(recoveryScore: Int, workoutType: WorkoutType) {
        if recoveryScore < 40 {
            actionCardTitle = "Hoy: Descanso activo"
            actionCardIntensity = .low
        } else if recoveryScore < 70 {
            actionCardTitle = "Hoy: \(workoutType.rawValue.capitalized) moderado"
            actionCardIntensity = .medium
        } else {
            actionCardTitle = "Hoy: \(workoutType.rawValue.capitalized)"
            actionCardIntensity = .high
        }
    }
}
