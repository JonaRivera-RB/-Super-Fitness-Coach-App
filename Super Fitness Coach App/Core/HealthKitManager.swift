//  HealthKitManager.swift
//  Super Fitness Coach App
//

import Foundation
import HealthKit
import os

@Observable
final class HealthKitManager {

    // MARK: - Published Properties

    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    private(set) var recoveryScore: HealthDataStatus<Int> = .loading
    private(set) var activityScore: HealthDataStatus<Int> = .loading
    private(set) var recoveryBreakdown: ScoreBreakdown?
    private(set) var activityBreakdown: ScoreBreakdown?

    // Individual metrics
    private(set) var sleepHours: HealthDataStatus<Double> = .loading
    private(set) var deepSleepHours: HealthDataStatus<Double> = .loading
    private(set) var remSleepHours: HealthDataStatus<Double> = .loading
    private(set) var restingHR: HealthDataStatus<Double> = .loading
    private(set) var hrv: HealthDataStatus<Double> = .loading
    private(set) var stepCount: HealthDataStatus<Double> = .loading
    private(set) var activeEnergy: HealthDataStatus<Double> = .loading

    // MARK: - Private

    private let healthStore: HKHealthStore?
    private let logger = Logger(subsystem: "com.superfitness.coach", category: "HealthKitManager")

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

        // Query all metrics concurrently
        // Sleep: uses smart range that crosses midnight (your fix)
        // HR/HRV: last 24h
        // Steps/Calories: today only (matches Apple Health day view)
        async let fetchedSleepPhases = querySleepPhases(store: healthStore, end: now)
        async let fetchedRestingHR = queryQuantity(store: healthStore, type: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: twentyFourHoursAgo, end: now)
        async let fetchedHRV = queryQuantity(store: healthStore, type: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: twentyFourHoursAgo, end: now)
        async let fetchedSteps = queryQuantityCumulative(store: healthStore, type: .stepCount, unit: .count(), start: startOfToday, end: now)
        async let fetchedEnergy = queryQuantityCumulative(store: healthStore, type: .activeEnergyBurned, unit: .kilocalorie(), start: startOfToday, end: now)
        // Auto-baselines: average over last 14 days
        async let fetchedBaseline = queryRestingHRBaseline(store: healthStore, end: now)
        async let fetchedHRVBaseline = queryHRVBaseline(store: healthStore, end: now)

        let sleepPhases = await fetchedSleepPhases
        let rhr = await fetchedRestingHR
        let hrvMs = await fetchedHRV
        let steps = await fetchedSteps
        let energy = await fetchedEnergy
        let autoBaseline = await fetchedBaseline
        let autoHRVBaseline = await fetchedHRVBaseline

        // Use auto-calculated baselines if available, otherwise fall back to config/defaults
        let effectiveBaseline = autoBaseline ?? config.baselineRestingHR
        let effectiveHRVBaseline = autoHRVBaseline ?? 60.0 // default 60ms if no history
        logger.info("refreshHealthData results — sleep: \(sleepPhases.total.map { String(format: "%.1f", $0) } ?? "nil")h, rhr: \(rhr.map { String(format: "%.0f", $0) } ?? "nil"), hrv: \(hrvMs.map { String(format: "%.0f", $0) } ?? "nil")ms, steps: \(steps.map { String(format: "%.0f", $0) } ?? "nil"), energy: \(energy.map { String(format: "%.0f", $0) } ?? "nil")kcal, rhrBaseline: \(String(format: "%.0f", effectiveBaseline))bpm, hrvBaseline: \(String(format: "%.0f", effectiveHRVBaseline))ms")

        // Map each query result to HealthDataStatus
        self.sleepHours = sleepPhases.total.map { .available($0) } ?? .unavailable
        self.deepSleepHours = sleepPhases.deep.map { .available($0) } ?? .unavailable
        self.remSleepHours = sleepPhases.rem.map { .available($0) } ?? .unavailable
        self.restingHR = rhr.map { .available($0) } ?? .unavailable
        self.hrv = hrvMs.map { .available($0) } ?? .unavailable
        self.stepCount = steps.map { .available($0) } ?? .unavailable
        self.activeEnergy = energy.map { .available($0) } ?? .unavailable

