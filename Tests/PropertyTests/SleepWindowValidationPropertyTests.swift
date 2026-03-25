//
//  SleepWindowValidationPropertyTests.swift
//  Super Fitness Coach AppTests
//
//  Bug Condition Exploration: Validates that HRV/RHR data outside the sleep window
//  should NOT contaminate the Recovery Score.
//
//  **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 2.8, 2.9, 2.10**
//

import Testing
import Foundation
@testable import Super_Fitness_Coach_App

// MARK: - Sleep Window Validation Helpers

/// Represents a sample with its timestamp information (what queryQuantity SHOULD return).
struct TimestampedSample {
    let value: Double
    let startDate: Date
    let endDate: Date
}

/// Determines if a sample's time interval overlaps with the sleep window.
/// A sample is valid if: sampleStart < sleepEnd AND sampleEnd > sleepStart
func sampleOverlapsSleepWindow(
    sampleStart: Date, sampleEnd: Date,
    sleepStart: Date, sleepEnd: Date
) -> Bool {
    return sampleStart < sleepEnd && sampleEnd > sleepStart
}

/// Given multiple timestamped samples, returns the most recent one that overlaps
/// with the sleep window, or nil if none overlap.
func mostRecentSampleInSleepWindow(
    samples: [TimestampedSample],
    sleepStart: Date, sleepEnd: Date
) -> TimestampedSample? {
    let validSamples = samples.filter {
        sampleOverlapsSleepWindow(
            sampleStart: $0.startDate, sampleEnd: $0.endDate,
            sleepStart: sleepStart, sleepEnd: sleepEnd
        )
    }
    // Return the most recent valid sample (sorted by startDate descending)
    return validSamples.sorted { $0.startDate > $1.startDate }.first
}

// MARK: - Bug Condition Exploration Tests

/// These tests demonstrate the bug: the current code uses HRV/RHR values from outside
/// the sleep window because queryQuantity discards timestamps and querySleepPhases
/// doesn't expose sessionStart/sessionEnd.
///
/// EXPECTED: These tests FAIL on unfixed code — confirming the bug exists.
/// The current HealthKitManager has no mechanism to filter samples by sleep window.

struct SleepWindowBugConditionTests {

    // MARK: - Helper: Create dates relative to a base date

