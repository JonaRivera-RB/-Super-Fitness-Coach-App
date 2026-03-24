//
//  WorkoutEngine.swift
//  Super Fitness Coach App
//

import Foundation
import Observation

@Observable
final class WorkoutEngine {
    private let repository: WorkoutRepository

    init(repository: WorkoutRepository) {
        self.repository = repository
    }

    // MARK: - Weekly Plan Generation

    /// Generate a 7-day plan (Mon–Sun) based on fitness goal and persist it.
    func generateWeeklyPlan(goal: FitnessGoal) -> WeeklyPlan {
        return generateWeeklyPlan(goal: goal, weightKg: nil, heightCm: nil)
    }

    /// Generate a 7-day plan adjusted for BMI when body metrics are available.
    /// Falls back to goal-only distribution when weight or height is nil.
    func generateWeeklyPlan(goal: FitnessGoal, weightKg: Double?, heightCm: Double?) -> WeeklyPlan {
        let category: BMICategory?
        if let w = weightKg, let h = heightCm, h > 0 {
            let bmi = Self.calculateBMI(weightKg: w, heightCm: h)
            category = Self.bmiCategory(bmi: bmi)
        } else {
            category = nil
        }

        let types = distribution(for: goal, bmiCategory: category)
        let arranged = arrangeDays(types)

        let days = arranged.enumerated().map { index, type in
            DayPlan(dayOfWeek: index + 1, workoutType: type)
        }

        let plan = WeeklyPlan(
            weekStartDate: Self.currentWeekMonday(),
            days: days,
            goal: goal
        )

        try? repository.saveWeeklyPlan(plan)
        return plan
    }

    /// Returns the workout type counts for a given goal, optionally adjusted by BMI category.
    private func distribution(for goal: FitnessGoal, bmiCategory: BMICategory? = nil) -> [WorkoutType] {
        var types: [WorkoutType]
        switch goal {
        case .loseWeight:
            // 1 Push, 1 Pull, 1 Legs, 2 Cardio, 2 Rest
            types = [.push, .pull, .legs, .cardio, .cardio, .rest, .rest]
        case .gainMuscle:
            // 2 Push, 2 Pull, 2 Legs, 0 Cardio, 1 Rest
            types = [.push, .push, .pull, .pull, .legs, .legs, .rest]
        case .beHealthy:
            // 1 Push, 1 Pull, 1 Legs, 1 Cardio, 3 Rest
            types = [.push, .pull, .legs, .cardio, .rest, .rest, .rest]
        }

        guard let category = bmiCategory else { return types }

        switch category {
        case .underweight:
            // -1 cardio, +1 strength (push)
            if let cardioIndex = types.firstIndex(of: .cardio) {
                types[cardioIndex] = .push
            }
        case .obese:
            // -1 high-intensity strength, +1 low-impact cardio
            // Replace last strength type with lightCardio
            if let strengthIndex = types.lastIndex(where: { $0 == .push || $0 == .pull || $0 == .legs }) {
                types[strengthIndex] = .lightCardio
            }
        case .normal, .overweight:
            break // No modification
        }

        return types
    }

    /// Arrange workout types into a sensible weekly order.
    /// Ensures rest days are spread out and strength days don't cluster.
    private func arrangeDays(_ types: [WorkoutType]) -> [WorkoutType] {
        var result = Array<WorkoutType?>(repeating: nil, count: 7)
        var remaining = types

        // Place rest days on Sunday (index 6) first, then Wednesday (index 2) if multiple
        let restCount = remaining.filter { $0 == .rest }.count
        if restCount >= 1 {
            result[6] = .rest
            remaining.removeFirst(where: { $0 == .rest })
        }
        if restCount >= 2 {
            result[2] = .rest
            remaining.removeFirst(where: { $0 == .rest })
        }
        if restCount >= 3 {
            result[4] = .rest
            remaining.removeFirst(where: { $0 == .rest })
        }

        // Fill remaining slots in order
        var idx = 0
        for type in remaining {
            while idx < 7 && result[idx] != nil {
                idx += 1
            }
            if idx < 7 {
                result[idx] = type
                idx += 1
            }
        }

        return result.map { $0 ?? .rest }
    }

