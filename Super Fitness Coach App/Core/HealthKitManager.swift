//
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

    /// Verify actual HealthKit authorization by performing a test query to stepCount.
    /// Sets authorizationStatus to .authorized, .denied, or .unavailable based on result.
    func verifyAuthorization() async {
        guard let healthStore else {
            authorizationStatus = .unavailable
            logger.warning("verifyAuthorization: healthStore is nil")
            return
        }

        let stepType = HKQuantityType(.stepCount)
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)

        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: stepType,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                healthStore.execute(query)
            }
            authorizationStatus = .authorized
            logger.info("verifyAuthorization: authorized (samples: \(samples.count))")
        } catch {
            logger.error("verifyAuthorization failed: \(error.localizedDescription)")
            // Don't set denied on transient errors — check authorizationStatus for the type
            let status = healthStore.authorizationStatus(for: HKQuantityType(.stepCount))
            if status == .sharingDenied {
                authorizationStatus = .denied
                logger.warning("verifyAuthorization: sharing denied by user")
            } else {
                // Transient error, try requestAuthorization as fallback
                logger.info("verifyAuthorization: transient error, attempting requestAuthorization")
                do {
                    try await requestAuthorization()
                } catch {
                    authorizationStatus = .denied
                    logger.error("verifyAuthorization: fallback requestAuthorization also failed")
                }
            }
        }
    }

    func requestAuthorization() async throws {
        guard let healthStore else {
            logger.warning("HealthKit not available, using defaults.")
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
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
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

    /// Query all health metrics from HealthKit and calculate Recovery/Activity scores
    /// using the user's personalized FitnessConfig goals.
    func refreshHealthData(config: FitnessConfig) async {
        guard let healthStore else {
            logger.warning("refreshHealthData: healthStore is nil")
            applyDefaults()
            return
        }
        
        // Auto-verify/request authorization if not yet authorized
        if authorizationStatus != .authorized {
            logger.info("refreshHealthData: not authorized yet, verifying...")
            await verifyAuthorization()
        }
        
        guard authorizationStatus == .authorized else {
            logger.warning("refreshHealthData: still not authorized after verify (status: \(String(describing: self.authorizationStatus)))")
            applyDefaults()
            return
        }

        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        logger.info("refreshHealthData: activity range \(startOfToday) to \(now), recovery range \(twentyFourHoursAgo) to \(now)")

        // Query all metrics concurrently
        // Sleep/HR/HRV: last 24h (sleep crosses midnight)
        // Steps/Calories: today only (matches Apple Health day view)
        async let fetchedSleepPhases = querySleepPhases(store: healthStore, start: twentyFourHoursAgo, end: now)
        async let fetchedRestingHR = queryQuantity(store: healthStore, type: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: twentyFourHoursAgo, end: now)
        async let fetchedHRV = queryQuantity(store: healthStore, type: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: twentyFourHoursAgo, end: now)
        async let fetchedSteps = queryQuantityCumulative(store: healthStore, type: .stepCount, unit: .count(), start: startOfToday, end: now)
        async let fetchedEnergy = queryQuantityCumulative(store: healthStore, type: .activeEnergyBurned, unit: .kilocalorie(), start: startOfToday, end: now)

        let sleepPhases = await fetchedSleepPhases
        let rhr = await fetchedRestingHR
        let hrvMs = await fetchedHRV
        let steps = await fetchedSteps
        let energy = await fetchedEnergy

        logger.info("refreshHealthData results — sleep: \(sleepPhases.total.map { String(format: "%.1f", $0) } ?? "nil")h, rhr: \(rhr.map { String(format: "%.0f", $0) } ?? "nil"), hrv: \(hrvMs.map { String(format: "%.0f", $0) } ?? "nil")ms, steps: \(steps.map { String(format: "%.0f", $0) } ?? "nil"), energy: \(energy.map { String(format: "%.0f", $0) } ?? "nil")kcal")

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
                totalHours: totalSleep,
                deepHours: sleepPhases.deep,
                remHours: sleepPhases.rem,
                sleepGoal: config.sleepGoalHours
            )
            let restingHRScore = rhr.map { Self.normalizeRestingHR(actual: $0, baseline: config.baselineRestingHR) }
            let hrvNormalized = hrvMs.map { Self.normalizeHRV(milliseconds: $0) }

            // Determine available recovery components for weight redistribution
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
                sleepQualityScore: sleepQualityScore,
                sleepRawHours: totalSleep,
                sleepGoal: config.sleepGoalHours,
                restingHRScore: restingHRScore ?? 0,
                restingHRRaw: rhr ?? 0,
                baseline: config.baselineRestingHR,
                hrvScore: hrvNormalized,
                hrvRawMs: hrvMs,
                finalScore: recScore,
                weights: weights
            )
        } else if rhr != nil || hrvMs != nil {
            // Sleep unavailable but other recovery metrics available
            let restingHRScore = rhr.map { Self.normalizeRestingHR(actual: $0, baseline: config.baselineRestingHR) }
            let hrvNormalized = hrvMs.map { Self.normalizeHRV(milliseconds: $0) }

            var available: [String] = []
            if restingHRScore != nil { available.append("hr") }
            if hrvNormalized != nil { available.append("hrv") }

            let originalWeights: [String: Double] = ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]
            let weights = Self.redistributeWeights(availableComponents: available, originalWeights: originalWeights)

            // Compute score manually from available components
            var score = 0.0
            if let hrs = restingHRScore, let w = weights["hr"] { score += hrs * w }
            if let h = hrvNormalized, let w = weights["hrv"] { score += h * w }
            let recScore = Int(round(score))
            self.recoveryScore = .available(recScore)
            self.recoveryBreakdown = nil
        } else if steps != nil || energy != nil {
            // No sleep/HR/HRV but activity data exists — estimate recovery from activity
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
                stepsScore: stepsNorm,
                stepsRaw: steps ?? 0,
                stepsGoal: config.stepsGoal,
                caloriesScore: calNorm,
                caloriesRaw: energy ?? 0,
                caloriesGoal: config.calorieGoal,
                finalScore: actScore
            )
        } else {
            self.activityScore = .unavailable
            self.activityBreakdown = nil
        }
    }

    // MARK: - Body Metrics Queries

    /// Query HealthKit for the most recent body mass sample, returning the value in kilograms.
    /// Returns nil if HealthKit is unavailable or no data exists.
    func queryLatestWeight() async -> Double? {
        guard let healthStore else { return nil }
        return await queryQuantity(
            store: healthStore,
            type: .bodyMass,
            unit: .gramUnit(with: .kilo),
            start: Date.distantPast,
            end: Date()
        )
    }

    /// Query HealthKit for the most recent height sample, returning the value in centimeters.
    /// Returns nil if HealthKit is unavailable or no data exists.
    func queryLatestHeight() async -> Double? {
        guard let healthStore else { return nil }
        return await queryQuantity(
            store: healthStore,
            type: .height,
            unit: .meterUnit(with: .centi),
            start: Date.distantPast,
            end: Date()
        )
    }

    // MARK: - Static Pure Functions

    /// Normalize a value to 0–100 given a min and max range.
    static func normalize(value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0 }
        let normalized = (value - min) / (max - min) * 100.0
        return Swift.min(100, Swift.max(0, normalized))
    }

    /// Calculate recovery score from health components using the weighted formula.
    /// Each unavailable component should be passed as its default (50).
    static func calculateRecoveryScore(
        sleepHours: Double,
        restingHR: Double,
        stepCount: Double,
        activeEnergy: Double
    ) -> Int {
        let sleepQuality = Swift.min(100, Swift.max(0, sleepHours / 8.0 * 100.0))
        let restingHRScore = Swift.min(100, Swift.max(0, (100.0 - restingHR) / (100.0 - 50.0) * 100.0))
        let stepsScore = Swift.min(100, Swift.max(0, stepCount / 10000.0 * 100.0))
        let workoutScore = Swift.min(100, Swift.max(0, activeEnergy / 500.0 * 100.0))

        let raw = sleepQuality * 0.4 + restingHRScore * 0.2 + stepsScore * 0.2 + workoutScore * 0.2
        let score = Int(round(raw))
        return Swift.min(100, Swift.max(0, score))
    }

    /// Normalize steps against user's goal. Returns 0 if goal <= 0.
    static func normalizeSteps(actual: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return Swift.min(100, Swift.max(0, actual / goal * 100))
    }

    /// Normalize calories against user's goal. Returns 0 if goal <= 0.
    static func normalizeCalories(actual: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return Swift.min(100, Swift.max(0, actual / goal * 100))
    }

    /// Normalize sleep duration against user's goal. Returns 0 if goal <= 0.
    static func normalizeSleepDuration(actual: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return Swift.min(100, Swift.max(0, actual / goal * 100))
    }

    /// Normalize resting HR against personal baseline using percentage-based formula with factor 2.5.
    /// actual == baseline → 100, actual ≥ baseline × 1.40 → 0, actual < baseline → clamped to 100.
    static func normalizeRestingHR(actual: Double, baseline: Double) -> Double {
        guard baseline > 0 else { return 0 }
        let percentageChange = (actual - baseline) / baseline
        return Swift.min(100, Swift.max(0, 100 - (percentageChange * 100 * 2.5)))
    }

    /// Normalize HRV: linear interpolation from 20ms → 0 to 100ms → 100, clamped [0, 100].
    static func normalizeHRV(milliseconds: Double) -> Double {
        return Swift.min(100, Swift.max(0, (milliseconds - 20) / 80 * 100))
    }

    /// Calculate sleep quality score using weighted formula:
    /// durationScore × 0.50 + deepScore × 0.25 + remScore × 0.25.
    /// Falls back to duration-only (weight 1.0) when deep/REM hours are nil.
    /// - Parameters:
    ///   - totalHours: Total sleep hours
    ///   - deepHours: Deep sleep hours (nil if unavailable)
    ///   - remHours: REM sleep hours (nil if unavailable)
    ///   - sleepGoal: User's sleep goal in hours from FitnessConfig
    /// - Returns: A score between 0 and 100
    static func calculateSleepQualityScore(
        totalHours: Double,
        deepHours: Double?,
        remHours: Double?,
        sleepGoal: Double
    ) -> Double {
        guard sleepGoal > 0 else { return 0 }

        let durationScore = Swift.min(100, Swift.max(0, totalHours / sleepGoal * 100))

        // Fallback to duration-only when phase data is unavailable
        guard let deepHours, let remHours, totalHours > 0 else {
            return durationScore
        }

        let deepPercentage = deepHours / totalHours
        let deepScore = Swift.min(100, Swift.max(0, deepPercentage / 0.175 * 100))

        let remPercentage = remHours / totalHours
        let remScore = Swift.min(100, Swift.max(0, remPercentage / 0.225 * 100))

        return durationScore * 0.50 + deepScore * 0.25 + remScore * 0.25
    }

    /// Recovery Score: weights sleep 0.45, HR 0.25, HRV 0.30.
    /// When HRV is unavailable (nil), falls back to sleep 0.60, HR 0.40.
    static func calculateRecoveryScore(
        sleepQualityScore: Double,
        restingHRScore: Double,
        hrvScore: Double?
    ) -> Int {
        if let hrvScore {
            return Int(round(sleepQualityScore * 0.45 + restingHRScore * 0.25 + hrvScore * 0.30))
        } else {
            return Int(round(sleepQualityScore * 0.60 + restingHRScore * 0.40))
        }
    }

    /// Activity Score: weights steps 0.50, calories 0.50.
    static func calculateActivityScore(
        stepsScore: Double,
        caloriesScore: Double
    ) -> Int {
        return Int(round(stepsScore * 0.50 + caloriesScore * 0.50))
    }

    /// Redistribute weights proportionally when some components are unavailable.
    /// Returns empty dictionary if no available components have positive weights.
    static func redistributeWeights(
        availableComponents: [String],
        originalWeights: [String: Double]
    ) -> [String: Double] {
        let availableSum = availableComponents.reduce(0.0) { $0 + (originalWeights[$1] ?? 0) }
        guard availableSum > 0 else { return [:] }
        var result: [String: Double] = [:]
        for key in availableComponents {
            result[key] = (originalWeights[key] ?? 0) / availableSum
        }
        return result
    }

    /// Determine ComponentStatus based on normalizedScore thresholds.
    private static func componentStatus(for normalizedScore: Double) -> ScoreBreakdown.ComponentStatus {
        if normalizedScore < 40 { return .warning }
        if normalizedScore >= 70 { return .good }
        return .normal
    }

    /// Build a ScoreBreakdown for Recovery Score with sleep, HR, and optional HRV components.
    static func buildRecoveryBreakdown(
        sleepQualityScore: Double, sleepRawHours: Double, sleepGoal: Double,
        restingHRScore: Double, restingHRRaw: Double, baseline: Double,
        hrvScore: Double?, hrvRawMs: Double?,
        finalScore: Int,
        weights: [String: Double]
    ) -> ScoreBreakdown {
        let sleepWeight = weights["sleep"] ?? 0.45
        let hrWeight = weights["hr"] ?? 0.25

        // Show duration-based progress in the bar (intuitive: hours vs goal)
        let durationScore = sleepGoal > 0 ? Swift.min(100, Swift.max(0, sleepRawHours / sleepGoal * 100)) : 0

        var components: [ScoreBreakdown.ScoreComponent] = [
            ScoreBreakdown.ScoreComponent(
                name: "Sleep",
                rawValue: sleepRawHours,
                rawUnit: "h",
                normalizedScore: durationScore,
                weight: sleepWeight,
                contribution: sleepQualityScore * sleepWeight,
                description: "Slept \(String(format: "%.1f", sleepRawHours))h of your \(String(format: "%.0f", sleepGoal))h goal",
                status: componentStatus(for: durationScore)
            ),
            ScoreBreakdown.ScoreComponent(
                name: "Resting HR",
                rawValue: restingHRRaw,
                rawUnit: "bpm",
                normalizedScore: restingHRScore,
                weight: hrWeight,
                contribution: restingHRScore * hrWeight,
                description: "Resting HR \(String(format: "%.0f", restingHRRaw)) bpm vs \(String(format: "%.0f", baseline))bpm baseline",
                status: componentStatus(for: restingHRScore)
            )
        ]

        if let hrvScore, let hrvRawMs {
            let hrvWeight = weights["hrv"] ?? 0.30
            components.append(
                ScoreBreakdown.ScoreComponent(
                    name: "HRV",
                    rawValue: hrvRawMs,
                    rawUnit: "ms",
                    normalizedScore: hrvScore,
                    weight: hrvWeight,
                    contribution: hrvScore * hrvWeight,
                    description: "HRV \(String(format: "%.0f", hrvRawMs))ms",
                    status: componentStatus(for: hrvScore)
                )
            )
        }

        return ScoreBreakdown(components: components, finalScore: finalScore)
    }

    /// Build a ScoreBreakdown for Activity Score with steps and calories components.
    static func buildActivityBreakdown(
        stepsScore: Double, stepsRaw: Double, stepsGoal: Double,
        caloriesScore: Double, caloriesRaw: Double, caloriesGoal: Double,
        finalScore: Int
    ) -> ScoreBreakdown {
        let stepsWeight = 0.50
        let caloriesWeight = 0.50

        let components: [ScoreBreakdown.ScoreComponent] = [
            ScoreBreakdown.ScoreComponent(
                name: "Steps",
                rawValue: stepsRaw,
                rawUnit: "steps",
                normalizedScore: stepsScore,
                weight: stepsWeight,
                contribution: stepsScore * stepsWeight,
                description: "\(String(format: "%.0f", stepsRaw)) of \(String(format: "%.0f", stepsGoal)) steps",
                status: componentStatus(for: stepsScore)
            ),
            ScoreBreakdown.ScoreComponent(
                name: "Active Calories",
                rawValue: caloriesRaw,
                rawUnit: "kcal",
                normalizedScore: caloriesScore,
                weight: caloriesWeight,
                contribution: caloriesScore * caloriesWeight,
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

    private func querySleepPhases(store: HKHealthStore, start: Date, end: Date) async -> (total: Double?, deep: Double?, rem: Double?) {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    self.logger.error("Sleep phases query failed: \(error.localizedDescription)")
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

                let totalSeconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                let deepSeconds = samples
                    .filter { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                let remSeconds = samples
                    .filter { $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                let totalHours = totalSeconds / 3600.0
                let deepHours: Double? = deepSeconds > 0 ? deepSeconds / 3600.0 : nil
                let remHours: Double? = remSeconds > 0 ? remSeconds / 3600.0 : nil

                continuation.resume(returning: (totalHours > 0 ? totalHours : nil, deepHours, remHours))
            }
            store.execute(query)
        }
    }

    private func queryQuantity(
        store: HKHealthStore,
        type: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
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
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func queryQuantityCumulative(
        store: HKHealthStore,
        type: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        let quantityType = HKQuantityType(type)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    self.logger.error("Cumulative query for \(type.rawValue) failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }

                let value = sum.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
