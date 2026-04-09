//
//  AICoach.swift
//  Super Fitness Coach App
//

import Foundation

struct AICoach {
    /// Genera un mensaje contextual del coach según el estado actual y el idioma de la app.
    static func generateMessage(
        userName: String,
        recoveryScore: Int,
        activityScore: Int,
        recoveryBreakdown: ScoreBreakdown? = nil,
        streakDays: Int,
        recentWorkoutCount: Int,
        recoveryConfidence: HealthKitManager.DataConfidenceLevel? = nil,
        language: AppLanguage = .current
    ) -> String {
        let firstName = extractFirstName(from: userName)
        let message: String

        switch language {
        case .spanish:
            message = generateMessageES(
                firstName: firstName,
                recoveryScore: recoveryScore,
                activityScore: activityScore,
                recoveryBreakdown: recoveryBreakdown,
                streakDays: streakDays
            )
        case .english:
            message = generateMessageEN(
                firstName: firstName,
                recoveryScore: recoveryScore,
                activityScore: activityScore,
                recoveryBreakdown: recoveryBreakdown,
                streakDays: streakDays
            )
        }

        return message + Self.confidenceSuffix(recoveryConfidence, language: language)
    }

    // MARK: - Spanish

    private static func generateMessageES(
        firstName: String,
        recoveryScore: Int,
        activityScore: Int,
        recoveryBreakdown: ScoreBreakdown?,
        streakDays: Int
    ) -> String {
        if recoveryScore < 40 {
            if activityScore > 70 {
                if let breakdown = recoveryBreakdown {
                    let reason = contextualReason(from: breakdown, language: .spanish)
                    return "\(firstName), estuviste muy activo pero tu cuerpo necesita descansar. \(reason) 💤"
                }
                return "\(firstName), estuviste muy activo pero tu cuerpo necesita descansar hoy. Tómatelo con calma 💤"
            } else if let breakdown = recoveryBreakdown {
                let reason = contextualReason(from: breakdown, language: .spanish)
                return "\(firstName), tu cuerpo necesita descansar hoy. \(reason) 💤"
            }
            return "\(firstName), tu cuerpo necesita descansar hoy. Tómatelo con calma y recupérate bien 💤"
        } else if streakDays >= 3 {
            let streakText = "\(streakDays) días seguidos, gran progreso"
            if recoveryScore >= 70 {
                return "\(firstName), \(streakText). Estás listo para entrenar fuerte hoy 🔥"
            } else if recoveryScore >= 40 {
                if let breakdown = recoveryBreakdown {
                    let reason = contextualReason(from: breakdown, language: .spanish)
                    return "\(firstName), \(streakText). Hoy ve con actividad moderada, \(reason) 🔥"
                }
                return "\(firstName), \(streakText). Hoy ve con actividad moderada 🔥"
            }
            return "\(firstName), \(streakText). Hoy toca descansar para seguir avanzando 🔥"
        } else if recoveryScore >= 40 && recoveryScore <= 69 {
            if let breakdown = recoveryBreakdown {
                let reason = contextualReason(from: breakdown, language: .spanish)
                return "\(firstName), tu recuperación es moderada. \(reason). Ve con actividad moderada hoy 🟡"
            }
            return "\(firstName), tu recuperación es moderada. Ve con actividad moderada hoy 🟡"
        } else if recoveryScore >= 70 {
            if streakDays == 0 && activityScore < 30 {
                return "\(firstName), estás listo para entrenar fuerte y no te has movido mucho. ¡Vamos a darle! 💪"
            }
            return "\(firstName), estás listo para entrenar fuerte hoy. ¡A darle con todo! 💪"
        }
        return "\(firstName), cada paso cuenta. ¡Sigue adelante! 🌟"
    }

    // MARK: - English

