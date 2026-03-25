//
//  DayManager.swift
//  Super Fitness Coach App
//

import Foundation
import os

/// Gestiona acciones sobre días del plan: completar, saltar, reprogramar.
/// Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 10.10
final class DayManager {
    private let repository: TrainingPlanRepository
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "DayManager")

    init(repository: TrainingPlanRepository) {
        self.repository = repository
    }

    // MARK: - Complete Day (Req 10.7)

    /// Marca un día como completado.
    /// - Parameters:
    ///   - planId: UUID del plan de entrenamiento.
    ///   - dayIndex: Índice del día dentro de la semana actual (0-based).
    func completeDay(planId: UUID, dayIndex: Int) throws {
        guard let plan = try repository.fetchActivePlan(), plan.id == planId else {
            logger.error("Plan not found for id: \(planId)")
            return
        }

        let weekIndex = plan.currentWeek - 1 // currentWeek is 1-based
        guard weekIndex >= 0, weekIndex < plan.weeks.count else {
            logger.error("Invalid currentWeek \(plan.currentWeek) for plan with \(plan.weeks.count) weeks")
            return
        }

        let week = plan.weeks[weekIndex]
        guard dayIndex >= 0, dayIndex < week.days.count else {
            logger.error("Invalid dayIndex \(dayIndex) for week with \(week.days.count) days")
            return
        }

        week.days[dayIndex].dayStatus = .completed
        // Force SwiftData to detect the mutation by reassigning the array
        let updatedDays = week.days
        week.days = updatedDays
        try repository.savePlan(plan)
    }

    // MARK: - Skip Day (Req 10.2)

    /// Marca un día como saltado sin modificar otros días.
    /// - Parameters:
    ///   - planId: UUID del plan de entrenamiento.
    ///   - dayIndex: Índice del día dentro de la semana actual (0-based).
    func skipDay(planId: UUID, dayIndex: Int) throws {
        guard let plan = try repository.fetchActivePlan(), plan.id == planId else {
            logger.error("Plan not found for id: \(planId)")
            return
        }

        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else {
            logger.error("Invalid currentWeek \(plan.currentWeek) for plan with \(plan.weeks.count) weeks")
            return
        }

        let week = plan.weeks[weekIndex]
        guard dayIndex >= 0, dayIndex < week.days.count else {
            logger.error("Invalid dayIndex \(dayIndex) for week with \(week.days.count) days")
            return
        }

        week.days[dayIndex].dayStatus = .skipped
        // Force SwiftData to detect the mutation by reassigning the array
        let updatedDays = week.days
        week.days = updatedDays
        try repository.savePlan(plan)
    }

    // MARK: - Reschedule Day (Req 10.3, 10.4, 10.5, 10.6, 10.9)

    /// Reprograma un día al siguiente día disponible (pending + isRestDay).
    /// Retorna false si no hay día disponible.
    /// - Parameters:
    ///   - planId: UUID del plan de entrenamiento.
    ///   - dayIndex: Índice del día dentro de la semana actual (0-based).
    /// - Returns: `true` si se reprogramó exitosamente, `false` si no hay día disponible.
    @discardableResult
    func rescheduleDay(planId: UUID, dayIndex: Int) throws -> Bool {
        guard let plan = try repository.fetchActivePlan(), plan.id == planId else {
            logger.error("Plan not found for id: \(planId)")
            return false
        }

        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else {
            logger.error("Invalid currentWeek \(plan.currentWeek)")
            return false
        }

        let week = plan.weeks[weekIndex]
        guard dayIndex >= 0, dayIndex < week.days.count else {
            logger.error("Invalid dayIndex \(dayIndex)")
            return false
        }

        // Check reschedule limit (Req 10.6)
        guard canReschedule(plan: plan, dayIndex: dayIndex) else {
            logger.info("Day at index \(dayIndex) was already rescheduled")
            return false
        }

        let sourceDay = week.days[dayIndex]

        // Find next available day: pending + isRestDay, after the current dayIndex (Req 10.4)
        var targetIndex: Int? = nil
        for i in (dayIndex + 1)..<week.days.count {
            let candidate = week.days[i]
            if candidate.dayStatus == .pending && candidate.isRestDay {
                targetIndex = i
                break
            }
        }

        guard let target = targetIndex else {
            // No available day found (Req 10.5)
            logger.info("No available day to reschedule for dayIndex \(dayIndex)")
            return false
        }

        // Move workout to target day (Req 10.3, 10.9)
        // Transfer muscle groups and exercises to the target rest day
        week.days[target].muscleGroups = sourceDay.muscleGroups
        week.days[target].exercises = sourceDay.exercises
        week.days[target].isRestDay = false
        week.days[target].wasRescheduled = true
        week.days[target].dayStatus = .pending

        // Mark source day as rescheduled and convert to rest day
        week.days[dayIndex].dayStatus = .rescheduled
        week.days[dayIndex].wasRescheduled = true
        week.days[dayIndex].muscleGroups = []
        week.days[dayIndex].exercises = []
        week.days[dayIndex].isRestDay = true

        // Force SwiftData to detect the mutation by reassigning the array
        let updatedDays = week.days
        week.days = updatedDays
        try repository.savePlan(plan)
        return true
    }

    // MARK: - Can Reschedule (Req 10.6)

    /// Verifica si un día puede ser reprogramado (límite: 1 vez por día).
    /// - Parameters:
    ///   - plan: El plan de entrenamiento.
    ///   - dayIndex: Índice del día dentro de la semana actual (0-based).
    /// - Returns: `true` si el día no ha sido reprogramado previamente.
    func canReschedule(plan: TrainingPlan, dayIndex: Int) -> Bool {
        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else {
            return false
        }

        let week = plan.weeks[weekIndex]
        guard dayIndex >= 0, dayIndex < week.days.count else {
            return false
        }

        return !week.days[dayIndex].wasRescheduled
    }

    // MARK: - Consecutive Skipped Days (Req 10.10)

    /// Cuenta días consecutivos saltados desde el final de la semana actual hacia atrás.
    /// Se usa para disparar re-engagement cuando consecutiveSkippedDays >= 3.
    /// - Parameter plan: El plan de entrenamiento.
    /// - Returns: Número de días consecutivos con estado `.skipped`.
    func consecutiveSkippedDays(plan: TrainingPlan) -> Int {
        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else {
            return 0
        }

        let days = plan.weeks[weekIndex].days
        var count = 0

        // Count consecutive skipped days from the end backwards
        for day in days.reversed() {
            if day.dayStatus == .skipped {
                count += 1
            } else if day.dayStatus != .pending {
                // Stop at any non-pending, non-skipped day
                break
            } else {
                // Pending days haven't been acted on yet, skip them
                continue
            }
        }

        return count
    }
}
