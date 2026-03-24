//
//  GamificationEngine.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

@Observable
final class GamificationEngine {
    private(set) var totalPoints: Int = 0
    private(set) var currentLevel: Int = 1
    private(set) var currentStreak: Int = 0
    private(set) var personalBestStreak: Int = 0
    private(set) var badges: [Badge] = []
    private(set) var workoutsCompleted: Int = 0
    private(set) var detoxDaysCompleted: Int = 0

    private let repository: GamificationRepository
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "GamificationEngine")

    init(repository: GamificationRepository) {
        self.repository = repository
        loadState()
    }

    // MARK: - Points

    static func pointsForAction(_ action: PointAction) -> Int {
        switch action {
        case .workoutCompleted: return 20
        case .workoutStarted:  return 10
        case .goodSleep:       return 10
        case .detoxDay:        return 15
        case .detoxComplete:   return 100
        }
    }

    func awardPoints(_ points: Int, for action: PointAction) {
        totalPoints += points

        if action == .workoutCompleted {
            workoutsCompleted += 1
        }
        if action == .detoxDay || action == .detoxComplete {
            if action == .detoxDay {
                detoxDaysCompleted += 1
            }
        }

        currentLevel = Self.calculateLevel(totalPoints: totalPoints)
        persistState()
    }

    // MARK: - Level

    static func calculateLevel(totalPoints: Int) -> Int {
        guard totalPoints > 0 else { return 1 }
        let pts = Double(totalPoints)
        let level = Int(floor((sqrt(1.0 + 8.0 * pts / 100.0) - 1.0) / 2.0) + 1.0)
        return min(max(level, 1), 100)
    }

    // MARK: - Streaks

    func updateStreak(hasActionToday: Bool) {
        if hasActionToday {
            currentStreak += 1
            if currentStreak > personalBestStreak {
                personalBestStreak = currentStreak
            }
        } else {
            if currentStreak > personalBestStreak {
                personalBestStreak = currentStreak
            }
            currentStreak = 0
        }
        persistState()
    }

    // MARK: - Badges

    func checkBadges() -> [Badge] {
        var newBadges: [Badge] = []
        for milestone in BadgeMilestone.allCases {
            let alreadyEarned = badges.contains { $0.id == milestone.rawValue }
            if !alreadyEarned && Self.isMilestoneReached(
                milestone: milestone,
                totalPoints: totalPoints,
                currentStreak: currentStreak,
                workoutsCompleted: workoutsCompleted,
                detoxDaysCompleted: detoxDaysCompleted,
                currentLevel: currentLevel
            ) {
                let badge = Badge(id: milestone.rawValue, name: milestone.rawValue, earnedAt: Date())
                badges.append(badge)
                newBadges.append(badge)
            }
        }
        if !newBadges.isEmpty {
            persistState()
        }
        return newBadges
    }

    static func isMilestoneReached(
        milestone: BadgeMilestone,
        totalPoints: Int,
        currentStreak: Int,
        workoutsCompleted: Int,
        detoxDaysCompleted: Int,
        currentLevel: Int
    ) -> Bool {
        switch milestone {
        case .sevenDaysNoAlcohol:
            return detoxDaysCompleted >= 7
        case .fiveConsecutiveWorkouts:
            return currentStreak >= 5
        case .firstWorkout:
            return workoutsCompleted >= 1
        case .levelTenReached:
            return currentLevel >= 10
        case .thirtyDayStreak:
            return currentStreak >= 30
        }
    }

    // MARK: - Persistence

    private func loadState() {
        do {
            if let state = try repository.fetchState() {
                totalPoints = state.totalPoints
                currentLevel = state.currentLevel
                currentStreak = state.currentStreak
                personalBestStreak = state.personalBestStreak
                badges = state.badges
                workoutsCompleted = state.workoutsCompleted
                detoxDaysCompleted = state.detoxDaysCompleted
            }
        } catch {
            logger.error("Failed to load gamification state: \(error.localizedDescription)")
        }
    }

    private func persistState() {
        do {
            if let state = try repository.fetchState() {
                state.totalPoints = totalPoints
                state.currentLevel = currentLevel
                state.currentStreak = currentStreak
                state.personalBestStreak = personalBestStreak
                state.badges = badges
                state.workoutsCompleted = workoutsCompleted
                state.detoxDaysCompleted = detoxDaysCompleted
                try repository.saveState(state)
            } else {
                let state = GamificationState()
                state.totalPoints = totalPoints
                state.currentLevel = currentLevel
                state.currentStreak = currentStreak
                state.personalBestStreak = personalBestStreak
                state.badges = badges
                state.workoutsCompleted = workoutsCompleted
                state.detoxDaysCompleted = detoxDaysCompleted
                try repository.saveState(state)
            }
        } catch {
            logger.error("Failed to persist gamification state: \(error.localizedDescription)")
        }
    }
}
