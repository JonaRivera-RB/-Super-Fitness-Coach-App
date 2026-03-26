//
//  GymCoach.swift
//  Super Fitness Coach App
//

import Foundation

/// Micro-coaching en sesión (gym): mensajes cortos en español, sin red.
enum GymCoach {

    // MARK: - Apertura de sesión

    static func sessionOpening(recoveryScore: Int, firstExerciseName: String) -> String {
        let recoveryHint: String
        if recoveryScore < 40 {
            recoveryHint = "Hoy el cuerpo pide calma: prioriza técnica sobre peso."
        } else if recoveryScore < 60 {
            recoveryHint = "Recuperación moderada: sube el peso solo si la forma se mantiene limpia."
        } else {
            recoveryHint = "Buena señal de recuperación: puedes empujar con intención, siempre con control."
        }
        return "Primer ejercicio: \(firstExerciseName). \(recoveryHint)"
    }

    // MARK: - Cambio de ejercicio

    static func exerciseIntro(
        exercise: PlannedExercise,
        exerciseIndex: Int,
        totalExercises: Int
    ) -> String {
        let position = "\(exerciseIndex + 1)/\(totalExercises)"
        let compound = exercise.isCompound
            ? "Movimiento compuesto: estabiliza el core antes de empujar o tirar."
            : "Accesorio: busca la conexión mente-músculo y evita balanceos."

        let cue = formCue(for: exercise)
        return "[\(position)] \(exercise.name). \(compound) \(cue)"
    }

    // MARK: - Tras completar una serie (y opcionalmente descanso)

    static func messageAfterSet(
        wasPR: Bool,
        exercise: PlannedExercise,
        completedSetIndex: Int,
        totalSets: Int,
        restSeconds: Int
    ) -> String {
        let remaining = max(0, totalSets - completedSetIndex - 1)
        let prLine: String
        if wasPR {
            prLine = "¡Eso es un PR estimado! "
        } else {
            prLine = ""
        }

        let nextLine: String
        if remaining > 0 {
            nextLine = "Te quedan \(remaining) serie(s)."
        } else {
            nextLine = "Última serie de este ejercicio: cierra fuerte y con buena forma."
        }

        if restSeconds > 0 {
            let restHint = restEncouragement(seconds: restSeconds, exercise: exercise)
            return "\(prLine)\(nextLine) Descanso \(restSeconds)s — \(restHint)"
        }
        return "\(prLine)\(nextLine)"
    }

    // MARK: - Descanso (cuenta atrás visible en UI; reforzamos el foco)

    static func restFocus(exercise: PlannedExercise, restSecondsRemaining: Int) -> String {
        if restSecondsRemaining <= 10 {
            return "Últimos segundos: respira, prepara la siguiente serie y revisa el recorrido."
        }
        let pool = [
            "Hidrátate un sorbo si lo necesitas.",
            "Afloja cuello y hombros; vuelve en tensión solo al iniciar la serie.",
            "Visualiza la siguiente repetición perfecta.",
            "Mantén el pecho alto y el core listo si el movimiento lo pide.",
        ]
        let idx = abs(exercise.effectiveCatalogId.hashValue) % pool.count
        return pool[idx]
    }

    // MARK: - Private

    private static func restEncouragement(seconds: Int, exercise: PlannedExercise) -> String {
        if seconds >= 120 {
            return "Descanso largo: puedes caminar un poco y movilizar articulaciones."
        }
        if exercise.isCompound {
            return "En compuestos, usa el descanso para recuperar el sistema nervioso, no solo el músculo."
        }
        return "Enfoca la siguiente serie: misma técnica, mismo recorrido."
    }

    private static func formCue(for exercise: PlannedExercise) -> String {
        switch exercise.muscleGroup {
        case .chest:
            return "Pecho: hombros abajo, pecho ligeramente alto, codos a ~45°."
        case .back:
            return "Espalda: tira con el codo, no con la mano; omóplatos activos."
        case .shoulders:
            return "Hombros: no bloquees respiración; rango sin dolor punzante."
        case .biceps, .triceps:
            return "Brazos: codos fijos; evita el impulso de cadera."
        case .quads, .hamstrings, .glutes:
            return "Piernas: rodillas alineadas con los pies; profundidad según movilidad."
        case .calves:
            return "Gemelos: rango completo arriba y abajo, sin rebotes bruscos."
        case .core:
            return "Core: lumbar neutro; si fatigas la técnica, baja intensidad."
        }
    }
}
