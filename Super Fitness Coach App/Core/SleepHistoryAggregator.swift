//  SleepHistoryAggregator.swift
//  Super Fitness Coach App
//
//  Rolling average of main sleep (merged asleep segments ≥ 90 min) per wake day, for trend UI.

import Foundation
import HealthKit

enum SleepHistoryAggregator {
    struct Interval: Equatable {
        let start: Date
        let end: Date
        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    /// Merged asleep intervals from HealthKit category samples (core, deep, REM, unspecified asleep).
    static func asleepIntervals(from samples: [HKCategorySample]) -> [Interval] {
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        let raw: [Interval] = samples
            .filter { asleepValues.contains($0.value) }
            .map { Interval(start: $0.startDate, end: $0.endDate) }
        return merge(intervals: raw, adjacencyGapSeconds: 10 * 60)
    }

    /// Average hours of main sleep for up to `maxNights` completed wake days before today.
    /// A "night" is attributed to the calendar **wake day** (`startOfDay` of `interval.end`).
    /// Only intervals with duration ≥ `minMainSleepSeconds` count.
    static func averageMainSleepHours(
        intervals: [Interval],
        now: Date,
        calendar: Calendar = .current,
        minMainSleepSeconds: TimeInterval = 90 * 60,
        maxNights: Int = 14
    ) -> (average: Double?, nightsUsed: Int) {
        let startOfToday = calendar.startOfDay(for: now)
        var totals: [Date: Double] = [:]

        for interval in intervals {
            guard interval.duration >= minMainSleepSeconds else { continue }
            let wakeDay = calendar.startOfDay(for: interval.end)
            totals[wakeDay, default: 0] += interval.duration / 3600.0
        }

        var values: [Double] = []
        for dayOffset in 1...maxNights {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: startOfToday) else { continue }
            let key = calendar.startOfDay(for: day)
            if let h = totals[key], h > 0 {
                values.append(h)
            }
        }

        guard !values.isEmpty else { return (nil, 0) }
        let sum = values.reduce(0, +)
        return (sum / Double(values.count), values.count)
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
}
