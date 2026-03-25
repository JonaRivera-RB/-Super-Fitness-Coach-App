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
        // Deactivate any existing active plans before saving the new one
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
        }

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

    /// Fetches the freshly saved plan by id — use this after savePlan to get a fully hydrated object.
    func fetchPlan(id: UUID) throws -> TrainingPlan? {
        let descriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate<TrainingPlan> { p in p.id == id }
        )
        return try context.fetch(descriptor).first
    }

    func fetchActivePlan() throws -> TrainingPlan? {
        let activeStatus = PlanStatus.active.rawValue
        let descriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate<TrainingPlan> { plan in
                plan.planStatusRaw == activeStatus
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
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
}
