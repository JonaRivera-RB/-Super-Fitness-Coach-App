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
    /// Regularidad vs horario configurado (Req. 9); vacío si no hay horario en Perfil.
    private(set) var sleepConsistencyLine: String = ""
    /// Una línea visible al inicio del dashboard: puntuación + confianza de datos.
    private(set) var dashboardHeroLine: String = ""
    /// Sueño anoche vs media de noches previas (HealthKit).
    private(set) var sleepTrendLine: String = ""
    /// VoiceOver corto para el resumen del coach (evita leer párrafos largos).
    private(set) var coachSummaryAccessibilityLabel: String = ""
    /// VoiceOver corto para la interpretación rápida.
    private(set) var quickMeaningAccessibilityLabel: String = ""
    /// Últimos días con recuperación guardada localmente (más antiguo → más reciente).
    private(set) var recoveryHistoryDays: [RecoveryHistoryDay] = []
    private(set) var recoveryInsights: [MetricInsight] = []
    private(set) var activityInsights: [MetricInsight] = []

    private let healthKitManager: HealthKitManager
    private let trainingPlanRepository: TrainingPlanRepository
    private let gamificationEngine: GamificationEngine
    private let detoxManager: DetoxManager
    private let notificationService: NotificationService
    private let userProfileRepository: UserProfileRepository
    private let recoverySnapshotRepository: RecoverySnapshotRepository
    private let userName: String

    struct RecoveryHistoryDay: Identifiable, Equatable {
        let id: Date
        let weekdayShort: String
        let recoveryScore: Int
    }

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
        recoverySnapshotRepository: RecoverySnapshotRepository,
        userName: String
    ) {
        self.healthKitManager = healthKitManager
        self.trainingPlanRepository = trainingPlanRepository
        self.gamificationEngine = gamificationEngine
        self.detoxManager = detoxManager
        self.notificationService = notificationService
        self.userProfileRepository = userProfileRepository
        self.recoverySnapshotRepository = recoverySnapshotRepository
        self.userName = userName
    }

    func onAppear() async { await refreshData(showLoading: true) }
    func refresh() async { await refreshData(showLoading: false) }

    private func refreshData(showLoading: Bool = false) async {
        if showLoading { isLoading = true }
        defer { if showLoading { isLoading = false } }

        let config: FitnessConfig
        if let profile = try? userProfileRepository.fetchCompleted() {
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
            recentWorkoutCount: gamificationEngine.workoutsCompleted,
            recoveryConfidence: healthKitManager.recoveryConfidence
        )

        coachSummary = recommendationText
        recoveryLabel = generateRecoveryLabel(score: recoveryValue)
        activityLabel = generateActivityLabel(score: activityValue)
        coachSummaryAccessibilityLabel = "Recuperación \(recoveryValue) de 100. \(recoveryLabel). \(recoveryConfidenceLabel)."
        coachEmoji = recoveryValue < 40 ? "🔴" : recoveryValue < 70 ? "🟡" : "🟢"
        dashboardHeroLine = "Recuperación \(recoveryValue)/100 · \(recoveryConfidenceLabel)"
        generateActionCard(recoveryScore: recoveryValue, muscleLabel: todayMuscleLabel)

        recoveryInsights = recoveryBreakdown.map { MetricInsightGenerator.generateInsights(from: $0, config: config) } ?? []
        activityInsights = activityBreakdown.map { MetricInsightGenerator.generateInsights(from: $0, config: config) } ?? []

        totalPoints = gamificationEngine.totalPoints

        if let progress = detoxManager.currentProgress, progress.isActive, !progress.isCompleted {
            detoxActive = true; detoxCurrentDay = progress.currentDay
        } else {
            detoxActive = false; detoxCurrentDay = 0
        }

        if authorizationStatus == .authorized,
           case .available(let r) = recoveryScore,
           case .available(let a) = activityScore {
            try? recoverySnapshotRepository.upsertToday(recovery: r, activity: a)
        }
        loadRecoveryHistory()

        await notificationService.scheduleDailyNotification(
            recoveryScore: recoveryValue,
            statusEmoji: statusIndicator.emoji,
            recommendation: Self.notificationRecommendationLine(recoveryScore: recoveryValue)
        )
    }

    private func loadRecoveryHistory() {
        do {
            let rows = try recoverySnapshotRepository.fetchRecent(limit: 7)
            let chronological = Array(rows.reversed())
            let df = DateFormatter()
            df.locale = Locale(identifier: "es_ES")
            df.setLocalizedDateFormatFromTemplate("EEE")
            recoveryHistoryDays = chronological.map { snap in
                let label = df.string(from: snap.dayStart).trimmingCharacters(in: .whitespaces)
                return RecoveryHistoryDay(
                    id: snap.dayStart,
                    weekdayShort: label.replacingOccurrences(of: ".", with: ""),
                    recoveryScore: snap.recoveryScore
                )
            }
        } catch {
            recoveryHistoryDays = []
        }
    }

    private static func notificationRecommendationLine(recoveryScore: Int) -> String {
        switch recoveryScore {
        case ..<40:
            return "Prioriza descanso y movilidad suave."
        case 40..<70:
            return "Intensidad moderada encaja bien con tu recuperación de hoy."
        default:
            return "Buena recuperación para entrenar según tu plan."
        }
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
            var line = String(format: "FC en reposo %.0f lpm · %@", actual, note)
            if hk.lastRHRMatchMode == .relaxedWindow {
                line += " · muestra alineada con ventana ampliada (intervalo FC diaria en Salud)"
            }
            rhrVsBaselineLine = line
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

        // Regularidad vs horario (solo si el usuario definió horario en Perfil)
        if config.sleepGoal == nil {
            sleepConsistencyLine = ""
        } else {
            let score = hk.sleepConsistencyScore
            let label: String
            switch score {
            case 70...100: label = "alta"
            case 40..<70: label = "media"
            default: label = "baja"
            }
            if case .available = hk.sleepHours {
                sleepConsistencyLine = String(format: "Regularidad vs tu horario: %d/100 (%@)", score, label)
            } else {
                sleepConsistencyLine = String(format: "Regularidad vs tu horario: %d/100 (%@) — sin sueño registrado en la ventana", score, label)
            }
        }

        // Tendencia sueño vs media de noches completadas (excluye la noche que termina hoy)
        if case .available(let lastNightH) = hk.sleepHours {
            if let avg = hk.sleepHours14DayAverage, hk.sleepHistoryNightsCount >= 3 {
                let diff = lastNightH - avg
                if abs(diff) < 0.15 {
                    sleepTrendLine = String(format: "Tendencia: anoche ~igual que tu media reciente (~%.1f h, %d noches).", avg, hk.sleepHistoryNightsCount)
                } else if diff > 0 {
                    sleepTrendLine = String(format: "Tendencia: anoche +%.1f h vs media ~%.1f h (%d noches).", diff, avg, hk.sleepHistoryNightsCount)
                } else {
                    sleepTrendLine = String(format: "Tendencia: anoche %.1f h vs media ~%.1f h (%d noches).", lastNightH, avg, hk.sleepHistoryNightsCount)
                }
            } else if hk.sleepHistoryNightsCount < 3 {
                sleepTrendLine = "Tendencia: necesitamos al menos 3 noches con sueño registrado para calcular la media."
            } else {
                sleepTrendLine = ""
            }
        } else {
            sleepTrendLine = ""
        }

        quickMeaningAccessibilityLabel = "Interpretación rápida. \(recoveryConfidenceLabel)."
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
