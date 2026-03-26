//
//  SleepHistoryAggregatorTests.swift
//  Super Fitness Coach AppTests
//

import Foundation
import Testing
@testable import Super_Fitness_Coach_App

struct SleepHistoryAggregatorTests {

    @Test func averageExcludesTodaysWakeAndAveragesPriorNights() {
        let cal = Calendar(identifier: .gregorian)
        // Today = Jan 15, 2025 noon
        var comps = DateComponents()
        comps.calendar = cal
        comps.timeZone = TimeZone(identifier: "UTC")
        comps.year = 2025
        comps.month = 1
        comps.day = 15
        comps.hour = 12
        comps.minute = 0
        let now = cal.date(from: comps)!

        // Night A: wake Jan 14 07:00 — 8h
        var bed = DateComponents(calendar: cal, timeZone: TimeZone(identifier: "UTC"), year: 2025, month: 1, day: 13, hour: 23, minute: 0)
        var wake = DateComponents(calendar: cal, timeZone: TimeZone(identifier: "UTC"), year: 2025, month: 1, day: 14, hour: 7, minute: 0)
        let a1 = SleepHistoryAggregator.Interval(start: bed.date!, end: wake.date!)

        // Night B: wake Jan 13 07:00 — 8h (Jan 12 23:00 → Jan 13 07:00)
        bed = DateComponents(calendar: cal, timeZone: TimeZone(identifier: "UTC"), year: 2025, month: 1, day: 12, hour: 23, minute: 0)
        wake = DateComponents(calendar: cal, timeZone: TimeZone(identifier: "UTC"), year: 2025, month: 1, day: 13, hour: 7, minute: 0)
        let a2 = SleepHistoryAggregator.Interval(start: bed.date!, end: wake.date!)

        let (avg, n) = SleepHistoryAggregator.averageMainSleepHours(
            intervals: [a1, a2],
            now: now,
            calendar: cal
        )
        #expect(n == 2)
        #expect(avg != nil)
        if let avg {
            #expect(abs(avg - 8.0) < 0.01)
        }
    }

    @Test func shortSessionsIgnored() {
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents(calendar: cal, timeZone: TimeZone(identifier: "UTC"), year: 2025, month: 1, day: 15, hour: 12, minute: 0)
        let now = cal.date(from: comps)!

        var bed = DateComponents(calendar: cal, timeZone: TimeZone(identifier: "UTC"), year: 2025, month: 1, day: 14, hour: 10, minute: 0)
        var wake = DateComponents(calendar: cal, timeZone: TimeZone(identifier: "UTC"), year: 2025, month: 1, day: 14, hour: 11, minute: 0)
        let nap = SleepHistoryAggregator.Interval(start: bed.date!, end: wake.date!) // 1h — below 90 min

        let (avg, n) = SleepHistoryAggregator.averageMainSleepHours(intervals: [nap], now: now, calendar: cal)
        #expect(avg == nil && n == 0)
    }
}
