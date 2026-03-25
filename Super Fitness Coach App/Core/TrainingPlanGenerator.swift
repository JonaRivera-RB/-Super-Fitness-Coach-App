//
//  TrainingPlanGenerator.swift
//  Super Fitness Coach App
//

import Foundation

struct TrainingPlanGenerator {

    // MARK: - Cálculo de Frecuencia Muscular (Req 2)

    /// Calcula la frecuencia semanal de cada grupo muscular.
    /// - ≥4 días: primary freq 2, secondary freq 1
    /// - <4 días: todos freq 1
    /// - Priority muscles incrementan freq +1 (máx 3)
    static func calculateMuscleFrequency(
        trainingDaysPerWeek: Int,
        priorityMuscles: [MuscleGroup]
    ) -> [MuscleGroup: Int] {
        var frequencies: [MuscleGroup: Int] = [:]

        for muscle in MuscleGroup.allCases {
            if trainingDaysPerWeek >= 4 {
                frequencies[muscle] = muscle.priority == .primary ? 2 : 1
            } else {
                frequencies[muscle] = 1
            }
        }

        // Priority muscles get +1 (capped at 3)
        for muscle in priorityMuscles {
            let current = frequencies[muscle] ?? 1
            frequencies[muscle] = min(current + 1, 3)
        }

        return normalizeFrequencies(frequencies, trainingDaysPerWeek: trainingDaysPerWeek)
    }

    /// Normaliza frecuencias para que Σ frecuencias ≤ trainingDaysPerWeek × 2.
    /// Si excede, reduce proporcionalmente manteniendo mínimo 1 por grupo.
    static func normalizeFrequencies(
        _ frequencies: [MuscleGroup: Int],
        trainingDaysPerWeek: Int
    ) -> [MuscleGroup: Int] {
        let maxTotal = trainingDaysPerWeek * 2
        let total = frequencies.values.reduce(0, +)

        guard total > maxTotal else { return frequencies }

        let factor = Double(maxTotal) / Double(total)
        var normalized: [MuscleGroup: Int] = [:]
        for (muscle, freq) in frequencies {
            normalized[muscle] = max(1, Int((Double(freq) * factor).rounded()))
        }

        return normalized
    }

    // MARK: - Generación del Split Semanal (Req 3)

    /// Genera el arreglo de TrainingDayPlan distribuyendo grupos musculares.
    /// - Máx 2 grupos musculares por día
    /// - Grupos primary no se repiten en días consecutivos
    /// - Días de descanso distribuidos uniformemente
    static func generateWeeklySplit(
        frequencies: [MuscleGroup: Int],
        trainingDaysPerWeek: Int,
        wantsCardio: Bool,
        restDays: Set<Int> = [6, 7],
        startDayOfWeek: Int = 1
    ) -> [TrainingDayPlan] {
        let clampedDays = max(3, min(6, trainingDaysPerWeek))

        // Build muscle pool sorted by frequency descending
        var pool: [MuscleGroup] = []
        for (muscle, freq) in frequencies.sorted(by: { $0.value > $1.value }) {
            for _ in 0..<freq { pool.append(muscle) }
        }

        // Assign muscles to training slots (greedy, max 2 per slot, no consecutive primary)
        var slots: [[MuscleGroup]] = Array(repeating: [], count: clampedDays)
        for muscle in pool {
            var bestSlot: Int? = nil
            var bestCount = Int.max
            for i in 0..<clampedDays {
                guard slots[i].count < 2 else { continue }
                if muscle.priority == .primary {
                    if i > 0, slots[i - 1].contains(muscle) { continue }
                    if i < clampedDays - 1, slots[i + 1].contains(muscle) { continue }
                }
                if slots[i].count < bestCount {
                    bestCount = slots[i].count
                    bestSlot = i
                }
            }
            if let slot = bestSlot { slots[slot].append(muscle) }
        }

        // Build the 7-day week in order 1...7 — all days start as pending
        var weekDays: [TrainingDayPlan] = []
        var trainingIndex = 0

        for dayOfWeek in 1...7 {
            if restDays.contains(dayOfWeek) {
                weekDays.append(TrainingDayPlan(
                    dayOfWeek: dayOfWeek,
                    muscleGroups: [],
                    exercises: [],
                    isRestDay: true
                ))
            } else {
                let muscleGroups = trainingIndex < slots.count ? slots[trainingIndex] : []
                trainingIndex += 1
                weekDays.append(TrainingDayPlan(
                    dayOfWeek: dayOfWeek,
                    muscleGroups: muscleGroups,
                    exercises: []
                ))
            }
        }

        return weekDays
    }

    // MARK: - Private Helpers

