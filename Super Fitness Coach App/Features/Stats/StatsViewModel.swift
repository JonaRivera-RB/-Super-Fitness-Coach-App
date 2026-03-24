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

    private let gamificationEngine: GamificationEngine

    init(gamificationEngine: GamificationEngine) {
        self.gamificationEngine = gamificationEngine
        refresh()
    }

    func refresh() {
        totalPoints = gamificationEngine.totalPoints
        currentLevel = gamificationEngine.currentLevel
        currentStreak = gamificationEngine.currentStreak
        personalBestStreak = gamificationEngine.personalBestStreak
        badges = gamificationEngine.badges
    }
}
