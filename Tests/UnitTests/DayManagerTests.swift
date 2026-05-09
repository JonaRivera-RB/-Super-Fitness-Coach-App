//
//  DayManagerTests.swift
//  Super Fitness Coach App
//

import Testing
import SwiftData
import Foundation
@testable import Super_Fitness_Coach_App

struct DayManagerTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: TrainingPlan.self, TrainingWeek.self, WorkoutLog.self,
            configurations: config
        )
    }

    private func makeManager(container: ModelContainer) -> DayManager {
        let context = container.mainContext
        let repository = TrainingPlanRepository(context: context)
        return DayManager(repository: repository)
    }

    /// Creates a sample plan with 7 days: 4 training + 3 rest, all pending.
    private func makeSamplePlan() -> TrainingPlan {
        let sampleExercise = PlannedExercise(
            id: "ex1", name: "Bench Press", muscleGroup: .chest,
            isCompound: true, sets: 3, reps: 10, suggestedWeight: 60.0,
            equipment: "barbell", gifUrl: nil, instructions: []
        )
        let days: [TrainingDayPlan] = [
            TrainingDayPlan(dayOfWeek: 1, muscleGroups: [.chest], exercises: [sampleExercise]),
            TrainingDayPlan(dayOfWeek: 2, muscleGroups: [.back], exercises: [sampleExercise]),
            TrainingDayPlan(dayOfWeek: 3, muscleGroups: [], exercises: [], isRestDay: true),
            TrainingDayPlan(dayOfWeek: 4, muscleGroups: [.quads], exercises: [sampleExercise]),
            TrainingDayPlan(dayOfWeek: 5, muscleGroups: [], exercises: [], isRestDay: true),
            TrainingDayPlan(dayOfWeek: 6, muscleGroups: [.shoulders], exercises: [sampleExercise]),
            TrainingDayPlan(dayOfWeek: 7, muscleGroups: [], exercises: [], isRestDay: true),
        ]
        let week = TrainingWeek(weekIndex: 0, days: days)
        return TrainingPlan(preferences: .default, weeks: [week])
    }

    /// Dos semanas de plantilla; solo Lun–Mar son entreno (el resto descanso). Avance de semana rápido de testear.
    private func makeMinimalTwoWeekPlan() -> TrainingPlan {
        let sampleExercise = PlannedExercise(
            id: "ex1", name: "Bench Press", muscleGroup: .chest,
            isCompound: true, sets: 3, reps: 10, suggestedWeight: 60.0,
            equipment: "barbell", gifUrl: nil, instructions: []
        )
        let weekDays: [TrainingDayPlan] = (1...7).map { dow in
            if dow <= 2 {
                TrainingDayPlan(dayOfWeek: dow, muscleGroups: [.chest], exercises: [sampleExercise])
            } else {
                TrainingDayPlan(dayOfWeek: dow, muscleGroups: [], exercises: [], isRestDay: true)
            }
        }
        let w1 = TrainingWeek(weekIndex: 1, days: weekDays)
        let w2 = TrainingWeek(weekIndex: 2, days: weekDays.map {
            TrainingDayPlan(
                dayOfWeek: $0.dayOfWeek,
                muscleGroups: $0.muscleGroups,
                exercises: $0.exercises,
                isRestDay: $0.isRestDay
            )
        })
        return TrainingPlan(preferences: .default, weeks: [w1, w2])
    }

    // MARK: - Complete Day (Req 10.7)

    @Test func completeDaySetsStatusToCompleted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        let plan = makeSamplePlan()
        try repo.savePlan(plan)

        try manager.completeDay(planId: plan.id, dayIndex: 0)

        let fetched = try repo.fetchActivePlan()!
        #expect(fetched.weeks[0].days[0].dayStatus == .completed)
    }

    @Test func completeDayDoesNotAffectOtherDays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        let plan = makeSamplePlan()
        try repo.savePlan(plan)

        try manager.completeDay(planId: plan.id, dayIndex: 0)

        let fetched = try repo.fetchActivePlan()!
        for i in 1..<fetched.weeks[0].days.count {
            #expect(fetched.weeks[0].days[i].dayStatus == .pending)
        }
    }

    /// Regression: segundo (y siguientes) planes generados — `completeDay` debe persistir tras `replaceActivePlan`.
    /// Cubre el caso donde `fetchActivePlan` devolvía relaciones aún no materializadas y el complete era no-op.
    @Test func completeDayAfterReplaceActivePlanPersists() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        let firstPlan = makeSamplePlan()
        try repo.savePlan(firstPlan)

        let secondPlan = makeSamplePlan()
        try repo.replaceActivePlan(with: secondPlan)

        let active = try repo.fetchActivePlan()!
        #expect(active.id == secondPlan.id)

        try manager.completeDay(plan: active, dayIndex: 0)

        let verified = try repo.fetchActivePlan()!
        let sortedDays = verified.weeks[0].days.sorted { $0.dayOfWeek < $1.dayOfWeek }
        #expect(sortedDays.first?.dayStatus == .completed)
    }

    @Test func completingAllTrainingDaysAdvancesPlanWeek() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        let plan = makeMinimalTwoWeekPlan()
        try repo.savePlan(plan)
        #expect(plan.currentWeek == 1)

        try manager.completeDay(plan: plan, dayIndex: 0)
        try manager.completeDay(plan: plan, dayIndex: 1)

        let fetched = try repo.fetchActivePlan()!
        #expect(fetched.currentWeek == 2)
        let sortedNext = fetched.weeks[1].days.sorted { $0.dayOfWeek < $1.dayOfWeek }
        let trainingNext = sortedNext.filter { !$0.isRestDay }
        #expect(trainingNext.allSatisfy { $0.dayStatus == .pending })
    }

    @Test func completingLastPlanWeekDoesNotAdvancePastEnd() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        let plan = makeMinimalTwoWeekPlan()
        plan.currentWeek = 2
        try repo.savePlan(plan)

        try manager.completeDay(plan: plan, dayIndex: 0)
        try manager.completeDay(plan: plan, dayIndex: 1)

        let fetched = try repo.fetchActivePlan()!
        #expect(fetched.currentWeek == 2)
    }

    // MARK: - Skip Day (Req 10.2)

    @Test func skipDaySetsStatusToSkipped() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        let plan = makeSamplePlan()
        try repo.savePlan(plan)

        try manager.skipDay(planId: plan.id, dayIndex: 1)

        let fetched = try repo.fetchActivePlan()!
        #expect(fetched.weeks[0].days[1].dayStatus == .skipped)
    }

    @Test func skipDayDoesNotModifyOtherDays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        let plan = makeSamplePlan()
        try repo.savePlan(plan)

        try manager.skipDay(planId: plan.id, dayIndex: 1)

        let fetched = try repo.fetchActivePlan()!
        #expect(fetched.weeks[0].days[0].dayStatus == .pending)
        for i in 2..<fetched.weeks[0].days.count {
            #expect(fetched.weeks[0].days[i].dayStatus == .pending)
        }
    }

    // MARK: - Reschedule Day (Req 10.3, 10.4, 10.5, 10.6, 10.9)

    @Test func rescheduleDayMovesWorkoutToNextRestDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        let plan = makeSamplePlan()
        try repo.savePlan(plan)

        // Reschedule day 0 (Monday, chest) → should move to day 2 (first rest day after)
        let result = try manager.rescheduleDay(planId: plan.id, dayIndex: 0)

        #expect(result == true)
        let fetched = try repo.fetchActivePlan()!
        let week = fetched.weeks[0]

        // Source day should be rescheduled and converted to rest
        #expect(week.days[0].dayStatus == .rescheduled)
        #expect(week.days[0].isRestDay == true)
        #expect(week.days[0].exercises.isEmpty)

        // Target day should have the workout
        #expect(week.days[2].dayStatus == .pending)
        #expect(week.days[2].isRestDay == false)
        #expect(week.days[2].muscleGroups == [.chest])
        #expect(!week.days[2].exercises.isEmpty)
        #expect(week.days[2].wasRescheduled == true)
    }

    @Test func rescheduleDayReturnsFalseWhenNoAvailableDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        // Create a plan with no rest days after the target
        let sampleExercise = PlannedExercise(
            id: "ex1", name: "Bench Press", muscleGroup: .chest,
            isCompound: true, sets: 3, reps: 10, suggestedWeight: 60.0,
            equipment: "barbell", gifUrl: nil, instructions: []
        )
        let days: [TrainingDayPlan] = [
            TrainingDayPlan(dayOfWeek: 1, muscleGroups: [.chest], exercises: [sampleExercise]),
            TrainingDayPlan(dayOfWeek: 2, muscleGroups: [.back], exercises: [sampleExercise]),
        ]
        let week = TrainingWeek(weekIndex: 0, days: days)
        let plan = TrainingPlan(preferences: .default, weeks: [week])
        try repo.savePlan(plan)

        let result = try manager.rescheduleDay(planId: plan.id, dayIndex: 0)
        #expect(result == false)
        // Day should remain unchanged
        let fetched = try repo.fetchActivePlan()!
        #expect(fetched.weeks[0].days[0].dayStatus == .pending)
    }

    @Test func rescheduleDayLimitedToOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        let plan = makeSamplePlan()
        try repo.savePlan(plan)

        // First reschedule should succeed
        let first = try manager.rescheduleDay(planId: plan.id, dayIndex: 1)
        #expect(first == true)

        // The target day (index 2) now has wasRescheduled = true
        // Trying to reschedule it again should fail
        let second = try manager.rescheduleDay(planId: plan.id, dayIndex: 2)
        #expect(second == false)
    }

    @Test func rescheduleDayPreservesSessionCount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repo = TrainingPlanRepository(context: context)
        let manager = DayManager(repository: repo)

        let plan = makeSamplePlan()
        try repo.savePlan(plan)

        // Count training days before
        let trainingDaysBefore = plan.weeks[0].days.filter { !$0.isRestDay }.count

        _ = try manager.rescheduleDay(planId: plan.id, dayIndex: 0)

        let fetched = try repo.fetchActivePlan()!
        let trainingDaysAfter = fetched.weeks[0].days.filter { !$0.isRestDay }.count

        #expect(trainingDaysBefore == trainingDaysAfter)
    }

    // MARK: - Can Reschedule (Req 10.6)

    @Test func canRescheduleReturnsTrueForFreshDay() throws {
        let plan = makeSamplePlan()
        let container = try makeContainer()
        let manager = makeManager(container: container)

        #expect(manager.canReschedule(plan: plan, dayIndex: 0) == true)
    }

    @Test func canRescheduleReturnsFalseForRescheduledDay() throws {
        let plan = makeSamplePlan()
        plan.weeks[0].days[0].wasRescheduled = true

        let container = try makeContainer()
        let manager = makeManager(container: container)

        #expect(manager.canReschedule(plan: plan, dayIndex: 0) == false)
    }

    @Test func canRescheduleReturnsFalseForInvalidIndex() throws {
        let plan = makeSamplePlan()
        let container = try makeContainer()
        let manager = makeManager(container: container)

        #expect(manager.canReschedule(plan: plan, dayIndex: 99) == false)
    }

    // MARK: - Consecutive Skipped Days (Req 10.10)

    @Test func consecutiveSkippedDaysCountsCorrectly() throws {
        let plan = makeSamplePlan()
        // Skip last 3 non-rest days from the end
        plan.weeks[0].days[6].dayStatus = .skipped // day 7 (rest, but mark skipped)
        plan.weeks[0].days[5].dayStatus = .skipped // day 6
        plan.weeks[0].days[4].dayStatus = .skipped // day 5 (rest, but mark skipped)

        let container = try makeContainer()
        let manager = makeManager(container: container)

        #expect(manager.consecutiveSkippedDays(plan: plan) == 3)
    }

    @Test func consecutiveSkippedDaysStopsAtCompletedDay() throws {
        let plan = makeSamplePlan()
        plan.weeks[0].days[6].dayStatus = .skipped
        plan.weeks[0].days[5].dayStatus = .completed // breaks the streak
        plan.weeks[0].days[4].dayStatus = .skipped

        let container = try makeContainer()
        let manager = makeManager(container: container)

        #expect(manager.consecutiveSkippedDays(plan: plan) == 1)
    }

    @Test func consecutiveSkippedDaysReturnsZeroWhenNoneSkipped() throws {
        let plan = makeSamplePlan()

        let container = try makeContainer()
        let manager = makeManager(container: container)

        #expect(manager.consecutiveSkippedDays(plan: plan) == 0)
    }

    @Test func consecutiveSkippedDaysSkipsPendingDays() throws {
        let plan = makeSamplePlan()
        // Last day pending, second-to-last skipped, third-to-last skipped
        plan.weeks[0].days[5].dayStatus = .skipped
        plan.weeks[0].days[4].dayStatus = .skipped
        // days[6] is still .pending — should be skipped over

        let container = try makeContainer()
        let manager = makeManager(container: container)

        #expect(manager.consecutiveSkippedDays(plan: plan) == 2)
    }

    // MARK: - Initialization (Req 10.8)

    @Test func allDaysInitializeWithPendingStatus() throws {
        let plan = makeSamplePlan()

        for day in plan.weeks[0].days {
            #expect(day.dayStatus == .pending)
        }
    }
}
