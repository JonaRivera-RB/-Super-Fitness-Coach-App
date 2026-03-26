//
//  TrainingPlanModels.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData

// MARK: - Enumerations

/// Grupos musculares disponibles para el plan de entrenamiento.
enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps
    case quads, hamstrings, glutes, calves, core

    var id: String { rawValue }

    /// Clasificación según MusclePriority.
    var priority: MusclePriority {
        switch self {
        case .chest, .back, .quads: return .primary
        default: return .secondary
        }
    }

    /// Mapeo a bodyPart de ExerciseDB API (usado por ExerciseService).
    var apiBodyPart: String {
        switch self {
        case .chest: return "chest"
        case .back: return "back"
        case .shoulders: return "shoulders"
        case .biceps: return "upper arms"
        case .triceps: return "upper arms"
        case .quads: return "upper legs"
        case .hamstrings: return "upper legs"
        case .glutes: return "upper legs"
        case .calves: return "lower legs"
        case .core: return "waist"
        }
    }
}

enum MusclePriority: String, Codable {
    case primary
    case secondary
}

enum DayStatus: String, Codable {
    case pending
    case completed
    case skipped
    case rescheduled
    case unavailable  // days before plan creation date in the current week
}

enum PlanStatus: String, Codable {
    case active
    case completed
    case paused
}

enum ProgressStatus: String, Codable {
    case improving   // 🔼
    case stable      // ➖
    case declining   // 🔽
}

// MARK: - Data Structures

/// Preferencias de entrenamiento capturadas en onboarding.
struct TrainingPreferences: Codable, Equatable {
    var goal: FitnessGoal
    var trainingDaysPerWeek: Int          // 3...6
    var experienceLevel: FitnessLevel
    var priorityMuscles: [MuscleGroup]    // máx 2
    var wantsCardio: Bool
    var planDurationWeeks: Int            // 4, 6, 8
    /// Preferencia de volumen. Útil para usuarios avanzados que toleran más sets por ejercicio.
    var prefersHighVolume: Bool

    static let `default` = TrainingPreferences(
        goal: .gainMuscle,
        trainingDaysPerWeek: 4,
        experienceLevel: .beginner,
        priorityMuscles: [],
        wantsCardio: false,
        planDurationWeeks: 4,
        prefersHighVolume: false
    )
}

/// Ejercicio planificado dentro de un día.
struct PlannedExercise: Codable, Equatable, Identifiable {
    /// Identificador único de esta fila (puede ser UUID si es duplicado del mismo ejercicio).
    var id: String
    /// ID en el catálogo de ejercicios para GIF, sustitutos y comparar con logs previos. Si es nil, `id` es el ID de catálogo.
    var catalogExerciseId: String?
    var name: String
    var muscleGroup: MuscleGroup
    var isCompound: Bool
    var sets: Int                          // default 3
    var reps: Int                          // default 8-12
    /// Peso objetivo mínimo / principal (kg).
    var suggestedWeight: Double
    /// Rango opcional: peso máximo objetivo (kg). Si es nil, solo se usa `suggestedWeight`.
    var targetWeightMax: Double?
    var equipment: String
    var gifUrl: String?
    var instructions: [String]
    /// Descanso entre series (segundos). nil = 90 por defecto.
    var restBetweenSetsSeconds: Int?
    /// Descanso por serie: índice = tras completar esa serie (antes de la siguiente). Debe coincidir con `sets` si se usa.
    var perSetRestSeconds: [Int]?
    /// IDs de ejercicios sustitutos en el catálogo.
    var alternateExerciseIds: [String]?

    /// ID de catálogo para medios, logs históricos y PR vs sesiones anteriores.
    var effectiveCatalogId: String { catalogExerciseId ?? id }

