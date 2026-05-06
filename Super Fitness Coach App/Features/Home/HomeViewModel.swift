//
//  HomeViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

@Observable
final class HomeViewModel {
    private(set) var recoveryScore: HealthDataStatus<Int> = .loading
    private(set) var activityScore: HealthDataStatus<Int> = .loading
    private(set) var sleepScore: HealthDataStatus<Int> = .loading
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
    // Raw health values for detail screens
    private(set) var sleepHours: HealthDataStatus<Double> = .loading
    private(set) var deepSleepHours: HealthDataStatus<Double> = .loading
    private(set) var remSleepHours: HealthDataStatus<Double> = .loading
    private(set) var sleepConsistencyScore: Int = 0
    /// Continuidad intranoche (0–100); `nil` si no hay dato (p. ej. vista de ayer sin histórico).
    private(set) var sleepContinuitySubscore: Int?
    private(set) var sleepSessionStart: Date?
    private(set) var sleepSessionEnd: Date?
    /// Episodios de vigilia (última sesión); 0 si no hay dato.
    private(set) var sleepAwakeEpisodeCount: Int = 0
    private(set) var sleepAwakeSecondsDuringSession: TimeInterval?
    private(set) var sleepSessionWallDuration: TimeInterval?
    /// Desglose crudo de `SleepQualityScoring` del último refresh (solo útil con build DEBUG en detalle).
    private(set) var sleepQualityDebugSnapshot: SleepQualityScoring.DebugSnapshot?
    /// Meta de horas de sueño del perfil (refresco actual); para detalle.
    private(set) var profileSleepGoalHours: Double = FitnessConfig.default.sleepGoalHours
    private(set) var restingHR: HealthDataStatus<Double> = .loading
    private(set) var hrv: HealthDataStatus<Double> = .loading
    private(set) var stepCount: HealthDataStatus<Double> = .loading
    private(set) var activeEnergy: HealthDataStatus<Double> = .loading
    /// Metas de actividad desde `FitnessConfig` (perfil).
    private(set) var stepsGoal: Double = FitnessConfig.default.stepsGoal
    private(set) var calorieGoal: Double = FitnessConfig.default.calorieGoal
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
    /// Si true, el ring/pantalla de Sueño está mostrando datos de AYER.
    private(set) var isShowingYesterdaySleep: Bool = false
    /// Texto opcional bajo el ring/pantalla de sueño (p. ej. “recopilando…”).
    private(set) var heroSleepMessage: String? = nil
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
    /// Últimos 7 días calendario (hoy a la izquierda), con snapshot opcional por día.
    private(set) var recoveryHistoryDays: [RecoveryHistoryDay] = []
    /// Ventana móvil de 7 días (hoy incluido) para gráfica 0...100.
    /// Si un día no tiene snapshot, se renderiza solo el track (sin fill).
    private(set) var rollingRecoveryDays: [RollingRecoveryDay] = []
    private(set) var recoveryInsights: [MetricInsight] = []
    private(set) var activityInsights: [MetricInsight] = []

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "HomeViewModel")
    private let healthKitManager: HealthKitManager
    private let trainingPlanRepository: TrainingPlanRepository
    private let gamificationEngine: GamificationEngine
    private let detoxManager: DetoxManager
    private let userProfileRepository: UserProfileRepository
    private let recoverySnapshotRepository: RecoverySnapshotRepository
    /// Nombre para saludo en Inicio (solo lectura desde la vista).
    private(set) var userName: String

    struct RecoveryHistoryDay: Identifiable, Equatable {
        let id: Date
        let weekdayShort: String
        let recoveryScore: Int
        let hasSnapshot: Bool
        let isToday: Bool
    }

    struct RollingRecoveryDay: Identifiable, Equatable {
        let id: Date // dayStart
        /// 1...7 (Lun...Dom / Mon...Sun)
        let dayOfWeek: Int
        /// nil = no snapshot
        let percent: Int?
        let isToday: Bool
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
        userProfileRepository: UserProfileRepository,
        recoverySnapshotRepository: RecoverySnapshotRepository,
        userName: String
    ) {
        self.healthKitManager = healthKitManager
        self.trainingPlanRepository = trainingPlanRepository
        self.gamificationEngine = gamificationEngine
        self.detoxManager = detoxManager
        self.userProfileRepository = userProfileRepository
        self.recoverySnapshotRepository = recoverySnapshotRepository
        self.userName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func onAppear() async { await refreshData(showLoading: true) }
    func refresh() async { await refreshData(showLoading: false) }

    /// Solo racha: barato; `displayedStreak()` aplica `invalidate` antes de leer. Úsalo al vuelve a Inicio o al reactivar la app.
    func syncStreakFromEngine() {
        trainingStreakDays = gamificationEngine.displayedStreak()
    }

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
        stepsGoal = config.stepsGoal
        calorieGoal = config.calorieGoal
        profileSleepGoalHours = config.effectiveSleepGoalHours

        await healthKitManager.refreshHealthData(config: config)
        let rawRecoveryScore = healthKitManager.recoveryScore
        let rawActivityScore = healthKitManager.activityScore
        let rawSleepScore = healthKitManager.sleepScore

        recoveryScore = rawRecoveryScore
        activityScore = rawActivityScore
        sleepScore = rawSleepScore
        recoveryBreakdown = healthKitManager.recoveryBreakdown
        activityBreakdown = healthKitManager.activityBreakdown
        authorizationStatus = healthKitManager.authorizationStatus
        sleepHours = healthKitManager.sleepHours
        deepSleepHours = healthKitManager.deepSleepHours
        remSleepHours = healthKitManager.remSleepHours
        sleepConsistencyScore = healthKitManager.sleepConsistencyScore
        sleepContinuitySubscore = healthKitManager.sleepContinuitySubscore
        sleepSessionStart = healthKitManager.sleepSessionStart
        sleepSessionEnd = healthKitManager.sleepSessionEnd
        sleepAwakeEpisodeCount = healthKitManager.sleepAwakeEpisodeCount
        sleepAwakeSecondsDuringSession = healthKitManager.sleepAwakeSecondsDuringSession
        sleepSessionWallDuration = healthKitManager.sleepSessionWallDuration
        sleepQualityDebugSnapshot = healthKitManager.lastSleepQualityDebugSnapshot
        restingHR = healthKitManager.restingHR
        hrv = healthKitManager.hrv
        stepCount = healthKitManager.stepCount
        activeEnergy = healthKitManager.activeEnergy
        let lang = AppLanguage.current
        recoveryConfidenceLabel = healthKitManager.recoveryConfidence.localizedLabel(lang)

        applyOvernightRecoveryPresentationIfNeeded(language: lang)
        applyOvernightSleepPresentationIfNeeded(language: lang)
        if isShowingYesterdaySleep {
            sleepQualityDebugSnapshot = nil
        }
        // Después de posibles sustituciones "anoche" (snapshot) para aros/mensajes: textos de contexto
        // alinean con el ViewModel, no con HK en bruto. Antes, la ventana 1:53–6:49 de HK y el VM
        // a 4:44 del snapshot quedaban desincronizados.
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

        if shouldPersistTodaySnapshot(),
           authorizationStatus == .authorized,
           case .available(let r) = rawRecoveryScore,
           case .available(let a) = rawActivityScore {
            try? recoverySnapshotRepository.upsertToday(
                recovery: r,
                activity: a,
                sleepScore: rawSleepScore.value,
                sleepHours: healthKitManager.sleepHours.value,
                deepSleepHours: healthKitManager.deepSleepHours.value,
                remSleepHours: healthKitManager.remSleepHours.value,
                sleepConsistencyScore: healthKitManager.sleepConsistencyScore,
                sleepSessionStart: healthKitManager.sleepSessionStart,
                sleepSessionEnd: healthKitManager.sleepSessionEnd,
                restingHR: healthKitManager.restingHR.value,
                hrv: healthKitManager.hrv.value,
                recoveryConfidenceRaw: healthKitManager.recoveryConfidence.rawValue
            )
        }
        loadRecoveryHistory()
        loadRollingRecoveryWindow(now: Date())
        // Notificación de “datos listos” la programa `HealthKitManager` al terminar el refresh
        // (incl. observer de sueño en segundo plano), no a hora fija.
    }

    private func loadRollingRecoveryWindow(now: Date) {
        do {
            let cal = Calendar.current
            let todayStart = cal.startOfDay(for: now)
            guard let start = cal.date(byAdding: .day, value: -6, to: todayStart) else {
                rollingRecoveryDays = []
                return
            }

            let snaps = try recoverySnapshotRepository.fetchRecent(limit: 60, now: now)
            var lookup: [Date: RecoverySnapshot] = [:]
            for s in snaps {
                lookup[cal.startOfDay(for: s.dayStart)] = s
            }

            var out: [RollingRecoveryDay] = []
            for offset in 0..<7 {
                guard let d = cal.date(byAdding: .day, value: offset, to: start) else { continue }
                let dayStart = cal.startOfDay(for: d)
                let weekday = cal.component(.weekday, from: dayStart) // 1=Sun...7=Sat
                let dayOfWeek = weekday == 1 ? 7 : weekday - 1 // 1=Mon...7=Sun
                let score = lookup[dayStart]?.recoveryScore
                out.append(
                    RollingRecoveryDay(
                        id: dayStart,
                        dayOfWeek: dayOfWeek,
                        percent: score.map { min(100, max(0, $0)) },
                        isToday: dayStart == todayStart
                    )
                )
            }
            rollingRecoveryDays = out
        } catch {
            rollingRecoveryDays = []
        }
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
                // Mostrar también métricas de AYER hasta que hoy esté listo (detalle Recovery).
                hrv = y.hrv.map { .available($0) } ?? .unavailable
                restingHR = y.restingHR.map { .available($0) } ?? .unavailable
                sleepScore = y.sleepScore.map { .available($0) } ?? sleepScore
                if let raw = y.recoveryConfidenceRaw,
                   let level = HealthKitManager.DataConfidenceLevel(rawValue: raw) {
                    recoveryConfidenceLabel = level.localizedLabel(language)
                }
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

    private func applyOvernightSleepPresentationIfNeeded(language: AppLanguage) {
        heroSleepMessage = nil
        isShowingYesterdaySleep = false

        let now = Date()
        let cal = Calendar.current
        let noonToday = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now

        // “Datos listos para sueño hoy”: sesión sincronizada + score disponible.
        let hasSleepSession = (healthKitManager.sleepSessionEnd != nil)
        let sleepReady = hasSleepSession && sleepScore.isAvailable
        guard !sleepReady else { return }

        if now < noonToday {
            let todayRow = fetchTodayRecoverySnapshot(now: now)
            heroSleepMessage = language.homeRecoveryCollectingOvernight
            if let y = fetchYesterdayRecoverySnapshot(now: now) {
                sleepScore = y.sleepScore.map { .available($0) } ?? .unavailable
                sleepHours = y.sleepHours.map { .available($0) } ?? .unavailable
                deepSleepHours = y.deepSleepHours.map { .available($0) } ?? .unavailable
                remSleepHours = y.remSleepHours.map { .available($0) } ?? .unavailable
                sleepConsistencyScore = y.sleepConsistencyScore ?? 0
                sleepContinuitySubscore = nil
                // Ventana 1:53–6:49 “de anoche” ≠ fila "ayer" en SwiftData: `fetchYesterday` es el calendario
                // (p. ej. 2/4) y su `sleepSession*` es de la noche que terminó **esa** mañana, no de la
                // noche 2/4→3/4. Sin HK, usar solo el snapshot de **hoy** (misma noche), no `y`.
                if !hasSleepSession,
                   let t = todayRow,
                   let tStart = t.sleepSessionStart,
                   let tEnd = t.sleepSessionEnd {
                    sleepSessionStart = tStart
                    sleepSessionEnd = tEnd
                }
                isShowingYesterdaySleep = !hasSleepSession
            } else {
                sleepScore = .unavailable
                sleepContinuitySubscore = nil
            }
            // #region agent log
            let src: String
            if hasSleepSession { src = "healthKit" }
            else if todayRow?.sleepSessionEnd != nil { src = "todaySnapshot" }
            else { src = "noWindow" }
            logger.info("overnight-sleep: hasHKSession=\(hasSleepSession) sessionSource=\(src) isShowingPlaceholder=\(!hasSleepSession)")
            agentDebugNDJSON(
                message: "overnight-sleep",
                data: [
                    "hypothesisId": "H-sleep-window",
                    "hasSleepSession": hasSleepSession,
                    "sessionSource": src,
                    "isShowingYesterdaySleep": !hasSleepSession
                ] as [String: Any]
            )
            // #endregion
            return
        }

        heroSleepMessage = language.homeRecoveryNotCollectedByNoon
        sleepScore = .unavailable
        sleepContinuitySubscore = nil
    }

    private func shouldPersistTodaySnapshot() -> Bool {
        let hasSleepSession = (healthKitManager.sleepSessionEnd != nil)
        let confidenceReady: Bool = {
            switch healthKitManager.recoveryConfidence {
            case .high, .medium: return true
            case .low, .insufficient: return false
            }
        }()
        return hasSleepSession
            && confidenceReady
            && healthKitManager.recoveryScore.isAvailable
            && healthKitManager.activityScore.isAvailable
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

    /// Fila con `dayStart` = inicio de **hoy** (persistida por `upsertToday`). La ventana de sueño
    /// "anoche → esta mañana" se asocia a **este** día, no a la fila "ayer" usada para scores placeholder.
    private func fetchTodayRecoverySnapshot(now: Date) -> RecoverySnapshot? {
        do {
            let cal = Calendar.current
            let todayStart = cal.startOfDay(for: now)
            let recent = try recoverySnapshotRepository.fetchRecent(limit: 7, now: now)
            return recent.first(where: { $0.dayStart == todayStart })
        } catch {
            return nil
        }
    }

    // #region agent log
    private func agentDebugNDJSON(message: String, data: [String: Any]) {
        var payload: [String: Any] = [
            "sessionId": "63c6d3",
            "location": "HomeViewModel.applyOvernightSleepPresentationIfNeeded",
            "message": message,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        for (k, v) in data { payload[k] = v }
        guard JSONSerialization.isValidJSONObject(payload),
              let json = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: json, encoding: .utf8) else { return }
        line += "\n"
        let path = "/Users/jonathanrivera/Desktop/CODE/Jona projects/Super Fitness Coach App/.cursor/debug-63c6d3.log"
        let url = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        guard let lineData = line.data(using: .utf8) else { return }
        do {
            let h = try FileHandle(forWritingTo: url)
            defer { try? h.close() }
            try h.seekToEnd()
            try h.write(contentsOf: lineData)
        } catch {
            // Host path no escribible en dispositivo; `logger` arriba sigue siendo la fuente.
        }
    }
    // #endregion

    private func loadRecoveryHistory() {
        do {
            let now = Date()
            let cal = Calendar.current
            let lang = AppLanguage.current
            let todayStart = cal.startOfDay(for: now)
            let rows = try recoverySnapshotRepository.fetchRecent(limit: 7, now: now)
            let df = DateFormatter()
            df.locale = Locale(identifier: lang == .spanish ? "es_ES" : "en_US")
            df.setLocalizedDateFormatFromTemplate("EEE")
            let chronological = Array(rows.reversed())
            recoveryHistoryDays = chronological.map { snap in
                let dayStart = cal.startOfDay(for: snap.dayStart)
                let label = df.string(from: dayStart).trimmingCharacters(in: .whitespaces)
                return RecoveryHistoryDay(
                    id: dayStart,
                    weekdayShort: label.replacingOccurrences(of: ".", with: ""),
                    recoveryScore: snap.recoveryScore,
                    hasSnapshot: true,
                    isToday: dayStart == todayStart
                )
            }
        } catch {
            recoveryHistoryDays = []
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

        switch sleepHours {
        case .available(let hours):
            lastNightSleepSummary = String(format: "Dormiste ~%.1f h", hours)
        default:
            lastNightSleepSummary = "Sin datos de sueño para anoche"
        }

        if let start = sleepSessionStart, let end = sleepSessionEnd {
            lastNightSleepWindow = "\(Self.formatLocalTimeOnly(start)) → \(Self.formatLocalTimeOnly(end))"
        } else {
            lastNightSleepWindow = ""
        }

        let goalHours = config.effectiveSleepGoalHours
        if goalHours > 0, case .available(let hours) = sleepHours {
            let diff = hours - goalHours
            sleepDiff = diff
            if diff >= -0.05 {
                sleepGoalComparisonLine = String(format: "Meta %.1f h · anoche %.1f h (en o por encima de la meta)", goalHours, hours)
            } else {
                sleepGoalComparisonLine = String(format: "Meta %.1f h · anoche %.1f h (%.1f h menos que la meta)", goalHours, hours, -diff)
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
            let score = sleepConsistencyScore
            let label: String
            switch score {
            case 70...100: label = "alta"
            case 40..<70: label = "media"
            default: label = "baja"
            }
            if case .available = sleepHours {
                sleepConsistencyLine = String(format: "Regularidad vs tu horario: %d/100 (%@)", score, label)
            } else {
                sleepConsistencyLine = String(format: "Regularidad vs tu horario: %d/100 (%@) — sin sueño registrado en la ventana", score, label)
            }
        }

        // Tendencia sueño vs media de noches completadas (excluye la noche que termina hoy)
        if case .available(let lastNightH) = sleepHours {
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

        switch sleepHours {
        case .available(let hours):
            lastNightSleepSummary = String(format: "You slept ~%.1f h", hours)
        default:
            lastNightSleepSummary = "No sleep data for last night"
        }

        if let start = sleepSessionStart, let end = sleepSessionEnd {
            lastNightSleepWindow = "\(Self.formatLocalTimeOnly(start)) → \(Self.formatLocalTimeOnly(end))"
        } else {
            lastNightSleepWindow = ""
        }

        let goalHoursEN = config.effectiveSleepGoalHours
        if goalHoursEN > 0, case .available(let hours) = sleepHours {
            let diff = hours - goalHoursEN
            sleepDiff = diff
            if diff >= -0.05 {
                sleepGoalComparisonLine = String(format: "Goal %.1f h · last night %.1f h (at or above goal)", goalHoursEN, hours)
            } else {
                sleepGoalComparisonLine = String(format: "Goal %.1f h · last night %.1f h (%.1f h below goal)", goalHoursEN, hours, -diff)
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
            let score = sleepConsistencyScore
            let label: String
            switch score {
            case 70...100: label = "high"
            case 40..<70: label = "medium"
            default: label = "low"
            }
            if case .available = sleepHours {
                sleepConsistencyLine = String(format: "Regularity vs your schedule: %d/100 (%@)", score, label)
            } else {
                sleepConsistencyLine = String(format: "Regularity vs your schedule: %d/100 (%@) — no sleep in window", score, label)
            }
        }

        if case .available(let lastNightH) = sleepHours {
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