    /// Returns the Monday 00:00 of the current week.
    static func currentWeekMonday() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: now)!
        return calendar.startOfDay(for: monday)
    }

    // MARK: - Current Plan Access

    /// Fetch today's scheduled workout type from the current weekly plan.
    func todayWorkoutType() -> WorkoutType {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let dayIndex = (weekday + 5) % 7 // 0=Mon, 6=Sun

        guard let plan = try? repository.fetchCurrentWeekPlan(),
              dayIndex < plan.days.count else {
            return .rest
        }

        return plan.days[dayIndex].workoutType
    }

    // MARK: - Daily Workout Adjustment

    /// Determine the adjustment action for a given recovery score and workout type.
    static func adjustmentAction(recoveryScore: Int, workoutType: WorkoutType) -> AdjustmentAction {
        let isStrength = workoutType == .push || workoutType == .pull || workoutType == .legs
        guard isStrength else { return .noChange }

        if recoveryScore < 40 {
            return .replaceWithLight
        } else if recoveryScore < 70 {
            return .reduceSets
        } else {
            return .noChange
        }
    }

    /// Body parts that map to each workout type.
    static func bodyParts(for workoutType: WorkoutType) -> [String] {
        switch workoutType {
        case .push:
            return ["chest", "shoulders", "upper arms"]
        case .pull:
            return ["back", "upper arms"]
        case .legs:
            return ["upper legs", "lower legs"]
        case .cardio, .lightCardio:
            return ["cardio"]
        case .rest:
            return []
        }
    }

    /// Build a WorkoutSession adjusted for recovery and BMI, filtering exercises by body part.
    func adjustedWorkout(
        scheduledType: WorkoutType,
        recoveryScore: Int,
        exercises: [Exercise],
        bmiCategory: BMICategory? = nil
    ) -> WorkoutSession {
        let action = Self.adjustmentAction(recoveryScore: recoveryScore, workoutType: scheduledType)

        let effectiveType: WorkoutType
        switch action {
        case .replaceWithLight:
            effectiveType = .lightCardio
        case .reduceSets, .noChange:
            effectiveType = scheduledType
        }

        let targetParts = Self.bodyParts(for: effectiveType)
        let matched = exercises.filter { exercise in
            targetParts.contains { exercise.bodyPart.lowercased().contains($0.lowercased()) }
        }

        // Select a reasonable number of exercises per session with variety
        let selected = Self.selectSessionExercises(from: matched, maxCount: 7)

        let baseSets = 4
        let baseReps = 12

        // Apply BMI-based adjustments if category is provided
        let (adjustedSets, adjustedReps): (Int, Int)
        if let category = bmiCategory {
            (adjustedSets, adjustedReps) = Self.adjustedSetsReps(baseSets: baseSets, baseReps: baseReps, bmiCategory: category)
        } else {
            (adjustedSets, adjustedReps) = (baseSets, baseReps)
        }

        let sessionExercises = selected.map { exercise in
            var sets = adjustedSets
            if action == .reduceSets {
                sets = max(1, sets - 1)
            }
            let reps = adjustedReps
            let duration = sets * reps * 3 // ~3 seconds per rep as estimate

            return SessionExercise(
                id: exercise.id,
                name: exercise.name,
                target: exercise.target,
                equipment: exercise.equipment,
                gifUrl: exercise.gifUrl ?? "",
                instructions: exercise.instructions ?? [],
                sets: sets,
                reps: reps,
                isCompleted: false,
                estimatedDurationSeconds: duration
            )
        }

        let session = WorkoutSession(
            date: Date(),
            workoutType: effectiveType,
            exercises: sessionExercises
        )
        session.adjustmentApplied = action
        return session
    }

    // MARK: - Session Completion & Resume

    /// Mark an individual exercise as completed within a session.
    func completeExercise(sessionID: UUID, exerciseIndex: Int) async {
        guard let session = try? repository.fetchSession(for: Date()),
              session.id == sessionID,
              exerciseIndex >= 0,
              exerciseIndex < session.exercises.count else { return }

        var exercises = session.exercises
        exercises[exerciseIndex].isCompleted = true
        session.exercises = exercises

        // Check if all exercises are now complete
        if exercises.allSatisfy({ $0.isCompleted }) {
            session.isCompleted = true
            session.completedAt = Date()
        }

        try? repository.saveSession(session)
    }

    /// Mark the entire session as completed and persist.
    func completeSession(sessionID: UUID) async {
        guard let session = try? repository.fetchSession(for: Date()),
              session.id == sessionID else { return }

        var exercises = session.exercises
        for i in exercises.indices {
            exercises[i].isCompleted = true
        }
        session.exercises = exercises
        session.isCompleted = true
        session.completedAt = Date()

        try? repository.saveSession(session)
    }

    /// Find the index of the first incomplete exercise for resuming a session.
    static func resumeIndex(for session: WorkoutSession) -> Int? {
        session.exercises.firstIndex(where: { !$0.isCompleted })
    }
}

