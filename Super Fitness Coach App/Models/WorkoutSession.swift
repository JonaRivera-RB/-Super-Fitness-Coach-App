//
//  WorkoutSession.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var workoutType: WorkoutType
    var exercises: [SessionExercise]
    var isCompleted: Bool
    var adjustmentApplied: AdjustmentAction
    var startedAt: Date?
    var completedAt: Date?

    init(date: Date, workoutType: WorkoutType, exercises: [SessionExercise]) {
        self.id = UUID()
        self.date = date
        self.workoutType = workoutType
        self.exercises = exercises
        self.isCompleted = false
        self.adjustmentApplied = .noChange
    }
}

struct SessionExercise: Codable, Identifiable {
    var id: String
    var name: String
    var target: String
    var equipment: String
    var gifUrl: String
    var instructions: [String]
    var sets: Int            // 3-5
    var reps: Int            // 8-15
    var isCompleted: Bool
    var estimatedDurationSeconds: Int
}

enum AdjustmentAction: String, Codable {
    case noChange
    case reduceSets
    case replaceWithLight
}
