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

    // MARK: - Performance-based Plan Updates (post-workout)

    /// Updates the active plan's future prescriptions using real session performance.
    /// - Uses logged reps vs planned reps to adjust suggestedWeight.
    /// - Optionally adds a set (high-volume preference) when user consistently beats target reps.
    func applyPerformanceUpdates(workoutLogs: [WorkoutLog]) throws {
        guard let plan = try fetchActivePlan() else { return }
        guard !workoutLogs.isEmpty else { return }

        // Map: exerciseId → (avgReps, avgWeight)
        struct Summary {
            let avgReps: Double
            let avgWeight: Double
        }
        var summaries: [String: Summary] = [:]
        for log in workoutLogs {
            let reps = log.sets.map { Double($0.reps) }
            let weights = log.sets.map { $0.weight }
            guard !reps.isEmpty, !weights.isEmpty else { continue }
            let avgReps = reps.reduce(0, +) / Double(reps.count)
            let avgWeight = weights.reduce(0, +) / Double(weights.count)
            summaries[log.exerciseId] = Summary(avgReps: avgReps, avgWeight: avgWeight)
        }
        guard !summaries.isEmpty else { return }

        let prefersHighVolume = plan.preferences.prefersHighVolume

        // Heuristics:
        // - If user beats target reps by >=2 on average → +2.5% weight next time
        // - If user misses target by >=2 on average → -2.5% weight next time
        // - If high-volume and beats by >=3 → +1 set (cap 8)
        let upWeightFactor = 1.025
        let downWeightFactor = 0.975

        var didChange = false

        for week in plan.weeks {
            for day in week.days {
                guard !day.exercises.isEmpty else { continue }
                var updated: [PlannedExercise] = []
                updated.reserveCapacity(day.exercises.count)

                for ex in day.exercises {
                    guard let s = summaries[ex.effectiveCatalogId] ?? summaries[ex.id] else {
                        updated.append(ex)
                        continue
                    }

                    var next = ex
                    let targetReps = Double(ex.reps)
                    let delta = s.avgReps - targetReps

                    if delta >= 2.0 {
                        next.suggestedWeight = max(0, ex.suggestedWeight * upWeightFactor)
                        if let maxW = ex.targetWeightMax {
                            next.targetWeightMax = maxW * upWeightFactor
                        }
                        didChange = true

                        if prefersHighVolume, delta >= 3.0 {
                            next.sets = min(8, ex.sets + 1)
                            if let per = next.perSetRestSeconds, per.count == ex.sets {
                                // If per-set rest existed, extend with last known rest.
                                let last = per.last ?? ex.effectiveRestBetweenSets
                                next.perSetRestSeconds = per + [last]
                            }
                            didChange = true
                        }
                    } else if delta <= -2.0 {
                        next.suggestedWeight = max(0, ex.suggestedWeight * downWeightFactor)
                        if let maxW = ex.targetWeightMax {
                            next.targetWeightMax = maxW * downWeightFactor
                        }
                        didChange = true
                    }

                    updated.append(next)
                }

                if updated != day.exercises {
                    day.exercises = updated
                }
            }
        }

        if didChange {
            try savePlan(plan)
        }
    }
}