// MARK: - BMI

enum BMICategory: String, Codable {
    case underweight
    case normal
    case overweight
    case obese
}

extension WorkoutEngine {
    static func calculateBMI(weightKg: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100.0
        guard heightM > 0 else { return 0 }
        return weightKg / (heightM * heightM)
    }

    static func bmiCategory(bmi: Double) -> BMICategory {
        switch bmi {
        case ..<18.5: return .underweight
        case 18.5..<25: return .normal
        case 25..<30: return .overweight
        default: return .obese
        }
    }

    static func adjustedSetsReps(baseSets: Int, baseReps: Int, bmiCategory: BMICategory) -> (sets: Int, reps: Int) {
        switch bmiCategory {
        case .underweight, .normal, .overweight:
            return (baseSets, baseReps)
        case .obese:
            return (max(2, baseSets - 1), max(8, baseReps - 2))
        }
    }

    /// Adjust sets/reps based on fitness level.
    /// beginner reduces intensity, intermediate keeps base, advanced increases.
    /// All returned values are >= 1.
    static func adjustedForFitnessLevel(baseSets: Int, baseReps: Int, level: FitnessLevel) -> (sets: Int, reps: Int) {
        switch level {
        case .beginner:
            return (sets: max(1, baseSets - 1), reps: max(1, baseReps - 2))
        case .intermediate:
            return (sets: baseSets, reps: baseReps)
        case .advanced:
            return (sets: baseSets + 1, reps: baseReps + 2)
        }
    }
}

// MARK: - Exercise Selection

extension WorkoutEngine {
    /// Select a diverse set of exercises for a session, prioritizing variety of targets.
    /// Shuffles to provide different workouts each day.
    static func selectSessionExercises(from exercises: [Exercise], maxCount: Int) -> [Exercise] {
        guard exercises.count > maxCount else { return exercises }

        // Group by target muscle to ensure variety
        var byTarget: [String: [Exercise]] = [:]
        for exercise in exercises {
            let key = exercise.target.lowercased()
            byTarget[key, default: []].append(exercise)
        }

        // Shuffle each group
        for key in byTarget.keys {
            byTarget[key]?.shuffle()
        }

        // Round-robin pick from each target group
        var selected: [Exercise] = []
        var keys = Array(byTarget.keys).shuffled()
        var index = 0

        while selected.count < maxCount && !keys.isEmpty {
            let key = keys[index % keys.count]
            if let exercise = byTarget[key]?.first {
                selected.append(exercise)
                byTarget[key]?.removeFirst()
                if byTarget[key]?.isEmpty == true {
                    keys.removeAll { $0 == key }
                    if !keys.isEmpty { index = index % keys.count }
                } else {
                    index += 1
                }
            } else {
                keys.removeAll { $0 == key }
                if !keys.isEmpty { index = index % keys.count }
            }
        }

        return selected
    }
}

// MARK: - Array Helper

private extension Array {
    /// Remove the first element matching the predicate.
    mutating func removeFirst(where predicate: (Element) -> Bool) {
        if let index = firstIndex(where: predicate) {
            remove(at: index)
        }
    }
}
