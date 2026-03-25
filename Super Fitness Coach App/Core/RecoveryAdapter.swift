//
//  RecoveryAdapter.swift
//  Super Fitness Coach App
//

import Foundation

struct RecoveryAdapter {

    // MARK: - Ajuste Diario por Recuperación (Req 6)

    /// Calcula el ajuste diario basado en el recoveryScore (0-100).
    ///   - recoveryScore ≥ 80: peso +5%, sin reducción de sets
    ///   - recoveryScore 50-79: sin cambios
    ///   - recoveryScore < 50: peso -15%, reducir 1 set
    static func dailyAdjustment(recoveryScore: Int) -> DailyAdjustment {
        if recoveryScore >= 80 {
            return DailyAdjustment(weightMultiplier: 1.05, setsReduction: 0)
        } else if recoveryScore >= 50 {
            return DailyAdjustment(weightMultiplier: 1.0, setsReduction: 0)
        } else {
            return DailyAdjustment(weightMultiplier: 0.85, setsReduction: 1)
        }
    }

    /// Aplica el ajuste de recuperación a un ejercicio planificado.
    /// - Peso: suggestedWeight × weightMultiplier
    /// - Sets: max(1, sets - setsReduction)
    static func applyAdjustment(
        to exercise: PlannedExercise,
        adjustment: DailyAdjustment
    ) -> PlannedExercise {
        var adjusted = exercise
        adjusted.suggestedWeight = exercise.suggestedWeight * adjustment.weightMultiplier
        adjusted.sets = max(1, exercise.sets - adjustment.setsReduction)
        return adjusted
    }
}
