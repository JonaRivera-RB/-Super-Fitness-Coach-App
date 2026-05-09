//
//  SleepOutlookFactsEngine.swift
//  Super Fitness Coach App
//
//  Agrega snapshots locales + última noche y produce banda orientativa + hechos (sin ML).
//

import Foundation

/// Un día persistido al refrescar Home (sin depender de `@Model` en tests).
struct RecoverySnapshotDayDTO: Equatable, Sendable {
    let dayStart: Date
    let recoveryScore: Int
    let sleepHours: Double?
}

enum SleepOutlookBand: String, Equatable, Sendable {
    case favorable
    case neutral
    case strained
}

enum SleepOutlookFact: Equatable, Sendable {
    case insufficientHistory(daysWithSleepData: Int)
    case nightsBelowGoalLast7(count: Int, goalHours: Double)
    case sleepHoursTrend(differenceHours: Double)
    case recoveryGapShortSleepVersusRested(deltaPoints: Int)
    case fragmentedSleep(continuityScore: Int)
}

struct SleepOutlookSnapshot: Equatable, Sendable {
    let band: SleepOutlookBand
    let facts: [SleepOutlookFact]

    /// Líneas neutras para prompt del modelo (sin texto libre del usuario).
    var structuredPromptLines: [String] {
        var lines = ["outlook_band: \(band.rawValue)"]
        for fact in facts {
            lines.append(fact.promptTag)
        }
        return lines
    }
}

extension SleepOutlookFact {
    fileprivate var promptTag: String {
        switch self {
        case .insufficientHistory(let days):
            return "fact_insufficient_history_days: \(days)"
        case .nightsBelowGoalLast7(let count, let goal):
            return "fact_nights_below_goal_last_7: \(count) goal_hours: \(String(format: "%.1f", goal))"
        case .sleepHoursTrend(let diff):
            return "fact_sleep_hours_trend_last7_minus_prior7: \(String(format: "%.2f", diff))"
        case .recoveryGapShortSleepVersusRested(let delta):
            return "fact_recovery_gap_short_vs_rested_points: \(delta)"
        case .fragmentedSleep(let score):
            return "fact_sleep_continuity_score: \(score)"
        }
    }
}

enum SleepOutlookFactsEngine {

    /// Calcula perspectiva orientativa (wellness, no clínica).
    static func compute(
        now: Date = Date(),
        calendar: Calendar = .current,
        sleepGoalHours: Double,
        snapshots: [RecoverySnapshotDayDTO],
        latestSleepHours: Double?,
        latestSleepContinuity: Int?
    ) -> SleepOutlookSnapshot {
        let goal = max(sleepGoalHours, 4)
        let todayStart = calendar.startOfDay(for: now)

        let deduped = dedupeByDayStart(snapshots, calendar: calendar)
        let withSleep = deduped.filter { $0.sleepHours != nil }

        let recentSleepDays = withSleep.filter {
            let d = calendar.startOfDay(for: $0.dayStart)
            guard let daysBack = calendar.dateComponents([.day], from: d, to: todayStart).day else { return false }
            return daysBack >= 0 && daysBack <= 20
        }

        if recentSleepDays.count < 3 {
            return SleepOutlookSnapshot(
                band: .neutral,
                facts: [.insufficientHistory(daysWithSleepData: recentSleepDays.count)]
            )
        }

        var facts: [SleepOutlookFact] = []

        let lowerThreshold = max(5.5, goal * 0.85)

        let last7Starts = (0..<7).compactMap { offset -> Date? in
            calendar.date(byAdding: .day, value: -offset, to: todayStart)
        }
        var nightsBelowGoal = 0
        for dayStart in last7Starts {
            guard let row = deduped.first(where: { calendar.startOfDay(for: $0.dayStart) == dayStart }),
                  let h = row.sleepHours else { continue }
            if h < lowerThreshold {
                nightsBelowGoal += 1
            }
        }
        if nightsBelowGoal > 0 {
            facts.append(.nightsBelowGoalLast7(count: nightsBelowGoal, goalHours: goal))
        }

        let avgLast7 = averageSleepHours(in: last7Starts, snapshots: deduped, calendar: calendar)
        let priorStarts = (7..<14).compactMap { offset -> Date? in
            calendar.date(byAdding: .day, value: -offset, to: todayStart)
        }
        let avgPrior7 = averageSleepHours(in: priorStarts, snapshots: deduped, calendar: calendar)

        if let a = avgLast7, let b = avgPrior7 {
            let diff = a - b
            if abs(diff) >= 0.35 {
                facts.append(.sleepHoursTrend(differenceHours: diff))
            }
        }

        if let cont = latestSleepContinuity, cont < 55 {
            facts.append(.fragmentedSleep(continuityScore: cont))
        }

        if let gap = computeRecoveryGapAmongSnapshots(deduped, sleepGoalHours: goal, calendar: calendar) {
            facts.append(.recoveryGapShortSleepVersusRested(deltaPoints: gap))
        }

        let band = classifyBand(
            nightsBelowGoalLast7: nightsBelowGoal,
            sleepGoalHours: goal,
            latestSleepHours: latestSleepHours,
            hasRecoveryGap: facts.contains(where: {
                if case .recoveryGapShortSleepVersusRested = $0 { return true }
                return false
            }),
            hasFragmented: facts.contains(where: {
                if case .fragmentedSleep = $0 { return true }
                return false
            })
        )

        if facts.isEmpty {
            facts.append(.nightsBelowGoalLast7(count: 0, goalHours: goal))
        }

        return SleepOutlookSnapshot(band: band, facts: facts)
    }

