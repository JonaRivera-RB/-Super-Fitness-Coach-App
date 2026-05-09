//
//  WeeklyProgressionEngine.swift
//  Super Fitness Coach App
//

import Foundation

struct WeeklyProgressionEngine {

    // MARK: - Progresión Semanal (Req 5)

    /// Calcula la progresión para una semana dada del plan.
    /// Ciclo de 4 semanas que se repite para planes de 6 u 8 semanas:
    ///   - Semana 1: base (1.0 / 1.0)
    ///   - Semana 2: +5% peso (1.05 / 1.0)
    ///   - Semana 3: +10% volumen (1.0 / 1.1)
    ///   - Semana 4: deload (0.9 / 0.85)
    static func progression(for currentWeek: Int) -> WeeklyProgression {
        let weekInCycle = ((max(1, currentWeek) - 1) % 4) + 1

        switch weekInCycle {
        case 1:
            return WeeklyProgression(weekInCycle: 1, weightMultiplier: 1.0, volumeMultiplier: 1.0)
        case 2:
            return WeeklyProgression(weekInCycle: 2, weightMultiplier: 1.05, volumeMultiplier: 1.0)
        case 3:
            return WeeklyProgression(weekInCycle: 3, weightMultiplier: 1.0, volumeMultiplier: 1.1)
        case 4:
            return WeeklyProgression(weekInCycle: 4, weightMultiplier: 0.9, volumeMultiplier: 0.85)
        default:
            return WeeklyProgression(weekInCycle: 1, weightMultiplier: 1.0, volumeMultiplier: 1.0)
        }
    }

    /// Aplica la progresión semanal a un ejercicio planificado.
    /// - Peso: suggestedWeight × weightMultiplier
    /// - Sets: round(sets × volumeMultiplier), mínimo 1
    static func applyProgression(
        to exercise: PlannedExercise,
        progression: WeeklyProgression
    ) -> PlannedExercise {
        var adjusted = exercise
        adjusted.suggestedWeight = exercise.suggestedWeight * progression.weightMultiplier
        if let maxW = exercise.targetWeightMax {
            adjusted.targetWeightMax = maxW * progression.weightMultiplier
        }
        adjusted.sets = max(1, Int((Double(exercise.sets) * progression.volumeMultiplier).rounded()))
        if let per = adjusted.perSetRestSeconds {
            adjusted.perSetRestSeconds = per.count == adjusted.sets ? per : Array(per.prefix(adjusted.sets))
        }
        return adjusted
    }
}
