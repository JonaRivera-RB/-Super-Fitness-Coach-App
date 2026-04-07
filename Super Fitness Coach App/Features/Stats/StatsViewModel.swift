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
        Task { @MainActor in
            await loadWorkoutHistory()
        }
    }

    @MainActor
    private func loadWorkoutHistory() async {
        do {
            let raw = try trainingPlanRepository.fetchAllLogs(limit: 500)
            // Build a name map for ids missing notes.
            let missingIds = Set(raw.compactMap { log in
                let hasNotes = (log.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                return hasNotes ? nil : log.exerciseId
            })
            var resolved: [String: String] = [:]
            for id in missingIds {
                if let name = await exerciseService.resolveExerciseName(exerciseId: id) {
                    resolved[id] = name
                }
            }

            recentHistory = Array(WorkoutHistoryAnalyzer.buildHistoryRows(
                from: raw,
                nameForExercise: { eid, notes in
                    if let n = notes, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return n
                    }
                    return resolved[eid] ?? eid
                }
            ).prefix(30))

            prRecords = Array(WorkoutHistoryAnalyzer.buildPRRows(
                from: raw,
                nameForExercise: { eid, notes in
                    if let n = notes, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return n
                    }
                    return resolved[eid] ?? eid
                }
            ).prefix(25))
        } catch {
            recentHistory = []
            prRecords = []
        }
    }
}
