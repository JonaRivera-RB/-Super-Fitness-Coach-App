# Plan de Implementación: Smart Training Plan

## Resumen

Implementación incremental del sistema Smart Training Plan para la Super Fitness Coach App. Se crean modelos de datos, motores de lógica (generación, progresión, recuperación), registro de sets, seguimiento de progreso, gestión de días, gamificación, vistas SwiftUI y tests de propiedad. Cada tarea construye sobre las anteriores y termina con la integración completa en la app existente.

## Tareas

- [x] 1. Crear enumeraciones y modelos de datos base
  - [x] 1.1 Crear enumeraciones nuevas: MuscleGroup, MusclePriority, DayStatus, PlanStatus, ProgressStatus
    - Crear archivo `Super Fitness Coach App/Models/TrainingPlanModels.swift`
    - MuscleGroup con CaseIterable, Identifiable, propiedad `priority` y `apiBodyPart`
    - MusclePriority, DayStatus, PlanStatus, ProgressStatus como enums Codable
    - _Requisitos: 2.6, 10.1, 10.8_

  - [x] 1.2 Crear estructuras de datos: TrainingPreferences, TrainingDayPlan, PlannedExercise, SetLog, WeeklyProgression, DailyAdjustment
    - Crear en `Super Fitness Coach App/Models/TrainingPlanModels.swift` (append)
    - TrainingPreferences con valor `default` estático
    - PlannedExercise con Identifiable y Equatable
    - _Requisitos: 1.1, 4.6, 5.1, 6.1_

  - [x] 1.3 Crear modelos SwiftData: TrainingPlan, TrainingWeek, WorkoutLog
    - TrainingWeek como `@Model` independiente (no array anidado)
    - TrainingPlan con relación a [TrainingWeek], campo currentWeek y planStatus
    - WorkoutLog como `@Model` con exerciseId, date, [SetLog], notes
    - _Requisitos: 13.1, 5.6_

  - [x] 1.4 Registrar nuevos modelos en ModelContainer
    - Actualizar `Super_Fitness_Coach_AppApp.swift` añadiendo TrainingPlan.self, TrainingWeek.self, WorkoutLog.self
    - Actualizar el Preview de `ContentView.swift` con los mismos modelos
    - _Requisitos: 13.1, 13.3_

- [x] 2. Implementar TrainingPlanRepository
  - [x] 2.1 Crear `Super Fitness Coach App/Repositories/TrainingPlanRepository.swift`
    - Métodos: savePlan, fetchActivePlan, saveWorkoutLog, fetchLatestLog, fetchLogs
    - Seguir el patrón de retry existente en WorkoutRepository
    - _Requisitos: 13.1, 13.2, 13.4_

  - [ ]* 2.2 Test de propiedad: WorkoutLog round-trip de persistencia
    - **Property 19: WorkoutLog round-trip de persistencia**
    - Generar WorkoutLogs aleatorios, guardar y recuperar, verificar equivalencia
    - Usar patrón SeededRNG de SleepWindowValidationPropertyTests
    - **Valida: Requisitos 8.1, 8.3, 8.4, 13.1, 13.2, 13.3**

- [x] 3. Implementar TrainingPlanGenerator — Frecuencia muscular y split
  - [x] 3.1 Crear `Super Fitness Coach App/Core/TrainingPlanGenerator.swift` con calculateMuscleFrequency y normalizeFrequencies
    - Lógica: ≥4 días → primary freq 2, secondary freq 1; <4 días → todos freq 1
    - Priority muscles incrementan freq +1 (máx 3)
    - Normalización: Σ frecuencias ≤ trainingDaysPerWeek × 2
    - _Requisitos: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [ ]* 3.2 Test de propiedad: Cálculo de frecuencia muscular
    - **Property 1: Cálculo de frecuencia muscular respeta reglas de prioridad y días**
    - Random trainingDays (3-6), random priorityMuscles (0-2 elementos)
    - **Valida: Requisitos 1.4, 2.1, 2.2, 2.3, 2.4, 2.5**

  - [x] 3.3 Implementar generateWeeklySplit en TrainingPlanGenerator
    - Distribuir grupos musculares con greedy (máx 2 por día)
    - Restricción: no repetir grupo primary en días consecutivos
    - Insertar días de descanso distribuidos uniformemente
    - _Requisitos: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [ ]* 3.4 Test de propiedad: Split genera días correctos con descanso
    - **Property 3: Split genera días correctos con descanso distribuido**
    - Verificar trainingDaysPerWeek días de entrenamiento + (7 - trainingDaysPerWeek) descanso = 7
    - **Valida: Requisitos 3.1, 3.5**

  - [ ]* 3.5 Test de propiedad: Máximo 2 grupos musculares por día
    - **Property 4: Máximo 2 grupos musculares por día**
    - **Valida: Requisitos 3.2**

  - [ ]* 3.6 Test de propiedad: Grupos principales no consecutivos
    - **Property 5: Grupos musculares principales no se repiten en días consecutivos**
    - **Valida: Requisitos 3.3**

  - [ ]* 3.7 Test de propiedad: Inclusión de cardio cuando solicitado
    - **Property 21: Inclusión de cardio cuando solicitado**
    - Con wantsCardio=true, al menos un día debe contener cardio
    - **Valida: Requisitos 4.4**

