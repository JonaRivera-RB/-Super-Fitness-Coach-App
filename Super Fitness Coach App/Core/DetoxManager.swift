//
//  DetoxManager.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

@Observable
final class DetoxManager {
    private(set) var currentProgress: DetoxProgress?

    private let repository: DetoxRepository
    private let gamificationEngine: GamificationEngine
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "DetoxManager")

    init(repository: DetoxRepository, gamificationEngine: GamificationEngine) {
        self.repository = repository
        self.gamificationEngine = gamificationEngine
        loadActiveChallenge()
    }

    // MARK: - Activate

    func activateChallenge() {
        let progress = DetoxProgress(startDate: Date())
        currentProgress = progress
        persistProgress(progress)
    }

    // MARK: - Mark Day Alcohol-Free

    func markDayAlcoholFree() {
        guard let progress = currentProgress, progress.isActive, !progress.isCompleted else {
            logger.warning("Cannot mark day: no active challenge")
            return
        }

        let dayIndex = progress.currentDay - 1
        guard dayIndex >= 0, dayIndex < progress.dailyLogs.count else {
            logger.error("Invalid day index: \(dayIndex)")
            return
        }

        progress.dailyLogs[dayIndex] = true
        gamificationEngine.awardPoints(
            GamificationEngine.pointsForAction(.detoxDay),
            for: .detoxDay
        )

        if progress.dailyLogs.allSatisfy({ $0 }) {
            completeChallenge()
        } else {
            progress.currentDay += 1
            persistProgress(progress)
        }
    }

    // MARK: - Check For Missed Day

    func checkForMissedDay() {
        guard let progress = currentProgress, progress.isActive, !progress.isCompleted else {
            return
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let expectedDate = calendar.date(
            byAdding: .day,
            value: progress.currentDay - 1,
            to: calendar.startOfDay(for: progress.startDate)
        ) ?? progress.startDate

        if startOfToday > expectedDate {
            logger.info("Missed day detected, resetting challenge")
            resetChallenge()
        }
    }

    // MARK: - Reset

    func resetChallenge() {
        guard let progress = currentProgress else { return }

        progress.currentDay = 1
        progress.dailyLogs = Array(repeating: false, count: 7)
        progress.startDate = Date()
        persistProgress(progress)
    }

    // MARK: - Complete

    func completeChallenge() {
        guard let progress = currentProgress else { return }

        progress.isCompleted = true
        progress.isActive = false

        gamificationEngine.awardPoints(
            GamificationEngine.pointsForAction(.detoxComplete),
            for: .detoxComplete
        )
        let _ = gamificationEngine.checkBadges()

        persistProgress(progress)
    }

    // MARK: - Load

    func loadActiveChallenge() {
        do {
            currentProgress = try repository.fetchActiveChallenge()
        } catch {
            logger.error("Failed to load active detox challenge: \(error.localizedDescription)")
        }
    }

    // MARK: - Persistence

    private func persistProgress(_ progress: DetoxProgress) {
        do {
            try repository.saveProgress(progress)
        } catch {
            logger.error("Failed to persist detox progress: \(error.localizedDescription)")
        }
    }
}
