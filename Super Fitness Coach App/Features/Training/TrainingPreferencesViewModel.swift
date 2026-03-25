//
//  TrainingPreferencesViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

@Observable
final class TrainingPreferencesViewModel {

    // MARK: - Preferences (Req 1.1)

    var goal: FitnessGoal = .gainMuscle
    var trainingDaysPerWeek: Int = 4
    var experienceLevel: FitnessLevel = .beginner
    var priorityMuscles: [MuscleGroup] = []
    var wantsCardio: Bool = false
    var planDurationWeeks: Int = 4 // Req 1.5: default 4
    var restDays: Set<Int> = [6, 7] // Default: Saturday, Sunday

    // MARK: - State

    private(set) var isGenerating: Bool = false
    private(set) var generatedPlan: TrainingPlan?
    private(set) var errorMessage: String?
    private(set) var didGenerate: Bool = false

    // MARK: - Dependencies

    private let exerciseService: ExerciseService
    private let repository: TrainingPlanRepository
    @ObservationIgnored private let logger = Logger(subsystem: "com.superfitnesscoach", category: "TrainingPreferencesVM")

    // MARK: - Init

    init(exerciseService: ExerciseService, repository: TrainingPlanRepository) {
        self.exerciseService = exerciseService
        self.repository = repository
    }

    // MARK: - Muscle Toggle (Req 1.3)

    /// Reset state for re-opening the preferences sheet.
    func resetState() {
        didGenerate = false
        errorMessage = nil
    }

    /// Toggles a muscle in the priority list.
    /// If already selected, removes it. If not selected and count < 2, adds it.
    /// If count >= 2, does nothing (limit enforced).
    func toggleMuscle(_ muscle: MuscleGroup) {
        if let index = priorityMuscles.firstIndex(of: muscle) {
            priorityMuscles.remove(at: index)
        } else if priorityMuscles.count < 2 {
            priorityMuscles.append(muscle)
        }
        // If count >= 2 and muscle not already selected, silently reject (Req 1.3)
    }

    // MARK: - Plan Generation (Req 1.1, 1.2, 1.4)

    /// Generates a training plan from current preferences, persists it via repository.
    func generatePlan() async {
        isGenerating = true
        errorMessage = nil
        didGenerate = false

        defer { isGenerating = false }

        let preferences = TrainingPreferences(
            goal: goal,
            trainingDaysPerWeek: trainingDaysPerWeek,
            experienceLevel: experienceLevel,
            priorityMuscles: priorityMuscles,
            wantsCardio: wantsCardio,
            planDurationWeeks: planDurationWeeks
        )

        // Fetch exercises — use fallback if API fails
        let allBodyParts = Set(MuscleGroup.allCases.map(\.apiBodyPart))
        var exercises: [Exercise] = []

        for bodyPart in allBodyParts {
            do {
                let fetched = try await exerciseService.fetchExercises(bodyPart: bodyPart, equipment: nil)
                exercises.append(contentsOf: fetched)
            } catch {
                logger.warning("Failed to fetch exercises for \(bodyPart), using fallback")
                let fallback = exerciseService.fallbackExercises(bodyPart: bodyPart)
                exercises.append(contentsOf: fallback)
            }
        }

        // If still empty after fallback, try all fallback exercises
        if exercises.isEmpty {
            for bodyPart in allBodyParts {
                exercises.append(contentsOf: exerciseService.fallbackExercises(bodyPart: bodyPart))
            }
        }

        guard !exercises.isEmpty else {
            errorMessage = "No exercises available. Check your connection."
            return
        }

        // Fetch previous logs for weight suggestions
        var previousLogs: [WorkoutLog] = []
        for exercise in exercises {
            if let log = try? repository.fetchLatestLog(exerciseId: exercise.id) {
                previousLogs.append(log)
            }
        }

        // Generate the plan with user-selected rest days
        let plan = TrainingPlanGenerator.generatePlan(
            preferences: preferences,
            exercises: exercises,
            previousLogs: previousLogs,
            restDays: restDays
        )

        // Verify exercises were assigned
        let totalExercises = plan.weeks.flatMap(\.days).flatMap(\.exercises).count
        guard totalExercises > 0 else {
            errorMessage = "Could not assign exercises to the plan. Try again."
            return
        }

        // Persist
        do {
            try repository.savePlan(plan)
            generatedPlan = plan
            didGenerate = true
            logger.info("Training plan generated and saved: \(plan.weeks.count) weeks")
        } catch {
            logger.error("Failed to save training plan: \(error.localizedDescription)")
            errorMessage = "No se pudo guardar el plan. Intenta de nuevo."
        }
    }
}
