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
    /// Días consecutivos con entreno (gamificación) — refuerzo positivo en Home.
    private(set) var trainingStreakDays: Int = 0
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
    /// Texto opcional bajo la card principal de recuperación (p. ej. “recopilando…”).
    private(set) var heroRecoveryMessage: String? = nil
    /// Si true, la card principal está mostrando el score de AYER.
    private(set) var isShowingYesterdayRecovery: Bool = false
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
    /// Nombre para saludo en Inicio (solo lectura desde la vista).
    private(set) var userName: String

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
        self.userName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func onAppear() async { await refreshData(showLoading: true) }
    func refresh() async { await refreshData(showLoading: false) }

    private func refreshData(showLoading: Bool = false) async {
        if showLoading { isLoading = true }
        defer { if showLoading { isLoading = false } }

        gamificationEngine.invalidateStaleStreakIfNeeded()

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
        let lang = AppLanguage.current
        recoveryConfidenceLabel = healthKitManager.recoveryConfidence.localizedLabel(lang)
        populateRecoveryContextLines(config: config)

        applyOvernightRecoveryPresentationIfNeeded(language: lang)

        let recoveryValue = recoveryScore.value ?? 50
        let activityValue = activityScore.value ?? 0
        statusIndicator = StatusIndicator.from(score: recoveryValue)

        todayMuscleLabel = todayMusclesFromPlan()

        recommendationText = AICoach.generateMessage(
            userName: userName,
            recoveryScore: recoveryValue,
            activityScore: activityValue,
            recoveryBreakdown: recoveryBreakdown,
            streakDays: gamificationEngine.displayedStreak(),
            recentWorkoutCount: gamificationEngine.workoutsCompleted,
            recoveryConfidence: healthKitManager.recoveryConfidence,
            language: lang
        )

        coachSummary = recommendationText
        recoveryLabel = generateRecoveryLabel(score: recoveryValue, language: lang)
        activityLabel = generateActivityLabel(score: activityValue, language: lang)
        coachSummaryAccessibilityLabel = lang == .spanish
            ? "Recuperación \(recoveryValue) de 100. \(recoveryLabel). \(recoveryConfidenceLabel)."
            : "Recovery \(recoveryValue) of 100. \(recoveryLabel). \(recoveryConfidenceLabel)."
        coachEmoji = recoveryValue < 40 ? "🔴" : recoveryValue < 70 ? "🟡" : "🟢"
        dashboardHeroLine = lang == .spanish
            ? "Recuperación \(recoveryValue)/100 · \(recoveryConfidenceLabel)"
            : "Recovery \(recoveryValue)/100 · \(recoveryConfidenceLabel)"
        generateActionCard(recoveryScore: recoveryValue, muscleLabel: todayMuscleLabel, language: lang)

        recoveryInsights = recoveryBreakdown.map { MetricInsightGenerator.generateInsights(from: $0, config: config) } ?? []
        activityInsights = activityBreakdown.map { MetricInsightGenerator.generateInsights(from: $0, config: config) } ?? []

        totalPoints = gamificationEngine.totalPoints
        trainingStreakDays = gamificationEngine.displayedStreak()

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
            recommendation: Self.notificationRecommendationLine(recoveryScore: recoveryValue, language: AppLanguage.current)
        )
    }

    private func applyOvernightRecoveryPresentationIfNeeded(language: AppLanguage) {
        heroRecoveryMessage = nil
        isShowingYesterdayRecovery = false

        let now = Date()
        let cal = Calendar.current
        let noonToday = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now

        // “Datos listos para hoy” (regla producto): sueño sincronizado + confianza al menos media.
        let hasSleepSession = (healthKitManager.sleepSessionEnd != nil)
        let confidenceReady: Bool = {
            switch healthKitManager.recoveryConfidence {
            case .high, .medium: return true
            case .low, .insufficient: return false
            }
        }()
        let todayReady = hasSleepSession && confidenceReady && recoveryScore.isAvailable
        guard !todayReady else { return }

        // Antes del mediodía: mostrar AYER si existe snapshot, y un mensaje “recopilando”.
        if now < noonToday {
            heroRecoveryMessage = AppLanguage.current.homeRecoveryCollectingOvernight
            if let y = fetchYesterdayRecoverySnapshot(now: now) {
                recoveryScore = .available(y.recoveryScore)
                // No mostrar breakdown “de hoy” si estamos enseñando ayer.
                recoveryBreakdown = nil
                isShowingYesterdayRecovery = true
            } else {
                // Si no hay ayer (primera vez), ocultar score.
                recoveryScore = .unavailable
            }
            return
        }

        // Después de mediodía sin datos: no inventar.
        heroRecoveryMessage = AppLanguage.current.homeRecoveryNotCollectedByNoon
        recoveryScore = .unavailable
        recoveryBreakdown = nil
    }

    private func fetchYesterdayRecoverySnapshot(now: Date) -> RecoverySnapshot? {
        do {
            let cal = Calendar.current
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: now) else { return nil }
            let yesterdayStart = cal.startOfDay(for: yesterday)
            let recent = try recoverySnapshotRepository.fetchRecent(limit: 7, now: now)
            return recent.first(where: { $0.dayStart == yesterdayStart })
        } catch {
            return nil
        }
    }

    private func loadRecoveryHistory() {
        do {
            let rows = try recoverySnapshotRepository.fetchRecent(limit: 7)
            let chronological = Array(rows.reversed())
            let df = DateFormatter()
            df.locale = Locale(identifier: AppLanguage.current == .spanish ? "es_ES" : "en_US")
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

    private static func notificationRecommendationLine(recoveryScore: Int, language: AppLanguage) -> String {
        switch language {
        case .spanish:
            switch recoveryScore {
            case ..<40: return "Prioriza descanso y movilidad suave."
            case 40..<70: return "Intensidad moderada encaja bien con tu recuperación de hoy."
            default: return "Buena recuperación para entrenar según tu plan."
            }
        case .english:
            switch recoveryScore {
            case ..<40: return "Prioritize rest and light mobility."
            case 40..<70: return "Moderate intensity fits today’s recovery."
            default: return "Good recovery—train as planned."
            }
        }
    }

    private func todayMusclesFromPlan() -> String {
        let lang = AppLanguage.current
        let fallback = lang == .spanish ? "Entrenamiento" : "Training"
        guard let plan = try? trainingPlanRepository.fetchActivePlan() else { return fallback }
        let weekIndex = plan.currentWeek - 1
        let rest = lang == .spanish ? "Descanso" : "Rest"
        guard weekIndex >= 0, weekIndex < plan.weeks.count else { return rest }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let todayDow = weekday == 1 ? 7 : weekday - 1
        guard let day = plan.weeks[weekIndex].days.first(where: { $0.dayOfWeek == todayDow }) else { return rest }
        if day.isRestDay { return rest }
        let muscles = day.muscleGroups.map { $0.displayName(lang) }.joined(separator: lang == .spanish ? " y " : " & ")
        return muscles.isEmpty ? fallback : muscles
    }

    private func generateRecoveryLabel(score: Int, language: AppLanguage) -> String {
        switch language {
        case .spanish:
            switch score {
            case 0...39: return "Necesitas descanso"
            case 40...69: return "Recuperación moderada"
            case 70...84: return "Buena recuperación"
            default: return "Recuperación óptima"
            }
        case .english:
            switch score {
            case 0...39: return "You need rest"
            case 40...69: return "Moderate recovery"
            case 70...84: return "Good recovery"
            default: return "Optimal recovery"
            }
        }
    }

    private func generateActivityLabel(score: Int, language: AppLanguage) -> String {
        switch language {
        case .spanish:
            switch score {
            case 0...39: return "Día tranquilo"
            case 40...69: return "En progreso"
            case 70...84: return "Muy activo"
            default: return "Excelente actividad"
            }
        case .english:
            switch score {
            case 0...39: return "Quiet day"
            case 40...69: return "In progress"
            case 70...84: return "Very active"
            default: return "Excellent activity"
            }
        }
    }

    private func populateRecoveryContextLines(config: FitnessConfig) {
        switch AppLanguage.current {
        case .spanish: populateRecoveryContextLinesES(config: config)
        case .english: populateRecoveryContextLinesEN(config: config)
        }
    }

    private func populateRecoveryContextLinesES(config: FitnessConfig) {
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

    private func populateRecoveryContextLinesEN(config: FitnessConfig) {
        let hk = healthKitManager
        var sleepDiff: Double?
        var hrvPct: Double?
        var rhrDelta: Double?

        switch hk.sleepHours {
        case .available(let hours):
            lastNightSleepSummary = String(format: "You slept ~%.1f h", hours)
        default:
            lastNightSleepSummary = "No sleep data for last night"
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
                sleepGoalComparisonLine = String(format: "Goal %.1f h · last night %.1f h (at or above goal)", goal, hours)
            } else {
                sleepGoalComparisonLine = String(format: "Goal %.1f h · last night %.1f h (%.1f h below goal)", goal, hours, -diff)
            }
        } else {
            sleepGoalComparisonLine = ""
        }

        if let actual = hk.hrv.value, let baseline = hk.hrvBaselineUsed, baseline > 0 {
            let pct = (actual - baseline) / baseline * 100.0
            hrvPct = pct
            let dir: String
            if abs(pct) < 3 {
                dir = "similar to your 14‑day average"
            } else if pct > 0 {
                dir = String(format: "%.0f%% above your 14‑day average", pct)
            } else {
                dir = String(format: "%.0f%% below your 14‑day average", abs(pct))
            }
            hrvVsBaselineLine = String(format: "HRV %.0f ms · %@ (avg ~%.0f ms)", actual, dir, baseline)
        } else {
            hrvVsBaselineLine = ""
        }

        if let actual = hk.restingHR.value, let baseline = hk.restingHRBaselineUsed, baseline > 0 {
            let delta = baseline - actual
            rhrDelta = delta
            let note: String
            if abs(delta) < 1 {
                note = "similar to your 14‑day average"
            } else if delta > 0 {
                note = String(format: "%.0f bpm below your average (%.0f)", delta, baseline)
            } else {
                note = String(format: "%.0f bpm above your average (%.0f)", -delta, baseline)
            }
            var line = String(format: "Resting HR %.0f bpm · %@", actual, note)
            if hk.lastRHRMatchMode == .relaxedWindow {
                line += " · sample aligned with wider window (daily HR range in Health)"
            }
            rhrVsBaselineLine = line
        } else {
            rhrVsBaselineLine = ""
        }

        let sleepPhrase: String
        if let diff = sleepDiff {
            sleepPhrase = diff >= 0 ? "sleep at/above goal" : "sleep below goal"
        } else {
            sleepPhrase = "unclear sleep data"
        }

        let hrvPhrase: String
        if let pct = hrvPct {
            if abs(pct) < 3 { hrvPhrase = "HRV near your average" }
            else if pct > 0 { hrvPhrase = "HRV above (good recovery)" }
            else { hrvPhrase = "HRV below (more load/fatigue)" }
        } else {
            hrvPhrase = "no HRV data"
        }

        let rhrPhrase: String
        if let delta = rhrDelta {
            if abs(delta) < 1 { rhrPhrase = "resting HR near your average" }
            else if delta > 0 { rhrPhrase = "resting HR better than your average" }
            else { rhrPhrase = "resting HR higher than your average" }
        } else {
            rhrPhrase = "no resting HR data"
        }

        switch hk.recoveryConfidence {
        case .high:
            quickMeaningLine = "Quick read: favorable signals. (Signals: \(sleepPhrase), \(hrvPhrase), \(rhrPhrase))"
        case .medium:
            quickMeaningLine = "Quick read: mixed signals. (Signals: \(sleepPhrase), \(hrvPhrase), \(rhrPhrase))"
        case .low:
            quickMeaningLine = "Quick read: unclear signals. (Signals: \(sleepPhrase), \(hrvPhrase), \(rhrPhrase))"
        case .insufficient:
            quickMeaningLine = "Quick read: missing key data for a reliable read."
        }

        if config.sleepGoal == nil {
            sleepConsistencyLine = ""
        } else {
            let score = hk.sleepConsistencyScore
            let label: String
            switch score {
            case 70...100: label = "high"
            case 40..<70: label = "medium"
            default: label = "low"
            }
            if case .available = hk.sleepHours {
                sleepConsistencyLine = String(format: "Regularity vs your schedule: %d/100 (%@)", score, label)
            } else {
                sleepConsistencyLine = String(format: "Regularity vs your schedule: %d/100 (%@) — no sleep in window", score, label)
            }
        }

        if case .available(let lastNightH) = hk.sleepHours {
            if let avg = hk.sleepHours14DayAverage, hk.sleepHistoryNightsCount >= 3 {
                let diff = lastNightH - avg
                if abs(diff) < 0.15 {
                    sleepTrendLine = String(format: "Trend: last night ~same as recent average (~%.1f h, %d nights).", avg, hk.sleepHistoryNightsCount)
                } else if diff > 0 {
                    sleepTrendLine = String(format: "Trend: last night +%.1f h vs ~%.1f h avg (%d nights).", diff, avg, hk.sleepHistoryNightsCount)
                } else {
                    sleepTrendLine = String(format: "Trend: last night %.1f h vs ~%.1f h avg (%d nights).", lastNightH, avg, hk.sleepHistoryNightsCount)
                }
            } else if hk.sleepHistoryNightsCount < 3 {
                sleepTrendLine = "Trend: we need at least 3 nights with logged sleep to compute the average."
            } else {
                sleepTrendLine = ""
            }
        } else {
            sleepTrendLine = ""
        }

        quickMeaningAccessibilityLabel = "Quick read. \(recoveryConfidenceLabel)."
    }

    private static func formatLocalTimeOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = .current
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func generateActionCard(recoveryScore: Int, muscleLabel: String, language: AppLanguage) {
        switch language {
        case .spanish:
            if recoveryScore < 40 {
                actionCardTitle = "Hoy: Descanso activo"; actionCardIntensity = .low
            } else if recoveryScore < 70 {
                actionCardTitle = "Hoy: \(muscleLabel) moderado"; actionCardIntensity = .medium
            } else {
                actionCardTitle = "Hoy: \(muscleLabel)"; actionCardIntensity = .high
            }
        case .english:
            if recoveryScore < 40 {
                actionCardTitle = "Today: Active recovery"; actionCardIntensity = .low
            } else if recoveryScore < 70 {
                actionCardTitle = "Today: \(muscleLabel) moderate"; actionCardIntensity = .medium
            } else {
                actionCardTitle = "Today: \(muscleLabel)"; actionCardIntensity = .high
            }
        }
    }
}

extension HomeViewModel.ActionIntensity {
    func localizedLabel(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.low, .spanish): return "Baja"
        case (.low, .english): return "Low"
        case (.medium, .spanish): return "Media"
        case (.medium, .english): return "Medium"
        case (.high, .spanish): return "Alta"
        case (.high, .english): return "High"
        }
    }
}
