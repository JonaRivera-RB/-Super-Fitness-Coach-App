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
    private let goal: FitnessGoal
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
        healthKitManager: HealthKitManager,
        goal: FitnessGoal
    ) {
        self.currentWeek = currentWeek
        self.plannedExercises = plannedExercises
        self.setLogger = setLogger
        self.healthKitManager = healthKitManager
        self.goal = goal

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

        // Step 2: Use performance (latest e1RM) to set today's target weight from rep target.
        // This keeps intensity aligned with the user's real strength, not just past suggestedWeight.
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

        adjusted = adjusted.map { ex in
            guard let e1rm = prevBest[ex.effectiveCatalogId], e1rm > 0 else { return ex }
            var next = ex
            let pct = Self.targetPercentForExercise(goal: goal, isCompound: ex.isCompound, targetReps: ex.reps)
            let target = e1rm * pct
            if target > 0 {
                next.suggestedWeight = target
                // Keep targetWeightMax only for gain muscle, otherwise nil to reduce noise.
                if goal != .gainMuscle {
                    next.targetWeightMax = nil
                } else if let maxW = next.targetWeightMax, maxW > 0 {
                    // Re-scale max to stay consistent with new base weight.
                    let ratio = maxW / max(1e-6, ex.suggestedWeight)
                    next.targetWeightMax = target * ratio
                }
            }
            return next
        }

        // Step 3: Apply recovery adjustment (override)
        let adjustment = RecoveryAdapter.dailyAdjustment(recoveryScore: recoveryScore)
        adjusted = adjusted.map { RecoveryAdapter.applyAdjustment(to: $0, adjustment: adjustment) }

        self.exercises = adjusted
        self.currentExerciseIndex = 0

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

    // MARK: - Intensity table (reps → %1RM)

    /// Approximate %1RM for a given "to-failure" rep count (EduFitness-style guidance).
    /// We use anchor points and linear interpolation for smooth behavior.
    private static func percent1RM(for reps: Int) -> Double {
        let r = max(1, min(30, reps))
        // Anchors (reps : %1RM). These are approximate and intentionally conservative.
        let anchors: [(Int, Double)] = [
            (1, 1.00),
            (2, 0.95),
            (3, 0.93),
            (4, 0.90),
            (5, 0.87),
            (6, 0.85),
            (7, 0.83),
            (8, 0.80),
            (9, 0.77),
            (10, 0.75),
            (12, 0.70),
            (15, 0.65),
            (20, 0.60),
            (25, 0.55),
            (30, 0.50),
        ]

        // Exact match
        if let exact = anchors.first(where: { $0.0 == r }) {
            return exact.1
        }

        // Find surrounding anchors
        var lower = anchors[0]
        var upper = anchors[anchors.count - 1]
        for i in 0..<(anchors.count - 1) {
            let a = anchors[i]
            let b = anchors[i + 1]
            if r > a.0 && r < b.0 {
                lower = a
                upper = b
                break
            }
        }

        let t = Double(r - lower.0) / Double(upper.0 - lower.0)
        return lower.1 + (upper.1 - lower.1) * t
    }

    private static func targetPercentForExercise(goal: FitnessGoal, isCompound: Bool, targetReps: Int) -> Double {
        // Default: derive from reps table.
        // For Lose Weight we bias slightly lighter to keep technique clean with short rests,
        // but still anchored to reps target.
        var pct = percent1RM(for: targetReps)
        switch goal {
        case .loseWeight:
            pct *= isCompound ? 0.98 : 0.96
        case .beHealthy:
            pct *= 0.98
        case .gainMuscle:
            pct *= 1.00
        }
        return max(0.40, min(1.00, pct))
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
        let catalogId = exercise.effectiveCatalogId
        if sessionSetBuffer[catalogId] == nil {
            sessionSetBuffer[catalogId] = (name: exercise.name, sets: [])
        }
        sessionSetBuffer[catalogId]?.sets.append(setLog)

        // Persist immediately via SetLogger (Req 8.1)
        do {
            // IMPORTANT: persist by catalog id so history, PRs, and plan updates match.
            try setLogger.logSet(exerciseId: catalogId, date: Date(), set: setLog)
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
