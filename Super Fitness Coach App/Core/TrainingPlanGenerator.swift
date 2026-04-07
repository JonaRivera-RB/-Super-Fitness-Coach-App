//
//  TrainingPlanGenerator.swift
//  Super Fitness Coach App
//

import Foundation

struct TrainingPlanGenerator {
    enum BMICategory: String {
        case underweight, normal, overweight, obese
    }

    private static func bmiCategory(weightKg: Double?, heightCm: Double?) -> BMICategory? {
        guard let kg = weightKg, let cm = heightCm, kg > 0, cm > 0 else { return nil }
        let m = cm / 100.0
        guard m > 0 else { return nil }
        let bmi = kg / (m * m)
        if bmi < 18.5 { return .underweight }
        if bmi < 25.0 { return .normal }
        if bmi < 30.0 { return .overweight }
        return .obese
    }

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

    private static func bodyWeightBasedDefault(
        weightKg: Double?,
        muscleGroup: MuscleGroup,
        isCompound: Bool,
        experienceLevel: FitnessLevel,
        bmi: BMICategory?
    ) -> Double? {
        guard let bw = weightKg, bw > 0 else { return nil }

        let baseFactor: Double = {
            switch muscleGroup {
            case .quads: return 0.55
            case .glutes: return 0.50
            case .hamstrings: return 0.45
            case .back: return 0.45
            case .chest: return 0.40
            case .shoulders: return 0.25
            case .biceps, .triceps: return 0.18
            case .calves: return 0.22
            case .core: return 0.12
            }
        }()

        let compoundMultiplier = isCompound ? 1.0 : 0.55
        let levelMultiplier: Double = {
            switch experienceLevel {
            case .beginner: return 0.85
            case .intermediate: return 1.0
            case .advanced: return 1.12
            }
        }()
        let bmiMultiplier: Double = {
            switch bmi {
            case .underweight: return 0.90
            case .normal: return 1.0
            case .overweight: return 0.95
            case .obese: return 0.90
            case .none: return 1.0
            }
        }()

        let suggested = bw * baseFactor * compoundMultiplier * levelMultiplier * bmiMultiplier
        return min(220.0, max(2.5, suggested))
    }

    private static func prescription(
        goal: FitnessGoal,
        experienceLevel: FitnessLevel,
        isCompound: Bool,
        bmi: BMICategory?
    ) -> (sets: Int, reps: Int, restSeconds: Int, weightTuning: Double, targetMaxFactor: Double?) {
        // weightTuning: multiplies the suggestedWeight when we DON'T have previous logs
        // targetMaxFactor: optional top-end weight range (for UI guidance)

        let base: (sets: Int, reps: Int, rest: Int) = {
            switch goal {
            case .gainMuscle:
                return isCompound ? (3, 8, 120) : (3, 12, 75)
            case .loseWeight:
                return isCompound ? (3, 12, 75) : (2, 15, 45)
            case .beHealthy:
                return isCompound ? (3, 10, 90) : (2, 12, 60)
            }
        }()

        let levelAdjust: (setDelta: Int, repDelta: Int, restDelta: Int) = {
            switch experienceLevel {
            case .beginner:
                return (0, +2, 0)
            case .intermediate:
                return (0, 0, 0)
            case .advanced:
                return (+1, -1, +15)
            }
        }()

        // NOTE: BMI NO afecta sets/reps (evita penalización fija por IMC).
        // Solo ajusta el peso sugerido inicial si no hay logs, y levemente el descanso.
        let bmiAdjust: (restDelta: Int, weightTuning: Double) = {
            switch bmi {
            case .underweight:
                return (+10, 1.02)
            case .obese:
                return (-5, 0.92)
            case .overweight:
                return (-5, 0.97)
            case .normal, .none:
                return (0, 1.0)
            }
        }()

        let sets = max(1, min(6, base.sets + levelAdjust.setDelta))
        let reps = max(5, min(20, base.reps + levelAdjust.repDelta))
        let restSeconds = max(30, min(240, base.rest + levelAdjust.restDelta + bmiAdjust.restDelta))

        let targetMaxFactor: Double? = {
            switch goal {
            case .gainMuscle:
                return isCompound ? 1.10 : 1.08
            case .loseWeight, .beHealthy:
                return nil
            }
        }()

        return (sets, reps, restSeconds, bmiAdjust.weightTuning, targetMaxFactor)
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
        preferences: TrainingPreferences,
        weightKg: Double?,
        heightCm: Double?,
        exerciseCount: Int = 5
    ) -> [PlannedExercise] {
        let targetCount = max(4, min(6, exerciseCount))
        let bmi = bmiCategory(weightKg: weightKg, heightCm: heightCm)

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
                let hasPrev = previousWeight(for: compound.id, in: previousLogs)
                let baseWeight = hasPrev
                    ?? bodyWeightBasedDefault(
                        weightKg: weightKg,
                        muscleGroup: muscleGroup,
                        isCompound: true,
                        experienceLevel: preferences.experienceLevel,
                        bmi: bmi
                    )
                    ?? defaultWeight(for: muscleGroup)
                let p = prescription(
                    goal: preferences.goal,
                    experienceLevel: preferences.experienceLevel,
                    isCompound: true,
                    bmi: bmi
                )
                let tunedWeight = hasPrev == nil ? (baseWeight * p.weightTuning) : baseWeight
                compounds.append(PlannedExercise(
                    id: compound.id,
                    name: compound.name,
                    muscleGroup: muscleGroup,
                    isCompound: true,
                    sets: p.sets,
                    reps: p.reps,
                    suggestedWeight: tunedWeight,
                    targetWeightMax: p.targetMaxFactor.map { tunedWeight * $0 },
                    equipment: compound.equipment,
                    gifUrl: compound.gifUrl,
                    instructions: compound.instructions ?? []
                    ,
                    restBetweenSetsSeconds: p.restSeconds
                ))
                usedIds.insert(compound.id)
            }

