//
//  WorkoutSessionCoordinator.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData
import os

/// Coordina la lógica de negocio de arranque y cierre de sesiones de entrenamiento.
/// Extrae de ContentView: construcción de WorkoutExecutorViewModel, gestión de sessionIds,
/// marcado de días completados y applyPerformanceUpdates.
///
/// No tiene estado publicado hacia la UI — no requiere @Observable.
final class WorkoutSessionCoordinator {

    // MARK: - Dependencies

    private let trainingPlanRepository: TrainingPlanRepository
    private let healthKitManager: HealthKitManager
    private let modelContext: ModelContext

    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "WorkoutSessionCoordinator")

    // MARK: - Tracking interno de sesión activa (opaco a la UI)

    /// dayIndex del plan de entrenamiento seleccionado; nil si es entreno de Mi Rutina.
    private(set) var selectedDayIndex: Int?
    /// dayOfWeek resuelto al construir el executor del plan; nil si es Mi Rutina.
    private(set) var selectedDayOfWeek: Int?

    // MARK: - Init

    init(
        trainingPlanRepository: TrainingPlanRepository,
        healthKitManager: HealthKitManager,
        modelContext: ModelContext
    ) {
        self.trainingPlanRepository = trainingPlanRepository
        self.healthKitManager = healthKitManager
        self.modelContext = modelContext
    }

    // MARK: - Construcción de ViewModels

    /// Construye el ViewModel para un día del plan de entrenamiento.
    /// Registra `selectedDayIndex` y `selectedDayOfWeek` para su uso en `completeTrainingPlanWorkout`.
    func buildTrainingPlanExecutor(
        for dayIndex: Int,
        appLanguage: AppLanguage
    ) -> WorkoutExecutorViewModel? {
        guard let plan = try? trainingPlanRepository.fetchActivePlan() else {
            logger.error("buildTrainingPlanExecutor: no active plan")
            return nil
        }

        logger.info("buildTrainingPlanExecutor: plan found, weeks=\(plan.weeks.count), currentWeek=\(plan.currentWeek)")

        let weekIndex = plan.currentWeek - 1
        guard weekIndex >= 0, weekIndex < plan.weeks.count else {
            logger.error("buildTrainingPlanExecutor: weekIndex \(weekIndex) out of range (weeks=\(plan.weeks.count))")
            return nil
        }

        let sortedDays = plan.weeks[weekIndex].days.sorted { $0.dayOfWeek < $1.dayOfWeek }
        guard dayIndex >= 0, dayIndex < sortedDays.count else {
            logger.error("buildTrainingPlanExecutor: dayIndex \(dayIndex) out of range (days=\(sortedDays.count))")
            return nil
        }

        let day = sortedDays[dayIndex]
        logger.info("buildTrainingPlanExecutor: day dow=\(day.dayOfWeek), exercises=\(day.exercises.count), isRest=\(day.isRestDay)")

        guard !day.exercises.isEmpty else {
            logger.error("buildTrainingPlanExecutor: exercises empty for day \(day.dayOfWeek)")
            selectedDayIndex = nil
            selectedDayOfWeek = nil
            return nil
        }

        // Registrar tracking ANTES de cualquier mutación del modelo SwiftData.
        selectedDayIndex = dayIndex
        selectedDayOfWeek = day.dayOfWeek

        // Asegurar sessionId estable (UserDefaults-backed) para que el resume no regrese.
        let sessionId = loadOrCreateSessionId(plan: plan, dayOfWeek: day.dayOfWeek)
        if day.activeSessionId == nil || day.activeSessionId?.isEmpty == true || day.activeSessionId != sessionId {
            day.activeSessionId = sessionId
            if day.activeSessionStartedAt == nil { day.activeSessionStartedAt = Date() }
            try? modelContext.save()
        }

        let setLogger = SetLogger(repository: trainingPlanRepository, sessionId: sessionId)
        return WorkoutExecutorViewModel(
            currentWeek: plan.currentWeek,
            plannedExercises: day.exercises,
            setLogger: setLogger,
            healthKitManager: healthKitManager,
            goal: plan.preferences.goal,
            sessionId: sessionId,
            appLanguage: appLanguage
        )
    }

    /// Construye el ViewModel para un entreno de Mi Rutina.
    /// Resetea el tracking de plan (selectedDayIndex/selectedDayOfWeek → nil).
    func buildRoutineExecutor(
        plannedExercises: [PlannedExercise],
        appLanguage: AppLanguage
    ) -> (viewModel: WorkoutExecutorViewModel, sessionDefaultsKey: String)? {
        // Rutina no usa tracking de plan.
        selectedDayIndex = nil
        selectedDayOfWeek = nil

        guard let routine = try? UserRoutineRepository(context: modelContext).fetchActive() else {
            logger.error("buildRoutineExecutor: no active routine")
            return nil
        }

        let (sessionId, defaultsKey) = loadOrCreateRoutineSessionId(routineId: routine.id)
        let setLogger = SetLogger(repository: trainingPlanRepository, sessionId: sessionId)
        let vm = WorkoutExecutorViewModel(
            currentWeek: 1,
            plannedExercises: plannedExercises,
            setLogger: setLogger,
            healthKitManager: healthKitManager,
            goal: .beHealthy,
            sessionId: sessionId,
            appLanguage: appLanguage,
            preservePrescribedVolume: true
        )
        return (vm, defaultsKey)
    }

    // MARK: - Cierre de sesión

    /// Completa un entreno del plan de entrenamiento.
    /// Aplica ajustes de rendimiento, limpia el sessionId y marca el día como completado.
    /// Llamar sólo cuando `selectedDayIndex != nil` (es decir, tras `buildTrainingPlanExecutor`).
    func completeTrainingPlanWorkout(
        logs: [WorkoutLog],
        trainingPlanViewModel: TrainingPlanViewModel
    ) {
        guard let idx = selectedDayIndex else {
            logger.error("completeTrainingPlanWorkout: selectedDayIndex es nil — llamada fuera de orden")
            return
        }

        // 1. Ajustes de rendimiento basados en los logs de la sesión.
        try? trainingPlanRepository.applyPerformanceUpdates(workoutLogs: logs)

        // 2. Limpiar sessionId en UserDefaults para que el próximo arranque sea fresco.
        if let plan = try? trainingPlanRepository.fetchActivePlan() {
            let weekIndex = plan.currentWeek - 1
            if weekIndex >= 0, weekIndex < plan.weeks.count {
                let sorted = plan.weeks[weekIndex].days.sorted { $0.dayOfWeek < $1.dayOfWeek }
                if idx >= 0, idx < sorted.count {
                    clearSessionId(plan: plan, dayOfWeek: sorted[idx].dayOfWeek)
                }
            }
        }

        // 3. Marcar día completado. Usa dayOfWeek si está disponible (más preciso).
        if let dow = selectedDayOfWeek {
            trainingPlanViewModel.completeDay(dayOfWeek: dow)
        } else {
            trainingPlanViewModel.completeDay(at: idx)
        }

        // 4. Sincronizar WorkoutView.
        trainingPlanViewModel.loadPlan()

        logger.info("completeTrainingPlanWorkout: día idx=\(idx) dow=\(self.selectedDayOfWeek ?? -1) completado")
    }

    /// Completa un entreno de Mi Rutina.
    /// Marca el día como completado, limpia el sessionId y recarga el plan.
    func completeRoutineWorkout(
        dayOfWeek: Int,
        routineSessionDefaultsKey: String?,
        trainingPlanViewModel: TrainingPlanViewModel
    ) {
        markRoutineDayCompleted(dayOfWeek: dayOfWeek)

        if let key = routineSessionDefaultsKey {
            UserDefaults.standard.removeObject(forKey: key)
        }

        trainingPlanViewModel.loadPlan()

        logger.info("completeRoutineWorkout: día dow=\(dayOfWeek) completado")
    }

    /// Limpia el estado interno de tracking. Llamar al final del closure de onWorkoutComplete.
    func resetSelectionState() {
        selectedDayIndex = nil
        selectedDayOfWeek = nil
    }

    // MARK: - Session ID helpers (privados)

    private func sessionDefaultsKey(planId: UUID, week: Int, dayOfWeek: Int) -> String {
        "trainingSession|\(planId.uuidString)|w\(week)|d\(dayOfWeek)"
    }

    private func loadOrCreateSessionId(plan: TrainingPlan, dayOfWeek: Int) -> String {
        let key = sessionDefaultsKey(planId: plan.id, week: plan.currentWeek, dayOfWeek: dayOfWeek)
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    private func clearSessionId(plan: TrainingPlan, dayOfWeek: Int) {
        let key = sessionDefaultsKey(planId: plan.id, week: plan.currentWeek, dayOfWeek: dayOfWeek)
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func loadOrCreateRoutineSessionId(
        routineId: UUID
    ) -> (sessionId: String, defaultsKey: String) {
        let pair = RoutineSessionStore.loadOrCreateSessionId(
            routineId: routineId,
            referenceDate: Date(),
            calendar: .current,
            defaults: .standard
        )
        return (pair.sessionId, pair.storageKey)
    }

    // MARK: - Mi Rutina — persistencia

    private func markRoutineDayCompleted(dayOfWeek: Int) {
        do {
            let repo = UserRoutineRepository(context: modelContext)
            try repo.markRoutineDayCompleted(dayOfWeek: dayOfWeek)
        } catch {
            print("❌ WorkoutSessionCoordinator.markRoutineDayCompleted: \(error.localizedDescription)")
        }
    }
}
