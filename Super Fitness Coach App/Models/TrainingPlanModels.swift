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

    static let `default` = TrainingPreferences(
        goal: .gainMuscle,
        trainingDaysPerWeek: 4,
        experienceLevel: .beginner,
        priorityMuscles: [],
        wantsCardio: false,
        planDurationWeeks: 4
    )
}

/// Ejercicio planificado dentro de un día.
struct PlannedExercise: Codable, Equatable, Identifiable {
    var id: String                        // exerciseId de Exercise
    var name: String
    var muscleGroup: MuscleGroup
    var isCompound: Bool
    var sets: Int                          // default 3
    var reps: Int                          // default 8-12
    var suggestedWeight: Double            // kg
    var equipment: String
    var gifUrl: String?
    var instructions: [String]
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
