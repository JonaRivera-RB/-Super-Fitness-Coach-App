//
//  WorkoutExecutorViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

@Observable
final class WorkoutExecutorViewModel {

    // MARK: - Published Properties

    /// Exercises for today's workout, adjusted by progression + recovery.
    private(set) var exercises: [PlannedExercise] = []

    /// Index of the exercise currently being executed.
    private(set) var currentExerciseIndex: Int = 0

    /// Remaining seconds on the rest timer.
    private(set) var restTimerSeconds: Int = 0

    /// Whether the rest timer is actively counting down.
    private(set) var isRestTimerActive: Bool = false

    /// Tracks completed sets per exercise: completedSets[exerciseIndex] is a set of completed setIndices.
    private(set) var completedSets: [[Bool]] = []

    // MARK: - Private Properties

    private let plan: TrainingPlan
    private let plannedExercises: [PlannedExercise]
    private let setLogger: SetLogger
    private let healthKitManager: HealthKitManager
    private var recoveryScore: Int = 50

    private var restTimer: Timer?

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "WorkoutExecutorVM")

    // MARK: - Init

    init(
        plan: TrainingPlan,
        plannedExercises: [PlannedExercise],
        setLogger: SetLogger,
        healthKitManager: HealthKitManager
    ) {
        self.plan = plan
        self.plannedExercises = plannedExercises
        self.setLogger = setLogger
        self.healthKitManager = healthKitManager

        // Read recovery score from HealthKitManager; default 50 if unavailable (Req 6.1)
        self.recoveryScore = healthKitManager.recoveryScore.value ?? 50
    }

    // MARK: - Build Daily Exercises (Req 7.1)

    /// Constructs today's exercises by applying weekly progression FIRST,
    /// then recovery adjustment (recovery overrides).
    ///
    /// **Critical order: progression → recovery.**
    /// Weekly progression sets the base intensity, then recovery adjustment
    /// overrides/modifies the resulting values. This ensures the user's
    /// current physical state always has the final say on workout intensity.
    func buildDailyExercises() {
        // Refresh recovery score from HealthKitManager
        recoveryScore = healthKitManager.recoveryScore.value ?? 50

        // Step 1: Apply weekly progression (base intensity)
        let progression = WeeklyProgressionEngine.progression(for: plan.currentWeek)
        var adjusted = plannedExercises.map {
            WeeklyProgressionEngine.applyProgression(to: $0, progression: progression)
        }

        // Step 2: Apply recovery adjustment (override)
        let adjustment = RecoveryAdapter.dailyAdjustment(recoveryScore: recoveryScore)
        adjusted = adjusted.map {
            RecoveryAdapter.applyAdjustment(to: $0, adjustment: adjustment)
        }

        self.exercises = adjusted
        self.currentExerciseIndex = 0

        // Initialize completed sets tracking: array of Bool arrays per exercise
        self.completedSets = adjusted.map { exercise in
            Array(repeating: false, count: exercise.sets)
        }

        logger.info("Built daily exercises: \(adjusted.count) exercises, week \(self.plan.currentWeek), recovery \(self.recoveryScore)")
    }

    // MARK: - Complete Set (Req 7.2, 8.1)

    /// Marks a set as completed, logs it via SetLogger, and starts the rest timer.
    /// When all sets of an exercise are completed, auto-advances to the next exercise (Req 7.5).
    func completeSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int) {
        guard exerciseIndex < exercises.count,
              setIndex < (completedSets[safe: exerciseIndex]?.count ?? 0) else {
            logger.warning("completeSet called with invalid indices: exercise \(exerciseIndex), set \(setIndex)")
            return
        }

        // Mark set as completed
        completedSets[exerciseIndex][setIndex] = true

        // Log the set via SetLogger (Req 8.1)
        let exercise = exercises[exerciseIndex]
        let setLog = SetLog(weight: weight, reps: reps)
        do {
            try setLogger.logSet(exerciseId: exercise.id, date: Date(), set: setLog)
        } catch {
            logger.error("Failed to log set: \(error.localizedDescription)")
        }

        // Start rest timer (Req 7.3)
        startRestTimer()

        // Check if all sets for this exercise are completed (Req 7.5)
        let allSetsCompleted = completedSets[exerciseIndex].allSatisfy { $0 }
        if allSetsCompleted {
            advanceToNextExercise()
        }
    }

    // MARK: - Rest Timer (Req 7.3, 7.4)

    /// Starts a 60-second rest timer. Not editable in MVP (Req 7.4).
    func startRestTimer() {
        stopRestTimer()

        restTimerSeconds = 60
        isRestTimerActive = true

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if self.restTimerSeconds > 0 {
                self.restTimerSeconds -= 1
            } else {
                self.stopRestTimer()
            }
        }
    }

    /// Stops the rest timer. Called when user navigates away (Req 7.6).
    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        isRestTimerActive = false
        restTimerSeconds = 0
    }

    // MARK: - Private Helpers

    /// Advances to the next exercise when all sets of the current one are completed (Req 7.5).
    private func advanceToNextExercise() {
        if currentExerciseIndex < exercises.count - 1 {
            currentExerciseIndex += 1
            logger.info("Advanced to exercise \(self.currentExerciseIndex): \(self.exercises[self.currentExerciseIndex].name)")
        } else {
            logger.info("All exercises completed")
        }
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
