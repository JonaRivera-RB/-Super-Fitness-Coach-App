import Foundation
import HealthKit

struct SleepDetectionResult: Equatable {
    let sleepDetected: Bool
    let sessionStart: Date?
    let sessionEnd: Date?
    let totalSleepHours: Double?
    let deepSleepHours: Double?
    let remSleepHours: Double?
    let sleepConfidence: Double        // [0.0, 1.0]
    let sleepConsistencyScore: Int     // [0, 100]
    let rawSampleCount: Int
    let mergedSessionCount: Int
}

struct SleepSessionFilter {
    private struct Interval: Equatable {
        let start: Date
        let end: Date

        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    static func process(
        samples: [HKCategorySample],
        window: SleepWindowBuilder.ExpectedSleepWindow,
        goal: SleepGoal?,
        calendar: Calendar = .current
    ) -> SleepDetectionResult {
        let rawCount = samples.count

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]

        let asleepSamples = samples.filter { asleepValues.contains($0.value) }
        if asleepSamples.isEmpty {
            return noSleepResult(window: window, rawSampleCount: rawCount, mergedSessionCount: 0)
        }

        let sorted = asleepSamples.sorted { $0.startDate < $1.startDate }
        let intervals = sorted.map { Interval(start: $0.startDate, end: $0.endDate) }

        let merged = merge(intervals: intervals, adjacencyGapSeconds: 10 * 60)
        let mergedCount = merged.count

        // Overlap with adjusted window.
        let windowAdjusted = Interval(start: window.adjustedStart, end: window.adjustedEnd)
        var overlapping = merged.filter { overlaps($0, windowAdjusted) }

        // Nap exclusion and late-start allowance.
        overlapping = overlapping.filter { session in
            let sessionDuration = session.duration
            if sessionDuration < 90 * 60 { return false } // < 90 minutes

            let expected = Interval(start: window.expectedStart, end: window.expectedEnd)
            let overlap = overlapSeconds(session, expected)
            let overlapFraction = sessionDuration > 0 ? overlap / sessionDuration : 0

            if overlapFraction < 0.20 { return false }

            // Allow sessions that start after expectedStart if overlap is strong.
            if session.start > window.expectedStart && overlapFraction <= 0.50 { return false }

            return true
        }

        guard !overlapping.isEmpty else {
            return noSleepResult(window: window, rawSampleCount: rawCount, mergedSessionCount: mergedCount)
        }

        // Select the session with greatest asleep duration (core+deep+REM) within that session.
        let best = overlapping.max { a, b in
            asleepSeconds(in: a, samples: asleepSamples) < asleepSeconds(in: b, samples: asleepSamples)
        }!

        let expected = Interval(start: window.expectedStart, end: window.expectedEnd)
        let confidence = computeConfidence(session: best, expected: expected, isFallback: window.isFallback)

        let totalSeconds = stageSeconds(in: best, samples: asleepSamples, allowedValues: [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ])
        let deepSeconds = stageSeconds(in: best, samples: asleepSamples, allowedValues: [
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue
        ])
        let remSeconds = stageSeconds(in: best, samples: asleepSamples, allowedValues: [
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ])

        let totalHours = totalSeconds > 0 ? totalSeconds / 3600.0 : nil
        let deepHours = deepSeconds > 0 ? deepSeconds / 3600.0 : nil
        let remHours = remSeconds > 0 ? remSeconds / 3600.0 : nil

        let consistency = computeConsistencyScore(
            goal: goal,
            expectedStart: window.expectedStart,
            expectedEnd: window.expectedEnd,
            actualStart: best.start,
            actualEnd: best.end,
            calendar: calendar
        )

        return SleepDetectionResult(
            sleepDetected: true,
            sessionStart: best.start,
            sessionEnd: best.end,
            totalSleepHours: totalHours,
            deepSleepHours: deepHours,
            remSleepHours: remHours,
            sleepConfidence: confidence,
            sleepConsistencyScore: consistency,
            rawSampleCount: rawCount,
            mergedSessionCount: mergedCount
        )
    }

    // MARK: - Confidence & consistency

    private static func computeConfidence(session: Interval, expected: Interval, isFallback: Bool) -> Double {
        let overlap = overlapSeconds(session, expected)
        let frac = session.duration > 0 ? overlap / session.duration : 0
        let clamped = max(0.0, min(1.0, frac))
        let capped = isFallback ? min(0.8, clamped) : clamped
        // Full overlap -> 1.0
        if session.start >= expected.start && session.end <= expected.end {
            return isFallback ? 0.8 : 1.0
        }
        return capped
    }

    private static func computeConsistencyScore(
        goal: SleepGoal?,
        expectedStart: Date,
        expectedEnd: Date,
        actualStart: Date,
        actualEnd: Date,
        calendar: Calendar
    ) -> Int {
        guard goal != nil else { return 0 }

        let startDeviation = abs(minutesBetween(expectedStart, actualStart, calendar: calendar))
        let endDeviation = abs(minutesBetween(expectedEnd, actualEnd, calendar: calendar))
        let deviationMinutes = Double(startDeviation + endDeviation) / 2.0

        let score = 100.0 - min(100.0, deviationMinutes / 120.0 * 100.0)
        return Int(max(0, min(100, round(score))))
    }

    private static func minutesBetween(_ a: Date, _ b: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.minute], from: a, to: b)
        return comps.minute ?? Int((b.timeIntervalSince(a) / 60.0).rounded())
    }

    // MARK: - Helpers

    private static func noSleepResult(
        window: SleepWindowBuilder.ExpectedSleepWindow,
        rawSampleCount: Int,
        mergedSessionCount: Int
    ) -> SleepDetectionResult {
        SleepDetectionResult(
            sleepDetected: false,
            sessionStart: nil,
            sessionEnd: nil,
            totalSleepHours: nil,
            deepSleepHours: nil,
            remSleepHours: nil,
            sleepConfidence: 0.2,
            sleepConsistencyScore: 0,
            rawSampleCount: rawSampleCount,
            mergedSessionCount: mergedSessionCount
        )
    }

    private static func overlaps(_ a: Interval, _ b: Interval) -> Bool {
        a.start < b.end && a.end > b.start
    }

    private static func overlapSeconds(_ a: Interval, _ b: Interval) -> TimeInterval {
        let start = max(a.start, b.start)
        let end = min(a.end, b.end)
        return max(0, end.timeIntervalSince(start))
    }

    private static func merge(intervals: [Interval], adjacencyGapSeconds: TimeInterval) -> [Interval] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [Interval] = [sorted[0]]

        for interval in sorted.dropFirst() {
            let last = merged[merged.count - 1]
            let gap = interval.start.timeIntervalSince(last.end)
            if interval.start <= last.end || gap <= adjacencyGapSeconds {
                merged[merged.count - 1] = Interval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    private static func asleepSeconds(in session: Interval, samples: [HKCategorySample]) -> TimeInterval {
        stageSeconds(in: session, samples: samples, allowedValues: [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ])
    }

    private static func stageSeconds(
        in session: Interval,
        samples: [HKCategorySample],
        allowedValues: Set<Int>
    ) -> TimeInterval {
        let stageIntervals: [Interval] = samples
            .filter { allowedValues.contains($0.value) }
            .compactMap { sample in
                let clippedStart = max(sample.startDate, session.start)
                let clippedEnd = min(sample.endDate, session.end)
                guard clippedStart < clippedEnd else { return nil }
                return Interval(start: clippedStart, end: clippedEnd)
            }

        return merge(intervals: stageIntervals, adjacencyGapSeconds: 0).reduce(0.0) { $0 + $1.duration }
    }
}

