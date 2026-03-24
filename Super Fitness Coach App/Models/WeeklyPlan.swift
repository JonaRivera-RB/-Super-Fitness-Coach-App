//
//  WeeklyPlan.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData

@Model
final class WeeklyPlan {
    @Attribute(.unique) var id: UUID
    var weekStartDate: Date
    var days: [DayPlan]
    var goal: FitnessGoal
    var createdAt: Date

    init(weekStartDate: Date, days: [DayPlan], goal: FitnessGoal) {
        self.id = UUID()
        self.weekStartDate = weekStartDate
        self.days = days
        self.goal = goal
        self.createdAt = Date()
    }
}

struct DayPlan: Codable {
    var dayOfWeek: Int       // 1=Mon, 7=Sun
    var workoutType: WorkoutType
}

enum WorkoutType: String, Codable, CaseIterable {
    case push, pull, legs, cardio, rest, lightCardio
}