        // --- Calculate Recovery Score ---
        if let totalSleep = sleepPhases.total {
            let sleepQualityScore = Self.calculateSleepQualityScore(
                totalHours: totalSleep, deepHours: sleepPhases.deep,
                remHours: sleepPhases.rem, sleepGoal: config.sleepGoalHours
            )
            let restingHRScore = rhr.map { Self.normalizeRestingHR(actual: $0, baseline: effectiveBaseline) }
            let hrvNormalized = hrvMs.map { Self.normalizeHRV(actual: $0, baseline: effectiveHRVBaseline) }

            var availableRecovery: [String] = ["sleep"]
            if restingHRScore != nil { availableRecovery.append("hr") }
            if hrvNormalized != nil { availableRecovery.append("hrv") }

            let originalWeights: [String: Double] = ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]
            let weights = Self.redistributeWeights(availableComponents: availableRecovery, originalWeights: originalWeights)

            let recScore = Self.calculateRecoveryScore(
                sleepQualityScore: sleepQualityScore,
                restingHRScore: restingHRScore ?? 0,
                hrvScore: hrvNormalized
            )
            self.recoveryScore = .available(recScore)
            self.recoveryBreakdown = Self.buildRecoveryBreakdown(
                sleepQualityScore: sleepQualityScore, sleepRawHours: totalSleep, sleepGoal: config.sleepGoalHours,
                restingHRScore: restingHRScore ?? 0, restingHRRaw: rhr ?? 0, baseline: effectiveBaseline,
                hrvScore: hrvNormalized, hrvRawMs: hrvMs, finalScore: recScore, weights: weights
            )
        } else if rhr != nil || hrvMs != nil {
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
        } else if steps != nil || energy != nil {
            let stepsNorm = steps.map { Self.normalizeSteps(actual: $0, goal: config.stepsGoal) } ?? 0
            let calNorm = energy.map { Self.normalizeCalories(actual: $0, goal: config.calorieGoal) } ?? 0
            let activityLevel = (stepsNorm + calNorm) / 2.0
            let estimatedRecovery = Int(round(70.0 - activityLevel * 0.30))
            self.recoveryScore = .available(max(20, min(80, estimatedRecovery)))
            self.recoveryBreakdown = nil
        } else {
            self.recoveryScore = .unavailable
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
            Task {
                await self.refreshHealthData()
                completionHandler()
            }
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
                self.logger.info("📊 Observer fired for \(sampleType.identifier) — refreshing data")
                Task {
                    await self.refreshHealthData()
                    completionHandler()
                }
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

    static func calculateSleepQualityScore(totalHours: Double, deepHours: Double?, remHours: Double?, sleepGoal: Double) -> Double {
        guard sleepGoal > 0 else { return 0 }
        let durationScore = Swift.min(100, Swift.max(0, totalHours / sleepGoal * 100))
        guard let deepHours, let remHours, totalHours > 0 else { return durationScore }
        let deepScore = Swift.min(100, Swift.max(0, (deepHours / totalHours) / 0.175 * 100))
        let remScore = Swift.min(100, Swift.max(0, (remHours / totalHours) / 0.225 * 100))
        return durationScore * 0.50 + deepScore * 0.25 + remScore * 0.25
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
        let durationScore = sleepGoal > 0 ? Swift.min(100, Swift.max(0, sleepRawHours / sleepGoal * 100)) : 0

        var components: [ScoreBreakdown.ScoreComponent] = [
            ScoreBreakdown.ScoreComponent(
                name: "Sleep", rawValue: sleepRawHours, rawUnit: "h",
                normalizedScore: durationScore, weight: sleepWeight,
                contribution: sleepQualityScore * sleepWeight,
                description: "Slept \(String(format: "%.1f", sleepRawHours))h of your \(String(format: "%.0f", sleepGoal))h goal",
                status: componentStatus(for: durationScore)
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
        recoveryBreakdown = nil
        activityBreakdown = nil
    }

    // MARK: - HealthKit Queries

    /// Sleep query: finds the most recent sleep session from HealthKit data.
    /// 
    /// Approach (based on Apple DTS recommendations):
    /// 1. Query asleep samples from last 24h (covers any sleep schedule)
    /// 2. Merge overlapping intervals to avoid double-counting (Watch + iPhone)
    /// 3. Group merged intervals into sessions (gap > 2h = separate session)
    /// 4. Return only the most recent session
    ///
    /// Note: Apple's sleep schedule is user-configured and not accessible via HealthKit API,
    /// so we detect sessions from the actual data instead of assuming fixed hours.
    private func querySleepPhases(store: HKHealthStore, end: Date) async -> (total: Double?, deep: Double?, rem: Double?) {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let lookback = Calendar.current.date(byAdding: .hour, value: -24, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: lookback, end: end, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType, predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { [self] _, samples, error in
                if let error {
                    self.logger.error("Sleep query failed: \(error.localizedDescription)")
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }

                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]

                let asleepSamples = samples.filter { asleepValues.contains($0.value) }
                guard !asleepSamples.isEmpty else {
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }

                // Step 1: Merge all overlapping intervals to get clean time blocks
                let allIntervals = asleepSamples.map { ($0.startDate, $0.endDate) }
                let merged = Self.mergeIntervals(allIntervals)

                // Step 2: Group merged intervals into sessions (gap > 2h = new session)
                let sessionGap: TimeInterval = 2 * 60 * 60
                var sessions: [[(Date, Date)]] = []
                var currentSession: [(Date, Date)] = []

                for interval in merged {
                    if let last = currentSession.last, interval.0.timeIntervalSince(last.1) > sessionGap {
                        sessions.append(currentSession)
                        currentSession = [interval]
                    } else {
                        currentSession.append(interval)
                    }
                }
                if !currentSession.isEmpty {
                    sessions.append(currentSession)
                }

                // Step 3: Take the most recent session (last one, since merged is sorted)
                guard let latestSession = sessions.last else {
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }

                let sessionStart = latestSession.first!.0
                let sessionEnd = latestSession.last!.1
                let totalSeconds = latestSession.reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }

                // Step 4: Deep and REM — filter original samples to this session's time range,
                // then merge their intervals separately
                let sessionSamples = asleepSamples.filter { $0.startDate >= sessionStart && $0.endDate <= sessionEnd }

                let deepIntervals = sessionSamples
                    .filter { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue }
                    .map { ($0.startDate, $0.endDate) }
                let deepSeconds = Self.mergeAndSum(intervals: deepIntervals)

                let remIntervals = sessionSamples
                    .filter { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                    .map { ($0.startDate, $0.endDate) }
                let remSeconds = Self.mergeAndSum(intervals: remIntervals)

                let totalHours = totalSeconds / 3600.0
                let deepHours = deepSeconds / 3600.0
                let remHours = remSeconds / 3600.0

                self.logger.info("Sleep: \(sessionSamples.count) samples in session, \(String(format: "%.1f", totalHours))h total (deep: \(String(format: "%.1f", deepHours))h, rem: \(String(format: "%.1f", remHours))h), session: \(sessionStart) → \(sessionEnd)")

                continuation.resume(returning: (
                    totalHours > 0 ? totalHours : nil,
                    deepHours > 0 ? deepHours : nil,
                    remHours > 0 ? remHours : nil
                ))
            }
            store.execute(query)
        }
    }

    /// Merge overlapping time intervals into non-overlapping blocks, sorted by start.
    private static func mergeIntervals(_ intervals: [(Date, Date)]) -> [(Date, Date)] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.0 < $1.0 }
        var merged: [(Date, Date)] = [sorted[0]]
        for interval in sorted.dropFirst() {
            let last = merged[merged.count - 1]
            if interval.0 <= last.1 {
                merged[merged.count - 1] = (last.0, max(last.1, interval.1))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    /// Merge overlapping intervals and return total seconds.
    private static func mergeAndSum(intervals: [(Date, Date)]) -> TimeInterval {
        return mergeIntervals(intervals).reduce(0.0) { $0 + $1.1.timeIntervalSince($1.0) }
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
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
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