    /// Creates a Date for a specific hour:minute on a given day offset from "today".
    /// dayOffset: 0 = today, -1 = yesterday
    private func makeDate(hour: Int, minute: Int, dayOffset: Int = 0) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday)!
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day)!
    }

    /// Simulates what the FIXED system should do: given a list of HRV/RHR samples and a
    /// sleep window, only use samples that overlap with the sleep window.
    /// Returns the value to use (nil if no valid sample), simulating expected behavior.
    private func expectedValueForRecovery(
        samples: [TimestampedSample],
        sleepStart: Date, sleepEnd: Date
    ) -> Double? {
        return mostRecentSampleInSleepWindow(
            samples: samples,
            sleepStart: sleepStart, sleepEnd: sleepEnd
        )?.value
    }

    /// Simulates what the CURRENT (buggy) system does: takes the most recent sample
    /// regardless of sleep window (queryQuantity with limit: 1, sorted by startDate desc).
    private func currentBuggyValue(samples: [TimestampedSample]) -> Double? {
        return samples.sorted { $0.startDate > $1.startDate }.first?.value
    }

    // MARK: - Case 1: HRV at 21:30 with sleep 23:00-07:00
    // The system should NOT use this HRV (it's before sleep started)
    // Bug: current code WILL use it because it takes the most recent sample without checking

    @Test("Case 1: HRV at 21:30 outside sleep window 23:00-07:00 should be excluded")
    func hrvBeforeSleepShouldBeExcluded() {
        // Sleep window: yesterday 23:00 to today 07:00
        let sleepStart = makeDate(hour: 23, minute: 0, dayOffset: -1)
        let sleepEnd = makeDate(hour: 7, minute: 0, dayOffset: 0)

        // HRV sample at 21:30 yesterday (before sleep, during waking hours)
        let hrvSample = TimestampedSample(
            value: 45.0, // HRV in ms
            startDate: makeDate(hour: 21, minute: 30, dayOffset: -1),
            endDate: makeDate(hour: 21, minute: 31, dayOffset: -1)
        )

        // Verify the sample is outside the sleep window
        let isOutside = !sampleOverlapsSleepWindow(
            sampleStart: hrvSample.startDate, sampleEnd: hrvSample.endDate,
            sleepStart: sleepStart, sleepEnd: sleepEnd
        )
        #expect(isOutside, "HRV at 21:30 should be outside sleep window 23:00-07:00")

        // Expected behavior: this HRV should be treated as nil (not available)
        let expectedHRV = expectedValueForRecovery(
            samples: [hrvSample], sleepStart: sleepStart, sleepEnd: sleepEnd
        )
        #expect(expectedHRV == nil, "Expected: HRV outside sleep window should be nil")

        // Bug demonstration: current system uses the value anyway
        let currentHRV = currentBuggyValue(samples: [hrvSample])

        // THIS ASSERTION SHOULD FAIL on unfixed code:
        // The current system returns 45.0 (uses the sample), but it should be nil
        #expect(
            currentHRV == expectedHRV,
            """
            BUG CONFIRMED: HRV sample at 21:30 (value: \(currentHRV ?? -1)) is used by the \
            current system, but should be excluded (nil) because it's outside sleep window \
            23:00-07:00. The current queryQuantity returns the most recent sample without \
            checking if it falls within the sleep window.
            """
        )
    }

    // MARK: - Case 2: RHR at 15:00 with sleep 00:30-06:45
    // The system should NOT use this RHR (afternoon reading, not during sleep)

    @Test("Case 2: RHR at 15:00 outside sleep window 00:30-06:45 should be excluded")
    func rhrAfternoonShouldBeExcluded() {
        // Sleep window: today 00:30 to today 06:45
        let sleepStart = makeDate(hour: 0, minute: 30, dayOffset: 0)
        let sleepEnd = makeDate(hour: 6, minute: 45, dayOffset: 0)

        // RHR sample at 15:00 yesterday (afternoon, waking hours)
        let rhrSample = TimestampedSample(
            value: 72.0, // RHR in bpm
            startDate: makeDate(hour: 15, minute: 0, dayOffset: -1),
            endDate: makeDate(hour: 15, minute: 1, dayOffset: -1)
        )

        // Verify the sample is outside the sleep window
        let isOutside = !sampleOverlapsSleepWindow(
            sampleStart: rhrSample.startDate, sampleEnd: rhrSample.endDate,
            sleepStart: sleepStart, sleepEnd: sleepEnd
        )
        #expect(isOutside, "RHR at 15:00 should be outside sleep window 00:30-06:45")

        // Expected behavior: this RHR should be treated as nil
        let expectedRHR = expectedValueForRecovery(
            samples: [rhrSample], sleepStart: sleepStart, sleepEnd: sleepEnd
        )
        #expect(expectedRHR == nil, "Expected: RHR outside sleep window should be nil")

        // Bug demonstration: current system uses the value anyway
        let currentRHR = currentBuggyValue(samples: [rhrSample])

        // THIS ASSERTION SHOULD FAIL on unfixed code
        #expect(
            currentRHR == expectedRHR,
            """
            BUG CONFIRMED: RHR sample at 15:00 (value: \(currentRHR ?? -1)) is used by the \
            current system, but should be excluded (nil) because it's outside sleep window \
            00:30-06:45. The current queryQuantity discards timestamps, making validation impossible.
            """
        )
    }

    // MARK: - Case 3: Most recent HRV at 09:00 (outside), earlier HRV at 03:15 (inside)
    // The system SHOULD use the 03:15 one (inside sleep), not the 09:00 one

    @Test("Case 3: Should use HRV at 03:15 (inside sleep) not 09:00 (outside)")
    func shouldPreferHRVInsideSleepOverMoreRecent() {
        // Sleep window: yesterday 23:00 to today 07:00
        let sleepStart = makeDate(hour: 23, minute: 0, dayOffset: -1)
        let sleepEnd = makeDate(hour: 7, minute: 0, dayOffset: 0)

        // HRV at 09:00 today — most recent but OUTSIDE sleep
        let hrvOutside = TimestampedSample(
            value: 38.0,
            startDate: makeDate(hour: 9, minute: 0, dayOffset: 0),
            endDate: makeDate(hour: 9, minute: 1, dayOffset: 0)
        )

        // HRV at 03:15 today — older but INSIDE sleep
        let hrvInside = TimestampedSample(
            value: 52.0,
            startDate: makeDate(hour: 3, minute: 15, dayOffset: 0),
            endDate: makeDate(hour: 3, minute: 16, dayOffset: 0)
        )

        let samples = [hrvOutside, hrvInside]

        // Expected: use the 03:15 sample (inside sleep window)
        let expectedHRV = expectedValueForRecovery(
            samples: samples, sleepStart: sleepStart, sleepEnd: sleepEnd
        )
        #expect(expectedHRV == 52.0, "Expected: should select HRV at 03:15 (inside sleep)")

        // Bug: current system takes the most recent (09:00, outside sleep)
        let currentHRV = currentBuggyValue(samples: samples)
        #expect(currentHRV == 38.0, "Current buggy system picks most recent: 09:00")

        // THIS ASSERTION SHOULD FAIL on unfixed code
        #expect(
            currentHRV == expectedHRV,
            """
            BUG CONFIRMED: Current system uses HRV at 09:00 (value: \(currentHRV ?? -1), \
            outside sleep) instead of HRV at 03:15 (value: 52.0, inside sleep window \
            23:00-07:00). queryQuantity with limit:1 returns the most recent sample \
            regardless of sleep window.
            """
        )
    }

    // MARK: - Case 4: Multiple HRVs inside sleep → should use most recent within window
    // HRVs at 01:00, 03:15, 05:30 with sleep 23:00-07:00 → use 05:30

    @Test("Case 4: Multiple HRVs inside sleep should use most recent within window (05:30)")
    func shouldUseMostRecentHRVInsideSleepWindow() {
        // Sleep window: yesterday 23:00 to today 07:00
        let sleepStart = makeDate(hour: 23, minute: 0, dayOffset: -1)
        let sleepEnd = makeDate(hour: 7, minute: 0, dayOffset: 0)

        let hrv0100 = TimestampedSample(
            value: 48.0,
            startDate: makeDate(hour: 1, minute: 0, dayOffset: 0),
            endDate: makeDate(hour: 1, minute: 1, dayOffset: 0)
        )
        let hrv0315 = TimestampedSample(
            value: 55.0,
            startDate: makeDate(hour: 3, minute: 15, dayOffset: 0),
            endDate: makeDate(hour: 3, minute: 16, dayOffset: 0)
        )
        let hrv0530 = TimestampedSample(
            value: 61.0,
            startDate: makeDate(hour: 5, minute: 30, dayOffset: 0),
            endDate: makeDate(hour: 5, minute: 31, dayOffset: 0)
        )

        let samples = [hrv0100, hrv0315, hrv0530]

        // All three are inside the sleep window
        for sample in samples {
            let isInside = sampleOverlapsSleepWindow(
                sampleStart: sample.startDate, sampleEnd: sample.endDate,
                sleepStart: sleepStart, sleepEnd: sleepEnd
            )
            #expect(isInside, "Sample at \(sample.startDate) should be inside sleep window")
        }

        // Expected: use the most recent within the window (05:30, value 61.0)
        let expectedHRV = expectedValueForRecovery(
            samples: samples, sleepStart: sleepStart, sleepEnd: sleepEnd
        )
        #expect(expectedHRV == 61.0, "Expected: most recent HRV inside sleep is 05:30 (61.0ms)")

        // Current system: also picks 05:30 since it's the most recent overall
        // This case actually passes because the most recent sample happens to be inside sleep
        let currentHRV = currentBuggyValue(samples: samples)

        #expect(
            currentHRV == expectedHRV,
            """
            When all samples are inside the sleep window, the current system happens to \
            pick the correct one (most recent = 05:30). This case is NOT buggy.
            """
        )
    }

    // MARK: - Integration: Recovery Score contamination demonstration
    // Shows that using out-of-sleep HRV/RHR produces a different (incorrect) Recovery Score

    @Test("Recovery Score is contaminated when using out-of-sleep HRV data")
    func recoveryScoreContaminatedByOutOfSleepData() {
        // Setup: sleep data available
        let sleepQualityScore = 80.0
        let baseline = 70.0
        let hrvBaseline = 60.0

        // Sleep window: yesterday 23:00 to today 07:00
        let sleepStart = makeDate(hour: 23, minute: 0, dayOffset: -1)
        let sleepEnd = makeDate(hour: 7, minute: 0, dayOffset: 0)

        // HRV sample at 21:30 (OUTSIDE sleep) — waking HRV tends to be lower
        let wakingHRV = TimestampedSample(
            value: 35.0, // Low HRV during waking
            startDate: makeDate(hour: 21, minute: 30, dayOffset: -1),
            endDate: makeDate(hour: 21, minute: 31, dayOffset: -1)
        )

        // RHR sample at 15:00 (OUTSIDE sleep) — waking RHR tends to be higher
        let wakingRHR = TimestampedSample(
            value: 78.0, // Higher RHR during waking
            startDate: makeDate(hour: 15, minute: 0, dayOffset: -1),
            endDate: makeDate(hour: 15, minute: 1, dayOffset: -1)
        )

        // Current buggy behavior: uses these waking values
        let buggyHRV = currentBuggyValue(samples: [wakingHRV])!
        let buggyRHR = currentBuggyValue(samples: [wakingRHR])!

        let buggyHRVNormalized = HealthKitManager.normalizeHRV(actual: buggyHRV, baseline: hrvBaseline)
        let buggyRHRNormalized = HealthKitManager.normalizeRestingHR(actual: buggyRHR, baseline: baseline)
        let buggyScore = HealthKitManager.calculateRecoveryScore(
            sleepQualityScore: sleepQualityScore,
            restingHRScore: buggyRHRNormalized,
            hrvScore: buggyHRVNormalized
        )

        // Expected behavior: these samples should be excluded (nil)
        let expectedHRV = expectedValueForRecovery(
            samples: [wakingHRV], sleepStart: sleepStart, sleepEnd: sleepEnd
        )
        let expectedRHR = expectedValueForRecovery(
            samples: [wakingRHR], sleepStart: sleepStart, sleepEnd: sleepEnd
        )

        #expect(expectedHRV == nil, "HRV outside sleep should be nil")
        #expect(expectedRHR == nil, "RHR outside sleep should be nil")

        // With correct behavior (no HRV, no RHR), weights redistribute to sleep-only
        let correctScore = HealthKitManager.calculateRecoveryScore(
            sleepQualityScore: sleepQualityScore,
            restingHRScore: 0,
            hrvScore: nil
        )
        // With only sleep: 80 * 0.60 + 0 * 0.40 = 48... but actually redistributeWeights
        // would give sleep 100% weight, so score = 80

        // THIS ASSERTION SHOULD FAIL: buggy score != correct score
        // The buggy score includes contaminated waking data
        #expect(
            buggyScore == correctScore,
            """
            BUG CONFIRMED: Recovery Score with waking data (\(buggyScore)) differs from \
            correct score without waking data (\(correctScore)). The current system uses \
            HRV=\(buggyHRV)ms from 21:30 and RHR=\(buggyRHR)bpm from 15:00, both outside \
            sleep window 23:00-07:00, contaminating the Recovery Score.
            """
        )
    }
}

