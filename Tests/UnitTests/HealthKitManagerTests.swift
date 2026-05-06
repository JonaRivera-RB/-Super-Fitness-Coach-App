//
//  HealthKitManagerTests.swift
//  Super Fitness Coach App
//

import Foundation
import Testing
@testable import Super_Fitness_Coach_App

struct HealthKitManagerTests {

    // MARK: - normalizeSteps tests

    @Test func normalizeStepsAtGoal() {
        let result = HealthKitManager.normalizeSteps(actual: 10000, goal: 10000)
        #expect(result == 100.0)
    }

    @Test func normalizeStepsHalfGoal() {
        let result = HealthKitManager.normalizeSteps(actual: 5000, goal: 10000)
        #expect(result == 50.0)
    }

    @Test func normalizeStepsZero() {
        let result = HealthKitManager.normalizeSteps(actual: 0, goal: 10000)
        #expect(result == 0.0)
    }

    @Test func normalizeStepsOverGoalClampsTo100() {
        let result = HealthKitManager.normalizeSteps(actual: 20000, goal: 10000)
        #expect(result == 100.0)
    }

    @Test func normalizeStepsZeroGoalReturnsZero() {
        let result = HealthKitManager.normalizeSteps(actual: 5000, goal: 0)
        #expect(result == 0.0)
    }

    // MARK: - normalizeCalories tests

    @Test func normalizeCaloriesAtGoal() {
        let result = HealthKitManager.normalizeCalories(actual: 500, goal: 500)
        #expect(result == 100.0)
    }

    @Test func normalizeCaloriesHalfGoal() {
        let result = HealthKitManager.normalizeCalories(actual: 250, goal: 500)
        #expect(result == 50.0)
    }

    @Test func normalizeCaloriesOverGoalClampsTo100() {
        let result = HealthKitManager.normalizeCalories(actual: 1000, goal: 500)
        #expect(result == 100.0)
    }

    @Test func normalizeCaloriesZero() {
        let result = HealthKitManager.normalizeCalories(actual: 0, goal: 500)
        #expect(result == 0.0)
    }

    // MARK: - normalizeSleepDuration tests (disabled: function removed from source)

    // @Test func normalizeSleepDurationAtGoal() {
    //     let result = HealthKitManager.normalizeSleepDuration(actual: 8.0, goal: 8.0)
    //     #expect(result == 100.0)
    // }

    // @Test func normalizeSleepDurationHalfGoal() {
    //     let result = HealthKitManager.normalizeSleepDuration(actual: 4.0, goal: 8.0)
    //     #expect(result == 50.0)
    // }

    // @Test func normalizeSleepDurationOverGoalClampsTo100() {
    //     let result = HealthKitManager.normalizeSleepDuration(actual: 12.0, goal: 8.0)
    //     #expect(result == 100.0)
    // }

    // MARK: - normalizeRestingHR tests

    @Test func normalizeRestingHRAtBaseline() {
        // actual == baseline → 100
        let result = HealthKitManager.normalizeRestingHR(actual: 70, baseline: 70)
        #expect(result == 100.0)
    }

    @Test func normalizeRestingHRBelowBaselineClampsTo100() {
        // actual < baseline → score > 100, clamped to 100
        let result = HealthKitManager.normalizeRestingHR(actual: 60, baseline: 70)
        #expect(result == 100.0)
    }

    @Test func normalizeRestingHR20PercentAboveBaseline() {
        // percentageChange = (84 - 70) / 70 = 0.2
        // score = 100 - (0.2 * 100 * 2.5) = 100 - 50 = 50
        let result = HealthKitManager.normalizeRestingHR(actual: 84, baseline: 70)
        #expect(result == 50.0)
    }

    @Test func normalizeRestingHR40PercentAboveBaselineClampsToZero() {
        // percentageChange = (98 - 70) / 70 = 0.4
        // score = 100 - (0.4 * 100 * 2.5) = 100 - 100 = 0
        let result = HealthKitManager.normalizeRestingHR(actual: 98, baseline: 70)
        #expect(result == 0.0)
    }

    @Test func normalizeRestingHRFarAboveBaselineClampsToZero() {
        let result = HealthKitManager.normalizeRestingHR(actual: 120, baseline: 70)
        #expect(result == 0.0)
    }

    @Test func normalizeRestingHRZeroBaselineReturnsZero() {
        let result = HealthKitManager.normalizeRestingHR(actual: 70, baseline: 0)
        #expect(result == 0.0)
    }