- [x] 4. Implementar TrainingPlanGenerator — Asignación de ejercicios y generación completa
  - [x] 4.1 Implementar assignExercises en TrainingPlanGenerator
    - Filtrar ejercicios por apiBodyPart del MuscleGroup
    - 1 compuesto obligatorio por grupo principal, completar con accesorios hasta 4-6
    - Ordenar: compuestos primero, accesorios después
    - Defaults: 3 sets, 10 reps; peso desde WorkoutLog previo o default estático
    - _Requisitos: 4.1, 4.2, 4.3, 4.5, 4.6, 4.7_

  - [ ]* 4.2 Test de propiedad: Ejercicios por día entre 4 y 6 con compuesto
    - **Property 6: Ejercicios por día entre 4 y 6 con al menos 1 compuesto por grupo principal**
    - **Valida: Requisitos 4.1, 4.2**

  - [ ]* 4.3 Test de propiedad: Orden compuestos antes que accesorios
    - **Property 7: Ejercicios compuestos antes que accesorios**
    - **Valida: Requisitos 4.5**

  - [ ]* 4.4 Test de propiedad: Defaults de sets y reps
    - **Property 8: Defaults de sets y reps**
    - Verificar sets == 3 y reps en 8...12 para plan recién generado
    - **Valida: Requisitos 4.6**

  - [ ]* 4.5 Test de propiedad: Peso sugerido desde log previo o default
    - **Property 22: Peso sugerido desde log previo o default**
    - **Valida: Requisitos 4.7**

  - [x] 4.6 Implementar generatePlan (función completa)
    - Orquestar: calculateMuscleFrequency → generateWeeklySplit → assignExercises para cada semana
    - Crear TrainingPlan con TrainingWeeks como @Model independientes
    - _Requisitos: 1.1, 2.1, 3.1, 4.1_

  - [ ]* 4.7 Test de propiedad: Inicialización de días con estado pending
    - **Property 17: Inicialización de días con estado pending**
    - Todos los días de un plan recién generado deben tener dayStatus == .pending
    - **Valida: Requisitos 10.8**

- [x] 5. Checkpoint — Verificar generación del plan
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

- [x] 6. Implementar WeeklyProgressionEngine
  - [x] 6.1 Crear `Super Fitness Coach App/Core/WeeklyProgressionEngine.swift`
    - progression(for:) con ciclo de 4 semanas: base → +5% peso → +10% volumen → deload
    - applyProgression(to:progression:) aplica multiplicadores a PlannedExercise
    - _Requisitos: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ]* 6.2 Test de propiedad: Ciclo de progresión semanal
    - **Property 9: Ciclo de progresión semanal de 4 semanas**
    - Random currentWeek (1-100), verificar weekInCycle y multiplicadores
    - **Valida: Requisitos 5.1, 5.2, 5.3, 5.4, 5.5**