    /// Distributes rest days as evenly as possible across a 7-day week.
    /// Returns a Set of 1-based day-of-week positions for rest days.
    private static func distributeRestDays(restCount: Int, totalDays: Int) -> Set<Int> {
        guard restCount > 0 else { return [] }

        var positions = Set<Int>()
        // Spread rest days evenly using stride
        let spacing = Double(totalDays) / Double(restCount)
        for i in 0..<restCount {
            let pos = Int((Double(i) * spacing + spacing / 2).rounded())
            // Clamp to 1...totalDays
            let clamped = max(1, min(totalDays, pos))
            positions.insert(clamped)
        }

        // If rounding caused collisions, fill remaining positions
        if positions.count < restCount {
            for day in 1...totalDays {
                if positions.count >= restCount { break }
                if !positions.contains(day) {
                    positions.insert(day)
                }
            }
        }

        return positions
    }

    // MARK: - Asignación de Ejercicios (Req 4)

    /// Compound exercise name keywords for heuristic detection.
    private static let compoundKeywords: [String] = [
        "bench press", "squat", "deadlift", "row", "press",
        "pull up", "pull-up", "chin up", "dip", "lunge",
        "clean", "snatch"
    ]

    /// Determines whether an exercise is compound.
    /// Uses `category` if available, otherwise falls back to name heuristic.
    private static func isCompound(_ exercise: Exercise) -> Bool {
        if let category = exercise.category?.lowercased(), !category.isEmpty {
            return category == "compound"
        }
        let lowerName = exercise.name.lowercased()
        return compoundKeywords.contains { lowerName.contains($0) }
    }

    /// Default weight (kg) by muscle group when no previous log exists.
    private static func defaultWeight(for muscleGroup: MuscleGroup) -> Double {
        switch muscleGroup {
        case .chest:      return 40.0
        case .back:       return 35.0
        case .shoulders:  return 20.0
        case .biceps:     return 12.0
        case .triceps:    return 12.0
        case .quads:      return 50.0
        case .hamstrings: return 35.0
        case .glutes:     return 40.0
        case .calves:     return 25.0
        case .core:       return 10.0
        }
    }

    /// Looks up the most recent WorkoutLog for a given exerciseId and returns
    /// the maximum weight across all its sets, or nil if no log exists.
    private static func previousWeight(
        for exerciseId: String,
        in logs: [WorkoutLog]
    ) -> Double? {
        let matching = logs
            .filter { $0.exerciseId == exerciseId }
            .sorted { $0.date > $1.date }

        guard let latest = matching.first else { return nil }
        return latest.sets.map(\.weight).max()
    }

