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
    private(set) var todayMuscleLabel: String = "Entrenamiento"
    private(set) var detoxActive: Bool = false
    private(set) var detoxCurrentDay: Int = 0
    private(set) var isLoading: Bool = false
    private(set) var recoveryBreakdown: ScoreBreakdown?
    private(set) var activityBreakdown: ScoreBreakdown?
    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    private(set) var coachSummary: String = ""
    private(set) var coachEmoji: String = "🟡"
    private(set) var actionCardTitle: String = ""
    private(set) var actionCardIntensity: ActionIntensity = .medium
    private(set) var recoveryLabel: String = ""
    private(set) var activityLabel: String = ""
    private(set) var recoveryConfidenceLabel: String = ""
    /// "Anoche" card: sleep duration, window, goal line, HRV/RHR vs baseline.
    private(set) var lastNightSleepSummary: String = ""
    private(set) var lastNightSleepWindow: String = ""
    private(set) var sleepGoalComparisonLine: String = ""
    private(set) var hrvVsBaselineLine: String = ""
    private(set) var rhrVsBaselineLine: String = ""
    /// Traduccion humana (bueno/malo) basada en las comparativas vs media.
    private(set) var quickMeaningLine: String = ""
    private(set) var recoveryInsights: [MetricInsight] = []
    private(set) var activityInsights: [MetricInsight] = []

    private let healthKitManager: HealthKitManager
    private let trainingPlanRepository: TrainingPlanRepository
    private let gamificationEngine: GamificationEngine
    private let detoxManager: DetoxManager
    private let notificationService: NotificationService
    private let userProfileRepository: UserProfileRepository
    private let userName: String

    enum StatusIndicator: String {
        case red, yellow, green
        var emoji: String {
            switch self { case .red: return "🔴"; case .yellow: return "🟡"; case .green: return "🟢" }
        }
        var label: String {
            switch self { case .red: return "Fatigued"; case .yellow: return "Medium"; case .green: return "Optimal" }
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
            switch self { case .low: return "Baja"; case .medium: return "Media"; case .high: return "Alta" }
        }
    }

    init(
        healthKitManager: HealthKitManager,
        trainingPlanRepository: TrainingPlanRepository,
        gamificationEngine: GamificationEngine,
        detoxManager: DetoxManager,
        notificationService: NotificationService,
        userProfileRepository: UserProfileRepository,
        userName: String
    ) {
        self.healthKitManager = healthKitManager
        self.trainingPlanRepository = trainingPlanRepository
        self.gamificationEngine = gamificationEngine
        self.detoxManager = detoxManager
        self.notificationService = notificationService
        self.userProfileRepository = userProfileRepository
        self.userName = userName
    }

    func onAppear() async { await refreshData(showLoading: true) }
    func refresh() async { await refreshData(showLoading: false) }

    private func refreshData(showLoading: Bool = false) async {
        if showLoading { isLoading = true }
        defer { if showLoading { isLoading = false } }

        let config: FitnessConfig
        if let profile = try? userProfileRepository.fetch() {
            config = profile.effectiveFitnessConfig
        } else {
            config = .default
        }

        await healthKitManager.refreshHealthData(config: config)
        recoveryScore = healthKitManager.recoveryScore
        activityScore = healthKitManager.activityScore
        recoveryBreakdown = healthKitManager.recoveryBreakdown
        activityBreakdown = healthKitManager.activityBreakdown
        authorizationStatus = healthKitManager.authorizationStatus
        recoveryConfidenceLabel = healthKitManager.recoveryConfidence.labelEs
        populateRecoveryContextLines(config: config)

        let recoveryValue = recoveryScore.value ?? 50
        let activityValue = activityScore.value ?? 0
        statusIndicator = StatusIndicator.from(score: recoveryValue)

        todayMuscleLabel = todayMusclesFromPlan()

        recommendationText = AICoach.generateMessage(
            userName: userName,
            recoveryScore: recoveryValue,
            activityScore: activityValue,
            recoveryBreakdown: recoveryBreakdown,
            streakDays: gamificationEngine.currentStreak,
            recentWorkoutCount: gamificationEngine.workoutsCompleted
        )

        coachSummary = recommendationText
        coachEmoji = recoveryValue < 40 ? "🔴" : recoveryValue < 70 ? "🟡" : "🟢"
        recoveryLabel = generateRecoveryLabel(score: recoveryValue)
        activityLabel = generateActivityLabel(score: activityValue)
        generateActionCard(recoveryScore: recoveryValue, muscleLabel: todayMuscleLabel)

        recoveryInsights = recoveryBreakdown.map { MetricInsightGenerator.generateInsights(from: $0, config: config) } ?? []
        activityInsights = activityBreakdown.map { MetricInsightGenerator.generateInsights(from: $0, config: config) } ?? []

        totalPoints = gamificationEngine.totalPoints

        if let progress = detoxManager.currentProgress, progress.isActive, !progress.isCompleted {
            detoxActive = true; detoxCurrentDay = progress.currentDay
        } else {
            detoxActive = false; detoxCurrentDay = 0
        }

        await notificationService.scheduleDailyNotification(
            recoveryScore: recoveryValue,
            statusEmoji: statusIndicator.emoji,
            recommendation: "\(todayMuscleLabel) is ready"
        )
    }

    private func todayMusclesFromPlan() -> String {
        guard let plan = try? trainingPlanRepository.fetchActivePlan() else { return "Entrenamiento" }
        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else { return "Descanso" }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let todayDow = weekday == 1 ? 7 : weekday - 1
        guard let day = plan.weeks[weekIndex].days.first(where: { $0.dayOfWeek == todayDow }) else { return "Descanso" }
        if day.isRestDay { return "Descanso" }
        let muscles = day.muscleGroups.map { $0.rawValue.capitalized }.joined(separator: " & ")
        return muscles.isEmpty ? "Entrenamiento" : muscles
    }

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

    private func populateRecoveryContextLines(config: FitnessConfig) {
        let hk = healthKitManager
        var sleepDiff: Double?
        var hrvPct: Double?
        var rhrDelta: Double?

        switch hk.sleepHours {
        case .available(let hours):
            lastNightSleepSummary = String(format: "Dormiste ~%.1f h", hours)
        default:
            lastNightSleepSummary = "Sin datos de sueño para anoche"
        }

        if let start = hk.sleepSessionStart, let end = hk.sleepSessionEnd {
            lastNightSleepWindow = "\(Self.formatLocalTimeOnly(start)) → \(Self.formatLocalTimeOnly(end))"
        } else {
            lastNightSleepWindow = ""
        }

        if config.sleepGoalHours > 0, case .available(let hours) = hk.sleepHours {
            let goal = config.sleepGoalHours
            let diff = hours - goal
            sleepDiff = diff
            if diff >= -0.05 {
                sleepGoalComparisonLine = String(format: "Meta %.1f h · anoche %.1f h (en o por encima de la meta)", goal, hours)
            } else {
                sleepGoalComparisonLine = String(format: "Meta %.1f h · anoche %.1f h (%.1f h menos que la meta)", goal, hours, -diff)
            }
        } else {
            sleepGoalComparisonLine = ""
        }

        if let actual = hk.hrv.value, let baseline = hk.hrvBaselineUsed, baseline > 0 {
            let pct = (actual - baseline) / baseline * 100.0
            hrvPct = pct
            let dir: String
            if abs(pct) < 3 {
                dir = "similar a tu media 14 d"
            } else if pct > 0 {
                dir = String(format: "%.0f%% por encima de tu media 14 d", pct)
            } else {
                dir = String(format: "%.0f%% por debajo de tu media 14 d", abs(pct))
            }
            hrvVsBaselineLine = String(format: "HRV %.0f ms · %@ (media ~%.0f ms)", actual, dir, baseline)
        } else {
            hrvVsBaselineLine = ""
        }

        if let actual = hk.restingHR.value, let baseline = hk.restingHRBaselineUsed, baseline > 0 {
            let delta = baseline - actual
            rhrDelta = delta
            let note: String
            if abs(delta) < 1 {
                note = "similar a tu media 14 d"
            } else if delta > 0 {
                note = String(format: "%.0f lpm menos que tu media (%.0f)", delta, baseline)
            } else {
                note = String(format: "%.0f lpm más que tu media (%.0f)", -delta, baseline)
            }
            rhrVsBaselineLine = String(format: "FC en reposo %.0f lpm · %@", actual, note)
        } else {
            rhrVsBaselineLine = ""
        }

        // ---- Traducción humana: bueno / malo / mixto ----
        let sleepPhrase: String
        if let diff = sleepDiff {
            sleepPhrase = diff >= 0 ? "sueño cerca/sobre tu meta" : "sueño por debajo de tu meta"
        } else {
            sleepPhrase = "sin dato claro de sueño"
        }

        let hrvPhrase: String
        if let pct = hrvPct {
            if abs(pct) < 3 { hrvPhrase = "HRV similar a tu media" }
            else if pct > 0 { hrvPhrase = "HRV por encima (buena recuperación)" }
            else { hrvPhrase = "HRV por debajo (más carga/fatiga)" }
        } else {
            hrvPhrase = "sin dato de HRV"
        }

        let rhrPhrase: String
        if let delta = rhrDelta {
            if abs(delta) < 1 { rhrPhrase = "FC reposo similar a tu media" }
            else if delta > 0 { rhrPhrase = "FC reposo mejor que tu media" }
            else { rhrPhrase = "FC reposo más alta que tu media" }
        } else {
            rhrPhrase = "sin dato de FC reposo"
        }

        // Mensaje final: prioriza la etiqueta de confianza del recovery.
        switch hk.recoveryConfidence {
        case .high:
            quickMeaningLine = "Interpretación rápida: señales favorables. (Señales: \(sleepPhrase), \(hrvPhrase), \(rhrPhrase))"
        case .medium:
            quickMeaningLine = "Interpretación rápida: señales mixtas. (Señales: \(sleepPhrase), \(hrvPhrase), \(rhrPhrase))"
        case .low:
            quickMeaningLine = "Interpretación rápida: señales poco claras. (Señales: \(sleepPhrase), \(hrvPhrase), \(rhrPhrase))"
        case .insufficient:
            quickMeaningLine = "Interpretación rápida: faltan datos clave para una lectura fiable."
        }
    }

    private static func formatLocalTimeOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = .current
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func generateActionCard(recoveryScore: Int, muscleLabel: String) {
        if recoveryScore < 40 {
            actionCardTitle = "Hoy: Descanso activo"; actionCardIntensity = .low
        } else if recoveryScore < 70 {
            actionCardTitle = "Hoy: \(muscleLabel) moderado"; actionCardIntensity = .medium
        } else {
            actionCardTitle = "Hoy: \(muscleLabel)"; actionCardIntensity = .high
        }
    }
}