    private static func dedupeByDayStart(_ rows: [RecoverySnapshotDayDTO], calendar: Calendar) -> [RecoverySnapshotDayDTO] {
        var best: [Date: RecoverySnapshotDayDTO] = [:]
        for row in rows {
            let key = calendar.startOfDay(for: row.dayStart)
            if let existing = best[key] {
                let preferNew: Bool = {
                    switch (existing.sleepHours, row.sleepHours) {
                    case (nil, .some): return true
                    case (.some, nil): return false
                    default: return row.dayStart >= existing.dayStart
                    }
                }()
                if preferNew { best[key] = row }
            } else {
                best[key] = row
            }
        }
        return best.values.sorted { $0.dayStart > $1.dayStart }
    }

    private static func averageSleepHours(
        in dayStarts: [Date],
        snapshots: [RecoverySnapshotDayDTO],
        calendar: Calendar
    ) -> Double? {
        var sum = 0.0
        var n = 0
        for dayStart in dayStarts {
            guard let row = snapshots.first(where: { calendar.startOfDay(for: $0.dayStart) == dayStart }),
                  let h = row.sleepHours else { continue }
            sum += h
            n += 1
        }
        guard n >= 2 else { return nil }
        return sum / Double(n)
    }

    /// Promedio recovery cuando sueño corto vs cuando sueño adecuado (últimos ~28 días con horas).
    private static func computeRecoveryGapAmongSnapshots(
        _ snapshots: [RecoverySnapshotDayDTO],
        sleepGoalHours: Double,
        calendar: Calendar
    ) -> Int? {
        let shortThreshold = sleepGoalHours * 0.9
        var shortSum = 0
        var shortN = 0
        var okSum = 0
        var okN = 0
        for row in snapshots {
            guard let h = row.sleepHours else { continue }
            if h < shortThreshold {
                shortSum += row.recoveryScore
                shortN += 1
            } else {
                okSum += row.recoveryScore
                okN += 1
            }
        }
        guard shortN >= 2, okN >= 2 else { return nil }
        let avgOk = Double(okSum) / Double(okN)
        let avgShort = Double(shortSum) / Double(shortN)
        let delta = avgOk - avgShort
        guard delta >= 8 else { return nil }
        return Int(delta.rounded())
    }

    private static func classifyBand(
        nightsBelowGoalLast7: Int,
        sleepGoalHours: Double,
        latestSleepHours: Double?,
        hasRecoveryGap: Bool,
        hasFragmented: Bool
    ) -> SleepOutlookBand {
        let strainedByNights = nightsBelowGoalLast7 >= 3
        let latestShort = latestSleepHours.map { $0 < max(5.5, sleepGoalHours * 0.85) } ?? false
        let strainedCombo = nightsBelowGoalLast7 >= 2 && latestShort

        if strainedByNights || hasRecoveryGap || strainedCombo || (hasFragmented && nightsBelowGoalLast7 >= 2) {
            return .strained
        }

        let favorableSleep = latestSleepHours.map { $0 >= sleepGoalHours * 0.88 } ?? false
        if nightsBelowGoalLast7 == 0 && !hasFragmented && !hasRecoveryGap {
            return .favorable
        }
        if nightsBelowGoalLast7 <= 1 && favorableSleep && !hasRecoveryGap {
            return .favorable
        }

        return .neutral
    }
}