    enum CodingKeys: String, CodingKey {
        case id, catalogExerciseId, name, muscleGroup, isCompound, sets, reps
        case suggestedWeight, targetWeightMax, equipment, gifUrl, instructions
        case restBetweenSetsSeconds, perSetRestSeconds, alternateExerciseIds
    }

    init(
        id: String,
        catalogExerciseId: String? = nil,
        name: String,
        muscleGroup: MuscleGroup,
        isCompound: Bool,
        sets: Int,
        reps: Int,
        suggestedWeight: Double,
        targetWeightMax: Double? = nil,
        equipment: String,
        gifUrl: String?,
        instructions: [String],
        restBetweenSetsSeconds: Int? = nil,
        perSetRestSeconds: [Int]? = nil,
        alternateExerciseIds: [String]? = nil
    ) {
        self.id = id
        self.catalogExerciseId = catalogExerciseId
        self.name = name
        self.muscleGroup = muscleGroup
        self.isCompound = isCompound
        self.sets = sets
        self.reps = reps
        self.suggestedWeight = suggestedWeight
        self.targetWeightMax = targetWeightMax
        self.equipment = equipment
        self.gifUrl = gifUrl
        self.instructions = instructions
        self.restBetweenSetsSeconds = restBetweenSetsSeconds
        self.perSetRestSeconds = perSetRestSeconds
        self.alternateExerciseIds = alternateExerciseIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        catalogExerciseId = try c.decodeIfPresent(String.self, forKey: .catalogExerciseId)
        name = try c.decode(String.self, forKey: .name)
        muscleGroup = try c.decode(MuscleGroup.self, forKey: .muscleGroup)
        isCompound = try c.decode(Bool.self, forKey: .isCompound)
        sets = try c.decode(Int.self, forKey: .sets)
        reps = try c.decode(Int.self, forKey: .reps)
        suggestedWeight = try c.decode(Double.self, forKey: .suggestedWeight)
        targetWeightMax = try c.decodeIfPresent(Double.self, forKey: .targetWeightMax)
        equipment = try c.decode(String.self, forKey: .equipment)
        gifUrl = try c.decodeIfPresent(String.self, forKey: .gifUrl)
        instructions = try c.decodeIfPresent([String].self, forKey: .instructions) ?? []
        restBetweenSetsSeconds = try c.decodeIfPresent(Int.self, forKey: .restBetweenSetsSeconds)
        perSetRestSeconds = try c.decodeIfPresent([Int].self, forKey: .perSetRestSeconds)
        alternateExerciseIds = try c.decodeIfPresent([String].self, forKey: .alternateExerciseIds)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(catalogExerciseId, forKey: .catalogExerciseId)
        try c.encode(name, forKey: .name)
        try c.encode(muscleGroup, forKey: .muscleGroup)
        try c.encode(isCompound, forKey: .isCompound)
        try c.encode(sets, forKey: .sets)
        try c.encode(reps, forKey: .reps)
        try c.encode(suggestedWeight, forKey: .suggestedWeight)
        try c.encodeIfPresent(targetWeightMax, forKey: .targetWeightMax)
        try c.encode(equipment, forKey: .equipment)
        try c.encodeIfPresent(gifUrl, forKey: .gifUrl)
        try c.encode(instructions, forKey: .instructions)
        try c.encodeIfPresent(restBetweenSetsSeconds, forKey: .restBetweenSetsSeconds)
        try c.encodeIfPresent(perSetRestSeconds, forKey: .perSetRestSeconds)
        try c.encodeIfPresent(alternateExerciseIds, forKey: .alternateExerciseIds)
    }
}

extension PlannedExercise {
    var effectiveRestBetweenSets: Int { restBetweenSetsSeconds ?? 90 }

    /// Descanso tras completar la serie `setIndex` (0-based), antes de la siguiente.
    func restSeconds(afterCompletingSet setIndex: Int) -> Int {
        if let per = perSetRestSeconds, per.indices.contains(setIndex) {
            return max(0, per[setIndex])
        }
        return max(0, effectiveRestBetweenSets)
    }

