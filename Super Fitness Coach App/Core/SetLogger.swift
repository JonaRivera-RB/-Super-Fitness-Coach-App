//
//  SetLogger.swift
//  Super Fitness Coach App
//

import Foundation
import os

/// Registers individual sets and persists WorkoutLogs via TrainingPlanRepository.
///
/// Supports in-memory buffering of sets per exercise so the user can edit
/// weight/reps before finalising. Once ready, `saveWorkoutLog` persists the
/// complete record.
final class SetLogger {
    private let repository: TrainingPlanRepository
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "SetLogger")

    /// In-memory buffer: keyed by "\(exerciseId)_\(dateKey)" to allow editing
    /// sets before the workout log is finalised.
    private var pendingSets: [String: [SetLog]] = [:]

    init(repository: TrainingPlanRepository) {
        self.repository = repository
    }

    // MARK: - Public API

    /// Registers a single set for an exercise on a given date.
    ///
    /// The set is buffered in memory *and* immediately persisted inside a
    /// WorkoutLog so no data is lost if the app is terminated unexpectedly
    /// (Req 8.1, 13.2).
    func logSet(exerciseId: String, date: Date, set: SetLog) throws {
        let key = bufferKey(exerciseId: exerciseId, date: date)
        pendingSets[key, default: []].append(set)

        // Persist immediately (Req 13.2)
        let log = WorkoutLog(
            exerciseId: exerciseId,
            date: date,
            sets: pendingSets[key] ?? [set]
        )
        try repository.saveWorkoutLog(log)
    }

    /// Saves a complete WorkoutLog (with optional notes) to the repository.
    ///
    /// Call this when the user finishes an exercise to persist the final
    /// record including any edits and notes (Req 8.2, 8.3, 8.4).
    func saveWorkoutLog(_ log: WorkoutLog) throws {
        let key = bufferKey(exerciseId: log.exerciseId, date: log.date)
        pendingSets.removeValue(forKey: key)

        try repository.saveWorkoutLog(log)
    }

    /// Returns the most recent WorkoutLog for a given exercise, or `nil`
    /// if none exists.
    func latestLog(for exerciseId: String) throws -> WorkoutLog? {
        try repository.fetchLatestLog(exerciseId: exerciseId)
    }

    // MARK: - Helpers

    /// Produces a stable dictionary key from exerciseId + date (day precision).
    private func bufferKey(exerciseId: String, date: Date) -> String {
        let formatter = Self.dayFormatter
        return "\(exerciseId)_\(formatter.string(from: date))"
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
