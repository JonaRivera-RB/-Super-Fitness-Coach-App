//
//  WorkoutInsights.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData

/// Read-only, derived metrics for the Workout tab UI.
/// Important: this must NOT mutate SwiftData or business rules.
struct WorkoutInsights: Equatable {
    struct Ring: Equatable {
        var title: String
        /// 0...1
        var progress: Double
        var valueText: String
        var subtitleText: String?
        /// Texto corto para el botón (i) en la card del anillo.
        var infoText: String?
    }

    struct VolumePoint: Identifiable, Equatable {
        var id: Date { periodStart }
        var periodStart: Date
        /// Total tonnage (kg * reps) for the period.
        var tonnage: Double
    }

    var primaryRing: Ring?
    var secondaryRing: Ring?
    var volumeRing: Ring?
    var todayRing: Ring?
    var volumeTrend: [VolumePoint] = []
}

enum WorkoutInsightsCalculator {
    /// Misma semana calendario que `reference` (anillo de rutina, píldoras «Esta semana»).
    static func isDateInSameCalendarWeekAsReference(
        _ date: Date,
        reference: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(date, equalTo: reference, toGranularity: .weekOfYear)
    }

    static func compute(
        activePlan: TrainingPlan?,
        activeRoutine: UserRoutine?,
        context: ModelContext,
        workoutSurface: WorkoutSurface,
        calendar: Calendar = .current,
        maxLogs: Int = 800
    ) -> WorkoutInsights {
        var insights = WorkoutInsights()

        let routineSurfacePrimary = workoutSurface == .routine && activeRoutine != nil

        if routineSurfacePrimary {
            if let routine = activeRoutine {
                let consistency = routineConsistencyThisWeek(routine: routine, calendar: calendar)
                insights.primaryRing = .init(
                    title: AppLanguage.current.workoutRingRoutine,
                    progress: consistency.progress,
                    valueText: "\(consistency.completed)/\(consistency.total)",
                    subtitleText: AppLanguage.current.workoutRingRoutineSubtitle,
                    infoText: AppLanguage.current.workoutRingRoutineInfo
                )
            }
        } else {
            if let plan = activePlan {
                let weekIndex = plan.currentWeek - 1
                let days: [TrainingDayPlan] = weekIndex >= 0 && weekIndex < plan.weeks.count
                    ? plan.weeks[weekIndex].days
                    : []
                let trainingDays = days.filter { !$0.isRestDay }
                let completedDays = trainingDays.filter { $0.dayStatus == .completed }
                let total = max(1, trainingDays.count)
                let progress = Double(completedDays.count) / Double(total)
                insights.primaryRing = .init(
                    title: AppLanguage.current.workoutRingWeek,
                    progress: progress,
                    valueText: "\(completedDays.count)/\(trainingDays.count)",
                    subtitleText: AppLanguage.current.workoutRingWeekSubtitle,
                    infoText: AppLanguage.current.workoutRingWeekInfo
                )

                let plannedSets = trainingDays
                    .flatMap(\.exercises)
                    .reduce(0) { $0 + max(0, $1.sets) }
                let completedSets = countCompletedSetsThisWeek(context: context, calendar: calendar, limit: maxLogs)
                let denom = max(1, plannedSets)
                let volumeProgress = min(1, Double(completedSets) / Double(denom))
                insights.volumeRing = .init(
                    title: AppLanguage.current.workoutRingVolume,
                    progress: volumeProgress,
                    valueText: "\(completedSets)/\(plannedSets)",
                    subtitleText: AppLanguage.current.workoutRingVolumeSubtitle,
                    infoText: AppLanguage.current.workoutRingVolumeInfo
                )

                if let todayDay = trainingDays.first(where: { $0.dayOfWeek == todayDayOfWeek(calendar: calendar, date: Date()) }) {
                    let plannedToday = todayDay.exercises.reduce(0) { $0 + max(0, $1.sets) }
                    let completedToday = countCompletedSetsToday(context: context, calendar: calendar, limit: maxLogs)
                    let denomToday = max(1, plannedToday)
                    insights.todayRing = .init(
                        title: AppLanguage.current.workoutRingToday,
                        progress: min(1, Double(completedToday) / Double(denomToday)),
                        valueText: "\(completedToday)/\(plannedToday)",
                        subtitleText: AppLanguage.current.workoutRingTodaySubtitle,
                        infoText: AppLanguage.current.workoutRingTodayInfo
                    )
                }
            }
            // Importante UX: en Plan guiado mostramos solo anillos del plan (no mezclar con Mi rutina).
        }

        insights.volumeTrend = volumeTrendByWeek(context: context, calendar: calendar, limit: maxLogs, weeks: 8)

        return insights
    }