    /// Copia con nuevo `id` de instancia para poder repetir el mismo movimiento en el día.
    func duplicatedInstance() -> PlannedExercise {
        var copy = self
        copy.catalogExerciseId = self.catalogExerciseId ?? self.id
        copy.id = UUID().uuidString
        return copy
    }
}

/// Registro individual de un set.
struct SetLog: Codable, Equatable {
    var weight: Double                    // kg
    var reps: Int
}

/// Multiplicadores de progresión semanal.
struct WeeklyProgression: Codable, Equatable {
    var weekInCycle: Int                  // 1-4
    var weightMultiplier: Double          // 1.0, 1.05, 1.0, 0.9
    var volumeMultiplier: Double          // 1.0, 1.0, 1.1, 0.85
}

/// Ajuste diario basado en recuperación.
struct DailyAdjustment: Codable, Equatable {
    var weightMultiplier: Double          // 1.05, 1.0, 0.85
    var setsReduction: Int                // 0 o 1
}

// MARK: - SwiftData Models

/// Ejercicio planificado dentro de un día (persistido como @Model).
@Model
final class TrainingDayPlan {
    var dayOfWeek: Int
    var muscleGroupsRaw: [String]         // stored as rawValues
    var exercises: [PlannedExercise]      // Codable struct array — shallow, serializes fine
    var dayStatusRaw: String
    var isRestDay: Bool
    var wasRescheduled: Bool

    var muscleGroups: [MuscleGroup] {
        get { muscleGroupsRaw.compactMap { MuscleGroup(rawValue: $0) } }
        set { muscleGroupsRaw = newValue.map(\.rawValue) }
    }

    var dayStatus: DayStatus {
        get { DayStatus(rawValue: dayStatusRaw) ?? .pending }
        set { dayStatusRaw = newValue.rawValue }
    }

    init(dayOfWeek: Int, muscleGroups: [MuscleGroup], exercises: [PlannedExercise], isRestDay: Bool = false) {
        self.dayOfWeek = dayOfWeek
        self.muscleGroupsRaw = muscleGroups.map(\.rawValue)
        self.exercises = exercises
        self.dayStatusRaw = DayStatus.pending.rawValue
        self.isRestDay = isRestDay
        self.wasRescheduled = false
    }
}

/// Semana dentro del plan de entrenamiento (persistida con SwiftData).
@Model
final class TrainingWeek {
    var weekIndex: Int
    @Relationship(deleteRule: .cascade) var days: [TrainingDayPlan]

    init(weekIndex: Int, days: [TrainingDayPlan]) {
        self.weekIndex = weekIndex
        self.days = days
    }
}

/// Plan de entrenamiento completo (persistido con SwiftData).
@Model
final class TrainingPlan {
    @Attribute(.unique) var id: UUID
    var preferences: TrainingPreferences
    @Relationship(deleteRule: .cascade) var weeks: [TrainingWeek]
    var currentWeek: Int
    var planStatusRaw: String
    var createdAt: Date

    var planStatus: PlanStatus {
        get { PlanStatus(rawValue: planStatusRaw) ?? .active }
        set { planStatusRaw = newValue.rawValue }
    }

    init(preferences: TrainingPreferences, weeks: [TrainingWeek]) {
        self.id = UUID()
        self.preferences = preferences
        self.weeks = weeks
        self.currentWeek = 1
        self.planStatusRaw = PlanStatus.active.rawValue
        self.createdAt = Date()
    }
}

/// Registro de un entrenamiento completo para un ejercicio.
@Model
final class WorkoutLog {
    @Attribute(.unique) var id: UUID
    var exerciseId: String
    var date: Date
    var sets: [SetLog]
    var notes: String?

    init(exerciseId: String, date: Date, sets: [SetLog], notes: String? = nil) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.date = date
        self.sets = sets
        self.notes = notes
    }
}