    private static func generateMessageEN(
        firstName: String,
        recoveryScore: Int,
        activityScore: Int,
        recoveryBreakdown: ScoreBreakdown?,
        streakDays: Int
    ) -> String {
        if recoveryScore < 40 {
            if activityScore > 70 {
                if let breakdown = recoveryBreakdown {
                    let reason = contextualReason(from: breakdown, language: .english)
                    return "\(firstName), you’ve been very active, but your body needs rest. \(reason) 💤"
                }
                return "\(firstName), you’ve been very active, but your body needs rest today. Take it easy 💤"
            } else if let breakdown = recoveryBreakdown {
                let reason = contextualReason(from: breakdown, language: .english)
                return "\(firstName), your body needs rest today. \(reason) 💤"
            }
            return "\(firstName), your body needs rest today. Ease up and recover well 💤"
        } else if streakDays >= 3 {
            let streakText = "\(streakDays) days in a row—great progress"
            if recoveryScore >= 70 {
                return "\(firstName), \(streakText). You’re ready to train hard today 🔥"
            } else if recoveryScore >= 40 {
                if let breakdown = recoveryBreakdown {
                    let reason = contextualReason(from: breakdown, language: .english)
                    return "\(firstName), \(streakText). Go moderate today—\(reason) 🔥"
                }
                return "\(firstName), \(streakText). Keep today moderate 🔥"
            }
            return "\(firstName), \(streakText). Rest today to keep progressing 🔥"
        } else if recoveryScore >= 40 && recoveryScore <= 69 {
            if let breakdown = recoveryBreakdown {
                let reason = contextualReason(from: breakdown, language: .english)
                return "\(firstName), recovery is moderate. \(reason). Keep activity moderate today 🟡"
            }
            return "\(firstName), recovery is moderate. Keep activity moderate today 🟡"
        } else if recoveryScore >= 70 {
            if streakDays == 0 && activityScore < 30 {
                return "\(firstName), you’re ready to train hard and haven’t moved much yet—let’s go 💪"
            }
            return "\(firstName), you’re ready to train hard today—let’s get after it 💪"
        }
        return "\(firstName), every step counts. Keep going 🌟"
    }

    private static func confidenceSuffix(_ level: HealthKitManager.DataConfidenceLevel?, language: AppLanguage) -> String {
        guard let level else { return "" }
        switch (level, language) {
        case (.insufficient, .spanish):
            return " Nota: faltan datos clave; la puntuación es poco fiable."
        case (.insufficient, .english):
            return " Note: key data is missing; the score is unreliable."
        case (.low, .spanish):
            return " Nota: señal de datos débil hoy; interpreta con calma."
        case (.low, .english):
            return " Note: weak data signal today—interpret gently."
        case (.medium, _), (.high, _):
            return ""
        }
    }

    /// Identifica el componente con peor normalizedScore del breakdown.
    static func worstComponent(from breakdown: ScoreBreakdown) -> ScoreBreakdown.ScoreComponent? {
        breakdown.components.min(by: { $0.normalizedScore < $1.normalizedScore })
    }

    /// Genera la razón contextual basada en el peor componente del breakdown.
    static func contextualReason(from breakdown: ScoreBreakdown, language: AppLanguage = .current) -> String {
        guard let worst = worstComponent(from: breakdown) else {
            switch language {
            case .spanish: return "tu cuerpo necesita recuperarse"
            case .english: return "your body needs to recover"
            }
        }

        let name = worst.name.lowercased()

        if name.contains("sleep") {
            let hours = worst.rawValue
            switch language {
            case .spanish:
                if hours < 6 {
                    return "dormiste solo \(String(format: "%.1f", hours))h, necesitas descansar más"
                }
                return "tu sueño no fue suficiente (\(String(format: "%.1f", hours))h)"
            case .english:
                if hours < 6 {
                    return "you only slept \(String(format: "%.1f", hours))h—you need more rest"
                }
                return "your sleep wasn’t enough (\(String(format: "%.1f", hours))h)"
            }
        }

        if name.contains("resting") || (name.contains("hr") && !name.contains("hrv")) {
            let bpm = Int(worst.rawValue)
            switch language {
            case .spanish:
                return "tu frecuencia cardíaca en reposo está elevada (\(bpm) bpm), señal de estrés cardiovascular"
            case .english:
                return "your resting heart rate is elevated (\(bpm) bpm)—a sign of cardiovascular stress"
            }
        }

        if name.contains("hrv") {
            let ms = Int(worst.rawValue)
            switch language {
            case .spanish:
                return "tu HRV está bajo (\(ms)ms), lo que indica menor recuperación"
            case .english:
                return "your HRV is low (\(ms) ms), suggesting lower recovery"
            }
        }

        if name.contains("step") {
            let steps = Int(worst.rawValue)
            switch language {
            case .spanish:
                return "llevas \(steps) pasos, necesitas moverte más"
            case .english:
                return "you’re at \(steps) steps—time to move more"
            }
        }

        if name.contains("calor") {
            let kcal = Int(worst.rawValue)
            switch language {
            case .spanish:
                return "llevas \(kcal) kcal activas, aún queda camino"
            case .english:
                return "you’re at \(kcal) active kcal—still room to grow"
            }
        }

        switch language {
        case .spanish: return "tu \(worst.name) necesita atención"
        case .english: return "your \(worst.name) needs attention"
        }
    }

    private static func extractFirstName(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }
}
