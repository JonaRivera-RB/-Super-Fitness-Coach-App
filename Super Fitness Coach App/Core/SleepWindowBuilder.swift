import Foundation

struct SleepWindowBuilder {
    struct ExpectedSleepWindow: Equatable {
        let expectedStart: Date
        let expectedEnd: Date
        let adjustedStart: Date
        let adjustedEnd: Date
        let isFallback: Bool
    }

    static func build(
        goal: SleepGoal?,
        referenceDate: Date,
        bufferMinutes: Int,
        calendar: Calendar = .current
    ) -> ExpectedSleepWindow {
        let clampedBuffer = max(0, min(180, bufferMinutes))

        let isFallback = (goal == nil)
        let effectiveGoal: SleepGoal = goal ?? SleepGoal(
            targetSleepTime: .init(hour: 20, minute: 0),
            targetWakeTime: .init(hour: 10, minute: 0)
        )

        let startOfRefDay = calendar.startOfDay(for: referenceDate)

        let sleepMinutes = minutesSinceMidnight(effectiveGoal.targetSleepTime.asDateComponents)
        let wakeMinutes = minutesSinceMidnight(effectiveGoal.targetWakeTime.asDateComponents)

        let crossesMidnight = wakeMinutes <= sleepMinutes

        let expectedStartDay = crossesMidnight
            ? calendar.date(byAdding: .day, value: -1, to: startOfRefDay)!
            : startOfRefDay

        let expectedStart = date(on: expectedStartDay, applying: effectiveGoal.targetSleepTime.asDateComponents, calendar: calendar)
        let expectedEnd = date(on: startOfRefDay, applying: effectiveGoal.targetWakeTime.asDateComponents, calendar: calendar)

        // Defensive: guarantee ordering even if calendar math behaves oddly around DST.
        let rawStart = min(expectedStart, expectedEnd)
        let rawEnd = max(expectedStart, expectedEnd)

        let adjustedStart = calendar.date(byAdding: .minute, value: -clampedBuffer, to: rawStart)!
        let adjustedEnd = calendar.date(byAdding: .minute, value: clampedBuffer, to: rawEnd)!

        return ExpectedSleepWindow(
            expectedStart: rawStart,
            expectedEnd: rawEnd,
            adjustedStart: adjustedStart,
            adjustedEnd: adjustedEnd,
            isFallback: isFallback
        )
    }

    /// Mismo criterio que el fetch de HealthKit: la ventana ajustada por meta+buffer no puede terminar
    /// antes de un despertar real más tarde; al menos hasta el mediodía del día de levantar.
    static func sleepFetchQueryEnd(window: ExpectedSleepWindow, calendar: Calendar = .current) -> Date {
        let wakeDayStart = calendar.startOfDay(for: window.expectedEnd)
        let throughNoon = calendar.date(byAdding: .hour, value: 12, to: wakeDayStart) ?? window.adjustedEnd
        return max(window.adjustedEnd, throughNoon)
    }

    private static func date(on day: Date, applying hm: DateComponents, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = hm.hour
        comps.minute = hm.minute
        comps.second = 0
        return calendar.date(from: comps) ?? day
    }

    private static func minutesSinceMidnight(_ c: DateComponents) -> Int {
        (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

