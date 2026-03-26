//
//  StatsViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation

@Observable
final class StatsViewModel {
    private(set) var totalPoints: Int = 0
    private(set) var currentLevel: Int = 1
    private(set) var currentStreak: Int = 0
    private(set) var personalBestStreak: Int = 0
    private(set) var badges: [Badge] = []

    private(set) var recentHistory: [WorkoutHistoryRow] = []
    private(set) var prRecords: [PRRecordRow] = []

    private let gamificationEngine: GamificationEngine
    private let trainingPlanRepository: TrainingPlanRepository
    private let exerciseService: ExerciseService

    init(
        gamificationEngine: GamificationEngine,
        trainingPlanRepository: TrainingPlanRepository,
        exerciseService: ExerciseService
    ) {
        self.gamificationEngine = gamificationEngine
        self.trainingPlanRepository = trainingPlanRepository
        self.exerciseService = exerciseService
        refresh()
    }

    func refresh() {
        totalPoints = gamificationEngine.totalPoints
        currentLevel = gamificationEngine.currentLevel
        currentStreak = gamificationEngine.currentStreak
        personalBestStreak = gamificationEngine.personalBestStreak
        badges = gamificationEngine.badges
        loadWorkoutHistory()
    }

    private func loadWorkoutHistory() {
        do {
            let raw = try trainingPlanRepository.fetchAllLogs(limit: 500)
            recentHistory = Array(WorkoutHistoryAnalyzer.buildHistoryRows(from: raw, nameForExercise: { self.displayName(exerciseId: $0, notes: $1) }).prefix(30))
            prRecords = Array(WorkoutHistoryAnalyzer.buildPRRows(from: raw, nameForExercise: { self.displayName(exerciseId: $0, notes: $1) }).prefix(25))
        } catch {
            recentHistory = []
            prRecords = []
        }
    }

    private func displayName(exerciseId: String, notes: String?) -> String {
        if let n = notes, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return n
        }
        return exerciseService.bundledExercise(withId: exerciseId)?.name ?? exerciseId
    }
}
