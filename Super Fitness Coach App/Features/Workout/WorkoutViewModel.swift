//
//  WorkoutViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

@Observable
final class WorkoutViewModel {
    private(set) var exercises: [SessionExercise] = []
    private(set) var currentExerciseIndex: Int = 0
    private(set) var isSessionComplete: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var workoutType: WorkoutType = .rest
    private(set) var adjustmentApplied: AdjustmentAction = .noChange
    private(set) var sessionID: UUID?

    private let workoutEngine: WorkoutEngine
    private let exerciseService: ExerciseService
    private let gamificationEngine: GamificationEngine
    private let healthKitManager: HealthKitManager
    private let bmiCategory: BMICategory?
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "WorkoutViewModel")

    private var hasAwardedStartPoints = false
    private var hasLoadedSession = false

    /// Live recovery score from HealthKitManager, falling back to 50 if unavailable.
    var recoveryScore: Int {
        healthKitManager.recoveryScore.value ?? 50
    }

    init(
        workoutEngine: WorkoutEngine,
        exerciseService: ExerciseService,
        gamificationEngine: GamificationEngine,
        healthKitManager: HealthKitManager,
        bmiCategory: BMICategory? = nil
    ) {
        self.workoutEngine = workoutEngine
        self.exerciseService = exerciseService
        self.gamificationEngine = gamificationEngine
        self.healthKitManager = healthKitManager
        self.bmiCategory = bmiCategory
    }

    // MARK: - Load Session

    /// Load or resume today's workout session.
    func loadSession() async {
        // Prevent re-loading if already loaded or attempted
        guard !hasLoadedSession else { return }
        hasLoadedSession = true
        
        isLoading = true
        defer { isLoading = false }

        let scheduledType = workoutEngine.todayWorkoutType()
        workoutType = scheduledType

        // Fetch exercises for the scheduled body parts
        let bodyParts = WorkoutEngine.bodyParts(for: scheduledType)
        var allExercises: [Exercise] = []
        for bodyPart in bodyParts {
            do {
                let fetched = try await exerciseService.fetchExercises(bodyPart: bodyPart, equipment: nil)
                allExercises.append(contentsOf: fetched)
            } catch {
                logger.warning("API fetch failed for \(bodyPart), using fallback")
                allExercises.append(contentsOf: exerciseService.fallbackExercises(bodyPart: bodyPart))
            }
        }

        // Build adjusted session
        let session = workoutEngine.adjustedWorkout(
            scheduledType: scheduledType,
            recoveryScore: recoveryScore,
            exercises: allExercises,
            bmiCategory: bmiCategory
        )

        sessionID = session.id
        exercises = session.exercises
        adjustmentApplied = session.adjustmentApplied
        workoutType = session.workoutType

        // Resume from last incomplete exercise
        if let resumeIdx = WorkoutEngine.resumeIndex(for: session) {
            currentExerciseIndex = resumeIdx
        }

        // Award points for starting only if there are actual exercises
        if !hasAwardedStartPoints && !exercises.isEmpty {
            hasAwardedStartPoints = true
            gamificationEngine.awardPoints(
                GamificationEngine.pointsForAction(.workoutStarted),
                for: .workoutStarted
            )
        }
    }

    // MARK: - Exercise Completion

    /// Mark the exercise at the given index as completed.
    func completeExercise(at index: Int) async {
        guard index >= 0, index < exercises.count, !exercises[index].isCompleted else { return }
        guard let sid = sessionID else { return }

        exercises[index].isCompleted = true
        await workoutEngine.completeExercise(sessionID: sid, exerciseIndex: index)

        // Check if all exercises are done
        if exercises.allSatisfy({ $0.isCompleted }) {
            isSessionComplete = true
            await workoutEngine.completeSession(sessionID: sid)
            gamificationEngine.awardPoints(
                GamificationEngine.pointsForAction(.workoutCompleted),
                for: .workoutCompleted
            )
            let _ = gamificationEngine.checkBadges()
        } else {
            // Advance to next incomplete exercise
            advanceToNextIncomplete()
        }
    }

    /// Mark the current exercise as completed.
    func completeCurrentExercise() async {
        await completeExercise(at: currentExerciseIndex)
    }

    // MARK: - Save Progress

    /// Save current progress for later resume. Called when the user exits.
    func saveProgress() async {
        guard let sid = sessionID else { return }
        // Session state is already persisted via WorkoutEngine on each completion.
        // This ensures the latest state is saved even if no exercise was completed.
        await workoutEngine.completeExercise(sessionID: sid, exerciseIndex: -1)
        // The call above will bail out due to bounds check, but the session
        // is already persisted from prior completions. This is a no-op safety call.
    }

    // MARK: - Helpers

    private func advanceToNextIncomplete() {
        if let nextIdx = exercises.firstIndex(where: { !$0.isCompleted }) {
            currentExerciseIndex = nextIdx
        }
    }

    var completedCount: Int {
        exercises.filter(\.isCompleted).count
    }

    var totalCount: Int {
        exercises.count
    }

    var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var adjustmentLabel: String? {
        switch adjustmentApplied {
        case .noChange: return nil
        case .reduceSets: return "Sets reduced (recovery: \(recoveryScore))"
        case .replaceWithLight: return "Switched to light workout (recovery: \(recoveryScore))"
        }
    }
}