    // MARK: - normalizeHRV tests (disabled: signature changed to normalizeHRV(actual:baseline:))

    // @Test func normalizeHRVAt20msReturnsZero() {
    //     let result = HealthKitManager.normalizeHRV(milliseconds: 20)
    //     #expect(result == 0.0)
    // }

    // @Test func normalizeHRVAt100msReturns100() {
    //     let result = HealthKitManager.normalizeHRV(milliseconds: 100)
    //     #expect(result == 100.0)
    // }

    // @Test func normalizeHRVAt60msMidpoint() {
    //     let result = HealthKitManager.normalizeHRV(milliseconds: 60)
    //     #expect(result == 50.0)
    // }

    // @Test func normalizeHRVBelow20msClampsToZero() {
    //     let result = HealthKitManager.normalizeHRV(milliseconds: 5)
    //     #expect(result == 0.0)
    // }

    // @Test func normalizeHRVAbove100msClampsTo100() {
    //     let result = HealthKitManager.normalizeHRV(milliseconds: 150)
    //     #expect(result == 100.0)
    // }

    // MARK: - SleepQualityScoring

    @Test func sleepQualityScoringShortNightIsCapped() {
        let r = SleepQualityScoring.compute(
            totalSleepHours: 2.5,
            deepSleepHours: 0.5,
            remSleepHours: 0.4,
            sleepGoalHours: 8.0,
            sessionWallDuration: 2.5 * 3600,
            awakeSecondsDuringSession: nil as TimeInterval?,
            sleepConfidence: 1.0
        )
        #expect(r.displayScore <= 45)
    }

    @Test func sleepQualityScoringLongNightWithNeutralContinuityIsHigh() {
        let r = SleepQualityScoring.compute(
            totalSleepHours: 8.0,
            deepSleepHours: 1.4,
            remSleepHours: 1.8,
            sleepGoalHours: 8.0,
            sessionWallDuration: 8.0 * 3600,
            awakeSecondsDuringSession: nil as TimeInterval?,
            sleepConfidence: 1.0
        )
        #expect(r.displayScore >= 85)
    }

    @Test func sleepQualityScoringPhasesDoNotRescueShortDuration() {
        let r = SleepQualityScoring.compute(
            totalSleepHours: 4.0,
            deepSleepHours: 0.8,
            remSleepHours: 1.2,
            sleepGoalHours: 8.0,
            sessionWallDuration: 4.0 * 3600,
            awakeSecondsDuringSession: 0.0,
            sleepConfidence: 1.0
        )
        #expect(r.displayScore < 70)
    }

    @Test func sleepQualityScoringZeroGoalYieldsZero() {
        let r = SleepQualityScoring.compute(
            totalSleepHours: 7.0,
            deepSleepHours: 1.0,
            remSleepHours: 1.0,
            sleepGoalHours: 0,
            sessionWallDuration: 7.0 * 3600,
            awakeSecondsDuringSession: nil as TimeInterval?,
            sleepConfidence: 0.8
        )
        #expect(r.displayScore == 0)
    }

    @Test func sleepQualityScoringConfidenceIsSoftTweak() {
        let low = SleepQualityScoring.compute(
            totalSleepHours: 7.0,
            deepSleepHours: 0.8,
            remSleepHours: 1.0,
            sleepGoalHours: 8.0,
            sessionWallDuration: 7.0 * 3600,
            awakeSecondsDuringSession: 300,
            sleepConfidence: 0.2
        )
        let high = SleepQualityScoring.compute(
            totalSleepHours: 7.0,
            deepSleepHours: 0.8,
            remSleepHours: 1.0,
            sleepGoalHours: 8.0,
            sessionWallDuration: 7.0 * 3600,
            awakeSecondsDuringSession: 300,
            sleepConfidence: 1.0
        )
        #expect(abs(high.displayScore - low.displayScore) <= 20)
    }

    // MARK: - calculateRecoveryScore (new signature) tests

    @Test func recoveryScoreWithHRV() {
        // sleep=80, hr=60, hrv=90
        // 80*0.45 + 60*0.25 + 90*0.30 = 36 + 15 + 27 = 78
        let score = HealthKitManager.calculateRecoveryScore(
            sleepQualityScore: 80, restingHRScore: 60, hrvScore: 90
        )
        #expect(score == 78)
    }

