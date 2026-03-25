//
//  ProgressTracker.swift
//  Super Fitness Coach App
//

import Foundation

struct ProgressTracker {

    /// Calcula el volumen total de un WorkoutLog: Σ(peso × reps) por set.
    static func totalVolume(from log: WorkoutLog) -> Double {
        log.sets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
    }

    /// Obtiene el peso máximo de un WorkoutLog.
    static func maxWeight(from log: WorkoutLog) -> Double {
        log.sets.map(\.weight).max() ?? 0.0
    }

    /// Obtiene las repeticiones máximas de un WorkoutLog.
    static func maxReps(from log: WorkoutLog) -> Int {
        log.sets.map(\.reps).max() ?? 0
    }

    /// Compara el log actual con el anterior y retorna el ProgressStatus.
    /// delta > 5% → improving, delta < -5% → declining, else → stable.
    /// Si no hay previousLog → stable (default).
    static func compareProgress(
        current: WorkoutLog,
        previous: WorkoutLog?
    ) -> ProgressStatus {
        guard let previous = previous else { return .stable }

        let previousVolume = totalVolume(from: previous)
        guard previousVolume > 0 else { return .stable }

        let currentVolume = totalVolume(from: current)
        let delta = (currentVolume - previousVolume) / previousVolume

        if delta > 0.05 {
            return .improving
        } else if delta < -0.05 {
            return .declining
        } else {
            return .stable
        }
    }
}