    private static func routineConsistencyThisWeek(
        routine: UserRoutine,
        calendar: Calendar
    ) -> (completed: Int, total: Int, progress: Double) {
        let total = max(1, routine.days.filter { !$0.isRestDay }.count)
        let completed = routine.days
            .filter { !$0.isRestDay }
            .filter { day in
                guard let d = day.lastRoutineWorkoutCompletedAt else { return false }
                return isDateInSameCalendarWeekAsReference(d, reference: Date(), calendar: calendar)
            }
            .count
        return (completed, total, Double(completed) / Double(total))
    }

    private static func countCompletedSetsThisWeek(
        context: ModelContext,
        calendar: Calendar,
        limit: Int
    ) -> Int {
        do {
            let now = Date()
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
            var fd = FetchDescriptor<WorkoutLog>(
                predicate: #Predicate<WorkoutLog> { $0.date >= startOfWeek }
            )
            fd.sortBy = [SortDescriptor(\WorkoutLog.date, order: .reverse)]
            fd.fetchLimit = max(1, limit)
            let logs = try context.fetch(fd)
            return logs.reduce(0) { $0 + $1.sets.count }
        } catch {
            return 0
        }
    }

    private static func countCompletedSetsToday(
        context: ModelContext,
        calendar: Calendar,
        limit: Int
    ) -> Int {
        do {
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            var fd = FetchDescriptor<WorkoutLog>(
                predicate: #Predicate<WorkoutLog> { $0.date >= startOfDay }
            )
            fd.sortBy = [SortDescriptor(\WorkoutLog.date, order: .reverse)]
            fd.fetchLimit = max(1, limit)
            let logs = try context.fetch(fd)
            return logs.reduce(0) { $0 + $1.sets.count }
        } catch {
            return 0
        }
    }

    private static func volumeTrendByWeek(
        context: ModelContext,
        calendar: Calendar,
        limit: Int,
        weeks: Int
    ) -> [WorkoutInsights.VolumePoint] {
        do {
            var fd = FetchDescriptor<WorkoutLog>()
            fd.sortBy = [SortDescriptor(\WorkoutLog.date, order: .reverse)]
            fd.fetchLimit = max(1, limit)
            let logs = try context.fetch(fd)

            var buckets: [Date: Double] = [:]
            for log in logs {
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: log.date)?.start ?? calendar.startOfDay(for: log.date)
                let tonnage = log.sets.reduce(0.0) { acc, set in
                    acc + max(0, set.weight) * Double(max(0, set.reps))
                }
                buckets[weekStart, default: 0] += tonnage
            }

            let now = Date()
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .weekOfYear, value: -(max(1, weeks) - 1), to: currentWeekStart) ?? currentWeekStart

            var out: [WorkoutInsights.VolumePoint] = []
            var cursor = start
            while cursor <= currentWeekStart {
                out.append(.init(periodStart: cursor, tonnage: buckets[cursor] ?? 0))
                cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? cursor.addingTimeInterval(7 * 86400)
            }
            return out
        } catch {
            return []
        }
    }

    private static func todayDayOfWeek(calendar: Calendar, date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }
}