    @Test func recoveryScoreWithoutHRV() {
        // sleep=80, hr=60, hrv=nil → fallback 0.60/0.40
        // 80*0.60 + 60*0.40 = 48 + 24 = 72
        let score = HealthKitManager.calculateRecoveryScore(
            sleepQualityScore: 80, restingHRScore: 60, hrvScore: nil
        )
        #expect(score == 72)
    }

    @Test func recoveryScorePerfect() {
        let score = HealthKitManager.calculateRecoveryScore(
            sleepQualityScore: 100, restingHRScore: 100, hrvScore: 100
        )
        #expect(score == 100)
    }

    @Test func recoveryScoreAllZero() {
        let score = HealthKitManager.calculateRecoveryScore(
            sleepQualityScore: 0, restingHRScore: 0, hrvScore: 0
        )
        #expect(score == 0)
    }

    @Test func recoveryScoreAllZeroWithoutHRV() {
        let score = HealthKitManager.calculateRecoveryScore(
            sleepQualityScore: 0, restingHRScore: 0, hrvScore: nil
        )
        #expect(score == 0)
    }

    @Test func recoveryScorePerfectWithoutHRV() {
        let score = HealthKitManager.calculateRecoveryScore(
            sleepQualityScore: 100, restingHRScore: 100, hrvScore: nil
        )
        #expect(score == 100)
    }

    // MARK: - calculateActivityScore tests

    @Test func activityScorePerfect() {
        let score = HealthKitManager.calculateActivityScore(stepsScore: 100, caloriesScore: 100)
        #expect(score == 100)
    }

    @Test func activityScoreAllZero() {
        let score = HealthKitManager.calculateActivityScore(stepsScore: 0, caloriesScore: 0)
        #expect(score == 0)
    }

    @Test func activityScoreMidValues() {
        // 50*0.50 + 50*0.50 = 50
        let score = HealthKitManager.calculateActivityScore(stepsScore: 50, caloriesScore: 50)
        #expect(score == 50)
    }

    @Test func activityScoreAsymmetric() {
        // 80*0.50 + 40*0.50 = 40 + 20 = 60
        let score = HealthKitManager.calculateActivityScore(stepsScore: 80, caloriesScore: 40)
        #expect(score == 60)
    }

    @Test func activityScoreRoundsCorrectly() {
        // 75*0.50 + 76*0.50 = 37.5 + 38 = 75.5 → rounds to 76
        let score = HealthKitManager.calculateActivityScore(stepsScore: 75, caloriesScore: 76)
        #expect(score == 76)
    }

    // MARK: - redistributeWeights tests

