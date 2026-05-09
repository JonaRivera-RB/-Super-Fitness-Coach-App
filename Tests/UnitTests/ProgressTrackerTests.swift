//
//  ProgressTrackerTests.swift
//  Super Fitness Coach App
//

import XCTest
@testable import Super_Fitness_Coach_App

final class ProgressTrackerTests: XCTestCase {

    // MARK: - totalVolume

    func testTotalVolume_SumsWeightTimesReps() {
        let log = makeLog(sets: [
            SetLog(weight: 100.0, reps: 10),
            SetLog(weight: 100.0, reps: 8),
            SetLog(weight: 90.0, reps: 6)
        ])
        // 100*10 + 100*8 + 90*6 = 1000 + 800 + 540 = 2340
        XCTAssertEqual(ProgressTracker.totalVolume(from: log), 2340.0, accuracy: 0.001)
    }

    func testTotalVolume_EmptySets_ReturnsZero() {
        let log = makeLog(sets: [])
        XCTAssertEqual(ProgressTracker.totalVolume(from: log), 0.0)
    }

    func testTotalVolume_SingleSet() {
        let log = makeLog(sets: [SetLog(weight: 50.0, reps: 12)])
        XCTAssertEqual(ProgressTracker.totalVolume(from: log), 600.0, accuracy: 0.001)
    }

    // MARK: - maxWeight

    func testMaxWeight_ReturnsHighest() {
        let log = makeLog(sets: [
            SetLog(weight: 80.0, reps: 10),
            SetLog(weight: 100.0, reps: 8),
            SetLog(weight: 90.0, reps: 6)
        ])
        XCTAssertEqual(ProgressTracker.maxWeight(from: log), 100.0)
    }

    func testMaxWeight_EmptySets_ReturnsZero() {
        let log = makeLog(sets: [])
        XCTAssertEqual(ProgressTracker.maxWeight(from: log), 0.0)
    }

    // MARK: - maxReps

    func testMaxReps_ReturnsHighest() {
        let log = makeLog(sets: [
            SetLog(weight: 80.0, reps: 10),
            SetLog(weight: 80.0, reps: 12),
            SetLog(weight: 80.0, reps: 8)
        ])
        XCTAssertEqual(ProgressTracker.maxReps(from: log), 12)
    }

    func testMaxReps_EmptySets_ReturnsZero() {
        let log = makeLog(sets: [])
        XCTAssertEqual(ProgressTracker.maxReps(from: log), 0)
    }

    // MARK: - compareProgress

    func testCompareProgress_NoPrevious_ReturnsStable() {
        let current = makeLog(sets: [SetLog(weight: 100.0, reps: 10)])
        XCTAssertEqual(ProgressTracker.compareProgress(current: current, previous: nil), .stable)
    }

    func testCompareProgress_VolumeUp6Percent_ReturnsImproving() {
        // previous volume = 100*10 = 1000, current = 106*10 = 1060 → delta = 6%
        let previous = makeLog(sets: [SetLog(weight: 100.0, reps: 10)])
        let current = makeLog(sets: [SetLog(weight: 106.0, reps: 10)])
        XCTAssertEqual(ProgressTracker.compareProgress(current: current, previous: previous), .improving)
    }

    func testCompareProgress_VolumeDown6Percent_ReturnsDeclining() {
        // previous volume = 100*10 = 1000, current = 94*10 = 940 → delta = -6%
        let previous = makeLog(sets: [SetLog(weight: 100.0, reps: 10)])
        let current = makeLog(sets: [SetLog(weight: 94.0, reps: 10)])
        XCTAssertEqual(ProgressTracker.compareProgress(current: current, previous: previous), .declining)
    }

    func testCompareProgress_VolumeWithin5Percent_ReturnsStable() {
        // previous volume = 1000, current = 1040 → delta = 4%
        let previous = makeLog(sets: [SetLog(weight: 100.0, reps: 10)])
        let current = makeLog(sets: [SetLog(weight: 104.0, reps: 10)])
        XCTAssertEqual(ProgressTracker.compareProgress(current: current, previous: previous), .stable)
    }

    func testCompareProgress_ExactlyAt5Percent_ReturnsStable() {
        // previous volume = 1000, current = 1050 → delta = exactly 5% (not > 5%)
        let previous = makeLog(sets: [SetLog(weight: 100.0, reps: 10)])
        let current = makeLog(sets: [SetLog(weight: 105.0, reps: 10)])
        XCTAssertEqual(ProgressTracker.compareProgress(current: current, previous: previous), .stable)
    }

    func testCompareProgress_ExactlyAtNeg5Percent_ReturnsStable() {
        // previous volume = 1000, current = 950 → delta = exactly -5% (not < -5%)
        let previous = makeLog(sets: [SetLog(weight: 100.0, reps: 10)])
        let current = makeLog(sets: [SetLog(weight: 95.0, reps: 10)])
        XCTAssertEqual(ProgressTracker.compareProgress(current: current, previous: previous), .stable)
    }

    func testCompareProgress_PreviousZeroVolume_ReturnsStable() {
        let previous = makeLog(sets: [])
        let current = makeLog(sets: [SetLog(weight: 100.0, reps: 10)])
        XCTAssertEqual(ProgressTracker.compareProgress(current: current, previous: previous), .stable)
    }

    // MARK: - Helpers

    private func makeLog(sets: [SetLog]) -> WorkoutLog {
        WorkoutLog(exerciseId: "bench-press", date: Date(), sets: sets)
    }
}
