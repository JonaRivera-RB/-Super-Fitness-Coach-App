//
//  SleepOutlookFactsEngineTests.swift
//  Super Fitness Coach AppTests
//

import Foundation
import Testing
@testable import Super_Fitness_Coach_App

struct SleepOutlookFactsEngineTests {

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func utcDay(_ y: Int, _ m: Int, _ d: Int, cal: Calendar) -> Date {
        let comps = DateComponents(calendar: cal, timeZone: TimeZone(identifier: "UTC"), year: y, month: m, day: d)
        return comps.date!
    }

    @Test func insufficientHistoryWhenFewSleepDays() {
        let cal = utcCalendar()
        let now = utcDay(2025, 1, 15, cal: cal)
        let rows = [
            RecoverySnapshotDayDTO(dayStart: utcDay(2025, 1, 14, cal: cal), recoveryScore: 50, sleepHours: 7),
            RecoverySnapshotDayDTO(dayStart: utcDay(2025, 1, 13, cal: cal), recoveryScore: 55, sleepHours: 7),
        ]
        let out = SleepOutlookFactsEngine.compute(
            now: now,
            calendar: cal,
            sleepGoalHours: 8,
            snapshots: rows,
            latestSleepHours: 7,
            latestSleepContinuity: nil
        )
        let insufficient = out.facts.contains {
            if case .insufficientHistory(let days) = $0 { return days == 2 }
            return false
        }
        #expect(insufficient)
        #expect(out.band == .neutral)
    }

    @Test func strainedWhenSeveralShortNightsInLastSeven() {
        let cal = utcCalendar()
        let now = utcDay(2025, 1, 15, cal: cal)
        var rows: [RecoverySnapshotDayDTO] = []
        // Historial extra para superar el mínimo de noches con datos en ventana 20 días.
        for dayOffset in 4..<30 {
            guard let d = cal.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            rows.append(RecoverySnapshotDayDTO(dayStart: cal.startOfDay(for: d), recoveryScore: 55, sleepHours: 8))
        }
        // Últimos días: 4 noches cortas dentro de la ventana de 7 (meta 8h → umbral 6.8h).
        for offset in 0..<4 {
            guard let d = cal.date(byAdding: .day, value: -offset, to: now) else { continue }
            rows.append(RecoverySnapshotDayDTO(dayStart: cal.startOfDay(for: d), recoveryScore: 42, sleepHours: 5))
        }
        let out = SleepOutlookFactsEngine.compute(
            now: now,
            calendar: cal,
            sleepGoalHours: 8,
            snapshots: rows,
            latestSleepHours: 5,
            latestSleepContinuity: nil
        )
        #expect(out.band == .strained)
        let nightsFact = out.facts.contains {
            if case .nightsBelowGoalLast7(let count, _) = $0 { return count >= 3 }
            return false
        }
        #expect(nightsFact)
    }

    @Test func recoveryGapFactWhenShortSleepAssociatesWithLowerRecovery() {
        let cal = utcCalendar()
        let now = utcDay(2025, 1, 28, cal: cal)
        var rows: [RecoverySnapshotDayDTO] = []
        // Noches "largas" recovery alto (≥ 7.2h para meta 8h)
        for i in 0..<5 {
            guard let d = cal.date(byAdding: .day, value: -(i + 1), to: now) else { continue }
            rows.append(RecoverySnapshotDayDTO(dayStart: cal.startOfDay(for: d), recoveryScore: 78, sleepHours: 8))
        }
        // Noches cortas recovery bajo
        for i in 0..<5 {
            guard let d = cal.date(byAdding: .day, value: -(i + 10), to: now) else { continue }
            rows.append(RecoverySnapshotDayDTO(dayStart: cal.startOfDay(for: d), recoveryScore: 40, sleepHours: 6))
        }
        let out = SleepOutlookFactsEngine.compute(
            now: now,
            calendar: cal,
            sleepGoalHours: 8,
            snapshots: rows,
            latestSleepHours: 8,
            latestSleepContinuity: nil
        )
        let gapFact = out.facts.contains {
            if case .recoveryGapShortSleepVersusRested(let delta) = $0 { return delta >= 8 }
            return false
        }
        #expect(gapFact)
    }

    @Test func favorableWhenRecentNightsMeetGoal() {
        let cal = utcCalendar()
        let now = utcDay(2025, 2, 10, cal: cal)
        var rows: [RecoverySnapshotDayDTO] = []
        for dayOffset in 1..<25 {
            guard let d = cal.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            rows.append(RecoverySnapshotDayDTO(dayStart: cal.startOfDay(for: d), recoveryScore: 72, sleepHours: 8))
        }
        let out = SleepOutlookFactsEngine.compute(
            now: now,
            calendar: cal,
            sleepGoalHours: 8,
            snapshots: rows,
            latestSleepHours: 8,
            latestSleepContinuity: nil
        )
        #expect(out.band == .favorable)
    }
}
