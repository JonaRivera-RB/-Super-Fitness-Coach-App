//  SleepQualityScoring.swift
//  Super Fitness Coach App
//
//  Puntuación de calidad de sueño a partir de HealthKit (duración, continuidad, fases).
//  No es el staging de Apple; son reglas de la app (ver steering).

import Foundation

/// Reglas de composite 60% duración / 20% continuidad / 10% REM / 10% deep, con techo por pocas horas
/// y ajuste suave de confianza (sin multiplicar el 0–100 entero).
enum SleepQualityScoring {

    // MARK: - Weights (producto)

    static let durationWeight = 0.6
    static let continuityWeight = 0.2
    static let remWeight = 0.1
    static let deepWeight = 0.1

    // MARK: - Tunables

    /// Curvatura &lt; meta: ratio^gamma penaliza dormir poco.
    private static let belowGoalCurvature: Double = 1.45

    /// Si no hay muestras `awake` en HealthKit, continuidad neutral (no castigar sin dato).
    private static let continuityNeutralNoAwakeStaging: Double = 78.0

    /// Deep/REM ausentes en categoría (solo «asleep» genérico): no quemar el 10%.
    private static let missingPhaseNeutral: Double = 72.0

    /// Máximo ajuste por `sleepConfidence` respecto a 0.5 (suma algebraica en puntos).
    private static let confidenceDeltaPoints: Double = 8.0

    /// Banda «óptima» del % del TST (AASM aprox.).
    private static let deepBandMin = 0.10
    private static let deepBandMax = 0.28
    private static let remBandMin = 0.15
    private static let remBandMax = 0.32

    /// Continuidad: fracción de vigilia sobre la ventana reloj a partir de la cual el subscore cae a ~0.
    private static let awakeRatioFullPenalty: Double = 0.30

    // MARK: - Result

    struct Result: Equatable {
        /// Puntos mostrados (0–100), enteros por redondeo.
        let displayScore: Int
        /// Mismo valor que feed a recovery, en double [0,100] para no doble-redondear.
        let sleepQualityForRecovery: Double
        /// Composite ponderado antes de techo por horas y ajuste de confianza.
        let rawWeightedComposite: Double
        let scoreAfterDurationHourCap: Double
        let durationSubscore: Double
        let continuitySubscore: Double
        let remSubscore: Double
        let deepSubscore: Double
    }

    /// Desglose del último `compute` (p. ej. panel DEBUG en detalle de sueño).
    struct DebugSnapshot: Equatable, Sendable {
        let totalSleepHours: Double
        let goalHoursUsed: Double
        let sleepConfidence: Double
        let durationSubscore: Double
        let rawWeightedComposite: Double
        let scoreAfterDurationHourCap: Double
        let displayScore: Int
        let sleepQualityForRecovery: Double
        let continuitySubscore: Double
        let remSubscore: Double
        let deepSubscore: Double
    }

    static func makeDebugSnapshot(
        result: Result,
        totalSleepHours: Double,
        goalHoursUsed: Double,
        sleepConfidence: Double
    ) -> DebugSnapshot {
        DebugSnapshot(
            totalSleepHours: totalSleepHours,
            goalHoursUsed: goalHoursUsed,
            sleepConfidence: sleepConfidence,
            durationSubscore: result.durationSubscore,
            rawWeightedComposite: result.rawWeightedComposite,
            scoreAfterDurationHourCap: result.scoreAfterDurationHourCap,
            displayScore: result.displayScore,
            sleepQualityForRecovery: result.sleepQualityForRecovery,
            continuitySubscore: result.continuitySubscore,
            remSubscore: result.remSubscore,
            deepSubscore: result.deepSubscore
        )
    }

    // MARK: - API

