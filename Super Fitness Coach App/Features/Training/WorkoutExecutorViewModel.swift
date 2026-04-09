//
//  WorkoutExecutorViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os
#if canImport(UIKit)
import UIKit
#endif

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
    private let sessionId: String
    private let appLanguage: AppLanguage
    private var recoveryScore: Int = 50

    /// In-memory log buffer: exerciseId → accumulated SetLogs for this session.
    private var sessionSetBuffer: [String: (name: String, sets: [SetLog])] = [:]

    /// Cached previous sets per exercise for autofill/PR UI.
    private var previousSets: [String: [SetLog]] = [:]

    /// Cached previous best estimated 1RM per exercise (from latest log).
    private var previousBestE1RM: [String: Double] = [:]

    private var restTimer: Timer?

    /// Fin absoluto del descanso (reloj del sistema); permite seguir el tiempo al volver de segundo plano.
    private var restTimerDeadline: Date?

    /// `true` para «Mi rutina»: no se reduce el número de series por progresión ni recuperación.
    private let preservePrescribedVolume: Bool

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "WorkoutExecutorVM")

    // MARK: - Init

    init(
        currentWeek: Int,
        plannedExercises: [PlannedExercise],
        setLogger: SetLogger,
        healthKitManager: HealthKitManager,
        goal: FitnessGoal,
        sessionId: String,
        appLanguage: AppLanguage = .current,
        preservePrescribedVolume: Bool = false
    ) {
        self.currentWeek = currentWeek
        self.plannedExercises = plannedExercises
        self.setLogger = setLogger
        self.healthKitManager = healthKitManager
        self.goal = goal
        self.sessionId = sessionId
        self.appLanguage = appLanguage
        self.preservePrescribedVolume = preservePrescribedVolume

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

        // Mi rutina: respeta series y descansos por serie tal como los guardó el usuario (la progresión/deload
        // y la recuperación baja pueden bajar 4→3 series o recortar perSetRest).
        if preservePrescribedVolume {
            adjusted = zip(adjusted, plannedExercises).map { adj, orig in
                var x = adj
                x.sets = max(1, orig.sets)
                if let per = orig.perSetRestSeconds, per.count == orig.sets {
                    x.perSetRestSeconds = per
                } else if let per = orig.perSetRestSeconds {
                    x.perSetRestSeconds = per.count >= orig.sets ? Array(per.prefix(orig.sets)) : nil
                }
                return x
            }
        }

        self.exercises = adjusted
        self.currentExerciseIndex = 0

        // Initialize completed sets tracking: array of Bool arrays per exercise
        self.completedSets = adjusted.map { exercise in
            Array(repeating: false, count: exercise.sets)
        }
        self.prSets = adjusted.map { exercise in
            Array(repeating: false, count: exercise.sets)
        }

        // Step 4: Resume in-progress workout (same calendar day) from the latest persisted log.
        // This is why stats can show sets even if you close the screen: we log each set immediately.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for (idx, ex) in adjusted.enumerated() {
            guard let log = try? setLogger.latestLog(for: ex.effectiveCatalogId) else { continue }
            // With session-scoped logs, latestLog already corresponds to the session.
            guard sessionId.isEmpty || log.sessionId == sessionId else { continue }
            // Daily / "Mi rutina" path uses empty sessionId; latestLog is global per exercise.
            // Without this, yesterday's completed sets were applied to today → instant "workout complete".
            if sessionId.isEmpty {
                guard cal.startOfDay(for: log.date) == today else { continue }
            }
            let doneCount = min(ex.sets, log.sets.count)
            if doneCount > 0 {
                for s in 0..<doneCount {
                    completedSets[idx][s] = true
                    let setLog = log.sets[s]
                    prSets[idx][s] = isPR(catalogExerciseId: ex.effectiveCatalogId, weight: setLog.weight, reps: setLog.reps)
                }
            }
        }

        // Advance to the first exercise that still has incomplete sets.
        if let firstIncomplete = completedSets.firstIndex(where: { !$0.allSatisfy { $0 } }) {
            currentExerciseIndex = firstIncomplete
        }

        // If everything is already completed today (e.g., user closed the screen after logging sets),
        // mark the workout complete so the caller can complete the training day.
        let allDone = completedSets.allSatisfy { $0.allSatisfy { $0 } }
        if allDone, !adjusted.isEmpty {
            // Build completedLogs from today's latest logs per exercise.
            var logs: [WorkoutLog] = []
            for ex in adjusted {
                if let log = try? setLogger.latestLog(for: ex.effectiveCatalogId),
                   (sessionId.isEmpty || log.sessionId == sessionId),
                   cal.startOfDay(for: log.date) == today {
                    logs.append(log)
                }
            }
            completedLogs = logs
            isWorkoutComplete = true
        }

        if let first = adjusted.first {
            gymCoachMessage = GymCoach.sessionOpening(
                recoveryScore: recoveryScore,
                firstExerciseName: first.name,
                language: appLanguage
            )
        } else {
            gymCoachMessage = ""
        }

        logger.info("Built daily exercises: \(adjusted.count) exercises, week \(self.currentWeek), recovery \(self.recoveryScore)")
    }

    func previousDisplay(catalogExerciseId: String, setIndex: Int, unit: LiftingWeightUnit) -> String {
        guard let sets = previousSets[catalogExerciseId], sets.indices.contains(setIndex) else { return "—" }
        let s = sets[setIndex]
        let w = UnitConverter.formatLiftKgForDisplay(s.weight, unit: unit)
        return "\(w) × \(s.reps)"
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
            try setLogger.logSet(exerciseId: catalogId, date: Date(), set: setLog, notes: exercise.name)
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
                restSeconds: restSec,
                language: appLanguage
            )
            startRestTimer(exerciseIndex: exerciseIndex, completedSetIndex: setIndex)
        }
        if allSetsCompleted {
            stopRestTimer()
            // Avanza relativo al ejercicio que realmente se acaba de completar
            // (evita desajustes si el índice visible cambia durante un rerender).
            advanceToNextExercise(fromSkip: false, fromExerciseIndex: exerciseIndex)
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
        restTimerDeadline = seconds > 0 ? Date().addingTimeInterval(TimeInterval(seconds)) : nil

        guard seconds > 0 else { return }

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tickRestTimer()
        }
        RunLoop.main.add(timer, forMode: .common)
        restTimer = timer
    }

    /// Sincroniza el contador con el reloj del sistema (p. ej. al volver de segundo plano).
    func syncRestTimerFromDeadline() {
        guard isRestTimerActive, let deadline = restTimerDeadline else { return }
        let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        let previous = restTimerSeconds
        restTimerSeconds = remaining
        if remaining <= 0, previous > 0 {
            restTimerFinishedNaturally()
        }
    }

    private func tickRestTimer() {
        syncRestTimerFromDeadline()
    }

    private func restTimerFinishedNaturally() {
        restTimer?.invalidate()
        restTimer = nil
        restTimerDeadline = nil
        isRestTimerActive = false
        restTimerSeconds = 0
        #if canImport(UIKit)
        DispatchQueue.main.async {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
        #endif
    }

    /// Stops the rest timer. Called when user navigates away (Req 7.6).
    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restTimerDeadline = nil
        isRestTimerActive = false
        restTimerSeconds = 0
    }

    /// Pasa al siguiente ejercicio sin completar series (descanso, teclado, etc.).
    func skipCurrentExercise() {
        guard !exercises.isEmpty, !isWorkoutComplete else { return }
        stopRestTimer()
        let skipped = currentExerciseIndex
        advanceToNextExercise(fromSkip: true, fromExerciseIndex: skipped)
        logger.info("User skipped exercise at index \(skipped)")
    }

    /// Texto bajo «Tus series»: aclara Mi rutina vs plan guiado cuando el número de series difiere.
    enum SetsFooterInfo: Equatable {
        case none
        case miRutinaNote
        case planAdjusted(original: Int, current: Int)
    }

    func setsFooterInfo(for exerciseIndex: Int) -> SetsFooterInfo {
        guard exercises.indices.contains(exerciseIndex) else { return .none }
        if preservePrescribedVolume {
            return exerciseIndex == 0 ? .miRutinaNote : .none
        }
        guard plannedExercises.indices.contains(exerciseIndex) else { return .none }
        let original = plannedExercises[exerciseIndex].sets
        let current = exercises[exerciseIndex].sets
        if original != current { return .planAdjusted(original: original, current: current) }
        return .none
    }

    /// Ir a cualquier ejercicio del entreno (orden libre en gimnasio).
    func jumpToExercise(at index: Int) {
        guard exercises.indices.contains(index), !isWorkoutComplete else { return }
        stopRestTimer()
        currentExerciseIndex = index
        let ex = exercises[index]
        gymCoachMessage = GymCoach.exerciseIntro(
            exercise: ex,
            exerciseIndex: index,
            totalExercises: exercises.count,
            language: appLanguage
        )
        logger.info("Jumped to exercise at index \(index): \(ex.name)")
    }

    // MARK: - Private Helpers

    private func applyExerciseIntro(at index: Int) {
        let ex = exercises[index]
        gymCoachMessage = GymCoach.exerciseIntro(
            exercise: ex,
            exerciseIndex: index,
            totalExercises: exercises.count,
            language: appLanguage
        )
    }

    /// Tras completar todas las series del ejercicio actual o al pulsar «siguiente»:
    /// 1) Si ya no queda ninguna serie pendiente en ningún ejercicio → termina el entreno (vale desde cualquier posición 1…n).
    /// 2) Si el **siguiente** en orden tiene series sin hacer (no empezado o a medias) → va ahí.
    /// 3) Si el siguiente ya está **terminado** → va al **primer** ejercicio con series pendientes.
    /// 4) Si estás en el último de la lista y aún falta algo → primer pendiente.
    private func advanceToNextExercise(fromSkip: Bool, fromExerciseIndex: Int) {
        if completedSets.allSatisfy({ $0.allSatisfy { $0 } }) {
            finishWorkout()
            return
        }

        let i = fromExerciseIndex

        if i < exercises.count - 1 {
            let next = i + 1
            let nextNeedsWork = !completedSets[next].allSatisfy { $0 }
            if nextNeedsWork {
                currentExerciseIndex = next
                applyExerciseIntro(at: next)
                logger.info("Moved to next exercise in order at \(next) (fromSkip=\(fromSkip))")
            } else if let firstPending = completedSets.firstIndex(where: { !$0.allSatisfy { $0 } }) {
                currentExerciseIndex = firstPending
                applyExerciseIntro(at: firstPending)
                logger.info("Next in order already complete; moved to first pending at \(firstPending) (fromSkip=\(fromSkip))")
            }
        } else if let firstPending = completedSets.firstIndex(where: { !$0.allSatisfy { $0 } }) {
            currentExerciseIndex = firstPending
            applyExerciseIntro(at: firstPending)
            logger.info("At last exercise in list; moved to first pending at \(firstPending) (fromSkip=\(fromSkip))")
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