- [x] 7. Implementar RecoveryAdapter
  - [x] 7.1 Crear `Super Fitness Coach App/Core/RecoveryAdapter.swift`
    - dailyAdjustment(recoveryScore:) con umbrales ≥80, 50-79, <50
    - applyAdjustment(to:adjustment:) con garantía de mínimo 1 set
    - _Requisitos: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ]* 7.2 Test de propiedad: Ajuste de recuperación según umbrales
    - **Property 10: Ajuste de recuperación según umbrales**
    - Random recoveryScore (0-100), verificar multiplicadores y setsReduction
    - **Valida: Requisitos 6.1, 6.2, 6.3**

  - [ ]* 7.3 Test de propiedad: Mínimo 1 set después de ajuste
    - **Property 11: Mínimo 1 set después de ajuste de recuperación**
    - Random exercises con sets ≥ 1, cualquier DailyAdjustment → sets ≥ 1
    - **Valida: Requisitos 6.4**

  - [ ]* 7.4 Test de propiedad: Ajuste no modifica ejercicios
    - **Property 12: Ajuste de recuperación no modifica ejercicios**
    - Verificar que IDs, nombres, orden y cantidad permanecen idénticos
    - **Valida: Requisitos 6.5**

- [x] 8. Implementar SetLogger y ProgressTracker
  - [x] 8.1 Crear `Super Fitness Coach App/Core/SetLogger.swift`
    - logSet, saveWorkoutLog, latestLog usando TrainingPlanRepository
    - _Requisitos: 8.1, 8.2, 8.3, 8.4_

  - [x] 8.2 Crear `Super Fitness Coach App/Core/ProgressTracker.swift`
    - totalVolume, maxWeight, maxReps como funciones estáticas puras
    - compareProgress: delta volumen >5% → improving, <-5% → declining, else stable
    - Sin log previo → stable
    - _Requisitos: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_

  - [ ]* 8.3 Test de propiedad: Comparación de progreso por volumen
    - **Property 13: Comparación de progreso por volumen**
    - Random WorkoutLogs, verificar umbrales de 5%
    - **Valida: Requisitos 9.1, 9.3, 9.4, 9.5, 9.6, 9.7**

- [x] 9. Implementar DayManager
  - [x] 9.1 Crear `Super Fitness Coach App/Core/DayManager.swift`
    - completeDay, skipDay, rescheduleDay, canReschedule, consecutiveSkippedDays
    - Reprogramar: mover al siguiente día pending + isRestDay, límite 1 vez (wasRescheduled)
    - _Requisitos: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 10.10_

  - [ ]* 9.2 Test de propiedad: Saltar día preserva otros días
    - **Property 14: Saltar día preserva otros días**
    - **Valida: Requisitos 10.2**

  - [ ]* 9.3 Test de propiedad: Reprogramar mueve al siguiente día disponible
    - **Property 15: Reprogramar mueve al siguiente día disponible y preserva sesiones**
    - **Valida: Requisitos 10.3, 10.4, 10.9**

  - [ ]* 9.4 Test de propiedad: Límite de reprogramación
    - **Property 16: Límite de reprogramación a una vez por día**
    - **Valida: Requisitos 10.6**

  - [ ]* 9.5 Test de propiedad: Detección de 3 días consecutivos saltados
    - **Property 18: Detección de 3 días consecutivos saltados**
    - **Valida: Requisitos 10.10**

- [x] 10. Checkpoint — Verificar lógica core completa
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

- [x] 11. Implementar ViewModels
  - [x] 11.1 Crear `Super Fitness Coach App/Features/Training/TrainingPreferencesViewModel.swift`
    - Propiedades: goal, trainingDaysPerWeek, experienceLevel, priorityMuscles, wantsCardio, planDurationWeeks
    - toggleMuscle con límite de 2 músculos prioritarios
    - generatePlan() async que invoca TrainingPlanGenerator y persiste vía TrainingPlanRepository
    - _Requisitos: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [ ]* 11.2 Test de propiedad: Límite de músculos prioritarios
    - **Property 2: Límite de músculos prioritarios**
    - Random MuscleGroup sequences, verificar que array nunca excede 2 elementos
    - **Valida: Requisitos 1.3**

  - [x] 11.3 Crear `Super Fitness Coach App/Features/Training/WorkoutExecutorViewModel.swift`
    - buildDailyExercises(): **orden crítico progresión → recuperación**
    - completeSet, startRestTimer (60s), stopRestTimer
    - Integrar WeeklyProgressionEngine, RecoveryAdapter, SetLogger, HealthKitManager
    - _Requisitos: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_

  - [x] 11.4 Crear `Super Fitness Coach App/Features/Training/TrainingPlanViewModel.swift`
    - Gestión de la vista del plan: semana actual, días, estados
    - Integrar DayManager y ProgressTracker
    - _Requisitos: 14.1, 14.2, 14.3, 14.4_

  - [x] 11.5 Crear `Super Fitness Coach App/Features/Training/FeedbackViewModel.swift`
    - Calcular mejoras de peso por ejercicio, días consecutivos, hasImproving
    - Integrar ProgressTracker y GamificationEngine
    - Otorgar 100 pts por entrenamiento + bonificación racha ≥ 3
    - _Requisitos: 12.1, 12.2, 12.3, 12.4, 11.1, 11.2, 11.3_

  - [ ]* 11.6 Test de propiedad: Gamificación otorga puntos correctos
    - **Property 20: Gamificación otorga puntos correctos**
    - 100 pts base + bonificación streak × 10 si streak ≥ 3
    - **Valida: Requisitos 11.1, 11.2**

