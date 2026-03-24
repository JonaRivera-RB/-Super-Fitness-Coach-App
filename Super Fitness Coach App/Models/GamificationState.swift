//
//  GamificationState.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData

@Model
final class GamificationState {
    @Attribute(.unique) var id: UUID
    var totalPoints: Int
    var currentLevel: Int
    var currentStreak: Int
    var personalBestStreak: Int
    var lastActionDate: Date?
    var badges: [Badge]
    var workoutsCompleted: Int
    var detoxDaysCompleted: Int

    init() {
        self.id = UUID()
        self.totalPoints = 0
        self.currentLevel = 1
        self.currentStreak = 0
        self.personalBestStreak = 0
        self.badges = []
        self.workoutsCompleted = 0
        self.detoxDaysCompleted = 0
    }
}

struct Badge: Codable, Identifiable {
    var id: String
    var name: String
    var earnedAt: Date
}

enum BadgeMilestone: String, CaseIterable {
    case sevenDaysNoAlcohol = "7 days no alcohol"
    case fiveConsecutiveWorkouts = "5 consecutive workouts"
    case firstWorkout = "First workout completed"
    case levelTenReached = "Level 10 reached"
    case thirtyDayStreak = "30-day streak"
}

enum PointAction {
    case workoutCompleted   // 20 pts
    case workoutStarted     // 10 pts
    case goodSleep          // 10 pts
    case detoxDay           // 15 pts
    case detoxComplete      // 100 pts bonus
}