    /// Asigna ejercicios a un día dado sus grupos musculares.
    /// - Filtra ejercicios por apiBodyPart del MuscleGroup
    /// - 1 compuesto obligatorio por grupo muscular principal
    /// - Completa con accesorios hasta alcanzar exerciseCount (4-6, default 5)
    /// - Orden: compuestos primero, accesorios después
    /// - Defaults: 3 sets, 10 reps
    /// - Peso: desde WorkoutLog previo o tabla estática por grupo muscular
    static func assignExercises(
        for muscleGroups: [MuscleGroup],
        from exercises: [Exercise],
        previousLogs: [WorkoutLog],
        exerciseCount: Int = 5
    ) -> [PlannedExercise] {
        let targetCount = max(4, min(6, exerciseCount))

        var compounds: [PlannedExercise] = []
        var accessories: [PlannedExercise] = []
        var usedIds = Set<String>()

        // For each muscle group, pick 1 mandatory compound + available accessories
        for muscleGroup in muscleGroups {
            let matching = exercises.filter {
                $0.bodyPart.lowercased() == muscleGroup.apiBodyPart.lowercased()
            }

            // Separate into compound and accessory pools
            let compoundPool = matching.filter { isCompound($0) && !usedIds.contains($0.id) }
            let accessoryPool = matching.filter { !isCompound($0) && !usedIds.contains($0.id) }

            // Pick 1 mandatory compound for this muscle group
            if let compound = compoundPool.first {
                let weight = previousWeight(for: compound.id, in: previousLogs)
                    ?? defaultWeight(for: muscleGroup)
                compounds.append(PlannedExercise(
                    id: compound.id,
                    name: compound.name,
                    muscleGroup: muscleGroup,
                    isCompound: true,
                    sets: 3,
                    reps: 10,
                    suggestedWeight: weight,
                    equipment: compound.equipment,
                    gifUrl: compound.gifUrl,
                    instructions: compound.instructions ?? []
                ))
                usedIds.insert(compound.id)
            }

            // Collect accessories for later filling
            for accessory in accessoryPool {
                guard !usedIds.contains(accessory.id) else { continue }
                let weight = previousWeight(for: accessory.id, in: previousLogs)
                    ?? defaultWeight(for: muscleGroup)
                accessories.append(PlannedExercise(
                    id: accessory.id,
                    name: accessory.name,
                    muscleGroup: muscleGroup,
                    isCompound: false,
                    sets: 3,
                    reps: 10,
                    suggestedWeight: weight,
                    equipment: accessory.equipment,
                    gifUrl: accessory.gifUrl,
                    instructions: accessory.instructions ?? []
                ))
                usedIds.insert(accessory.id)
            }
        }

        // Build final list: compounds first, then fill with accessories up to targetCount
        var result = compounds
        let remaining = targetCount - result.count
        if remaining > 0 {
            result.append(contentsOf: accessories.prefix(remaining))
        }

        // Ensure we have at least 4 exercises; if not enough accessories, add more compounds
        if result.count < 4 {
            // Try to add more from any remaining exercises not yet used
            for muscleGroup in muscleGroups {
                guard result.count < 4 else { break }
                let matching = exercises.filter {
                    $0.bodyPart.lowercased() == muscleGroup.apiBodyPart.lowercased()
                        && !usedIds.contains($0.id)
                }
                for ex in matching {
                    guard result.count < 4 else { break }
                    let weight = previousWeight(for: ex.id, in: previousLogs)
                        ?? defaultWeight(for: muscleGroup)
                    result.append(PlannedExercise(
                        id: ex.id,
                        name: ex.name,
                        muscleGroup: muscleGroup,
                        isCompound: isCompound(ex),
                        sets: 3,
                        reps: 10,
                        suggestedWeight: weight,
                        equipment: ex.equipment,
                        gifUrl: ex.gifUrl,
                        instructions: ex.instructions ?? []
                    ))
                    usedIds.insert(ex.id)
                }
            }
        }

        // Cap at 6
        let capped = Array(result.prefix(6))

        // Final sort: compounds first, accessories after
        return capped.sorted { lhs, rhs in
            if lhs.isCompound == rhs.isCompound { return false }
            return lhs.isCompound && !rhs.isCompound
        }
    }

    // MARK: - Generación Completa del Plan (Req 1, 2, 3, 4)

    /// Genera un TrainingPlan completo a partir de las preferencias del usuario.
    /// Orquesta: calculateMuscleFrequency → generateWeeklySplit → assignExercises por semana.
    static func generatePlan(
        preferences: TrainingPreferences,
        exercises: [Exercise],
        previousLogs: [WorkoutLog],
        restDays: Set<Int> = [6, 7]
    ) -> TrainingPlan {
        // Step 1: Calculate muscle frequency
        let frequencies = calculateMuscleFrequency(
            trainingDaysPerWeek: preferences.trainingDaysPerWeek,
            priorityMuscles: preferences.priorityMuscles
        )

        // Step 2: Generate weekly split template with user-selected rest days
        // No unavailable days in generator — handled dynamically in UI based on current date
        let weeklySplitTemplate = generateWeeklySplit(
            frequencies: frequencies,
            trainingDaysPerWeek: preferences.trainingDaysPerWeek,
            wantsCardio: preferences.wantsCardio,
            restDays: restDays,
            startDayOfWeek: 1  // always start from Monday — UI handles unavailable display
        )

        // Step 3: For each week, create a copy of the split and assign exercises
        var allWeeks: [TrainingWeek] = []
        for weekNumber in 1...preferences.planDurationWeeks {
            var daysWithExercises: [TrainingDayPlan] = []

            for day in weeklySplitTemplate {
                // Always create a NEW TrainingDayPlan instance per week
                // @Model objects cannot be shared across multiple parents in SwiftData
                if day.isRestDay || day.muscleGroups.isEmpty {
                    let newDay = TrainingDayPlan(
                        dayOfWeek: day.dayOfWeek,
                        muscleGroups: [],
                        exercises: [],
                        isRestDay: true
                    )
                    daysWithExercises.append(newDay)
                } else {
                    let planned = assignExercises(
                        for: day.muscleGroups,
                        from: exercises,
                        previousLogs: previousLogs
                    )
                    let newDay = TrainingDayPlan(
                        dayOfWeek: day.dayOfWeek,
                        muscleGroups: day.muscleGroups,
                        exercises: planned
                    )
                    daysWithExercises.append(newDay)
                }
            }

            let week = TrainingWeek(weekIndex: weekNumber, days: daysWithExercises)
            allWeeks.append(week)
        }

        // Step 4: Create and return the plan
        return TrainingPlan(preferences: preferences, weeks: allWeeks)
    }
}
