//
//  DayManager.swift
//  Super Fitness Coach App
//

import Foundation
import os

/// Gestiona acciones sobre días del plan.
/// IMPORTANT: dayIndex is always the index in the SORTED (Mon→Sun) array.
/// We look up the actual @Model object by dayOfWeek to avoid index mismatch
/// between the sorted UI array and the unsorted SwiftData array.
final class DayManager {
    private let repository: TrainingPlanRepository
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "DayManager")

    init(repository: TrainingPlanRepository) {
        self.repository = repository
    }

    // MARK: - Private helper: resolve @Model day from sorted index

    private func resolveDay(plan: TrainingPlan, sortedDayIndex: Int) -> TrainingDayPlan? {
        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else { return nil }
        let week = plan.weeks[weekIndex]
        let sorted = week.days.sorted { $0.dayOfWeek < $1.dayOfWeek }
        guard sortedDayIndex >= 0, sortedDayIndex < sorted.count else { return nil }
        let targetDayOfWeek = sorted[sortedDayIndex].dayOfWeek
        // Return the actual @Model object from the unsorted array
        return week.days.first(where: { $0.dayOfWeek == targetDayOfWeek })
    }

    // MARK: - Complete Day

    func completeDay(plan: TrainingPlan, dayIndex: Int) throws {
        guard let day = resolveDay(plan: plan, sortedDayIndex: dayIndex) else {
            logger.warning("completeDay(index): could not resolve sortedIndex=\(dayIndex) planId=\(plan.id.uuidString) currentWeek=\(plan.currentWeek) weekCount=\(plan.weeks.count)")
            return
        }
        day.dayStatus = .completed
        day.activeSessionId = nil
        day.activeSessionStartedAt = nil
        try repository.savePlan(plan)
        try repository.advanceToNextTrainingWeekIfNeeded(plan: plan)
    }

    func completeDay(plan: TrainingPlan, dayOfWeek: Int) throws {
        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else {
            logger.warning("completeDay(dow): invalid weekIndex=\(weekIndex) planId=\(plan.id.uuidString)")
            return
        }
        let week = plan.weeks[weekIndex]
        guard let day = week.days.first(where: { $0.dayOfWeek == dayOfWeek }) else {
            logger.warning("completeDay(dow): no day dow=\(dayOfWeek) planId=\(plan.id.uuidString) daysInWeek=\(week.days.count)")
            return
        }
        day.dayStatus = .completed
        day.activeSessionId = nil
        day.activeSessionStartedAt = nil
        try repository.savePlan(plan)
        try repository.advanceToNextTrainingWeekIfNeeded(plan: plan)
    }

    // MARK: - Skip Day

    func skipDay(plan: TrainingPlan, dayIndex: Int) throws {
        guard let day = resolveDay(plan: plan, sortedDayIndex: dayIndex) else {
            logger.error("skipDay: could not resolve day at sortedIndex \(dayIndex)")
            return
        }
        logger.info("skipDay: marking dayOfWeek=\(day.dayOfWeek) as skipped (was \(day.dayStatusRaw))")
        day.dayStatus = .skipped
        try repository.savePlan(plan)

        // Log all days after skip for debugging
        let weekIndex = plan.currentWeek - 1
        if weekIndex >= 0, weekIndex < plan.weeks.count {
            let sorted = plan.weeks[weekIndex].days.sorted { $0.dayOfWeek < $1.dayOfWeek }
            for d in sorted {
                logger.info("  day \(d.dayOfWeek): status=\(d.dayStatusRaw) isRest=\(d.isRestDay)")
            }
        }
    }

    // MARK: - Reschedule Day

    @discardableResult
    func rescheduleDay(plan: TrainingPlan, dayIndex: Int) throws -> Bool {
        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else { return false }
        let week = plan.weeks[weekIndex]
        let sorted = week.days.sorted { $0.dayOfWeek < $1.dayOfWeek }
        guard dayIndex >= 0, dayIndex < sorted.count else { return false }

        let sourceDayOfWeek = sorted[dayIndex].dayOfWeek
        guard let sourceDay = week.days.first(where: { $0.dayOfWeek == sourceDayOfWeek }) else { return false }
        guard !sourceDay.wasRescheduled else { return false }

        // Find next available rest day after source (by dayOfWeek)
        guard let targetDay = sorted.first(where: {
            $0.dayOfWeek > sourceDayOfWeek && $0.dayStatus == .pending && $0.isRestDay
        }), let actualTarget = week.days.first(where: { $0.dayOfWeek == targetDay.dayOfWeek }) else {
            logger.info("No available rest day to reschedule into")
            return false
        }

        actualTarget.muscleGroups = sourceDay.muscleGroups
        actualTarget.exercises = sourceDay.exercises
        actualTarget.isRestDay = false
        actualTarget.wasRescheduled = true
        actualTarget.dayStatus = .pending

        sourceDay.dayStatus = .rescheduled
        sourceDay.wasRescheduled = true
        sourceDay.muscleGroups = []
        sourceDay.exercises = []
        sourceDay.isRestDay = true

        try repository.savePlan(plan)
        return true
    }

    // MARK: - Can Reschedule

    func canReschedule(plan: TrainingPlan, dayIndex: Int) -> Bool {
        guard let day = resolveDay(plan: plan, sortedDayIndex: dayIndex) else { return false }
        return !day.wasRescheduled
    }

    // MARK: - Consecutive Skipped Days

    func consecutiveSkippedDays(plan: TrainingPlan) -> Int {
        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else { return 0 }
        let days = plan.weeks[weekIndex].days.sorted { $0.dayOfWeek < $1.dayOfWeek }
        var count = 0
        for day in days.reversed() {
            if day.dayStatus == .skipped { count += 1 }
            else if day.dayStatus == .pending { continue }
            else { break }
        }
        return count
    }

    // MARK: - Legacy planId-based API (for tests)

    func completeDay(planId: UUID, dayIndex: Int) throws {
        guard let plan = try repository.fetchActivePlan(), plan.id == planId else { return }
        try completeDay(plan: plan, dayIndex: dayIndex)
    }

    func skipDay(planId: UUID, dayIndex: Int) throws {
        guard let plan = try repository.fetchActivePlan(), plan.id == planId else { return }
        try skipDay(plan: plan, dayIndex: dayIndex)
    }

    func rescheduleDay(planId: UUID, dayIndex: Int) throws -> Bool {
        guard let plan = try repository.fetchActivePlan(), plan.id == planId else { return false }
        return try rescheduleDay(plan: plan, dayIndex: dayIndex)
    }
}