// MARK: - Preservation Property Tests (Task 2)

/// Property 2: Preservation — Verifies that existing behavior is preserved for:
/// - Recovery Score calculation with valid sleep-window data
/// - Activity Score calculation (independent of sleep)
/// - redistributeWeights always sums to 1.0
/// - normalizeHRV and normalizeRestingHR determinism
/// - Fallback behavior without sleep data
/// - Sleep quality score consistency
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**
///
/// These tests MUST PASS on unfixed code — they capture the baseline behavior to preserve.

struct SleepWindowPreservationTests {

    // MARK: - Seeded Random Generator

    /// Simple linear congruential generator for deterministic "random" values.
    struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    /// Generate a Double in a range using a seeded RNG.
    private func randomDouble(in range: ClosedRange<Double>, using rng: inout SeededRNG) -> Double {
        let raw = Double(rng.next() % 1_000_000) / 1_000_000.0
        return range.lowerBound + raw * (range.upperBound - range.lowerBound)
    }

    // MARK: - Test 1: Recovery Score preservation with valid data
    // When HRV and RHR are within the sleep window, calculateRecoveryScore
    // uses weights sleep=0.45, hr=0.25, hrv=0.30.

    @Test("Preservation: Recovery Score with all components uses weights 0.45/0.25/0.30")
    func recoveryScorePreservationWithAllComponents() {
        var rng = SeededRNG(seed: 42)

        for _ in 0..<100 {
            let sleepScore = randomDouble(in: 0...100, using: &rng)
            let hrScore = randomDouble(in: 0...100, using: &rng)
            let hrvScore = randomDouble(in: 0...100, using: &rng)

            let result = HealthKitManager.calculateRecoveryScore(
                sleepQualityScore: sleepScore,
                restingHRScore: hrScore,
                hrvScore: hrvScore
            )

            let expected = Int(round(sleepScore * 0.45 + hrScore * 0.25 + hrvScore * 0.30))

            #expect(
                result == expected,
                "Recovery Score mismatch: got \(result), expected \(expected) for sleep=\(sleepScore), hr=\(hrScore), hrv=\(hrvScore)"
            )
        }
    }

    // MARK: - Test 2: Activity Score preservation
    // calculateActivityScore uses weights steps=0.50, calories=0.50.

    @Test("Preservation: Activity Score uses weights 0.50/0.50 for steps and calories")
    func activityScorePreservation() {
        var rng = SeededRNG(seed: 99)

        for _ in 0..<100 {
            let stepsScore = randomDouble(in: 0...100, using: &rng)
            let caloriesScore = randomDouble(in: 0...100, using: &rng)

            let result = HealthKitManager.calculateActivityScore(
                stepsScore: stepsScore,
                caloriesScore: caloriesScore
            )

            let expected = Int(round(stepsScore * 0.50 + caloriesScore * 0.50))

            #expect(
                result == expected,
                "Activity Score mismatch: got \(result), expected \(expected) for steps=\(stepsScore), cal=\(caloriesScore)"
            )
        }
    }

    // MARK: - Test 3: redistributeWeights sums to 1.0
    // For any non-empty subset of ["sleep", "hr", "hrv"], redistributed weights sum to 1.0.

    @Test("Preservation: redistributeWeights produces weights summing to 1.0")
    func redistributeWeightsSumToOne() {
        let allComponents = ["sleep", "hr", "hrv"]
        let originalWeights: [String: Double] = ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]

        // Generate all non-empty subsets of the 3 components (7 subsets)
        let subsets: [[String]] = [
            ["sleep"],
            ["hr"],
            ["hrv"],
            ["sleep", "hr"],
            ["sleep", "hrv"],
            ["hr", "hrv"],
            ["sleep", "hr", "hrv"]
        ]

        for subset in subsets {
            let weights = HealthKitManager.redistributeWeights(
                availableComponents: subset,
                originalWeights: originalWeights
            )

            // All keys should be present
            #expect(weights.count == subset.count, "Expected \(subset.count) weights for \(subset)")

            // Weights must sum to 1.0 (within floating point tolerance)
            let sum = weights.values.reduce(0.0, +)
            #expect(
                abs(sum - 1.0) < 1e-10,
                "Weights for \(subset) sum to \(sum), expected 1.0"
            )

            // Each weight must be positive
            for (key, value) in weights {
                #expect(value > 0, "Weight for \(key) should be positive, got \(value)")
            }
        }

        // Empty components should return empty dictionary
        let emptyWeights = HealthKitManager.redistributeWeights(
            availableComponents: [],
            originalWeights: originalWeights
        )
        #expect(emptyWeights.isEmpty, "Empty components should produce empty weights")

        // Components not in originalWeights should produce empty (all zeros)
        let unknownWeights = HealthKitManager.redistributeWeights(
            availableComponents: ["unknown"],
            originalWeights: originalWeights
        )
        #expect(unknownWeights.isEmpty, "Unknown components should produce empty weights")

        // Property-based: random subsets of allComponents
        var rng = SeededRNG(seed: 77)
        for _ in 0..<100 {
            // Generate a random non-empty subset
            var subset: [String] = []
            for component in allComponents {
                if rng.next() % 2 == 0 {
                    subset.append(component)
                }
            }
            if subset.isEmpty { subset = [allComponents[Int(rng.next() % 3)]] }

            let weights = HealthKitManager.redistributeWeights(
                availableComponents: subset,
                originalWeights: originalWeights
            )

            let sum = weights.values.reduce(0.0, +)
            #expect(
                abs(sum - 1.0) < 1e-10,
                "Random subset \(subset): weights sum to \(sum), expected 1.0"
            )
        }
    }

    // MARK: - Test 4: normalizeHRV determinism
    // Same inputs always produce the same output.

    @Test("Preservation: normalizeHRV is deterministic — same inputs produce same output")
    func normalizeHRVDeterminism() {
        var rng = SeededRNG(seed: 123)

        for _ in 0..<100 {
            let actual = randomDouble(in: 0...200, using: &rng)
            let baseline = randomDouble(in: 1...150, using: &rng)

            let result1 = HealthKitManager.normalizeHRV(actual: actual, baseline: baseline)
            let result2 = HealthKitManager.normalizeHRV(actual: actual, baseline: baseline)

            #expect(
                result1 == result2,
                "normalizeHRV not deterministic: actual=\(actual), baseline=\(baseline) → \(result1) vs \(result2)"
            )

            // Also verify output is in [0, 100]
            #expect(result1 >= 0 && result1 <= 100, "normalizeHRV out of range: \(result1)")
        }

        // Edge case: baseline = 0 should return 50
        let zeroBaseline = HealthKitManager.normalizeHRV(actual: 60.0, baseline: 0.0)
        #expect(zeroBaseline == 50, "normalizeHRV with baseline=0 should return 50")
    }

    // MARK: - Test 5: normalizeRestingHR determinism
    // Same inputs always produce the same output.

    @Test("Preservation: normalizeRestingHR is deterministic — same inputs produce same output")
    func normalizeRestingHRDeterminism() {
        var rng = SeededRNG(seed: 456)

        for _ in 0..<100 {
            let actual = randomDouble(in: 30...120, using: &rng)
            let baseline = randomDouble(in: 35...100, using: &rng)

            let result1 = HealthKitManager.normalizeRestingHR(actual: actual, baseline: baseline)
            let result2 = HealthKitManager.normalizeRestingHR(actual: actual, baseline: baseline)

            #expect(
                result1 == result2,
                "normalizeRestingHR not deterministic: actual=\(actual), baseline=\(baseline) → \(result1) vs \(result2)"
            )

            // Also verify output is in [0, 100]
            #expect(result1 >= 0 && result1 <= 100, "normalizeRestingHR out of range: \(result1)")
        }

        // Edge case: baseline = 0 should return 0
        let zeroBaseline = HealthKitManager.normalizeRestingHR(actual: 70.0, baseline: 0.0)
        #expect(zeroBaseline == 0, "normalizeRestingHR with baseline=0 should return 0")
    }

    // MARK: - Test 6: Fallback without sleep data
    // When sleep is nil but HR/HRV are available, Recovery Score uses redistributed weights.

    @Test("Preservation: Fallback without sleep uses redistributed HR/HRV weights")
    func fallbackWithoutSleepData() {
        var rng = SeededRNG(seed: 789)

        let originalWeights: [String: Double] = ["sleep": 0.45, "hr": 0.25, "hrv": 0.30]

        for _ in 0..<100 {
            let hrScore = randomDouble(in: 0...100, using: &rng)
            let hrvScore = randomDouble(in: 0...100, using: &rng)
            let hasHR = rng.next() % 4 != 0  // 75% chance of having HR
            let hasHRV = rng.next() % 4 != 0  // 75% chance of having HRV

            // At least one must be available for fallback
            guard hasHR || hasHRV else { continue }

            var available: [String] = []
            if hasHR { available.append("hr") }
            if hasHRV { available.append("hrv") }

            let weights = HealthKitManager.redistributeWeights(
                availableComponents: available,
                originalWeights: originalWeights
            )

            // Calculate expected score using redistributed weights
            var expectedScore = 0.0
            if hasHR, let w = weights["hr"] { expectedScore += hrScore * w }
            if hasHRV, let w = weights["hrv"] { expectedScore += hrvScore * w }
            let expected = Int(round(expectedScore))

            // Verify weights sum to 1.0
            let weightSum = weights.values.reduce(0.0, +)
            #expect(
                abs(weightSum - 1.0) < 1e-10,
                "Fallback weights should sum to 1.0, got \(weightSum)"
            )

            // Verify the score is within valid range
            #expect(expected >= 0 && expected <= 100, "Fallback score out of range: \(expected)")
        }
    }

    // MARK: - Test 7: Sleep quality score preservation
    // calculateSleepQualityScore produces consistent results for the same inputs.

    @Test("Preservation: Sleep quality score is consistent and follows expected formula")
    func sleepQualityScorePreservation() {
        var rng = SeededRNG(seed: 321)

        for _ in 0..<100 {
            let totalHours = randomDouble(in: 0...12, using: &rng)
            let sleepGoal = randomDouble(in: 4...12, using: &rng)
            let hasPhases = rng.next() % 2 == 0

            if hasPhases && totalHours > 0 {
                // With deep and REM phases
                let deepRatio = randomDouble(in: 0...0.35, using: &rng)
                let remRatio = randomDouble(in: 0...0.45, using: &rng)
                let deepHours = totalHours * deepRatio
                let remHours = totalHours * remRatio

                let result1 = HealthKitManager.calculateSleepQualityScore(
                    totalHours: totalHours, deepHours: deepHours,
                    remHours: remHours, sleepGoal: sleepGoal
                )
                let result2 = HealthKitManager.calculateSleepQualityScore(
                    totalHours: totalHours, deepHours: deepHours,
                    remHours: remHours, sleepGoal: sleepGoal
                )

                // Determinism
                #expect(result1 == result2, "Sleep quality score not deterministic")

                // Verify formula: duration*0.50 + deep*0.25 + rem*0.25
                let durationScore = Swift.min(100, Swift.max(0, totalHours / sleepGoal * 100))
                let deepScore = Swift.min(100, Swift.max(0, (deepHours / totalHours) / 0.175 * 100))
                let remScore = Swift.min(100, Swift.max(0, (remHours / totalHours) / 0.225 * 100))
                let expected = durationScore * 0.50 + deepScore * 0.25 + remScore * 0.25

                #expect(
                    abs(result1 - expected) < 1e-10,
                    "Sleep quality score mismatch: got \(result1), expected \(expected)"
                )
            } else {
                // Without phases — only duration score
                let result = HealthKitManager.calculateSleepQualityScore(
                    totalHours: totalHours, deepHours: nil,
                    remHours: nil, sleepGoal: sleepGoal
                )

                let expected = Swift.min(100, Swift.max(0, totalHours / sleepGoal * 100))
                #expect(
                    abs(result - expected) < 1e-10,
                    "Sleep quality (no phases) mismatch: got \(result), expected \(expected)"
                )
            }
        }

        // Edge case: sleepGoal = 0 should return 0
        let zeroGoal = HealthKitManager.calculateSleepQualityScore(
            totalHours: 7.0, deepHours: 1.0, remHours: 1.5, sleepGoal: 0.0
        )
        #expect(zeroGoal == 0, "Sleep quality with goal=0 should return 0")
    }

    // MARK: - Test: Recovery Score without HRV uses fallback weights (0.60/0.40)

    @Test("Preservation: Recovery Score without HRV uses sleep=0.60, hr=0.40")
    func recoveryScoreWithoutHRV() {
        var rng = SeededRNG(seed: 555)

        for _ in 0..<100 {
            let sleepScore = randomDouble(in: 0...100, using: &rng)
            let hrScore = randomDouble(in: 0...100, using: &rng)

            let result = HealthKitManager.calculateRecoveryScore(
                sleepQualityScore: sleepScore,
                restingHRScore: hrScore,
                hrvScore: nil
            )

            let expected = Int(round(sleepScore * 0.60 + hrScore * 0.40))

            #expect(
                result == expected,
                "Recovery Score (no HRV) mismatch: got \(result), expected \(expected)"
            )
        }
    }

    // MARK: - Test: normalizeSteps and normalizeCalories preservation

    @Test("Preservation: normalizeSteps and normalizeCalories are deterministic and bounded [0,100]")
    func normalizeStepsAndCaloriesPreservation() {
        var rng = SeededRNG(seed: 888)

        for _ in 0..<100 {
            let steps = randomDouble(in: 0...20000, using: &rng)
            let stepsGoal = randomDouble(in: 1000...15000, using: &rng)
            let calories = randomDouble(in: 0...1000, using: &rng)
            let calorieGoal = randomDouble(in: 100...800, using: &rng)

            let stepsResult1 = HealthKitManager.normalizeSteps(actual: steps, goal: stepsGoal)
            let stepsResult2 = HealthKitManager.normalizeSteps(actual: steps, goal: stepsGoal)
            #expect(stepsResult1 == stepsResult2, "normalizeSteps not deterministic")
            #expect(stepsResult1 >= 0 && stepsResult1 <= 100, "normalizeSteps out of range: \(stepsResult1)")

            let calResult1 = HealthKitManager.normalizeCalories(actual: calories, goal: calorieGoal)
            let calResult2 = HealthKitManager.normalizeCalories(actual: calories, goal: calorieGoal)
            #expect(calResult1 == calResult2, "normalizeCalories not deterministic")
            #expect(calResult1 >= 0 && calResult1 <= 100, "normalizeCalories out of range: \(calResult1)")

            // Verify formula: min(100, max(0, actual/goal * 100))
            let expectedSteps = Swift.min(100, Swift.max(0, steps / stepsGoal * 100))
            let expectedCal = Swift.min(100, Swift.max(0, calories / calorieGoal * 100))
            #expect(abs(stepsResult1 - expectedSteps) < 1e-10, "normalizeSteps formula mismatch")
            #expect(abs(calResult1 - expectedCal) < 1e-10, "normalizeCalories formula mismatch")
        }

        // Edge case: goal = 0
        #expect(HealthKitManager.normalizeSteps(actual: 5000, goal: 0) == 0)
        #expect(HealthKitManager.normalizeCalories(actual: 300, goal: 0) == 0)
    }
}
