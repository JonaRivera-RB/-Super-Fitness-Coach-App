//
//  RecoveryAdapterTests.swift
//  Super Fitness Coach App
//

import XCTest
@testable import Super_Fitness_Coach_App

final class RecoveryAdapterTests: XCTestCase {

    // MARK: - dailyAdjustment tests

    func testHighRecovery_ReturnsWeightBoost() {
        let adj = RecoveryAdapter.dailyAdjustment(recoveryScore: 80)
        XCTAssertEqual(adj.weightMultiplier, 1.05)
        XCTAssertEqual(adj.setsReduction, 0)
    }

    func testVeryHighRecovery_ReturnsWeightBoost() {
        let adj = RecoveryAdapter.dailyAdjustment(recoveryScore: 100)
        XCTAssertEqual(adj.weightMultiplier, 1.05)
        XCTAssertEqual(adj.setsReduction, 0)
    }

    func testMidRecovery_ReturnsNoChange() {
        let adj = RecoveryAdapter.dailyAdjustment(recoveryScore: 50)
        XCTAssertEqual(adj.weightMultiplier, 1.0)
        XCTAssertEqual(adj.setsReduction, 0)
    }

    func testMidRecoveryUpperBound_ReturnsNoChange() {
        let adj = RecoveryAdapter.dailyAdjustment(recoveryScore: 79)
        XCTAssertEqual(adj.weightMultiplier, 1.0)
        XCTAssertEqual(adj.setsReduction, 0)
    }

    func testLowRecovery_ReturnsReduction() {
        let adj = RecoveryAdapter.dailyAdjustment(recoveryScore: 49)
        XCTAssertEqual(adj.weightMultiplier, 0.85)
        XCTAssertEqual(adj.setsReduction, 1)
    }

    func testZeroRecovery_ReturnsReduction() {
        let adj = RecoveryAdapter.dailyAdjustment(recoveryScore: 0)
        XCTAssertEqual(adj.weightMultiplier, 0.85)
        XCTAssertEqual(adj.setsReduction, 1)
    }

    // MARK: - applyAdjustment tests

    func testApplyAdjustment_HighRecovery_BoostsWeight() {
        let exercise = makePlannedExercise(sets: 3, weight: 100.0)
        let adj = DailyAdjustment(weightMultiplier: 1.05, setsReduction: 0)

        let result = RecoveryAdapter.applyAdjustment(to: exercise, adjustment: adj)

        XCTAssertEqual(result.suggestedWeight, 105.0, accuracy: 0.001)
        XCTAssertEqual(result.sets, 3)
    }

    func testApplyAdjustment_LowRecovery_ReducesWeightAndSets() {
        let exercise = makePlannedExercise(sets: 3, weight: 100.0)
        let adj = DailyAdjustment(weightMultiplier: 0.85, setsReduction: 1)

        let result = RecoveryAdapter.applyAdjustment(to: exercise, adjustment: adj)

        XCTAssertEqual(result.suggestedWeight, 85.0, accuracy: 0.001)
        XCTAssertEqual(result.sets, 2)
    }

    func testApplyAdjustment_MinimumOneSet() {
        let exercise = makePlannedExercise(sets: 1, weight: 50.0)
        let adj = DailyAdjustment(weightMultiplier: 0.85, setsReduction: 1)

        let result = RecoveryAdapter.applyAdjustment(to: exercise, adjustment: adj)

        XCTAssertEqual(result.sets, 1, "Sets should never go below 1")
    }

    func testApplyAdjustment_PreservesExerciseIdentity() {
        let exercise = makePlannedExercise(sets: 3, weight: 80.0)
        let adj = DailyAdjustment(weightMultiplier: 0.85, setsReduction: 1)

        let result = RecoveryAdapter.applyAdjustment(to: exercise, adjustment: adj)

        XCTAssertEqual(result.id, exercise.id)
        XCTAssertEqual(result.name, exercise.name)
        XCTAssertEqual(result.muscleGroup, exercise.muscleGroup)
        XCTAssertEqual(result.isCompound, exercise.isCompound)
        XCTAssertEqual(result.reps, exercise.reps)
        XCTAssertEqual(result.equipment, exercise.equipment)
    }

    // MARK: - Helpers

    private func makePlannedExercise(sets: Int, weight: Double) -> PlannedExercise {
        PlannedExercise(
            id: "bench-press",
            name: "Bench Press",
            muscleGroup: .chest,
            isCompound: true,
            sets: sets,
            reps: 10,
            suggestedWeight: weight,
            equipment: "barbell",
            gifUrl: nil,
            instructions: []
        )
    }
}
