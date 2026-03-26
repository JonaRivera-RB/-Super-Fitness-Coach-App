//
//  AICoach.swift
//  Super Fitness Coach App
//

import Foundation

struct AICoach {
    /// Genera un mensaje contextual del coach basado en el estado actual.
    /// Las reglas se evalúan en orden de prioridad:
    ///   1. Recovery < 40 → recomendación de descanso (con contexto de actividad y breakdown)
    ///   2. Streak ≥ 3 → reconocimiento del streak + recomendación basada en recovery
    ///   3. Recovery 40-69 → actividad moderada con métricas limitantes
    ///   4. Recovery >= 70 → listo para entrenar fuerte
    ///   5. Default → motivación general
    /// Todos los mensajes incluyen el primer nombre del usuario y están en español.
    static func generateMessage(
        userName: String,
        recoveryScore: Int,
        activityScore: Int,
        recoveryBreakdown: ScoreBreakdown? = nil,
        streakDays: Int,
        recentWorkoutCount: Int,
        recoveryConfidence: HealthKitManager.DataConfidenceLevel? = nil
    ) -> String {
        let firstName = extractFirstName(from: userName)
        let message: String

        // Rule 1: Low recovery → rest recommendation
        if recoveryScore < 40 {
            if activityScore > 70 {
                // Req 1.7: Acknowledge effort + emphasize recovery
                if let breakdown = recoveryBreakdown {
                    let reason = contextualReason(from: breakdown)
                    message = "\(firstName), estuviste muy activo pero tu cuerpo necesita descansar. \(reason) 💤"
                } else {
                    message = "\(firstName), estuviste muy activo pero tu cuerpo necesita descansar hoy. Tómatelo con calma 💤"
                }
            } else if let breakdown = recoveryBreakdown {
                let reason = contextualReason(from: breakdown)
                message = "\(firstName), tu cuerpo necesita descansar hoy. \(reason) 💤"
            } else {
                message = "\(firstName), tu cuerpo necesita descansar hoy. Tómatelo con calma y recupérate bien 💤"
            }
        } else if streakDays >= 3 {
            // Rule 2: Active streak → combine streak recognition with recovery-based recommendation
            let streakText = "\(streakDays) días seguidos, gran progreso"
            if recoveryScore >= 70 {
                message = "\(firstName), \(streakText). Estás listo para entrenar fuerte hoy 🔥"
            } else if recoveryScore >= 40 {
                if let breakdown = recoveryBreakdown {
                    let reason = contextualReason(from: breakdown)
                    message = "\(firstName), \(streakText). Hoy ve con actividad moderada, \(reason) 🔥"
                } else {
                    message = "\(firstName), \(streakText). Hoy ve con actividad moderada 🔥"
                }
            } else {
                message = "\(firstName), \(streakText). Hoy toca descansar para seguir avanzando 🔥"
            }
        } else if recoveryScore >= 40 && recoveryScore <= 69 {
            // Rule 3: Recovery 40-69 → moderate activity, indicate limiting metrics
            if let breakdown = recoveryBreakdown {
                let reason = contextualReason(from: breakdown)
                message = "\(firstName), tu recuperación es moderada. \(reason). Ve con actividad moderada hoy 🟡"
            } else {
                message = "\(firstName), tu recuperación es moderada. Ve con actividad moderada hoy 🟡"
            }
        } else if recoveryScore >= 70 {
            // Rule 4: Recovery >= 70 → ready for intense training
            if streakDays == 0 && activityScore < 30 {
                message = "\(firstName), estás listo para entrenar fuerte y no te has movido mucho. ¡Vamos a darle! 💪"
            } else {
                message = "\(firstName), estás listo para entrenar fuerte hoy. ¡A darle con todo! 💪"
            }
        } else {
            // Rule 5: Default encouragement
            message = "\(firstName), cada paso cuenta. ¡Sigue adelante! 🌟"
        }

        return message + Self.confidenceSuffix(recoveryConfidence)
    }

    private static func confidenceSuffix(_ level: HealthKitManager.DataConfidenceLevel?) -> String {
        guard let level else { return "" }
        switch level {
        case .insufficient:
            return " Nota: faltan datos clave; la puntuación es poco fiable."
        case .low:
            return " Nota: señal de datos débil hoy; interpreta con calma."
        case .medium, .high:
            return ""
        }
    }

    /// Identifica el componente con peor normalizedScore del breakdown.
    static func worstComponent(from breakdown: ScoreBreakdown) -> ScoreBreakdown.ScoreComponent? {
        breakdown.components.min(by: { $0.normalizedScore < $1.normalizedScore })
    }

    /// Genera la razón contextual basada en el peor componente del breakdown.
    static func contextualReason(from breakdown: ScoreBreakdown) -> String {
        guard let worst = worstComponent(from: breakdown) else {
            return "tu cuerpo necesita recuperarse"
        }

        let name = worst.name.lowercased()

        if name.contains("sleep") {
            let hours = worst.rawValue
            if hours < 6 {
                return "dormiste solo \(String(format: "%.1f", hours))h, necesitas descansar más"
            }
            return "tu sueño no fue suficiente (\(String(format: "%.1f", hours))h)"
        }

        if name.contains("resting") || (name.contains("hr") && !name.contains("hrv")) {
            let bpm = Int(worst.rawValue)
            return "tu frecuencia cardíaca en reposo está elevada (\(bpm) bpm), señal de estrés cardiovascular"
        }

        if name.contains("hrv") {
            let ms = Int(worst.rawValue)
            return "tu HRV está bajo (\(ms)ms), lo que indica menor recuperación"
        }

        if name.contains("step") {
            let steps = Int(worst.rawValue)
            return "llevas \(steps) pasos, necesitas moverte más"
        }

        if name.contains("calor") {
            let kcal = Int(worst.rawValue)
            return "llevas \(kcal) kcal activas, aún queda camino"
        }

        // Generic fallback for unknown component names
        return "tu \(worst.name) necesita atención"
    }

    /// Extrae el primer nombre (primer token separado por espacios) del nombre completo.
    private static func extractFirstName(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }
}