    /// Calcula el score de calidad de sueño de la noche. `sleepGoalHours` ≤ 0 ⇒ 0.
    static func compute(
        totalSleepHours: Double,
        deepSleepHours: Double?,
        remSleepHours: Double?,
        sleepGoalHours: Double,
        sessionWallDuration: TimeInterval?,
        awakeSecondsDuringSession: TimeInterval?,
        sleepConfidence: Double
    ) -> Result {
        guard sleepGoalHours > 0, totalSleepHours > 0 else {
            return Result(
                displayScore: 0,
                sleepQualityForRecovery: 0,
                rawWeightedComposite: 0,
                scoreAfterDurationHourCap: 0,
                durationSubscore: 0,
                continuitySubscore: 0,
                remSubscore: 0,
                deepSubscore: 0
            )
        }

        let duration = durationSubscore(totalHours: totalSleepHours, goalHours: sleepGoalHours)
        let continuity = continuitySubscore(
            wallDuration: sessionWallDuration,
            awakeSeconds: awakeSecondsDuringSession
        )
        let tst = totalSleepHours
        let dPct = deepSleepHours.map { $0 / tst }
        let rPct = remSleepHours.map { $0 / tst }
        let deepS: Double = {
            guard let p = dPct else { return missingPhaseNeutral }
            return trapezoidPercentScore(percent: p, bandMin: deepBandMin, bandMax: deepBandMax)
        }()
        let remS: Double = {
            guard let p = rPct else { return missingPhaseNeutral }
            return trapezoidPercentScore(percent: p, bandMin: remBandMin, bandMax: remBandMax)
        }()

        let raw = duration * durationWeight
            + continuity * continuityWeight
            + deepS * deepWeight
            + remS * remWeight

        let hourCap = maxScoreCapForTotalHours(totalSleepHours)
        let afterCap = min(raw, hourCap)

        let conf = max(0.0, min(1.0, sleepConfidence))
        let withConfidence = afterCap + confidenceDeltaPoints * (conf - 0.5)
        let clamped = max(0.0, min(100.0, withConfidence))
        let display = Int(max(0, min(100, round(clamped))))

        return Result(
            displayScore: display,
            sleepQualityForRecovery: clamped,
            rawWeightedComposite: raw,
            scoreAfterDurationHourCap: afterCap,
            durationSubscore: duration,
            continuitySubscore: continuity,
            remSubscore: remS,
            deepSubscore: deepS
        )
    }

    // MARK: - Subscores

    /// Duración no lineal por debajo de la meta; por encima se considera 100 en el subscore.
    static func durationSubscore(totalHours: Double, goalHours: Double) -> Double {
        guard goalHours > 0 else { return 0 }
        let ratio = min(1.0, totalHours / goalHours)
        if totalHours >= goalHours { return 100.0 }
        return min(100.0, 100.0 * pow(ratio, belowGoalCurvature))
    }

    /// Vigilia relativa al ancho reloj de la sesión; sin datos de `awake` ⇒ neutral.
    static func continuitySubscore(
        wallDuration: TimeInterval?,
        awakeSeconds: TimeInterval?
    ) -> Double {
        guard let wall = wallDuration, wall > 1 else { return continuityNeutralNoAwakeStaging }
        guard let awake = awakeSeconds else { return continuityNeutralNoAwakeStaging }
        let r = max(0.0, min(1.0, awake / wall))
        return min(100.0, max(0.0, 100.0 * (1.0 - min(1.0, r / awakeRatioFullPenalty))))
    }

    /// Techo global de puntuación cuando la duración es insuficiente (evita compensar con REM/deep).
    static func maxScoreCapForTotalHours(_ hours: Double) -> Double {
        if hours < 3.0 { return 32 }
        if hours < 3.5 { return 44 }
        if hours < 4.0 { return 54 }
        if hours < 4.5 { return 64 }
        if hours < 5.0 { return 72 }
        if hours < 6.0 { return 82 }
        if hours < 6.5 { return 88 }
        if hours < 7.0 { return 93 }
        if hours < 7.5 { return 97 }
        return 100
    }

    /// Plataforma en la banda [bandMin, bandMax] del porcentaje del TST; fuera, descenso suave.
    private static func trapezoidPercentScore(percent: Double, bandMin: Double, bandMax: Double) -> Double {
        let p = max(0.0, min(1.0, percent))
        if p >= bandMin && p <= bandMax { return 100.0 }
        if p < bandMin {
            guard bandMin > 0 else { return 0 }
            return min(100.0, 100.0 * p / bandMin)
        }
        // por encima del máximo de banda: ligera penalización (exceso raro)
        let over = p - bandMax
        let room = max(0.08, 0.45 - bandMax)
        return max(55.0, 100.0 * (1.0 - min(1.0, over / room)))
    }
}
