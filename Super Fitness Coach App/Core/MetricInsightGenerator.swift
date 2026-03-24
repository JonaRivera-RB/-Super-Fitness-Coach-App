import Foundation

/// Insight contextual generado para una métrica individual.
struct MetricInsight {
    let metricName: String
    let message: String
    let status: ScoreBreakdown.ComponentStatus
}

/// Genera insights contextuales en español para cada componente de un ScoreBreakdown.
struct MetricInsightGenerator {

    /// Genera insights para todos los componentes de un breakdown.
    /// Retorna array vacío si el breakdown no tiene componentes.
    static func generateInsights(
        from breakdown: ScoreBreakdown,
        config: FitnessConfig
    ) -> [MetricInsight] {
        breakdown.components.map { generateInsight(for: $0, config: config) }
    }

    /// Genera un insight individual para un componente.
    static func generateInsight(
        for component: ScoreBreakdown.ScoreComponent,
        config: FitnessConfig
    ) -> MetricInsight {
        switch component.name {
        case "Sleep":
            return sleepInsight(for: component, config: config)
        case "Resting HR":
            return restingHRInsight(for: component, config: config)
        case "HRV":
            return hrvInsight(for: component)
        case "Steps":
            return stepsInsight(for: component, config: config)
        case "Active Calories":
            return caloriesInsight(for: component, config: config)
        default:
            return MetricInsight(
                metricName: component.name,
                message: "\(component.name): \(formatValue(component.rawValue)) \(component.rawUnit)",
                status: component.status
            )
        }
    }

    // MARK: - Private Insight Generators

    private static func sleepInsight(
        for component: ScoreBreakdown.ScoreComponent,
        config: FitnessConfig
    ) -> MetricInsight {
        let hours = component.rawValue
        let goal = config.sleepGoalHours

        let message: String
        switch component.status {
        case .warning:
            if goal > 0 {
                let deficit = goal - hours
                message = "Dormiste \(formatValue(hours))h de tu meta de \(formatValue(goal))h — te faltaron \(formatValue(deficit))h 😴"
            } else {
                message = "Dormiste \(formatValue(hours))h — necesitas más descanso 😴"
            }
        case .normal:
            message = "Dormiste \(formatValue(hours))h — cerca de tu meta de \(formatValue(goal))h"
        case .good:
            message = "Buen descanso: \(formatValue(hours))h de sueño ✓"
        }

        return MetricInsight(metricName: "Sueño", message: message, status: component.status)
    }

    private static func restingHRInsight(
        for component: ScoreBreakdown.ScoreComponent,
        config: FitnessConfig
    ) -> MetricInsight {
        let hr = Int(component.rawValue)
        let baseline = Int(config.baselineRestingHR)

        // When HealthKit returns no resting HR data, rawValue is 0 — show a "no data" message
        guard hr > 0 else {
            return MetricInsight(
                metricName: "Frecuencia Cardíaca",
                message: "Sin datos de FC en reposo disponibles",
                status: component.status
            )
        }

        let message: String
        switch component.status {
        case .warning:
            message = "Tu FC en reposo (\(hr) bpm) está elevada vs tu promedio (\(baseline) bpm) — señal de fatiga"
        case .normal:
            message = "FC en reposo normal: \(hr) bpm"
        case .good:
            message = "FC en reposo baja: \(hr) bpm — buena recuperación ✓"
        }

        return MetricInsight(metricName: "Frecuencia Cardíaca", message: message, status: component.status)
    }

    private static func hrvInsight(
        for component: ScoreBreakdown.ScoreComponent
    ) -> MetricInsight {
        let hrv = Int(component.rawValue)

        let message: String
        switch component.status {
        case .warning:
            message = "Tu variabilidad cardíaca (\(hrv)ms) está baja — menor recuperación"
        case .normal:
            message = "HRV normal: \(hrv)ms"
        case .good:
            message = "HRV alto (\(hrv)ms) — tu sistema nervioso está bien recuperado ✓"
        }

        return MetricInsight(metricName: "HRV", message: message, status: component.status)
    }

    private static func stepsInsight(
        for component: ScoreBreakdown.ScoreComponent,
        config: FitnessConfig
    ) -> MetricInsight {
        let steps = Int(component.rawValue)
        let goal = Int(config.stepsGoal)

        let message: String
        switch component.status {
        case .warning:
            message = "Llevas \(formatInt(steps)) de \(formatInt(goal)) pasos — ¡a moverse! 🚶"
        case .normal:
            message = "\(formatInt(steps)) de \(formatInt(goal)) pasos — vas bien"
        case .good:
            message = "¡Gran actividad! \(formatInt(steps)) pasos hoy ✓"
        }

        return MetricInsight(metricName: "Pasos", message: message, status: component.status)
    }

    private static func caloriesInsight(
        for component: ScoreBreakdown.ScoreComponent,
        config: FitnessConfig
    ) -> MetricInsight {
        let cals = Int(component.rawValue)
        let goal = Int(config.calorieGoal)

        let message: String
        switch component.status {
        case .warning:
            message = "\(cals) de \(goal) kcal activas — aún queda camino"
        case .normal:
            message = "\(cals) de \(goal) kcal activas — en progreso"
        case .good:
            message = "Meta de calorías cumplida: \(cals) kcal ✓"
        }

        return MetricInsight(metricName: "Calorías", message: message, status: component.status)
    }

    // MARK: - Formatting Helpers

    private static func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private static func formatInt(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
