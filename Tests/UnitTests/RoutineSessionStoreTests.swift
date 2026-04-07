//
//  RoutineSessionStoreTests.swift
//

import XCTest
@testable import Super_Fitness_Coach_App

final class RoutineSessionStoreTests: XCTestCase {

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    func testStorageKeyDiffersBetweenConsecutiveCalendarDays() {
        let cal = utcCalendar()
        let routineId = UUID()
        let noonDay1 = cal.date(from: DateComponents(year: 2026, month: 4, day: 6, hour: 12, minute: 30))!
        let morningDay2 = cal.date(from: DateComponents(year: 2026, month: 4, day: 7, hour: 6))!

        let k1 = RoutineSessionStore.storageKey(routineId: routineId, calendarDay: noonDay1, calendar: cal)
        let k2 = RoutineSessionStore.storageKey(routineId: routineId, calendarDay: morningDay2, calendar: cal)

        XCTAssertNotEqual(k1, k2)
        XCTAssertTrue(k1.hasSuffix("|2026-04-06"), "key: \(k1)")
        XCTAssertTrue(k2.hasSuffix("|2026-04-07"), "key: \(k2)")
    }

    func testSameCalendarDaySameKeyRegardlessOfTime() {
        let cal = utcCalendar()
        let routineId = UUID()
        let early = cal.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 0, minute: 5))!
        let late = cal.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 23, minute: 55))!

        let kEarly = RoutineSessionStore.storageKey(routineId: routineId, calendarDay: early, calendar: cal)
        let kLate = RoutineSessionStore.storageKey(routineId: routineId, calendarDay: late, calendar: cal)

        XCTAssertEqual(kEarly, kLate)
    }

    func testDifferentRoutinesDifferentKeysSameDay() {
        let cal = utcCalendar()
        let a = UUID()
        let b = UUID()
        let day = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

        XCTAssertNotEqual(
            RoutineSessionStore.storageKey(routineId: a, calendarDay: day, calendar: cal),
            RoutineSessionStore.storageKey(routineId: b, calendarDay: day, calendar: cal)
        )
    }

    /// Simula «hoy» vs «mañana»: al cambiar de día calendario debe existir otra sesión (otro UUID).
    func testLoadOrCreateNewSessionIdOnNextCalendarDay() {
        let suite = "RoutineSessionStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let cal = utcCalendar()
        let routineId = UUID()
        let today = cal.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 10))!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let (idToday, keyToday) = RoutineSessionStore.loadOrCreateSessionId(
            routineId: routineId,
            referenceDate: today,
            calendar: cal,
            defaults: defaults
        )
        let (idTodayAgain, keyAgain) = RoutineSessionStore.loadOrCreateSessionId(
            routineId: routineId,
            referenceDate: today,
            calendar: cal,
            defaults: defaults
        )
        XCTAssertEqual(keyToday, keyAgain)
        XCTAssertEqual(idToday, idTodayAgain, "Mismo día → mismo sessionId")

        let (idTomorrow, keyTomorrow) = RoutineSessionStore.loadOrCreateSessionId(
            routineId: routineId,
            referenceDate: tomorrow,
            calendar: cal,
            defaults: defaults
        )
        XCTAssertNotEqual(keyToday, keyTomorrow)
        XCTAssertNotEqual(idToday, idTomorrow, "Otro día calendario → nueva sesión aislada")
    }

    func testClearStorageKeyAllowsFreshSessionSameDay() {
        let suite = "RoutineSessionStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let cal = utcCalendar()
        let routineId = UUID()
        let day = cal.date(from: DateComponents(year: 2026, month: 3, day: 20))!

        let (first, key) = RoutineSessionStore.loadOrCreateSessionId(
            routineId: routineId,
            referenceDate: day,
            calendar: cal,
            defaults: defaults
        )
        defaults.removeObject(forKey: key)

        let (second, key2) = RoutineSessionStore.loadOrCreateSessionId(
            routineId: routineId,
            referenceDate: day,
            calendar: cal,
            defaults: defaults
        )
        XCTAssertEqual(key, key2)
        XCTAssertNotEqual(first, second, "Tras borrar la clave, nuevo sessionId (como al completar entreno)")
    }
}
