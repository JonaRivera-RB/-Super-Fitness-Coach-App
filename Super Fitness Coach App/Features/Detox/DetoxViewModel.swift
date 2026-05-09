//
//  DetoxViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation

@Observable
final class DetoxViewModel {
    private(set) var currentDay: Int = 1
    private(set) var dailyLogs: [Bool] = Array(repeating: false, count: 7)
    private(set) var isActive: Bool = false
    private(set) var isCompleted: Bool = false
    private(set) var earnedPoints: Int = 0

    /// Total bonus points available: 7 × 15 daily + 100 completion = 205
    let totalBonusPoints: Int = 205

    private let detoxManager: DetoxManager

    init(detoxManager: DetoxManager) {
        self.detoxManager = detoxManager
        refresh()
    }

    // MARK: - Actions

    func activateChallenge() {
        detoxManager.activateChallenge()
        refresh()
    }

    func deactivateChallenge() {
        guard let progress = detoxManager.currentProgress, progress.isActive else { return }
        progress.isActive = false
        progress.isCompleted = false
        progress.currentDay = 1
        progress.dailyLogs = Array(repeating: false, count: 7)
        detoxManager.loadActiveChallenge()
        refresh()
    }

    func markTodayAlcoholFree() {
        detoxManager.markDayAlcoholFree()
        refresh()
    }

    func refresh() {
        detoxManager.checkForMissedDay()
        if let progress = detoxManager.currentProgress {
            currentDay = progress.currentDay
            dailyLogs = progress.dailyLogs
            isActive = progress.isActive
            isCompleted = progress.isCompleted
            earnedPoints = calculateEarnedPoints()
        } else {
            currentDay = 1
            dailyLogs = Array(repeating: false, count: 7)
            isActive = false
            isCompleted = false
            earnedPoints = 0
        }
    }

    // MARK: - Helpers

    /// Whether today's log has already been marked
    var isTodayMarked: Bool {
        guard isActive, !isCompleted else { return false }
        let dayIndex = currentDay - 1
        guard dayIndex >= 0, dayIndex < dailyLogs.count else { return false }
        return dailyLogs[dayIndex]
    }

    /// Number of days marked so far
    var daysCompleted: Int {
        dailyLogs.filter { $0 }.count
    }

    private func calculateEarnedPoints() -> Int {
        let dailyPoints = dailyLogs.filter { $0 }.count * 15
        let completionBonus = isCompleted ? 100 : 0
        return dailyPoints + completionBonus
    }
}