            // Collect accessories for later filling
            for accessory in accessoryPool {
                guard !usedIds.contains(accessory.id) else { continue }
                let hasPrev = previousWeight(for: accessory.id, in: previousLogs)
                let baseWeight = hasPrev
                    ?? bodyWeightBasedDefault(
                        weightKg: weightKg,
                        muscleGroup: muscleGroup,
                        isCompound: false,
                        experienceLevel: preferences.experienceLevel,
                        bmi: bmi
                    )
                    ?? defaultWeight(for: muscleGroup)
                let p = prescription(
                    goal: preferences.goal,
                    experienceLevel: preferences.experienceLevel,
                    isCompound: false,
                    bmi: bmi
                )
                let tunedWeight = hasPrev == nil ? (baseWeight * p.weightTuning) : baseWeight
                accessories.append(PlannedExercise(
                    id: accessory.id,
                    name: accessory.name,
                    muscleGroup: muscleGroup,
                    isCompound: false,
                    sets: p.sets,
                    reps: p.reps,
                    suggestedWeight: tunedWeight,
                    targetWeightMax: p.targetMaxFactor.map { tunedWeight * $0 },
                    equipment: accessory.equipment,
                    gifUrl: accessory.gifUrl,
                    instructions: accessory.instructions ?? []
                    ,
                    restBetweenSetsSeconds: p.restSeconds
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
                    let isComp = isCompound(ex)
                    let hasPrev = previousWeight(for: ex.id, in: previousLogs)
                    let baseWeight = hasPrev
                        ?? bodyWeightBasedDefault(
                            weightKg: weightKg,
                            muscleGroup: muscleGroup,
                            isCompound: isComp,
                            experienceLevel: preferences.experienceLevel,
                            bmi: bmi
                        )
                        ?? defaultWeight(for: muscleGroup)
                    let p = prescription(
                        goal: preferences.goal,
                        experienceLevel: preferences.experienceLevel,
                        isCompound: isComp,
                        bmi: bmi
                    )
                    let tunedWeight = hasPrev == nil ? (baseWeight * p.weightTuning) : baseWeight
                    result.append(PlannedExercise(
                        id: ex.id,
                        name: ex.name,
                        muscleGroup: muscleGroup,
                        isCompound: isComp,
                        sets: p.sets,
                        reps: p.reps,
                        suggestedWeight: tunedWeight,
                        targetWeightMax: p.targetMaxFactor.map { tunedWeight * $0 },
                        equipment: ex.equipment,
                        gifUrl: ex.gifUrl,
                        instructions: ex.instructions ?? []
                        ,
                        restBetweenSetsSeconds: p.restSeconds
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
        weightKg: Double? = nil,
        heightCm: Double? = nil,
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
                        ,
                        preferences: preferences,
                        weightKg: weightKg,
                        heightCm: heightCm
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
