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
    private let sessionId: String

    init(repository: TrainingPlanRepository, sessionId: String = "") {
        self.repository = repository
        self.sessionId = sessionId
    }

    // MARK: - Public API

    /// Registers a single set for an exercise on a given date.
    ///
    /// Persists progress safely by upserting a single log per exercise per day.
    /// This survives app closes without regressing resume progress.
    func logSet(exerciseId: String, date: Date, set: SetLog, notes: String? = nil) throws {
        guard !sessionId.isEmpty else {
            // Fallback to daily upsert for legacy callers (e.g., routine without session id).
            let existing = try repository.fetchLogs(exerciseId: exerciseId, limit: 40)
            let cal = Calendar.current
            let today = cal.startOfDay(for: date)
            let todays = existing.filter { cal.startOfDay(for: $0.date) == today }
            let base = todays.max(by: { $0.sets.count < $1.sets.count })
            let mergedSets = (base?.sets ?? []) + [set]
            try repository.upsertDailyWorkoutLog(exerciseId: exerciseId, date: date, sets: mergedSets, notes: notes)
            return
        }

        let base = try repository.fetchLatestLog(exerciseId: exerciseId, sessionId: sessionId)
        let mergedSets = (base?.sets ?? []) + [set]
        try repository.upsertSessionWorkoutLog(exerciseId: exerciseId, sessionId: sessionId, date: date, sets: mergedSets, notes: notes)
    }

    /// Saves a complete WorkoutLog (with optional notes) to the repository.
    ///
    /// Call this when the user finishes an exercise to persist the final
    /// record including any edits and notes (Req 8.2, 8.3, 8.4).
    func saveWorkoutLog(_ log: WorkoutLog) throws {
        if !sessionId.isEmpty {
            try repository.upsertSessionWorkoutLog(exerciseId: log.exerciseId, sessionId: sessionId, date: log.date, sets: log.sets, notes: log.notes)
        } else {
            try repository.upsertDailyWorkoutLog(exerciseId: log.exerciseId, date: log.date, sets: log.sets, notes: log.notes)
        }
    }

    /// Returns the most recent WorkoutLog for a given exercise, or `nil`
    /// if none exists.
    func latestLog(for exerciseId: String) throws -> WorkoutLog? {
        if !sessionId.isEmpty {
            return try repository.fetchLatestLog(exerciseId: exerciseId, sessionId: sessionId)
        }
        return try repository.fetchLatestLog(exerciseId: exerciseId)
    }

    // No in-memory buffering required anymore.
}
