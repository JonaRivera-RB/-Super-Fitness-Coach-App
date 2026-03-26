//
//  UserRoutineRepository.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData
import os

final class UserRoutineRepository {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "UserRoutineRepository")

    init(context: ModelContext) {
        self.context = context
    }

    func fetchActive() throws -> UserRoutine? {
        let descriptor = FetchDescriptor<UserRoutine>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func getOrCreateActiveDefault() throws -> UserRoutine {
        if let existing = try fetchActive() { return existing }
        let created = UserRoutine.emptyDefault()
        context.insert(created)
        try context.save()
        logger.info("Created default UserRoutine")
        return created
    }

    func save() throws {
        try context.save()
    }

    /// Marca el día de la semana como entreno completado hoy (Mi rutina).
    func markRoutineDayCompleted(dayOfWeek: Int) throws {
        guard let routine = try fetchActive() else { return }
        guard let day = routine.days.first(where: { $0.dayOfWeek == dayOfWeek }) else { return }
        day.lastRoutineWorkoutCompletedAt = Date()
        try save()
    }
}

