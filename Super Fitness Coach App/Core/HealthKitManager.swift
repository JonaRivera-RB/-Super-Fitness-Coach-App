//  HealthKitManager.swift
//  Super Fitness Coach App
//

import Foundation
import HealthKit
import os

/// How a HealthKit quantity sample was matched to the asleep window (for confidence / UI).
enum SleepWindowQuantityMatchMode: String, Codable, Sendable {
    case strict
    case partialOverlap
    case relaxedWindow
}

struct SleepWindowQuantityMatch: Sendable {
    let value: Double
    let startDate: Date
    let endDate: Date
    let mode: SleepWindowQuantityMatchMode
}

@Observable
final class HealthKitManager {

    // MARK: - Published Properties

    enum DataConfidenceLevel: String, Codable {
        case insufficient
        case high
        case medium
        case low

        var labelEs: String {
            switch self {
            case .insufficient: return "Datos insuficientes"
            case .high: return "Altamente confiable"
            case .medium: return "Confiabilidad media"
            case .low: return "Poco confiable"
            }
        }
    }

    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    private(set) var recoveryScore: HealthDataStatus<Int> = .loading
    private(set) var activityScore: HealthDataStatus<Int> = .loading
    private(set) var sleepScore: HealthDataStatus<Int> = .loading
    private(set) var recoveryBreakdown: ScoreBreakdown?
    private(set) var activityBreakdown: ScoreBreakdown?
    private(set) var recoveryConfidence: DataConfidenceLevel = .low

    // Individual metrics
    private(set) var sleepHours: HealthDataStatus<Double> = .loading
    private(set) var deepSleepHours: HealthDataStatus<Double> = .loading
    private(set) var remSleepHours: HealthDataStatus<Double> = .loading
    private(set) var restingHR: HealthDataStatus<Double> = .loading
    private(set) var hrv: HealthDataStatus<Double> = .loading
    private(set) var stepCount: HealthDataStatus<Double> = .loading
    private(set) var activeEnergy: HealthDataStatus<Double> = .loading

    /// Last refresh: main sleep interval from HealthKit (for UI). Not the user's goal window.
    private(set) var sleepSessionStart: Date?
    private(set) var sleepSessionEnd: Date?
    /// Baselines used for scoring this refresh (14-day auto or profile fallback).
    private(set) var restingHRBaselineUsed: Double?
    private(set) var hrvBaselineUsed: Double?
    /// Last refresh: how RHR was aligned to sleep (relaxed = heuristic).
    private(set) var lastRHRMatchMode: SleepWindowQuantityMatchMode?
    /// Alineación del sueño detectado con el horario esperado (0–100). Con `sleepGoal == nil` el filtro devuelve 0.
    private(set) var sleepConsistencyScore: Int = 0
    /// Subscore 0–100 de continuidad (menos vigilia intranoche); `nil` si no hubo sesión de sueño detectada.
    private(set) var sleepContinuitySubscore: Int?
    /// Episodios de vigilia fusionados en la última sesión (útil para UI de detalle).
    private(set) var sleepAwakeEpisodeCount: Int = 0
    /// Segundos de vigilia dentro de la ventana de sesión (HealthKit `awake`).
    private(set) var sleepAwakeSecondsDuringSession: TimeInterval?
    /// Duración reloj inicio–fin de la sesión mostrada (para eficiencia vs TST).
    private(set) var sleepSessionWallDuration: TimeInterval?
    /// Media de horas de sueño principal en hasta 14 noches completadas (excluye la noche que termina hoy).
    private(set) var sleepHours14DayAverage: Double?
    /// Cuántas noches entraron en esa media (puede ser menor a 14 si faltan datos).
    private(set) var sleepHistoryNightsCount: Int = 0
    /// Último desglose de `SleepQualityScoring.compute` (build DEBUG / diagnóstico). `nil` si no hubo TST.
    private(set) var lastSleepQualityDebugSnapshot: SleepQualityScoring.DebugSnapshot?

    // MARK: - Private

    private let healthStore: HKHealthStore?
    private let logger = Logger(subsystem: "com.superfitness.coach", category: "HealthKitManager")

    /// Observers call debounced refresh; use profile config (set via `configureObserverRefresh`).
    private var fitnessConfigForObservers: () -> FitnessConfig = { .default }
    private var debouncedRefreshTask: Task<Void, Never>?
    /// Notificación cuando “hoy” pasa a datos listos (configurar desde `ContentView`).
    private var notificationService: NotificationService?

    // Sleep Monitoring
    private var sleepObserverQuery: HKObserverQuery?
    private var sleepMonitoringTimer: Timer?

    // Health Metric Observers
    private var healthObserverQueries: [HKObserverQuery] = []

    // MARK: - Init

