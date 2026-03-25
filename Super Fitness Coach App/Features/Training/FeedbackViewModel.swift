//
//  FeedbackViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

@Observable
final class FeedbackViewModel {

    // MARK: - Published Properties

    /// Weight delta per exercise: (exerciseName, delta in kg vs previous workout).
    private(set) var weightImprovements: [(exerciseName: String, delta: Double)] = []

    /// Number of consecutive training days (from GamificationEngine streak).
    private(set) var consecutiveDays: Int = 0

    /// True if at least one exercise has ProgressStatus.improving.
    private(set) var hasImproving: Bool = false

    /// True when there is no previous workout data (first workout ever).
    private(set) var isFirstWorkout: Bool = false

    // MARK: - Private Properties

    private let workoutLogs: [WorkoutLog]
    private let repository: TrainingPlanRepository
    private let gamificationEngine: GamificationEngine

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "FeedbackVM")

    // MARK: - Init

    /// - Parameters:
    ///   - workoutLogs: The WorkoutLogs from the just-completed workout session.
    ///   - repository: Repository to fetch previous logs for comparison.
    ///   - gamificationEngine: Engine for points, streak, and badges.
    init(
        workoutLogs: [WorkoutLog],
        repository: TrainingPlanRepository,
        gamificationEngine: GamificationEngine
    ) {
        self.workoutLogs = workoutLogs
        self.repository = repository
        self.gamificationEngine = gamificationEngine
    }

    // MARK: - Load Feedback

    /// Computes all feedback metrics and awards gamification points.
    /// Call this once after navigating to FeedbackView.
    func loadFeedback() {
        computeWeightImprovements()
        computeConsecutiveDays()
        awardGamificationPoints()
    }

    // MARK: - Weight Improvements (Req 12.1)

    /// For each exercise in the just-completed workout, computes the weight delta
    /// vs the previous workout of the same exerciseId.
    private func computeWeightImprovements() {
        var improvements: [(exerciseName: String, delta: Double)] = []
        var hasPreviousData = false

        for log in workoutLogs {
            let currentMax = ProgressTracker.maxWeight(from: log)

            do {
                // Fetch the two most recent logs for this exercise.
                // The first one is the current workout (just saved), so we need the second.
                let recentLogs = try repository.fetchLogs(exerciseId: log.exerciseId, limit: 2)
                let previousLog = recentLogs.count >= 2 ? recentLogs[1] : nil

                if let previousLog {
                    hasPreviousData = true
                    let previousMax = ProgressTracker.maxWeight(from: previousLog)
                    let delta = currentMax - previousMax
                    improvements.append((exerciseName: log.exerciseId, delta: delta))

                    // Check improving status (Req 12.3)
                    let status = ProgressTracker.compareProgress(current: log, previous: previousLog)
                    if status == .improving {
                        hasImproving = true
                    }
                } else {
                    // No previous data for this exercise
                    improvements.append((exerciseName: log.exerciseId, delta: 0.0))
                }
            } catch {
                logger.error("Failed to fetch previous logs for \(log.exerciseId): \(error.localizedDescription)")
                improvements.append((exerciseName: log.exerciseId, delta: 0.0))
            }
        }

        weightImprovements = improvements

        // Req 12.4: If no previous data exists at all, mark as first workout
        isFirstWorkout = !hasPreviousData
    }

    // MARK: - Consecutive Days (Req 12.2)

    /// Reads the current streak from GamificationEngine.
    private func computeConsecutiveDays() {
        consecutiveDays = gamificationEngine.currentStreak
    }

    // MARK: - Gamification (Req 11.1, 11.2, 11.3)

    /// Awards points for completing a training plan workout.
    /// - 100 points base (Req 11.1)
    /// - Updates streak (Req 11.3)
    /// - If streak >= 3, awards bonus: streak × 10 additional points (Req 11.2)
    private func awardGamificationPoints() {
        // Award 100 points for completed training plan workout (Req 11.1)
        gamificationEngine.awardPoints(100, for: .workoutCompleted)

        // Update streak (Req 11.3)
        gamificationEngine.updateStreak(hasActionToday: true)

        // Refresh consecutive days after streak update
        consecutiveDays = gamificationEngine.currentStreak

        // Bonus for streak >= 3 (Req 11.2)
        if gamificationEngine.currentStreak >= 3 {
            let bonus = gamificationEngine.currentStreak * 10
            gamificationEngine.awardPoints(bonus, for: .workoutCompleted)
        }

        // Check for new badges
        let _ = gamificationEngine.checkBadges()
    }
}
