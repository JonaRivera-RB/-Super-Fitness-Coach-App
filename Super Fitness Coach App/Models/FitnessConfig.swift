import Foundation

/// Unidad en la que el usuario introduce y ve el peso de las pesas (gimnasio). Los datos internos siguen en kg.
enum LiftingWeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms
    case pounds

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lb"
        }
    }
}

/// Nivel de fitness del usuario, usado para ajustar intensidad de entrenamientos.
enum FitnessLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}

/// User-defined expected sleep schedule (hour + minute only).
/// Note: We intentionally do NOT store DateComponents here because SwiftData can crash
/// when persisting structs containing Calendar/TimeZone internals.
struct SleepGoal: Codable, Equatable {
    struct HourMinute: Codable, Equatable {
        let hour: Int
        let minute: Int

        init(hour: Int, minute: Int) {
            self.hour = hour
            self.minute = minute
        }

        init(from components: DateComponents) {
            self.hour = components.hour ?? 0
            self.minute = components.minute ?? 0
        }

        var asDateComponents: DateComponents {
            DateComponents(hour: hour, minute: minute)
        }
    }

    var targetSleepTime: HourMinute
    var targetWakeTime: HourMinute

    /// True when times differ and duration is at least 4 hours.
    var isValid: Bool {
        guard targetSleepTime.hour != targetWakeTime.hour || targetSleepTime.minute != targetWakeTime.minute else {
            return false
        }
        return durationHours >= 4.0
    }

    /// Duration in hours between targetSleepTime and targetWakeTime, crossing midnight if needed.
    var durationHours: Double {
        let start = Self.minutesSinceMidnight(targetSleepTime)
        let end = Self.minutesSinceMidnight(targetWakeTime)
        let minutes: Int
        if end > start {
            minutes = end - start
        } else {
            minutes = (24 * 60 - start) + end
        }
        return Double(minutes) / 60.0
    }

    private static func minutesSinceMidnight(_ hm: HourMinute) -> Int {
        hm.hour * 60 + hm.minute
    }

    init(targetSleepTime: HourMinute, targetWakeTime: HourMinute) {
        self.targetSleepTime = targetSleepTime
        self.targetWakeTime = targetWakeTime
    }

    init(targetSleepTime: DateComponents, targetWakeTime: DateComponents) {
        self.targetSleepTime = HourMinute(from: targetSleepTime)
        self.targetWakeTime = HourMinute(from: targetWakeTime)
    }
}

/// Metas personalizadas del usuario. Se almacena como propiedad Codable dentro de UserProfile.
struct FitnessConfig: Codable, Equatable {
    var sleepGoalHours: Double    // 4.0...12.0, default 8.0
    var stepsGoal: Double         // 1000...50000, default 10000
    var calorieGoal: Double       // 100...2000, default 500
    var baselineRestingHR: Double // 35...120, default 70
    var fitnessLevel: FitnessLevel // default .beginner
    /// Peso de entreno: unidad de la máquina / barra (kg o lb). Almacenamiento del plan y logs en kg.
    var liftingWeightUnit: LiftingWeightUnit
    var sleepGoal: SleepGoal?      // nil -> use fallback window
    var bufferMinutes: Int         // default 60, clamped to [0, 180]

    static let `default` = FitnessConfig(
        sleepGoalHours: 8.0,
        stepsGoal: 10000,
        calorieGoal: 500,
        baselineRestingHR: 70,
        fitnessLevel: .beginner,
        liftingWeightUnit: .kilograms,
        sleepGoal: nil,
        bufferMinutes: 60
    )

    /// Meta de horas usada en Home, scoring y copys: duración del horario cama–despertar si está guardado y es válido; si no, **8 h** (no el valor almacenado en `sleepGoalHours` cuando no hay horario).
    var effectiveSleepGoalHours: Double {
        if let g = sleepGoal, g.isValid {
            return g.durationHours
        }
        return Self.default.sleepGoalHours
    }

    /// Valida que todos los campos estén dentro de rangos aceptables.
    var isValid: Bool {
        (4.0...12.0).contains(sleepGoalHours) &&
        (1000...50000).contains(stepsGoal) &&
        (100...2000).contains(calorieGoal) &&
        (35...120).contains(baselineRestingHR)
    }

    init(
        sleepGoalHours: Double,
        stepsGoal: Double,
        calorieGoal: Double,
        baselineRestingHR: Double,
        fitnessLevel: FitnessLevel,
        liftingWeightUnit: LiftingWeightUnit = .kilograms,
        sleepGoal: SleepGoal? = nil,
        bufferMinutes: Int = 60
    ) {
        self.sleepGoalHours = sleepGoalHours
        self.stepsGoal = stepsGoal
        self.calorieGoal = calorieGoal
        self.baselineRestingHR = baselineRestingHR
        self.fitnessLevel = fitnessLevel
        self.liftingWeightUnit = liftingWeightUnit
        self.sleepGoal = sleepGoal
        self.bufferMinutes = Self.clampBufferMinutes(bufferMinutes)
    }

    private static func clampBufferMinutes(_ value: Int) -> Int {
        Swift.max(0, Swift.min(180, value))
    }

    // MARK: - Codable backward compatibility

    private enum CodingKeys: String, CodingKey {
        case sleepGoalHours
        case stepsGoal
        case calorieGoal
        case baselineRestingHR
        case fitnessLevel
        case liftingWeightUnit
        case sleepGoal
        case bufferMinutes
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sleepGoalHours = try c.decode(Double.self, forKey: .sleepGoalHours)
        self.stepsGoal = try c.decode(Double.self, forKey: .stepsGoal)
        self.calorieGoal = try c.decode(Double.self, forKey: .calorieGoal)
        self.baselineRestingHR = try c.decode(Double.self, forKey: .baselineRestingHR)
        self.fitnessLevel = try c.decodeIfPresent(FitnessLevel.self, forKey: .fitnessLevel) ?? FitnessConfig.default.fitnessLevel
        self.liftingWeightUnit = try c.decodeIfPresent(LiftingWeightUnit.self, forKey: .liftingWeightUnit) ?? .kilograms
        self.sleepGoal = try c.decodeIfPresent(SleepGoal.self, forKey: .sleepGoal)
        self.bufferMinutes = Self.clampBufferMinutes(try c.decodeIfPresent(Int.self, forKey: .bufferMinutes) ?? 60)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sleepGoalHours, forKey: .sleepGoalHours)
        try c.encode(stepsGoal, forKey: .stepsGoal)
        try c.encode(calorieGoal, forKey: .calorieGoal)
        try c.encode(baselineRestingHR, forKey: .baselineRestingHR)
        try c.encode(fitnessLevel, forKey: .fitnessLevel)
        try c.encode(liftingWeightUnit, forKey: .liftingWeightUnit)
        try c.encodeIfPresent(sleepGoal, forKey: .sleepGoal)
        try c.encode(bufferMinutes, forKey: .bufferMinutes)
    }
}
