//
//  WorkoutRepository.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData
import os

final class WorkoutRepository {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "WorkoutRepository")

    init(context: ModelContext) {
        self.context = context
    }

    func saveWeeklyPlan(_ plan: WeeklyPlan) throws {
        context.insert(plan)
        do {
            try context.save()
        } catch {
            logger.warning("First saveWeeklyPlan attempt failed, retrying: \(error.localizedDescription)")
            do {
                try context.save()
            } catch {
                logger.error("Retry saveWeeklyPlan failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    func fetchCurrentWeekPlan() throws -> WeeklyPlan? {
        var descriptor = FetchDescriptor<WeeklyPlan>(
            sortBy: [SortDescriptor(\.weekStartDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func saveSession(_ session: WorkoutSession) throws {
        context.insert(session)
        do {
            try context.save()
        } catch {
            logger.warning("First saveSession attempt failed, retrying: \(error.localizedDescription)")
            do {
                try context.save()
            } catch {
                logger.error("Retry saveSession failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    func fetchSession(for date: Date) throws -> WorkoutSession? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.date >= startOfDay && session.date < endOfDay
            }
        )
        return try context.fetch(descriptor).first
    }
}
