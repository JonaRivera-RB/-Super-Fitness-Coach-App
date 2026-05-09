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
    /// vs el **último entreno previo en otro día** (evita comparar con guardados parciales del mismo día).
    private func computeWeightImprovements() {
        hasImproving = false
        var improvements: [(exerciseName: String, delta: Double)] = []
        var anyPreviousDayLog = false

        for log in workoutLogs {
            let currentMax = ProgressTracker.maxWeight(from: log)
            let displayName = log.notes ?? log.exerciseId

            do {
                guard let previousLog = try bestLogFromPreviousDays(exerciseId: log.exerciseId, sessionDate: log.date) else {
                    improvements.append((exerciseName: displayName, delta: 0.0))
                    continue
                }

                anyPreviousDayLog = true
                let previousMax = ProgressTracker.maxWeight(from: previousLog)
                let delta = currentMax - previousMax
                improvements.append((exerciseName: displayName, delta: delta))

                let status = ProgressTracker.compareProgress(current: log, previous: previousLog)
                if status == .improving { hasImproving = true }
            } catch {
                logger.error("Failed to fetch previous logs for \(log.exerciseId): \(error.localizedDescription)")
                improvements.append((exerciseName: displayName, delta: 0.0))
            }
        }

        weightImprovements = improvements
        isFirstWorkout = !anyPreviousDayLog
    }

    /// Mejor registro de un día **anterior** al día del entreno (no incluye el mismo día).
    private func bestLogFromPreviousDays(exerciseId: String, sessionDate: Date) throws -> WorkoutLog? {
        let all = try repository.fetchLogs(exerciseId: exerciseId, limit: 120)
        let sessionDay = Calendar.current.startOfDay(for: sessionDate)
        let older = all.filter { Calendar.current.startOfDay(for: $0.date) < sessionDay }
        guard !older.isEmpty else { return nil }

        let byDay = Dictionary(grouping: older) { Calendar.current.startOfDay(for: $0.date) }
        let bestPerDay: [WorkoutLog] = byDay.values.compactMap { logs in
            logs.max(by: { $0.sets.count < $1.sets.count })
        }
        return bestPerDay.max(by: { $0.date < $1.date })
    }

    // MARK: - Consecutive Days (Req 12.2)

    /// Reads the current streak from GamificationEngine.
    private func computeConsecutiveDays() {
        consecutiveDays = gamificationEngine.displayedStreak()
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
        consecutiveDays = gamificationEngine.displayedStreak()

        // Bonus for streak >= 3 (Req 11.2)
        if gamificationEngine.currentStreak >= 3 {
            let bonus = gamificationEngine.currentStreak * 10
            gamificationEngine.awardPoints(bonus, for: .workoutCompleted)
        }

        // Check for new badges
        let _ = gamificationEngine.checkBadges()
    }
}
