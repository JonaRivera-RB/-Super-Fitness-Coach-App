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

    /// Tracks completed sets per exercise.
    private(set) var completedSets: [[Bool]] = []

    /// Tracks whether a completed set is a PR (estimated 1RM) vs the latest logged workout for that exercise.
    private(set) var prSets: [[Bool]] = []

    /// True when every set of every exercise has been completed.
    private(set) var isWorkoutComplete: Bool = false

    /// WorkoutLogs collected during this session — available once isWorkoutComplete = true.
    private(set) var completedLogs: [WorkoutLog] = []

    /// Micro-coaching en gimnasio (texto en español para la UI).
    private(set) var gymCoachMessage: String = ""

    // MARK: - Private Properties

    private let currentWeek: Int
    private let plannedExercises: [PlannedExercise]
    private let setLogger: SetLogger
    private let healthKitManager: HealthKitManager
    private var recoveryScore: Int = 50

    /// In-memory log buffer: exerciseId → accumulated SetLogs for this session.
    private var sessionSetBuffer: [String: (name: String, sets: [SetLog])] = [:]

    /// Cached previous sets per exercise for autofill/PR UI.
    private var previousSets: [String: [SetLog]] = [:]

    /// Cached previous best estimated 1RM per exercise (from latest log).
    private var previousBestE1RM: [String: Double] = [:]

    private var restTimer: Timer?

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "WorkoutExecutorVM")

    // MARK: - Init

    init(
        currentWeek: Int,
        plannedExercises: [PlannedExercise],
        setLogger: SetLogger,
        healthKitManager: HealthKitManager
    ) {
        self.currentWeek = currentWeek
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
        let progression = WeeklyProgressionEngine.progression(for: currentWeek)
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

        // Cache previous sets for autofill / "previous" column.
        var prev: [String: [SetLog]] = [:]
        var prevBest: [String: Double] = [:]
        for ex in adjusted {
            let catalogKey = ex.effectiveCatalogId
            if let log = try? setLogger.latestLog(for: catalogKey) {
                prev[catalogKey] = log.sets
                prevBest[catalogKey] = log.sets
                    .map { Self.estimate1RM(weight: $0.weight, reps: $0.reps) }
                    .max()
            }
        }
        self.previousSets = prev
        self.previousBestE1RM = prevBest

        // Initialize completed sets tracking: array of Bool arrays per exercise
        self.completedSets = adjusted.map { exercise in
            Array(repeating: false, count: exercise.sets)
        }
        self.prSets = adjusted.map { exercise in
            Array(repeating: false, count: exercise.sets)
        }

        if let first = adjusted.first {
            gymCoachMessage = GymCoach.sessionOpening(
                recoveryScore: recoveryScore,
                firstExerciseName: first.name
            )
        } else {
            gymCoachMessage = ""
        }

        logger.info("Built daily exercises: \(adjusted.count) exercises, week \(self.currentWeek), recovery \(self.recoveryScore)")
    }

    func previousDisplay(catalogExerciseId: String, setIndex: Int) -> String {
        guard let sets = previousSets[catalogExerciseId], sets.indices.contains(setIndex) else { return "—" }
        let s = sets[setIndex]
        return "\(String(format: "%.0f", s.weight)) × \(s.reps)"
    }

    func defaultWeight(exercise: PlannedExercise, setIndex: Int) -> Double {
        let key = exercise.effectiveCatalogId
        if let sets = previousSets[key], sets.indices.contains(setIndex) {
            return sets[setIndex].weight
        }
        return exercise.suggestedWeight
    }

    func defaultReps(exercise: PlannedExercise, setIndex: Int) -> Int {
        let key = exercise.effectiveCatalogId
        if let sets = previousSets[key], sets.indices.contains(setIndex) {
            return sets[setIndex].reps
        }
        return exercise.reps
    }

    func isPR(catalogExerciseId: String, weight: Double, reps: Int) -> Bool {
        guard weight > 0, reps > 0 else { return false }
        let e1rm = Self.estimate1RM(weight: weight, reps: reps)
        guard let prevBest = previousBestE1RM[catalogExerciseId] else {
            // No prior log: treat the first meaningful set as PR.
            return true
        }
        return e1rm > prevBest + 0.01
    }

    private static func estimate1RM(weight: Double, reps: Int) -> Double {
        // Epley: e1RM = w * (1 + reps/30)
        let r = max(1, reps)
        return weight * (1.0 + Double(r) / 30.0)
    }

    // MARK: - Complete Set (Req 7.2, 8.1)

    func completeSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int) {
        guard exerciseIndex < exercises.count,
              setIndex < (completedSets[safe: exerciseIndex]?.count ?? 0) else {
            logger.warning("completeSet called with invalid indices: exercise \(exerciseIndex), set \(setIndex)")
            return
        }

        let exercise = exercises[exerciseIndex]
        prSets[exerciseIndex][setIndex] = isPR(catalogExerciseId: exercise.effectiveCatalogId, weight: weight, reps: reps)
        completedSets[exerciseIndex][setIndex] = true

        // Accumulate set in session buffer (keyed by exerciseId)
        let setLog = SetLog(weight: weight, reps: reps)
        if sessionSetBuffer[exercise.id] == nil {
            sessionSetBuffer[exercise.id] = (name: exercise.name, sets: [])
        }
        sessionSetBuffer[exercise.id]?.sets.append(setLog)

        // Persist immediately via SetLogger (Req 8.1)
        do {
            try setLogger.logSet(exerciseId: exercise.id, date: Date(), set: setLog)
        } catch {
            logger.error("Failed to log set: \(error.localizedDescription)")
        }

        let allSetsCompleted = completedSets[exerciseIndex].allSatisfy { $0 }
        if !allSetsCompleted {
            let restSec = exercise.restSeconds(afterCompletingSet: setIndex)
            gymCoachMessage = GymCoach.messageAfterSet(
                wasPR: prSets[exerciseIndex][setIndex],
                exercise: exercise,
                completedSetIndex: setIndex,
                totalSets: exercise.sets,
                restSeconds: restSec
            )
            startRestTimer(exerciseIndex: exerciseIndex, completedSetIndex: setIndex)
        }
        if allSetsCompleted {
            stopRestTimer()
            advanceToNextExercise()
        }
    }

    // MARK: - Rest Timer (Req 7.3, 7.4)

    /// Inicia el temporizador de descanso según el ejercicio (y opcionalmente por serie).
    func startRestTimer(exerciseIndex: Int, completedSetIndex: Int) {
        stopRestTimer()

        guard exerciseIndex < exercises.count else { return }
        let ex = exercises[exerciseIndex]
        let seconds = ex.restSeconds(afterCompletingSet: completedSetIndex)
        restTimerSeconds = seconds
        isRestTimerActive = seconds > 0

        guard seconds > 0 else { return }

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

    private func advanceToNextExercise() {
        if currentExerciseIndex < exercises.count - 1 {
            currentExerciseIndex += 1
            let ex = exercises[currentExerciseIndex]
            gymCoachMessage = GymCoach.exerciseIntro(
                exercise: ex,
                exerciseIndex: currentExerciseIndex,
                totalExercises: exercises.count
            )
            logger.info("Advanced to exercise \(self.currentExerciseIndex): \(ex.name)")
        } else {
            finishWorkout()
        }
    }

    private func finishWorkout() {
        stopRestTimer()
        isWorkoutComplete = true

        // Build WorkoutLog array with real exercise names from the session buffer
        completedLogs = sessionSetBuffer.map { exerciseId, entry in
            WorkoutLog(exerciseId: exerciseId, date: Date(), sets: entry.sets, notes: entry.name)
        }

        logger.info("Workout complete: \(self.completedLogs.count) exercises logged")
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
