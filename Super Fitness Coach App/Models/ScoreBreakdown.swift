import Foundation

/// Desglose explicable de un score. Cada componente muestra su contribución individual.
struct ScoreBreakdown: Equatable {
    let components: [ScoreComponent]
    let finalScore: Int

    struct ScoreComponent: Equatable {
        let name: String           // e.g. "Sleep Quality", "Resting HR"
        let rawValue: Double       // e.g. 6.2 (horas), 62 (bpm)
        let rawUnit: String        // e.g. "h", "bpm", "ms", "steps", "kcal"
        let normalizedScore: Double // 0-100
        let weight: Double         // e.g. 0.45
        let contribution: Double   // normalizedScore × weight
        let description: String    // e.g. "Dormiste 6.2h de tu meta de 8h"
        let status: ComponentStatus
    }

    enum ComponentStatus: Equatable {
        case normal
        case warning  // normalizedScore < 40
        case good     // normalizedScore >= 70
    }
}