    init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HKHealthStore()
        } else {
            self.healthStore = nil
            authorizationStatus = .unavailable
            logger.warning("HealthKit is not available on this device.")
        }
    }

    // MARK: - Authorization

    func verifyAuthorization() async {
        guard let healthStore else {
            authorizationStatus = .unavailable
            return
        }

        let stepType = HKQuantityType(.stepCount)

        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(sampleType: stepType, predicate: nil, limit: 1, sortDescriptors: nil) {
                    _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                healthStore.execute(query)
            }
            authorizationStatus = .authorized
        } catch {
            let status = healthStore.authorizationStatus(for: HKQuantityType(.stepCount))
            if status == .sharingDenied {
                authorizationStatus = .denied
            } else {
                do {
                    try await requestAuthorization()
                } catch {
                    authorizationStatus = .denied
                }
            }
        }
    }

    func requestAuthorization() async throws {
        guard let healthStore else {
            applyDefaults()
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.bodyMass),
            HKQuantityType(.height)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            authorizationStatus = .authorized
        } catch {
            authorizationStatus = .denied
            applyDefaults()
            throw error
        }
    }

    // MARK: - Data Refresh

    /// Backward-compatible convenience that uses default config.
    func refreshHealthData() async {
        await refreshHealthData(config: .default)
    }

    /// Call from app root with SwiftData: observers will refresh with the user’s real `FitnessConfig` (sleep goal, etc.).
    func configureObserverRefresh(_ provider: @escaping () -> FitnessConfig) {
        fitnessConfigForObservers = provider
    }

    /// Para avisar cuando el refresh detecta datos de recuperación de hoy ya fiables (tras sincronizar sueño).
    func configureNotificationDelivery(_ service: NotificationService) {
        notificationService = service
    }

    /// Coalesce multiple HKObserverQuery callbacks into one refresh after a short delay (~3s).
    func scheduleDebouncedRefreshFromObservers() {
        debouncedRefreshTask?.cancel()
        debouncedRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            let config = self.fitnessConfigForObservers()
            self.logger.info("refreshHealthData: debounced observer refresh (sleepGoal saved=\(config.sleepGoal != nil))")
            await self.refreshHealthData(config: config)
        }
    }

    /// Query all health metrics and calculate Recovery/Activity scores using user's FitnessConfig.
    func refreshHealthData(config: FitnessConfig) async {
        guard let healthStore else {
            applyDefaults()
            return
        }

        if authorizationStatus != .authorized {
            await verifyAuthorization()
        }

        guard authorizationStatus == .authorized else {
            applyDefaults()
            return
        }

        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        logger.info("refreshHealthData: activity range \(startOfToday) to \(now), recovery range \(twentyFourHoursAgo) to \(now)")

        // Query metrics concurrently (except HRV/RHR which depend on sleep window)
        // Sleep: uses smart range that crosses midnight
        // Steps/Calories: today only (matches Apple Health day view)
        let expectedWindow = SleepWindowBuilder.build(
            goal: config.sleepGoal,
            referenceDate: now,
            bufferMinutes: config.bufferMinutes
        )
        logger.info("""
        sleep-window (UTC):
        expectedStart=\(expectedWindow.expectedStart)
        expectedEnd=\(expectedWindow.expectedEnd)
        adjustedStart=\(expectedWindow.adjustedStart)
        adjustedEnd=\(expectedWindow.adjustedEnd)
        isFallback=\(expectedWindow.isFallback)
        sleep-window (local): expected \(Self.formatLocalTime(expectedWindow.expectedStart))–\(Self.formatLocalTime(expectedWindow.expectedEnd)) | adjusted \(Self.formatLocalTime(expectedWindow.adjustedStart))–\(Self.formatLocalTime(expectedWindow.adjustedEnd))
        """)

        async let fetchedSleepDetection = querySleepDetection(
            store: healthStore,
            window: expectedWindow,
            goal: config.sleepGoal
        )
        async let fetchedSleepHistoryAvg = queryAverageMainSleepLast14Nights(store: healthStore, now: now)
        async let fetchedSteps = queryQuantityCumulative(store: healthStore, type: .stepCount, unit: .count(), start: startOfToday, end: now)
        async let fetchedEnergy = queryQuantityCumulative(store: healthStore, type: .activeEnergyBurned, unit: .kilocalorie(), start: startOfToday, end: now)
        // Auto-baselines: average over last 14 days
        async let fetchedBaseline = queryRestingHRBaseline(store: healthStore, end: now)
        async let fetchedHRVBaseline = queryHRVBaseline(store: healthStore, end: now)

        // Await sleep phases first to get the sleep window for HRV/RHR validation
        let sleepDetection = await fetchedSleepDetection
        let (avg14, nights14) = await fetchedSleepHistoryAvg
        self.sleepHours14DayAverage = avg14
        self.sleepHistoryNightsCount = nights14
        if let avg14 {
            logger.info("sleep-history: 14n avg=\(String(format: "%.2f", avg14))h over \(nights14) nights (completed wake days before today)")
        } else {
            logger.info("sleep-history: insufficient nights for rolling average")
        }
        let sessionLocal: String
        if let s = sleepDetection.sessionStart, let e = sleepDetection.sessionEnd {
            sessionLocal = "\(Self.formatLocalTime(s)) → \(Self.formatLocalTime(e)) (HealthKit merged asleep interval, not your goal times)"
        } else {
            sessionLocal = "nil"
        }
        logger.info("""
        sleep-detection:
        detected=\(sleepDetection.sleepDetected)
        rawSamples=\(sleepDetection.rawSampleCount)
        mergedSessions=\(sleepDetection.mergedSessionCount)
        sessionStartUTC=\(sleepDetection.sessionStart?.description ?? "nil")
        sessionEndUTC=\(sleepDetection.sessionEnd?.description ?? "nil")
        sessionLocal=\(sessionLocal)
        sleepConfidence=\(String(format: "%.2f", sleepDetection.sleepConfidence))
        consistency=\(sleepDetection.sleepConsistencyScore)
        """)

        // Conditionally query HRV and RHR based on sleep window availability
        let rhr: Double?
        let hrvMs: Double?

        var rhrMatchMode: SleepWindowQuantityMatchMode?

        if let sessionStart = sleepDetection.sessionStart, let sessionEnd = sleepDetection.sessionEnd {
            // Sleep window available — use queryQuantityInSleepWindow to filter by sleep window
            logger.info("Sleep window validation: sleepStartUTC=\(sessionStart) sleepEndUTC=\(sessionEnd) | local \(Self.formatLocalTime(sessionStart))–\(Self.formatLocalTime(sessionEnd))")
            async let fetchedRHR = queryQuantityInSleepWindow(store: healthStore, type: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: twentyFourHoursAgo, end: now, sleepStart: sessionStart, sleepEnd: sessionEnd)
            async let fetchedHRV = queryQuantityInSleepWindow(store: healthStore, type: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: twentyFourHoursAgo, end: now, sleepStart: sessionStart, sleepEnd: sessionEnd)
            let rhrResult = await fetchedRHR
            let hrvResult = await fetchedHRV
            rhr = rhrResult?.value
            hrvMs = hrvResult?.value
            rhrMatchMode = rhrResult?.mode
            lastRHRMatchMode = rhrResult?.mode
            logger.info("HRV validation: \(hrvMs != nil ? "accepted (within sleep window)" : "rejected (no sample within sleep window)")")
            logger.info("RHR validation: \(rhr != nil ? "accepted (match=\(rhrMatchMode?.rawValue ?? "?"))" : "rejected")")
        } else {
            // No sleep window — fallback to existing behavior (most recent sample)
            logger.info("Sleep window validation: no sleep session detected, using fallback (most recent sample)")
            async let fetchedRHR = queryQuantity(store: healthStore, type: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: twentyFourHoursAgo, end: now)
            async let fetchedHRV = queryQuantity(store: healthStore, type: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: twentyFourHoursAgo, end: now)
            rhr = await fetchedRHR
            hrvMs = await fetchedHRV
            rhrMatchMode = nil
            lastRHRMatchMode = nil
        }

        let steps = await fetchedSteps
        let energy = await fetchedEnergy
        let autoBaseline = await fetchedBaseline
        let autoHRVBaseline = await fetchedHRVBaseline

        // Compute overall confidence based on available signals.
        let hasRHR = (rhr != nil)
        let hasHRV = (hrvMs != nil)
        recoveryConfidence = Self.computeRecoveryConfidence(
            sleepDetected: sleepDetection.sleepDetected,
            sleepConfidence: sleepDetection.sleepConfidence,
            hasRHR: hasRHR,
            hasHRV: hasHRV,
            rhrMatchMode: rhrMatchMode
        )
        logger.info("recovery-confidence: \(self.recoveryConfidence.rawValue) (\(self.recoveryConfidence.labelEs))")

        // Use auto-calculated baselines if available, otherwise fall back to config/defaults
        let effectiveBaseline = autoBaseline ?? config.baselineRestingHR
        let effectiveHRVBaseline = autoHRVBaseline ?? 60.0 // default 60ms if no history
        self.sleepSessionStart = sleepDetection.sessionStart
        self.sleepSessionEnd = sleepDetection.sessionEnd
        self.sleepConsistencyScore = sleepDetection.sleepConsistencyScore
        self.sleepAwakeEpisodeCount = sleepDetection.awakeEpisodeCount
        self.sleepAwakeSecondsDuringSession = sleepDetection.awakeSecondsDuringSession
        self.sleepSessionWallDuration = sleepDetection.sessionWallDuration
        self.restingHRBaselineUsed = effectiveBaseline
        self.hrvBaselineUsed = effectiveHRVBaseline
        logger.info("refreshHealthData results — sleep: \(sleepDetection.totalSleepHours.map { String(format: "%.1f", $0) } ?? "nil")h, rhr: \(rhr.map { String(format: "%.0f", $0) } ?? "nil"), hrv: \(hrvMs.map { String(format: "%.0f", $0) } ?? "nil")ms, steps: \(steps.map { String(format: "%.0f", $0) } ?? "nil"), energy: \(energy.map { String(format: "%.0f", $0) } ?? "nil")kcal, rhrBaseline: \(String(format: "%.0f", effectiveBaseline))bpm, hrvBaseline: \(String(format: "%.0f", effectiveHRVBaseline))ms")

        // Map each query result to HealthDataStatus
        self.sleepHours = sleepDetection.totalSleepHours.map { .available($0) } ?? .unavailable
        self.deepSleepHours = sleepDetection.deepSleepHours.map { .available($0) } ?? .unavailable
        self.remSleepHours = sleepDetection.remSleepHours.map { .available($0) } ?? .unavailable
        self.restingHR = rhr.map { .available($0) } ?? .unavailable
        self.hrv = hrvMs.map { .available($0) } ?? .unavailable
        self.stepCount = steps.map { .available($0) } ?? .unavailable
        self.activeEnergy = energy.map { .available($0) } ?? .unavailable

        // --- Calculate Recovery Score ---
        if let totalSleep = sleepDetection.totalSleepHours {
            let sq = SleepQualityScoring.compute(
                totalSleepHours: totalSleep,
                deepSleepHours: sleepDetection.deepSleepHours,
                remSleepHours: sleepDetection.remSleepHours,
                sleepGoalHours: config.effectiveSleepGoalHours,
                sessionWallDuration: sleepDetection.sessionWallDuration,
                awakeSecondsDuringSession: sleepDetection.awakeSecondsDuringSession,
                sleepConfidence: sleepDetection.sleepConfidence
            )
            self.sleepScore = .available(sq.displayScore)
            self.sleepContinuitySubscore = Int(max(0, min(100, round(sq.continuitySubscore))))
            self.lastSleepQualityDebugSnapshot = SleepQualityScoring.makeDebugSnapshot(
                result: sq,
                totalSleepHours: totalSleep,
                goalHoursUsed: config.effectiveSleepGoalHours,
                sleepConfidence: sleepDetection.sleepConfidence
            )
            logger.info("""
            recovery: sleep composite display=\(sq.displayScore) raw=\(String(format: "%.1f", sq.rawWeightedComposite)) \
            afterHourCap=\(String(format: "%.1f", sq.scoreAfterDurationHourCap)) \
            forRecovery=\(String(format: "%.1f", sq.sleepQualityForRecovery)) \
            conf=\(String(format: "%.2f", sleepDetection.sleepConfidence)) \
            dur=\(String(format: "%.1f", sq.durationSubscore)) cont=\(String(format: "%.1f", sq.continuitySubscore)) \
            rem=\(String(format: "%.1f", sq.remSubscore)) deep=\(String(format: "%.1f", sq.deepSubscore))
            """)
            let restingHRScore = rhr.map { Self.normalizeRestingHR(actual: $0, baseline: effectiveBaseline) }
            let hrvNormalized = hrvMs.map { Self.normalizeHRV(actual: $0, baseline: effectiveHRVBaseline) }

            var availableRecovery: [String] = ["sleep"]
            if restingHRScore != nil { availableRecovery.append("hr") }
            if hrvNormalized != nil { availableRecovery.append("hrv") }

            let originalWeights: [String: Double] = ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]
            let weights = Self.redistributeWeights(availableComponents: availableRecovery, originalWeights: originalWeights)

            let recScore = Self.calculateRecoveryScore(
                sleepQualityScore: sq.sleepQualityForRecovery,
                restingHRScore: restingHRScore ?? 0,
                hrvScore: hrvNormalized
            )
            self.recoveryScore = .available(recScore)
            self.recoveryBreakdown = Self.buildRecoveryBreakdown(
                sleepQualityScore: sq.sleepQualityForRecovery, sleepRawHours: totalSleep, sleepGoal: config.effectiveSleepGoalHours,
                restingHRScore: restingHRScore ?? 0, restingHRRaw: rhr ?? 0, baseline: effectiveBaseline,
                hrvScore: hrvNormalized, hrvRawMs: hrvMs, finalScore: recScore, weights: weights
            )
        } else if rhr != nil || hrvMs != nil {
            self.sleepScore = .unavailable
            self.sleepContinuitySubscore = nil
            self.lastSleepQualityDebugSnapshot = nil
            let restingHRScore = rhr.map { Self.normalizeRestingHR(actual: $0, baseline: effectiveBaseline) }
            let hrvNormalized = hrvMs.map { Self.normalizeHRV(actual: $0, baseline: effectiveHRVBaseline) }
            var available: [String] = []
            if restingHRScore != nil { available.append("hr") }
            if hrvNormalized != nil { available.append("hrv") }
            let originalWeights: [String: Double] = ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]
            let weights = Self.redistributeWeights(availableComponents: available, originalWeights: originalWeights)
            var score = 0.0
            if let hrs = restingHRScore, let w = weights["hr"] { score += hrs * w }
            if let h = hrvNormalized, let w = weights["hrv"] { score += h * w }
            self.recoveryScore = .available(Int(round(score)))
            self.recoveryBreakdown = nil
        } else {
            self.sleepScore = .unavailable
            self.sleepContinuitySubscore = nil
            self.lastSleepQualityDebugSnapshot = nil
            // Neutral recovery when no sleep and no HRV/RHR.
            self.recoveryScore = .available(50)
            self.recoveryBreakdown = nil
        }

        // --- Calculate Activity Score ---
        if steps != nil || energy != nil {
            let stepsNorm = steps.map { Self.normalizeSteps(actual: $0, goal: config.stepsGoal) } ?? 0
            let calNorm = energy.map { Self.normalizeCalories(actual: $0, goal: config.calorieGoal) } ?? 0
            let actScore = Self.calculateActivityScore(stepsScore: stepsNorm, caloriesScore: calNorm)
            self.activityScore = .available(actScore)
            self.activityBreakdown = Self.buildActivityBreakdown(
                stepsScore: stepsNorm, stepsRaw: steps ?? 0, stepsGoal: config.stepsGoal,
                caloriesScore: calNorm, caloriesRaw: energy ?? 0, caloriesGoal: config.calorieGoal,
                finalScore: actScore
            )
        } else {
            self.activityScore = .unavailable
            self.activityBreakdown = nil
        }

        if shouldNotifyRecoveryDataReady,
           case .available(let rec) = self.recoveryScore,
           let notificationService {
            await notificationService.scheduleRecoveryDataReadyIfNeeded(recoveryScore: rec)
        }
    }

    /// Alineado con `HomeViewModel` “hoy listo”: sesión de sueño, confianza media+ y score disponible.
    private var shouldNotifyRecoveryDataReady: Bool {
        guard sleepSessionEnd != nil else { return false }
        switch recoveryConfidence {
        case .high, .medium: break
        case .low, .insufficient: return false
        }
        guard case .available = recoveryScore else { return false }
        return true
    }

    // MARK: - Sleep Monitoring (HKObserverQuery)

    /// Start observing HealthKit for new sleep data. When the Watch syncs sleep,
    /// HealthKit fires the observer and we auto-refresh.
    func startSleepMonitoring() {
        guard let healthStore else { return }
        stopSleepMonitoring()

        let sleepType = HKCategoryType(.sleepAnalysis)

        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else {
                completionHandler()
                return
            }
            if let error {
                self.logger.error("Sleep observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            self.logger.info("🛌 Sleep observer fired — new sleep data available")
            self.scheduleDebouncedRefreshFromObservers()
            completionHandler()
        }

        healthStore.execute(query)
        sleepObserverQuery = query
        logger.info("Sleep observer started")

        // Also enable background delivery so iOS wakes us when sleep data arrives
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { success, error in
            if success {
                self.logger.info("Background delivery enabled for sleep")
            } else if let error {
                self.logger.error("Background delivery failed: \(error.localizedDescription)")
            }
        }
    }

    func stopSleepMonitoring() {
        if let query = sleepObserverQuery, let healthStore {
            healthStore.stop(query)
            sleepObserverQuery = nil
        }
        sleepMonitoringTimer?.invalidate()
        sleepMonitoringTimer = nil
    }

    // MARK: - Health Metric Observers

    /// Start observing key health metrics (resting HR, HRV, steps, calories)
    /// so the dashboard updates in real time when HealthKit receives new data.
    func startHealthObservers() {
        guard let healthStore else { return }
        stopHealthObservers()

        let types: [HKSampleType] = [
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned)
        ]

        for sampleType in types {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                guard let self else {
                    completionHandler()
                    return
                }
                if let error {
                    self.logger.error("Observer error for \(sampleType.identifier): \(error.localizedDescription)")
                    completionHandler()
                    return
                }
                self.logger.info("📊 Observer fired for \(sampleType.identifier) — scheduling debounced refresh")
                self.scheduleDebouncedRefreshFromObservers()
                completionHandler()
            }
            healthStore.execute(query)
            healthObserverQueries.append(query)

            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
                if success {
                    self.logger.info("Background delivery enabled for \(sampleType.identifier)")
                } else if let error {
                    self.logger.error("Background delivery failed for \(sampleType.identifier): \(error.localizedDescription)")
                }
            }
        }
        logger.info("Health metric observers started (\(types.count) types)")
    }

    func stopHealthObservers() {
        guard let healthStore else { return }
        for query in healthObserverQueries {
            healthStore.stop(query)
        }
        healthObserverQueries.removeAll()
    }

    // MARK: - Body Metrics Queries

    /// Query average resting HR over the last 14 days to use as automatic baseline.
    /// Returns nil if no data available.
    private func queryRestingHRBaseline(store: HKHealthStore, end: Date) async -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let start = Calendar.current.date(byAdding: .day, value: -14, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) {
                _, samples, error in
                if let error {
                    self.logger.error("Resting HR baseline query failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let sum = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
                let avg = sum / Double(samples.count)
                self.logger.info("Resting HR baseline: \(String(format: "%.0f", avg))bpm from \(samples.count) samples over 14 days")
                
                for sample in samples {
                    let value = sample.quantity.doubleValue(for: unit)
                    self.logger.info("RHR sample: \(sample.startDate) → \(sample.endDate) | value: \(value)")
                }
                
                continuation.resume(returning: avg)
            }
            store.execute(query)
        }
    }

    /// Query average HRV (SDNN) over the last 14 days to use as automatic baseline.
    private func queryHRVBaseline(store: HKHealthStore, end: Date) async -> Double? {
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let unit = HKUnit.secondUnit(with: .milli)
        let start = Calendar.current.date(byAdding: .day, value: -14, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) {
                _, samples, error in
                if let error {
                    self.logger.error("HRV baseline query failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let sum = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
                let avg = sum / Double(samples.count)
                self.logger.info("HRV baseline: \(String(format: "%.0f", avg))ms from \(samples.count) samples over 14 days")
                continuation.resume(returning: avg)
            }
            store.execute(query)
        }
    }

    func queryLatestWeight() async -> Double? {
        guard let healthStore else { return nil }
        return await queryQuantity(store: healthStore, type: .bodyMass, unit: .gramUnit(with: .kilo), start: Date.distantPast, end: Date())
    }

    func queryLatestHeight() async -> Double? {
        guard let healthStore else { return nil }
        return await queryQuantity(store: healthStore, type: .height, unit: .meterUnit(with: .centi), start: Date.distantPast, end: Date())
    }

    // MARK: - Static Pure Functions

    static func normalizeSteps(actual: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return Swift.min(100, Swift.max(0, actual / goal * 100))
    }

    static func normalizeCalories(actual: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return Swift.min(100, Swift.max(0, actual / goal * 100))
    }

    static func normalizeRestingHR(actual: Double, baseline: Double) -> Double {
        guard baseline > 0 else { return 0 }
        let percentageChange = (actual - baseline) / baseline
        return Swift.min(100, Swift.max(0, 100 - (percentageChange * 100 * 2.5)))
    }

    /// Normalize HRV against personal baseline.
    /// actual >= baseline → 100 (well recovered), actual at 50% of baseline → 0 (fatigued).
    static func normalizeHRV(actual: Double, baseline: Double) -> Double {
        guard baseline > 0 else { return 50 }
        // Ratio: 1.0 = at baseline, >1 = above (good), <1 = below (bad)
        let ratio = actual / baseline
        // Map: ratio 0.5 → 0, ratio 1.0 → 80, ratio 1.5+ → 100
        let score = (ratio - 0.5) / 0.5 * 80.0
        return Swift.min(100, Swift.max(0, score))
    }

    static func calculateRecoveryScore(sleepQualityScore: Double, restingHRScore: Double, hrvScore: Double?) -> Int {
        if let hrvScore {
            return Int(round(sleepQualityScore * 0.45 + restingHRScore * 0.25 + hrvScore * 0.30))
        } else {
            return Int(round(sleepQualityScore * 0.60 + restingHRScore * 0.40))
        }
    }

    static func calculateActivityScore(stepsScore: Double, caloriesScore: Double) -> Int {
        return Int(round(stepsScore * 0.50 + caloriesScore * 0.50))
    }

    static func redistributeWeights(availableComponents: [String], originalWeights: [String: Double]) -> [String: Double] {
        let availableSum = availableComponents.reduce(0.0) { $0 + (originalWeights[$1] ?? 0) }
        guard availableSum > 0 else { return [:] }
        var result: [String: Double] = [:]
        for key in availableComponents {
            result[key] = (originalWeights[key] ?? 0) / availableSum
        }
        return result
    }

    private static func componentStatus(for normalizedScore: Double) -> ScoreBreakdown.ComponentStatus {
        if normalizedScore < 40 { return .warning }
        if normalizedScore >= 70 { return .good }
        return .normal
    }

    static func buildRecoveryBreakdown(
        sleepQualityScore: Double, sleepRawHours: Double, sleepGoal: Double,
        restingHRScore: Double, restingHRRaw: Double, baseline: Double,
        hrvScore: Double?, hrvRawMs: Double?,
        finalScore: Int, weights: [String: Double]
    ) -> ScoreBreakdown {
        let sleepWeight = weights["sleep"] ?? 0.45
        let hrWeight = weights["hr"] ?? 0.25

        var components: [ScoreBreakdown.ScoreComponent] = [
            ScoreBreakdown.ScoreComponent(
                name: "Sleep", rawValue: sleepRawHours, rawUnit: "h",
                normalizedScore: sleepQualityScore, weight: sleepWeight,
                contribution: sleepQualityScore * sleepWeight,
                description: "Sleep quality \(String(format: "%.0f", sleepQualityScore))/100 (duration, continuity, REM/deep; goal \(String(format: "%.0f", sleepGoal))h)",
                status: componentStatus(for: sleepQualityScore)
            ),
            ScoreBreakdown.ScoreComponent(
                name: "Resting HR", rawValue: restingHRRaw, rawUnit: "bpm",
                normalizedScore: restingHRScore, weight: hrWeight,
                contribution: restingHRScore * hrWeight,
                description: "Resting HR \(String(format: "%.0f", restingHRRaw)) bpm vs \(String(format: "%.0f", baseline))bpm baseline",
                status: componentStatus(for: restingHRScore)
            )
        ]

        if let hrvScore, let hrvRawMs {
            let hrvWeight = weights["hrv"] ?? 0.30
            components.append(ScoreBreakdown.ScoreComponent(
                name: "HRV", rawValue: hrvRawMs, rawUnit: "ms",
                normalizedScore: hrvScore, weight: hrvWeight,
                contribution: hrvScore * hrvWeight,
                description: "HRV \(String(format: "%.0f", hrvRawMs))ms",
                status: componentStatus(for: hrvScore)
            ))
        }

        return ScoreBreakdown(components: components, finalScore: finalScore)
    }

    static func buildActivityBreakdown(
        stepsScore: Double, stepsRaw: Double, stepsGoal: Double,
        caloriesScore: Double, caloriesRaw: Double, caloriesGoal: Double,
        finalScore: Int
    ) -> ScoreBreakdown {
        let components: [ScoreBreakdown.ScoreComponent] = [
            ScoreBreakdown.ScoreComponent(
                name: "Steps", rawValue: stepsRaw, rawUnit: "steps",
                normalizedScore: stepsScore, weight: 0.50,
                contribution: stepsScore * 0.50,
                description: "\(String(format: "%.0f", stepsRaw)) of \(String(format: "%.0f", stepsGoal)) steps",
                status: componentStatus(for: stepsScore)
            ),
            ScoreBreakdown.ScoreComponent(
                name: "Active Calories", rawValue: caloriesRaw, rawUnit: "kcal",
                normalizedScore: caloriesScore, weight: 0.50,
                contribution: caloriesScore * 0.50,
                description: "\(String(format: "%.0f", caloriesRaw)) of \(String(format: "%.0f", caloriesGoal)) kcal",
                status: componentStatus(for: caloriesScore)
            )
        ]
        return ScoreBreakdown(components: components, finalScore: finalScore)
    }

    // MARK: - Private Helpers

    /// For logs: same `Date` as the user sees in Settings / Health app (not UTC).
    private static func formatLocalTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = .current
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f.string(from: date)
    }

    private func applyDefaults() {
        sleepHours = .unavailable
        deepSleepHours = .unavailable
        remSleepHours = .unavailable
        restingHR = .unavailable
        hrv = .unavailable
        stepCount = .unavailable
        activeEnergy = .unavailable
        recoveryScore = .unavailable
        activityScore = .unavailable
        sleepScore = .unavailable
        recoveryBreakdown = nil
        activityBreakdown = nil
        recoveryConfidence = .low
        sleepSessionStart = nil
        sleepSessionEnd = nil
        restingHRBaselineUsed = nil
        hrvBaselineUsed = nil
        lastRHRMatchMode = nil
        sleepConsistencyScore = 0
        sleepContinuitySubscore = nil
        sleepAwakeEpisodeCount = 0
        sleepAwakeSecondsDuringSession = nil
        sleepSessionWallDuration = nil
        sleepHours14DayAverage = nil
        sleepHistoryNightsCount = 0
        lastSleepQualityDebugSnapshot = nil
    }

    private static func computeRecoveryConfidence(
        sleepDetected: Bool,
        sleepConfidence: Double,
        hasRHR: Bool,
        hasHRV: Bool,
        rhrMatchMode: SleepWindowQuantityMatchMode?
    ) -> DataConfidenceLevel {
        // Insufficient: no sleep detected and no physiological signals.
        if !sleepDetected, !(hasRHR || hasHRV) {
            return .insufficient
        }

        // High: sleep session detected with strong overlap + at least one physiological signal.
        var level: DataConfidenceLevel
        if sleepDetected, sleepConfidence >= 0.80, (hasRHR || hasHRV) {
            level = .high
        } else if sleepDetected, sleepConfidence >= 0.50 {
            level = .medium
        } else if sleepDetected, sleepConfidence >= 0.80, !(hasRHR || hasHRV) {
            level = .medium
        } else {
            level = .low
        }

        // RHR matched with expanded window = heuristic alignment; don’t claim “high” on that basis alone.
        if level == .high, rhrMatchMode == .relaxedWindow {
            return .medium
        }
        return level
    }

    // MARK: - HealthKit Queries

    /// Sleep query: fetch raw HealthKit samples in the adjusted window and select the main
    /// session using SleepSessionFilter (merging, nap exclusion, confidence).
    private func querySleepDetection(
        store: HKHealthStore,
        window: SleepWindowBuilder.ExpectedSleepWindow,
        goal: SleepGoal?
    ) async -> SleepDetectionResult {
        let sleepType = HKCategoryType(.sleepAnalysis)
        // No acotar el fetch al final de la ventana ajustada por meta: si el despertar real
        // es mucho más tarde que la hora objetivo (+ buffer), HealthKit no devuelve esos tramos
        // y la sesión “fusionada” termina en el último minuto incluido (p. ej. ~4:44 con meta 4:30).
        // Ampliar hasta mediodía del día de despertar; el filtrado sigue en `SleepSessionFilter` (overlap con window).
        let cal = Calendar.current
        let queryEnd = SleepWindowBuilder.sleepFetchQueryEnd(window: window, calendar: cal)
        logger.info("sleep query range: adjustedEnd=\(Self.formatLocalTime(window.adjustedEnd)) → queryEnd=\(Self.formatLocalTime(queryEnd)) (fetch through wake-day noon if needed)")
        let predicate = HKQuery.predicateForSamples(withStart: window.adjustedStart, end: queryEnd, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [self] _, samples, error in
                if let error {
                    self.logger.error("Sleep query failed: \(error.localizedDescription)")
                    continuation.resume(returning: SleepDetectionResult(
                        sleepDetected: false,
                        sessionStart: nil,
                        sessionEnd: nil,
                        totalSleepHours: nil,
                        deepSleepHours: nil,
                        remSleepHours: nil,
                        sleepConfidence: 0.2,
                        sleepConsistencyScore: 0,
                        sessionWallDuration: nil,
                        awakeSecondsDuringSession: nil,
                        awakeEpisodeCount: 0,
                        rawSampleCount: 0,
                        mergedSessionCount: 0
                    ))
                    return
                }

                let hkSamples = (samples as? [HKCategorySample]) ?? []
                let result = SleepSessionFilter.process(samples: hkSamples, window: window, goal: goal)

                if hkSamples.isEmpty {
                    self.logger.info("Sleep query: 0 samples in adjusted window")
                } else {
                    self.logger.info("Sleep query: \(hkSamples.count) samples in adjusted window")
                }

                continuation.resume(returning: result)
            }

            store.execute(query)
        }
    }

    /// Rolling average of main sleep (≥90 min merged asleep) over completed wake days before `now` (excludes today’s wake).
    private func queryAverageMainSleepLast14Nights(store: HKHealthStore, now: Date) async -> (average: Double?, nights: Int) {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        guard let rangeStart = cal.date(byAdding: .day, value: -21, to: cal.startOfDay(for: now)) else {
            return (nil, 0)
        }
        let predicate = HKQuery.predicateForSamples(withStart: rangeStart, end: now, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    self.logger.error("queryAverageMainSleepLast14Nights failed: \(error.localizedDescription)")
                    continuation.resume(returning: (nil, 0))
                    return
                }
                let hkSamples = (samples as? [HKCategorySample]) ?? []
                let intervals = SleepHistoryAggregator.asleepIntervals(from: hkSamples)
                let result = SleepHistoryAggregator.averageMainSleepHours(intervals: intervals, now: now, calendar: cal)
                continuation.resume(returning: (result.average, result.nightsUsed))
            }
            store.execute(query)
        }
    }

    private func queryQuantity(store: HKHealthStore, type: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) {
                _, samples, error in
                if let error {
                    self.logger.error("Query for \(type.rawValue) failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let value = sample.quantity.doubleValue(for: unit)
                let date = sample.startDate

                print("🧪 \(type.rawValue) value: \(value) — date: \(date)")

                continuation.resume(returning: value)
            }
            
            store.execute(query)
        }
    }

    /// Query a quantity sample best associated with the sleep window.
    /// 1) Strict interval overlap with `[sleepStart, sleepEnd]`.
    /// 2) If none (common for Resting HR “daily” intervals), pick the sample with **maximum overlap**
    ///    with sleep; if still zero, use a **slightly expanded** sleep window for RHR only (HealthKit
    ///    often stores RHR in intervals that don’t align with asleep segments).
    private func queryQuantityInSleepWindow(
        store: HKHealthStore,
        type: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        sleepStart: Date,
        sleepEnd: Date
    ) async -> SleepWindowQuantityMatch? {
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: start,
                                                    end: end,
                                                    options: [])
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    self.logger.error("queryQuantityInSleepWindow for \(type.rawValue) failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                func overlapSeconds(_ a0: Date, _ a1: Date, _ b0: Date, _ b1: Date) -> TimeInterval {
                    let s = max(a0, b0)
                    let e = min(a1, b1)
                    return max(0, e.timeIntervalSince(s))
                }

                // 1) Strict overlap — prefer most recent start among ties (query already sorted desc by start)
                for sample in quantitySamples {
                    if sample.startDate < sleepEnd && sample.endDate > sleepStart {
                        let value = sample.quantity.doubleValue(for: unit)
                        self.logger.info("queryQuantityInSleepWindow \(type.rawValue): strict overlap \(sample.startDate) → \(sample.endDate)")
                        continuation.resume(returning: SleepWindowQuantityMatch(
                            value: value,
                            startDate: sample.startDate,
                            endDate: sample.endDate,
                            mode: .strict
                        ))
                        return
                    }
                }

                // 2) Best overlap duration with asleep window
                var best: HKQuantitySample?
                var bestOverlap: TimeInterval = 0
                for sample in quantitySamples {
                    let o = overlapSeconds(sample.startDate, sample.endDate, sleepStart, sleepEnd)
                    if o > bestOverlap {
                        bestOverlap = o
                        best = sample
                    }
                }
                if let best, bestOverlap > 0 {
                    let value = best.quantity.doubleValue(for: unit)
                    self.logger.info("queryQuantityInSleepWindow \(type.rawValue): max partial overlap=\(Int(bestOverlap))s \(best.startDate) → \(best.endDate)")
                    continuation.resume(returning: SleepWindowQuantityMatch(
                        value: value,
                        startDate: best.startDate,
                        endDate: best.endDate,
                        mode: .partialOverlap
                    ))
                    return
                }

                // 3) Resting HR: expand search window (Apple’s RHR intervals often end before final awake time)
                if type == .restingHeartRate {
                    let expandPre: TimeInterval = -3 * 3600
                    let expandPost: TimeInterval = 3600
                    let win0 = sleepStart.addingTimeInterval(expandPre)
                    let win1 = sleepEnd.addingTimeInterval(expandPost)
                    var bestR: HKQuantitySample?
                    var bestRO: TimeInterval = 0
                    for sample in quantitySamples {
                        let o = overlapSeconds(sample.startDate, sample.endDate, win0, win1)
                        if o > bestRO {
                            bestRO = o
                            bestR = sample
                        }
                    }
                    if let bestR, bestRO > 0 {
                        let value = bestR.quantity.doubleValue(for: unit)
                        self.logger.info("queryQuantityInSleepWindow RHR: relaxed-window overlap=\(Int(bestRO))s \(bestR.startDate) → \(bestR.endDate)")
                        continuation.resume(returning: SleepWindowQuantityMatch(
                            value: value,
                            startDate: bestR.startDate,
                            endDate: bestR.endDate,
                            mode: .relaxedWindow
                        ))
                        return
                    }
                }

                for sample in quantitySamples {
                    let value = sample.quantity.doubleValue(for: unit)
                    self.logger.info("RHR sample del dia: \(sample.startDate) → \(sample.endDate) | value: \(value)")
                }

                continuation.resume(returning: nil)
            }
            store.execute(query)
        }
    }

    private func queryQuantityCumulative(store: HKHealthStore, type: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) {
                _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}

extension HealthKitManager.DataConfidenceLevel {
    func localizedLabel(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.insufficient, .spanish): return "Datos insuficientes"
        case (.insufficient, .english): return "Insufficient data"
        case (.high, .spanish): return "Altamente confiable"
        case (.high, .english): return "Highly reliable"
        case (.medium, .spanish): return "Confiabilidad media"
        case (.medium, .english): return "Medium reliability"
        case (.low, .spanish): return "Poco confiable"
        case (.low, .english): return "Low reliability"
        }
    }
}
