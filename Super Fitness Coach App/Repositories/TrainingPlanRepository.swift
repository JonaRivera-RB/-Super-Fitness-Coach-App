//
//  TrainingPlanRepository.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData
import os

final class TrainingPlanRepository {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "TrainingPlanRepository")

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - TrainingPlan

    func savePlan(_ plan: TrainingPlan) throws {
        // Only insert if not already tracked by this context
        // (avoid deleting existing plan when just updating day status)
        context.insert(plan)
        do {
            try context.save()
        } catch {
            logger.warning("First savePlan attempt failed, retrying: \(error.localizedDescription)")
            do {
                try context.save()
            } catch {
                logger.error("Retry savePlan failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Saves a new plan, replacing any existing active plans.
    /// Use this only when generating a brand-new plan.
    func replaceActivePlan(with plan: TrainingPlan) throws {
        let activeStatus = PlanStatus.active.rawValue
        let descriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate<TrainingPlan> { p in
                p.planStatusRaw == activeStatus
            }
        )
        if let existingPlans = try? context.fetch(descriptor) {
            for existing in existingPlans {
                context.delete(existing)
            }
            // Save deletes BEFORE inserting new plan to avoid relationship conflicts
            try context.save()
        }
        context.insert(plan)
        try context.save()
    }

    /// Fetches the freshly saved plan by id — use this after savePlan to get a fully hydrated object.
    func fetchPlan(id: UUID) throws -> TrainingPlan? {
        let descriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate<TrainingPlan> { p in p.id == id }
        )
        guard let plan = try context.fetch(descriptor).first else { return nil }

        // Force-hydrate relationships
        for week in plan.weeks {
            for day in week.days {
                _ = day.exercises.count
            }
        }

        return plan
    }

    func fetchActivePlan() throws -> TrainingPlan? {
        let activeStatus = PlanStatus.active.rawValue
        var descriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate<TrainingPlan> { plan in
                plan.planStatusRaw == activeStatus
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        // Prefetch nested relationships eagerly — prevents lazy-load empty array bug
        descriptor.relationshipKeyPathsForPrefetching = [\.weeks]
        guard let plan = try context.fetch(descriptor).first else { return nil }

        // Also touch days to ensure they're hydrated
        for week in plan.weeks {
            _ = week.days.count
        }

        return plan
    }

    // MARK: - WorkoutLog

    func saveWorkoutLog(_ log: WorkoutLog) throws {
        context.insert(log)
        do {
            try context.save()
        } catch {
            logger.warning("First saveWorkoutLog attempt failed, retrying: \(error.localizedDescription)")
            do {
                try context.save()
            } catch {
                logger.error("Retry saveWorkoutLog failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    func fetchLatestLog(exerciseId: String) throws -> WorkoutLog? {
        var descriptor = FetchDescriptor<WorkoutLog>(
            predicate: #Predicate<WorkoutLog> { log in
                log.exerciseId == exerciseId
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchLogs(exerciseId: String, limit: Int) throws -> [WorkoutLog] {
        var descriptor = FetchDescriptor<WorkoutLog>(
            predicate: #Predicate<WorkoutLog> { log in
                log.exerciseId == exerciseId
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    /// Todos los registros recientes (para historial / PRs en estadísticas).
    func fetchAllLogs(limit: Int) throws -> [WorkoutLog] {
        var descriptor = FetchDescriptor<WorkoutLog>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
}