    @Test func redistributeWeightsAllAvailable() {
        let weights = HealthKitManager.redistributeWeights(
            availableComponents: ["sleep", "hr", "hrv"],
            originalWeights: ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]
        )
        #expect(abs(weights["sleep"]! - 0.45) < 0.0001)
        #expect(abs(weights["hr"]! - 0.25) < 0.0001)
        #expect(abs(weights["hrv"]! - 0.30) < 0.0001)
    }

    @Test func redistributeWeightsWithoutHRV() {
        let weights = HealthKitManager.redistributeWeights(
            availableComponents: ["sleep", "hr"],
            originalWeights: ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]
        )
        // sleep: 0.45/0.70 ≈ 0.6429, hr: 0.25/0.70 ≈ 0.3571
        let sum = weights.values.reduce(0, +)
        #expect(abs(sum - 1.0) < 0.0001)
        #expect(weights["hrv"] == nil)
    }

    @Test func redistributeWeightsEmptyReturnsEmpty() {
        let weights = HealthKitManager.redistributeWeights(
            availableComponents: [],
            originalWeights: ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]
        )
        #expect(weights.isEmpty)
    }

    @Test func redistributeWeightsSingleComponent() {
        let weights = HealthKitManager.redistributeWeights(
            availableComponents: ["sleep"],
            originalWeights: ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]
        )
        #expect(abs(weights["sleep"]! - 1.0) < 0.0001)
    }

    // MARK: - buildRecoveryBreakdown tests

    @Test func recoveryBreakdownComponentCount() {
        let breakdown = HealthKitManager.buildRecoveryBreakdown(
            sleepQualityScore: 80, sleepRawHours: 7.0, sleepGoal: 8.0,
            restingHRScore: 90, restingHRRaw: 62, baseline: 70,
            hrvScore: 70, hrvRawMs: 76,
            finalScore: 80,
            weights: ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]
        )
        #expect(breakdown.components.count == 3)
        #expect(breakdown.finalScore == 80)
    }

    @Test func recoveryBreakdownWithoutHRV() {
        let breakdown = HealthKitManager.buildRecoveryBreakdown(
            sleepQualityScore: 80, sleepRawHours: 7.0, sleepGoal: 8.0,
            restingHRScore: 90, restingHRRaw: 62, baseline: 70,
            hrvScore: nil, hrvRawMs: nil,
            finalScore: 76,
            weights: ["sleep": 0.60, "hr": 0.40]
        )
        #expect(breakdown.components.count == 2)
    }

    @Test func recoveryBreakdownComponentStatuses() {
        let breakdown = HealthKitManager.buildRecoveryBreakdown(
            sleepQualityScore: 30, sleepRawHours: 3.0, sleepGoal: 8.0,
            restingHRScore: 80, restingHRRaw: 65, baseline: 70,
            hrvScore: 50, hrvRawMs: 60,
            finalScore: 47,
            weights: ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]
        )
        // sleep score 30 → warning, hr score 80 → good, hrv score 50 → normal
        #expect(breakdown.components[0].status == .warning)
        #expect(breakdown.components[1].status == .good)
        #expect(breakdown.components[2].status == .normal)
    }

    // MARK: - buildActivityBreakdown tests

    @Test func activityBreakdownComponentCount() {
        let breakdown = HealthKitManager.buildActivityBreakdown(
            stepsScore: 80, stepsRaw: 8000, stepsGoal: 10000,
            caloriesScore: 60, caloriesRaw: 300, caloriesGoal: 500,
            finalScore: 70
        )
        #expect(breakdown.components.count == 2)
        #expect(breakdown.finalScore == 70)
    }

    @Test func activityBreakdownStatuses() {
        let breakdown = HealthKitManager.buildActivityBreakdown(
            stepsScore: 30, stepsRaw: 3000, stepsGoal: 10000,
            caloriesScore: 90, caloriesRaw: 450, caloriesGoal: 500,
            finalScore: 60
        )
        #expect(breakdown.components[0].status == .warning)  // steps 30 < 40
        #expect(breakdown.components[1].status == .good)     // calories 90 >= 70
    }

    // MARK: - Legacy normalize function tests (disabled: function removed from source)

    // @Test func normalizeMiddleValue() {
    //     let result = HealthKitManager.normalize(value: 75.0, min: 50.0, max: 100.0)
    //     #expect(result == 50.0)
    // }

    // @Test func normalizeAtMin() {
    //     let result = HealthKitManager.normalize(value: 0.0, min: 0.0, max: 100.0)
    //     #expect(result == 0.0)
    // }

    // @Test func normalizeAtMax() {
    //     let result = HealthKitManager.normalize(value: 100.0, min: 0.0, max: 100.0)
    //     #expect(result == 100.0)
    // }

    // @Test func normalizeBelowMinClampsToZero() {
    //     let result = HealthKitManager.normalize(value: -10.0, min: 0.0, max: 100.0)
    //     #expect(result == 0.0)
    // }

    // @Test func normalizeAboveMaxClampsTo100() {
    //     let result = HealthKitManager.normalize(value: 200.0, min: 0.0, max: 100.0)
    //     #expect(result == 100.0)
    // }

    // @Test func normalizeEqualMinMax() {
    //     let result = HealthKitManager.normalize(value: 50.0, min: 50.0, max: 50.0)
    //     #expect(result == 0.0)
    // }

    // MARK: - Edge cases: boundary values

    @Test func normalizeStepsNegativeActualClampsToZero() {
        let result = HealthKitManager.normalizeSteps(actual: -100, goal: 10000)
        #expect(result == 0.0)
    }

    @Test func normalizeCaloriesNegativeGoalReturnsZero() {
        let result = HealthKitManager.normalizeCalories(actual: 300, goal: -500)
        #expect(result == 0.0)
    }

    // @Test func normalizeHRVExactly20ms() {
    //     #expect(HealthKitManager.normalizeHRV(milliseconds: 20) == 0.0)
    // }

    // @Test func normalizeHRVExactly100ms() {
    //     #expect(HealthKitManager.normalizeHRV(milliseconds: 100) == 100.0)
    // }

    @Test func recoveryScoreRoundsHalfUp() {
        // 50*0.45 + 50*0.25 + 50*0.30 = 22.5 + 12.5 + 15 = 50
        let score = HealthKitManager.calculateRecoveryScore(
            sleepQualityScore: 50, restingHRScore: 50, hrvScore: 50
        )
        #expect(score == 50)
    }
}
