//
//  UserRoutine.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData

/// Rutina editable por el usuario (no depende del plan generado).
@Model
final class UserRoutine {
    @Attribute(.unique) var id: UUID
    var name: String
    var isActive: Bool
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var days: [UserRoutineDay]

    init(name: String, isActive: Bool = true, days: [UserRoutineDay]) {
        self.id = UUID()
        self.name = name
        self.isActive = isActive
        self.createdAt = Date()
        self.days = days
    }

    static func emptyDefault(name: String = "Mi rutina") -> UserRoutine {
        let days = (1...7).map { UserRoutineDay(dayOfWeek: $0, isRestDay: false, exercises: []) }
        return UserRoutine(name: name, isActive: true, days: days)
    }
}

@Model
final class UserRoutineDay {
    var dayOfWeek: Int // 1...7 (Mon..Sun)
    var isRestDay: Bool
    var exercises: [PlannedExercise]
    /// Última vez que se completó un entreno de «Mi rutina» para este día (cualquier hora del día calendario).
    var lastRoutineWorkoutCompletedAt: Date?

    init(dayOfWeek: Int, isRestDay: Bool, exercises: [PlannedExercise]) {
        self.dayOfWeek = dayOfWeek
        self.isRestDay = isRestDay
        self.exercises = exercises
        self.lastRoutineWorkoutCompletedAt = nil
    }
}

