//
//  GymCoach.swift
//  Super Fitness Coach App
//

import Foundation

/// Micro-coaching en sesión (gym): mensajes cortos, sin red. Respeta `AppLanguage`.
enum GymCoach {

    // MARK: - Apertura de sesión

    static func sessionOpening(recoveryScore: Int, firstExerciseName: String, language: AppLanguage) -> String {
        switch language {
        case .spanish:
            return sessionOpeningES(recoveryScore: recoveryScore, firstExerciseName: firstExerciseName)
        case .english:
            return sessionOpeningEN(recoveryScore: recoveryScore, firstExerciseName: firstExerciseName)
        }
    }

    private static func sessionOpeningES(recoveryScore: Int, firstExerciseName: String) -> String {
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

    private static func sessionOpeningEN(recoveryScore: Int, firstExerciseName: String) -> String {
        let recoveryHint: String
        if recoveryScore < 40 {
            recoveryHint = "Your body is asking for calm today: prioritize technique over load."
        } else if recoveryScore < 60 {
            recoveryHint = "Moderate recovery: add weight only if form stays crisp."
        } else {
            recoveryHint = "Recovery looks good: you can push with intent, always under control."
        }
        return "First exercise: \(firstExerciseName). \(recoveryHint)"
    }

    // MARK: - Cambio de ejercicio

    static func exerciseIntro(
        exercise: PlannedExercise,
        exerciseIndex: Int,
        totalExercises: Int,
        language: AppLanguage
    ) -> String {
        switch language {
        case .spanish:
            return exerciseIntroES(exercise: exercise, exerciseIndex: exerciseIndex, totalExercises: totalExercises)
        case .english:
            return exerciseIntroEN(exercise: exercise, exerciseIndex: exerciseIndex, totalExercises: totalExercises)
        }
    }

    private static func exerciseIntroES(exercise: PlannedExercise, exerciseIndex: Int, totalExercises: Int) -> String {
        let position = "\(exerciseIndex + 1)/\(totalExercises)"
        let compound = exercise.isCompound
            ? "Movimiento compuesto: estabiliza el core antes de empujar o tirar."
            : "Accesorio: busca la conexión mente-músculo y evita balanceos."
        let cue = formCue(for: exercise, language: .spanish)
        return "[\(position)] \(exercise.name). \(compound) \(cue)"
    }

    private static func exerciseIntroEN(exercise: PlannedExercise, exerciseIndex: Int, totalExercises: Int) -> String {
        let position = "\(exerciseIndex + 1)/\(totalExercises)"
        let compound = exercise.isCompound
            ? "Compound lift: brace your core before you push or pull."
            : "Accessory: chase mind-muscle connection and avoid swinging."
        let cue = formCue(for: exercise, language: .english)
        return "[\(position)] \(exercise.name). \(compound) \(cue)"
    }

    // MARK: - Tras completar una serie (y opcionalmente descanso)

    static func messageAfterSet(
        wasPR: Bool,
        exercise: PlannedExercise,
        completedSetIndex: Int,
        totalSets: Int,
        restSeconds: Int,
        language: AppLanguage
    ) -> String {
        switch language {
        case .spanish:
            return messageAfterSetES(
                wasPR: wasPR,
                exercise: exercise,
                completedSetIndex: completedSetIndex,
                totalSets: totalSets,
                restSeconds: restSeconds
            )
        case .english:
            return messageAfterSetEN(
                wasPR: wasPR,
                exercise: exercise,
                completedSetIndex: completedSetIndex,
                totalSets: totalSets,
                restSeconds: restSeconds
            )
        }
    }

    private static func messageAfterSetES(
        wasPR: Bool,
        exercise: PlannedExercise,
        completedSetIndex: Int,
        totalSets: Int,
        restSeconds: Int
    ) -> String {
        let remaining = max(0, totalSets - completedSetIndex - 1)
        let prLine = wasPR ? "¡Eso es un PR estimado! " : ""
        let nextLine: String
        if remaining > 0 {
            nextLine = "Te quedan \(remaining) serie(s)."
        } else {
            nextLine = "Última serie de este ejercicio: cierra fuerte y con buena forma."
        }
        if restSeconds > 0 {
            let restHint = restEncouragement(seconds: restSeconds, exercise: exercise, language: .spanish)
            return "\(prLine)\(nextLine) Descanso \(restSeconds)s — \(restHint)"
        }
        return "\(prLine)\(nextLine)"
    }

    private static func messageAfterSetEN(
        wasPR: Bool,
        exercise: PlannedExercise,
        completedSetIndex: Int,
        totalSets: Int,
        restSeconds: Int
    ) -> String {
        let remaining = max(0, totalSets - completedSetIndex - 1)
        let prLine = wasPR ? "That’s an estimated PR! " : ""
        let nextLine: String
        if remaining > 0 {
            nextLine = remaining == 1 ? "1 set left." : "\(remaining) sets left."
        } else {
            nextLine = "Last set for this exercise: finish strong with good form."
        }
        if restSeconds > 0 {
            let restHint = restEncouragement(seconds: restSeconds, exercise: exercise, language: .english)
            return "\(prLine)\(nextLine) Rest \(restSeconds)s — \(restHint)"
        }
        return "\(prLine)\(nextLine)"
    }

    // MARK: - Descanso (cuenta atrás visible en UI; reforzamos el foco)

    static func restFocus(exercise: PlannedExercise, restSecondsRemaining: Int, language: AppLanguage) -> String {
        switch language {
        case .spanish:
            return restFocusES(exercise: exercise, restSecondsRemaining: restSecondsRemaining)
        case .english:
            return restFocusEN(exercise: exercise, restSecondsRemaining: restSecondsRemaining)
        }
    }

    private static func restFocusES(exercise: PlannedExercise, restSecondsRemaining: Int) -> String {
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

    private static func restFocusEN(exercise: PlannedExercise, restSecondsRemaining: Int) -> String {
        if restSecondsRemaining <= 10 {
            return "Final seconds: breathe, prep the next set, and check your range of motion."
        }
        let pool = [
            "Take a sip of water if you need it.",
            "Loosen neck and shoulders; get tight only when you start the set.",
            "Visualize your next perfect rep.",
            "Keep chest tall and core ready if the lift demands it.",
        ]
        let idx = abs(exercise.effectiveCatalogId.hashValue) % pool.count
        return pool[idx]
    }

    // MARK: - Private

    private static func restEncouragement(seconds: Int, exercise: PlannedExercise, language: AppLanguage) -> String {
        switch language {
        case .spanish:
            if seconds >= 120 {
                return "Descanso largo: puedes caminar un poco y movilizar articulaciones."
            }
            if exercise.isCompound {
                return "En compuestos, usa el descanso para recuperar el sistema nervioso, no solo el músculo."
            }
            return "Enfoca la siguiente serie: misma técnica, mismo recorrido."
        case .english:
            if seconds >= 120 {
                return "Long rest: walk a bit and loosen up your joints."
            }
            if exercise.isCompound {
                return "On compounds, use the rest for your nervous system, not just the muscle."
            }
            return "Lock in the next set: same technique, same range."
        }
    }

    private static func formCue(for exercise: PlannedExercise, language: AppLanguage) -> String {
        switch language {
        case .spanish:
            return formCueES(for: exercise)
        case .english:
            return formCueEN(for: exercise)
        }
    }

    private static func formCueES(for exercise: PlannedExercise) -> String {
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

    private static func formCueEN(for exercise: PlannedExercise) -> String {
        switch exercise.muscleGroup {
        case .chest:
            return "Chest: shoulders down, slight chest lift, elbows ~45°."
        case .back:
            return "Back: pull with the elbow, not the hand; scaps engaged."
        case .shoulders:
            return "Shoulders: don’t hold your breath; move through pain-free range."
        case .biceps, .triceps:
            return "Arms: elbows fixed; avoid hip swing."
        case .quads, .hamstrings, .glutes:
            return "Legs: knees track over toes; depth based on mobility."
        case .calves:
            return "Calves: full range up and down—no harsh bouncing."
        case .core:
            return "Core: neutral lumbar; if form breaks down, reduce intensity."
        }
    }
}
