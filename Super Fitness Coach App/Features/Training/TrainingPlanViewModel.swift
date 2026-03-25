//
//  TrainingPlanViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

/// ViewModel for the training plan view.
/// Manages current week, day statuses, and actions (complete/skip/reschedule).
/// Integrates DayManager and ProgressTracker.
/// Validates: Requirements 14.1, 14.2, 14.3, 14.4
@Observable
final class TrainingPlanViewModel {

    // MARK: - Exposed State

    /// The active training plan, if any.
    private(set) var plan: TrainingPlan?

    /// Days for the current week.
    private(set) var currentWeekDays: [TrainingDayPlan] = []

    /// Current week number (1-based).
    private(set) var currentWeek: Int = 0

    /// Total weeks in the plan.
    private(set) var totalWeeks: Int = 0

    /// Number of consecutive skipped days (for re-engagement, Req 10.10).
    private(set) var consecutiveSkipped: Int = 0

    /// Whether a re-engagement alert should be shown (≥3 consecutive skips).
    private(set) var showReEngagement: Bool = false

    /// Error message for the view, if any.
    private(set) var errorMessage: String?

    /// Loading state.
    private(set) var isLoading: Bool = false

    // MARK: - Dependencies

    private let repository: TrainingPlanRepository
    private let dayManager: DayManager

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "TrainingPlanVM")

    // MARK: - Init

    init(repository: TrainingPlanRepository, dayManager: DayManager) {
        self.repository = repository
        self.dayManager = dayManager
    }

    // MARK: - Load Plan

    /// Loads the active plan from the repository and refreshes the current week's days.
    func loadPlan() {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let activePlan = try repository.fetchActivePlan()
            self.plan = activePlan
            refreshState()
        } catch {
            logger.error("Failed to load active plan: \(error.localizedDescription)")
            errorMessage = "No se pudo cargar el plan. Intenta de nuevo."
        }
    }

    // MARK: - Day Actions (Req 10.1)

    /// Marks a day as completed and refreshes state.
    /// - Parameter dayIndex: 0-based index within the current week's days.
    func completeDay(at dayIndex: Int) {
        guard let plan else { return }

        do {
            try dayManager.completeDay(planId: plan.id, dayIndex: dayIndex)
            refreshState()
        } catch {
            logger.error("Failed to complete day \(dayIndex): \(error.localizedDescription)")
            errorMessage = "No se pudo completar el día."
        }
    }

    /// Marks a day as skipped and refreshes state. Checks for re-engagement (Req 10.10).
    /// - Parameter dayIndex: 0-based index within the current week's days.
    func skipDay(at dayIndex: Int) {
        guard let plan else { return }

        do {
            try dayManager.skipDay(planId: plan.id, dayIndex: dayIndex)
            refreshState()
        } catch {
            logger.error("Failed to skip day \(dayIndex): \(error.localizedDescription)")
            errorMessage = "No se pudo saltar el día."
        }
    }

    /// Reschedules a day to the next available rest day and refreshes state.
    /// - Parameter dayIndex: 0-based index within the current week's days.
    /// - Returns: `true` if rescheduled successfully.
    @discardableResult
    func rescheduleDay(at dayIndex: Int) -> Bool {
        guard let plan else { return false }

        do {
            let success = try dayManager.rescheduleDay(planId: plan.id, dayIndex: dayIndex)
            if !success {
                errorMessage = "No hay días disponibles para reprogramar."
            }
            refreshState()
            return success
        } catch {
            logger.error("Failed to reschedule day \(dayIndex): \(error.localizedDescription)")
            errorMessage = "No se pudo reprogramar el día."
            return false
        }
    }

    /// Whether a specific day can be rescheduled (not already rescheduled once).
    /// - Parameter dayIndex: 0-based index within the current week's days.
    func canReschedule(at dayIndex: Int) -> Bool {
        guard let plan else { return false }
        return dayManager.canReschedule(plan: plan, dayIndex: dayIndex)
    }

    // MARK: - Progress (Req 14.4)

    /// Returns a formatted string like "Semana 2 / 8".
    var progressText: String {
        guard totalWeeks > 0 else { return "" }
        return "Semana \(currentWeek) / \(totalWeeks)"
    }

    /// Progress fraction (0.0 to 1.0) for a progress bar.
    var progressFraction: Double {
        guard totalWeeks > 0 else { return 0 }
        return Double(currentWeek) / Double(totalWeeks)
    }

    // MARK: - Day Helpers (Req 14.2, 14.3)

    /// Whether a specific day is a rest day.
    func isRestDay(at dayIndex: Int) -> Bool {
        guard dayIndex >= 0, dayIndex < currentWeekDays.count else { return false }
        return currentWeekDays[dayIndex].isRestDay
    }

    /// Returns the status of a specific day.
    func dayStatus(at dayIndex: Int) -> DayStatus {
        guard dayIndex >= 0, dayIndex < currentWeekDays.count else { return .pending }
        return currentWeekDays[dayIndex].dayStatus
    }

    /// Returns the muscle groups for a specific day.
    func muscleGroups(at dayIndex: Int) -> [MuscleGroup] {
        guard dayIndex >= 0, dayIndex < currentWeekDays.count else { return [] }
        return currentWeekDays[dayIndex].muscleGroups
    }

    /// Returns the exercises for a specific day.
    func exercises(at dayIndex: Int) -> [PlannedExercise] {
        guard dayIndex >= 0, dayIndex < currentWeekDays.count else { return [] }
        return currentWeekDays[dayIndex].exercises
    }

    // MARK: - Private

    /// Refreshes all derived state from the current plan.
    private func refreshState() {
        guard let plan else {
            currentWeekDays = []
            currentWeek = 0
            totalWeeks = 0
            consecutiveSkipped = 0
            showReEngagement = false
            return
        }

        currentWeek = plan.currentWeek
        totalWeeks = plan.preferences.planDurationWeeks

        let weekIndex = plan.currentWeek - 1
        if weekIndex >= 0, weekIndex < plan.weeks.count {
            currentWeekDays = plan.weeks[weekIndex].days
        } else {
            currentWeekDays = []
        }

        // Track consecutive skipped days for re-engagement (Req 10.10)
        consecutiveSkipped = dayManager.consecutiveSkippedDays(plan: plan)
        showReEngagement = consecutiveSkipped >= 3
    }
}
