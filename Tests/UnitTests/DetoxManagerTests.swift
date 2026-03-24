//
//  DetoxManagerTests.swift
//  Super Fitness Coach App
//

import Testing
import SwiftData
import Foundation
@testable import Super_Fitness_Coach_App

struct DetoxManagerTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: DetoxProgress.self, GamificationState.self,
            configurations: config
        )
    }

    private func makeManager(container: ModelContainer) -> DetoxManager {
        let context = container.mainContext
        let detoxRepo = DetoxRepository(context: context)
        let gamRepo = GamificationRepository(context: context)
        let engine = GamificationEngine(repository: gamRepo)
        return DetoxManager(repository: detoxRepo, gamificationEngine: engine)
    }

    // MARK: - Activation

    @Test func activateChallengeInitializesCorrectState() throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.activateChallenge()

        let progress = manager.currentProgress
        #expect(progress != nil)
        #expect(progress?.currentDay == 1)
        #expect(progress?.isActive == true)
        #expect(progress?.isCompleted == false)
        #expect(progress?.dailyLogs == Array(repeating: false, count: 7))
    }

    // MARK: - Mark Day Alcohol-Free

    @Test func markDayAlcoholFreeSetsLogAndAwardsPoints() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let detoxRepo = DetoxRepository(context: context)
        let gamRepo = GamificationRepository(context: context)
        let engine = GamificationEngine(repository: gamRepo)
        let manager = DetoxManager(repository: detoxRepo, gamificationEngine: engine)

        manager.activateChallenge()
        manager.markDayAlcoholFree()

        let progress = manager.currentProgress!
        #expect(progress.dailyLogs[0] == true)
        #expect(progress.currentDay == 2)
        #expect(engine.totalPoints == 15)
    }

    @Test func markDayDoesNothingWithoutActiveChallenge() throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        // No challenge activated
        manager.markDayAlcoholFree()
        #expect(manager.currentProgress == nil)
    }

    // MARK: - Completion

    @Test func completionAfterAllSevenDays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let detoxRepo = DetoxRepository(context: context)
        let gamRepo = GamificationRepository(context: context)
        let engine = GamificationEngine(repository: gamRepo)
        let manager = DetoxManager(repository: detoxRepo, gamificationEngine: engine)

        manager.activateChallenge()

        // Mark all 7 days
        for _ in 1...7 {
            manager.markDayAlcoholFree()
        }

        let progress = manager.currentProgress!
        #expect(progress.isCompleted == true)
        #expect(progress.isActive == false)
        // 7 days × 15 pts + 100 bonus = 205
        #expect(engine.totalPoints == 205)
    }

    // MARK: - Reset

    @Test func resetChallengeClearsProgress() throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.activateChallenge()
        manager.markDayAlcoholFree()
        manager.markDayAlcoholFree()

        manager.resetChallenge()

        let progress = manager.currentProgress!
        #expect(progress.currentDay == 1)
        #expect(progress.dailyLogs == Array(repeating: false, count: 7))
        #expect(progress.isActive == true)
    }

    // MARK: - Missed Day Detection

    @Test func checkForMissedDayResetsWhenDayMissed() throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.activateChallenge()

        // Simulate a challenge started 2 days ago but still on day 1
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        manager.currentProgress?.startDate = twoDaysAgo

        manager.checkForMissedDay()

        let progress = manager.currentProgress!
        #expect(progress.currentDay == 1)
        #expect(progress.dailyLogs == Array(repeating: false, count: 7))
    }

    @Test func checkForMissedDayDoesNotResetWhenOnTrack() throws {
        let container = try makeContainer()
        let manager = makeManager(container: container)

        manager.activateChallenge()
        // Challenge just started today, on day 1 — no missed day
        manager.checkForMissedDay()

        let progress = manager.currentProgress!
        #expect(progress.currentDay == 1)
        #expect(progress.isActive == true)
    }

    // MARK: - Load Active Challenge

    @Test func loadActiveChallengeFromRepository() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let detoxRepo = DetoxRepository(context: context)
        let gamRepo = GamificationRepository(context: context)

        // Persist a challenge directly
        let progress = DetoxProgress(startDate: Date())
        progress.currentDay = 3
        progress.dailyLogs[0] = true
        progress.dailyLogs[1] = true
        try detoxRepo.saveProgress(progress)

        // Create a new manager — it should load the existing challenge
        let engine = GamificationEngine(repository: gamRepo)
        let manager = DetoxManager(repository: detoxRepo, gamificationEngine: engine)

        #expect(manager.currentProgress != nil)
        #expect(manager.currentProgress?.currentDay == 3)
        #expect(manager.currentProgress?.dailyLogs[0] == true)
        #expect(manager.currentProgress?.dailyLogs[1] == true)
    }
}