- [x] 12. Implementar Vistas SwiftUI
  - [x] 12.1 Crear `Super Fitness Coach App/Features/Training/TrainingPreferencesView.swift`
    - Formulario con: goal picker, days stepper (3-6), level picker, muscle selector (máx 2), cardio toggle, duration picker (4/6/8)
    - Botón de generar plan
    - _Requisitos: 1.1, 1.2, 1.3, 1.5_

  - [x] 12.2 Crear `Super Fitness Coach App/Features/Training/TrainingPlanView.swift`
    - Vista del plan semanal con días, grupos musculares, estados (pending/completed/skipped/rescheduled)
    - Acciones por día: completar, saltar, reprogramar
    - Indicador de progreso del plan (semana actual / total)
    - Indicador de día de descanso
    - _Requisitos: 14.1, 14.2, 14.3, 14.4, 10.1_

  - [x] 12.3 Crear `Super Fitness Coach App/Features/Training/WorkoutExecutorView.swift`
    - Pantalla por ejercicio con campos de peso/reps por set
    - Checkmark por set completado
    - Temporizador de descanso 60s (no editable)
    - Avance automático al siguiente ejercicio
    - _Requisitos: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 12.4 Crear `Super Fitness Coach App/Features/Training/FeedbackView.swift`
    - Mejoras de peso por ejercicio, días consecutivos, indicador 🔼
    - Mensaje de bienvenida si es primer entrenamiento
    - _Requisitos: 12.1, 12.2, 12.3, 12.4_

- [x] 13. Integración con la app existente
  - [x] 13.1 Añadir propiedad `trainingPreferences: TrainingPreferences?` a UserProfile
    - Modificar `Super Fitness Coach App/Models/UserProfile.swift`
    - _Requisitos: 13.1_

  - [x] 13.2 Extender GamificationEngine para puntos del plan de entrenamiento
    - Usar awardPoints(100, for: .workoutCompleted) para entrenamientos del plan
    - Bonificación racha: si currentStreak ≥ 3, otorgar streak × 10 puntos adicionales
    - _Requisitos: 11.1, 11.2, 11.3_

  - [x] 13.3 Integrar flujo de Training en ContentView
    - Crear e inyectar TrainingPlanRepository, TrainingPreferencesViewModel, TrainingPlanViewModel
    - Añadir navegación desde la tab Workout hacia el flujo de Training Plan
    - Conectar WorkoutExecutorView con el flujo de ejecución
    - _Requisitos: 14.1_

  - [x] 13.4 Conectar RecoveryAdapter con HealthKitManager.recoveryScore
    - Leer recoveryScore existente; si no autorizado, usar default 50
    - _Requisitos: 6.1, 6.2, 6.3_

- [x] 14. Checkpoint final — Verificar integración completa
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

## Notas

- Las tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido
- Cada tarea referencia requisitos específicos para trazabilidad
- Los checkpoints aseguran validación incremental
- Los tests de propiedad validan propiedades universales de correctitud (22 propiedades del diseño)
- Los tests unitarios validan ejemplos específicos y edge cases
- El orden crítico progresión → recuperación en `buildDailyExercises()` está documentado en la tarea 11.3
- TrainingWeek como @Model independiente (no array anidado) está documentado en la tarea 1.3
