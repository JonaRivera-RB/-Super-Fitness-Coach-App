import Foundation

/// Nivel de fitness del usuario, usado para ajustar intensidad de entrenamientos.
enum FitnessLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}

/// Metas personalizadas del usuario. Se almacena como propiedad Codable dentro de UserProfile.
struct FitnessConfig: Codable, Equatable {
    var sleepGoalHours: Double    // 4.0...12.0, default 8.0
    var stepsGoal: Double         // 1000...50000, default 10000
    var calorieGoal: Double       // 100...2000, default 500
    var baselineRestingHR: Double // 35...120, default 70
    var fitnessLevel: FitnessLevel // default .beginner

    static let `default` = FitnessConfig(
        sleepGoalHours: 8.0,
        stepsGoal: 10000,
        calorieGoal: 500,
        baselineRestingHR: 70,
        fitnessLevel: .beginner
    )

    /// Valida que todos los campos estén dentro de rangos aceptables.
    var isValid: Bool {
        (4.0...12.0).contains(sleepGoalHours) &&
        (1000...50000).contains(stepsGoal) &&
        (100...2000).contains(calorieGoal) &&
        (35...120).contains(baselineRestingHR)
    }
}
