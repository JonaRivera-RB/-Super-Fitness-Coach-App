# Plan de Implementación: Smart Home Dashboard

## Resumen

Transformar el Home Dashboard de datos numéricos crudos a un coach inteligente con resumen ejecutivo, tarjeta de acción, etiquetas descriptivas e insights contextuales en español. Los cambios son exclusivamente en la capa de presentación: `HealthKitManager`, `ScoreBreakdown` y `refreshHealthData()` NO se modifican.

## Tareas

- [x] 1. Crear MetricInsightGenerator con funciones puras de generación de insights
  - [x] 1.1 Crear archivo `Super Fitness Coach App/Core/MetricInsightGenerator.swift` con el struct `MetricInsight` y el struct `MetricInsightGenerator`
    - Definir `MetricInsight` con propiedades `metricName: String`, `message: String`, `status: ScoreBreakdown.ComponentStatus`
    - Implementar `static func generateInsights(from breakdown: ScoreBreakdown, config: FitnessConfig) -> [MetricInsight]` que itera sobre los componentes y delega a `generateInsight`
    - Implementar `static func generateInsight(for component: ScoreBreakdown.ScoreComponent, config: FitnessConfig) -> MetricInsight` con reglas por nombre de métrica (Sleep, Resting HR, HRV, Steps, Active Calories) y status (warning/normal/good)
    - Mensajes en español según la tabla del diseño: sueño con déficit de horas, FC con comparación al baseline, HRV con estado del sistema nervioso, pasos con motivación, calorías con progreso
    - Manejar edge cases: `sleepGoalHours = 0` (evitar división por cero), breakdown vacío (retornar array vacío)
    - _Requisitos: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [ ]* 1.2 Escribir test de propiedad para MetricInsightGenerator — un insight por componente
    - **Propiedad 3: Insight Generator produce un insight por componente del breakdown**
    - **Valida: Requisito 3.1**

  - [ ]* 1.3 Escribir test de propiedad para insight de sueño con déficit
    - **Propiedad 4: Insight de sueño menciona déficit cuando está por debajo del 70% de la meta**
    - **Valida: Requisito 3.2**

  - [ ]* 1.4 Escribir test de propiedad para insight de FC en reposo
    - **Propiedad 5: Insight de FC en reposo menciona fatiga cuando está por encima del baseline**
    - **Valida: Requisito 3.3**

  - [ ]* 1.5 Escribir test de propiedad para insight de HRV
    - **Propiedad 6: Insight de HRV refleja correctamente la comparación con el baseline**
    - **Valida: Requisitos 3.4, 3.5**

  - [ ]* 1.6 Escribir test de propiedad para insight de pasos motivacional
    - **Propiedad 7: Insight de pasos es motivacional cuando está por debajo del 50% de la meta**
    - **Valida: Requisito 3.6**

  - [ ]* 1.7 Escribir test de propiedad para preservación de status
    - **Propiedad 8: El status del insight preserva el status del componente**
    - **Valida: Requisito 3.7**

  - [ ]* 1.8 Escribir unit tests para MetricInsightGenerator
    - Test de insight para sleep con rawValue = 0
    - Test de insight para breakdown vacío (0 componentes)
    - Tests de ejemplos específicos para cada tipo de métrica y status
    - _Requisitos: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [-] 2. Mejorar AICoach con reglas contextuales y mensajes en español
  - [x] 2.1 Modificar `AICoach.generateMessage()` en `Super Fitness Coach App/Core/AICoach.swift`
    - Agregar parámetro `recoveryBreakdown: ScoreBreakdown?` a la firma
    - Implementar `static func worstComponent(from breakdown: ScoreBreakdown) -> ScoreBreakdown.ScoreComponent?` que retorna el componente con menor `normalizedScore`
    - Implementar `static func contextualReason(from breakdown: ScoreBreakdown) -> String` que genera texto contextual basado en el peor componente
    - Cambiar todos los mensajes a español
    - Regla: recovery < 40 con breakdown → mencionar la métrica específica que está baja (sueño < 6h, HR elevada, HRV bajo)
    - Regla: activity > 70 y recovery < 40 → reconocer esfuerzo reciente y enfatizar recuperación
    - Regla: streak ≥ 3 → combinar reconocimiento del streak con recomendación basada en recovery actual
    - Fallback: cuando `recoveryBreakdown` es `nil`, generar mensajes genéricos (backward compatible)
    - _Requisitos: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 1.2, 1.3, 1.4, 1.7_

  - [ ]* 2.2 Escribir test de propiedad para Coach Summary y estado correcto
    - **Propiedad 1: Coach Summary mapea Recovery Score al estado correcto**
    - **Valida: Requisitos 1.1, 1.2, 1.3, 1.4, 1.6**

  - [ ]* 2.3 Escribir test de propiedad para AICoach referenciando métricas en warning
    - **Propiedad 9: AICoach referencia métricas en warning del breakdown**
    - **Valida: Requisito 4.1**

  - [ ]* 2.4 Escribir test de propiedad para AICoach combinando streak con recomendación
    - **Propiedad 10: AICoach combina reconocimiento de streak con recomendación**
    - **Valida: Requisito 4.4**

  - [ ]* 2.5 Escribir unit tests para AICoach mejorado
    - Test: sleep < 6h y recovery < 50 menciona sueño (edge case Req 4.2)
    - Test: HR > baseline * 1.1 menciona estrés cardiovascular (edge case Req 4.3)
    - Test: activity > 70 y recovery < 40 reconoce esfuerzo (edge case Req 1.7)
    - Test: breakdown nil genera mensaje genérico (backward compat)
    - _Requisitos: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 3. Checkpoint — Verificar que MetricInsightGenerator y AICoach compilan y tests pasan
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

- [x] 4. Extender HomeViewModel con nuevas propiedades de presentación
  - [x] 4.1 Agregar nuevas propiedades y enums a `Super Fitness Coach App/Features/Home/HomeViewModel.swift`
    - Agregar enum `ActionIntensity` con cases `.low`, `.medium`, `.high` y propiedades `label` (Baja/Media/Alta) y `systemColor` (red/orange/green)
    - Agregar propiedades: `coachSummary: String`, `coachEmoji: String`, `actionCardTitle: String`, `actionCardIntensity: ActionIntensity`, `recoveryLabel: String`, `activityLabel: String`, `recoveryInsights: [MetricInsight]`, `activityInsights: [MetricInsight]`
    - Implementar función privada `generateRecoveryLabel(score: Int) -> String` con 4 niveles: 0-39 "Necesitas descanso", 40-69 "Recuperación moderada", 70-84 "Buena recuperación", 85-100 "Recuperación óptima"
    - Implementar función privada `generateActivityLabel(score: Int) -> String` con 4 niveles: 0-39 "Día tranquilo", 40-69 "En progreso", 70-84 "Muy activo", 85-100 "Excelente actividad"
    - Implementar función privada `generateActionCard(recoveryScore: Int, workoutType: WorkoutType)` que asigna `actionCardTitle` y `actionCardIntensity` según recovery
    - _Requisitos: 5.1, 5.2, 6.1, 6.2, 6.3, 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 4.2 Integrar las nuevas propiedades en `refreshData()` de HomeViewModel
    - Después de obtener los scores y breakdowns existentes, calcular y asignar: `coachSummary` y `coachEmoji` usando `AICoach.generateMessage()` actualizado con `recoveryBreakdown`
    - Calcular `recoveryLabel` y `activityLabel` usando las funciones de 4 niveles
    - Calcular `actionCardTitle` y `actionCardIntensity` usando la lógica de intensidad
    - Generar `recoveryInsights` y `activityInsights` usando `MetricInsightGenerator.generateInsights()` con `FitnessConfig`
    - Actualizar la llamada a `AICoach.generateMessage()` para pasar `recoveryBreakdown`
    - NO modificar la lógica de `refreshHealthData()` de HealthKitManager — solo consumir su output
    - _Requisitos: 1.1, 1.5, 2.1, 3.1, 5.1_

  - [ ]* 4.3 Escribir test de propiedad para Action Card e intensidad
    - **Propiedad 2: Action Card mapea Recovery Score a intensidad correcta**
    - **Valida: Requisitos 2.2, 2.3, 2.4**

  - [ ]* 4.4 Escribir test de propiedad para etiquetas de score
    - **Propiedad 11: Etiqueta de score mapea al descriptor de rango correcto**
    - **Valida: Requisitos 6.1, 6.2, 6.3**

  - [ ]* 4.5 Escribir unit tests para HomeViewModel
    - Test: action card con recovery = 39 (boundary) → intensidad baja
    - Test: action card con recovery = 40 (boundary) → intensidad media
    - Test: action card con recovery = 70 (boundary) → intensidad alta
    - Test: score labels con valores boundary (0, 39, 40, 69, 70, 84, 85, 100)
    - _Requisitos: 2.2, 2.3, 2.4, 6.1, 6.2, 6.3_

- [x] 5. Checkpoint — Verificar que HomeViewModel compila y tests pasan
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

- [x] 6. Rediseñar HomeView con nueva jerarquía visual
  - [x] 6.1 Rediseñar `Super Fitness Coach App/Features/Home/HomeView.swift` con la nueva jerarquía
    - Reemplazar la estructura actual del `ScrollView` con el nuevo orden: Coach Summary → Action Card → Recovery compacto con insights → Activity compacto con insights → Puntos/Detox → Iniciar Rutina
    - Implementar sección Coach Summary como primer elemento: fondo coloreado según estado (rojo/naranja/verde), emoji + texto grande del `coachSummary`, `accessibilityLabel` descriptivo
    - Implementar sección Action Card: título del `actionCardTitle` en texto grande, barra de intensidad con color según `actionCardIntensity`, `accessibilityLabel` descriptivo
    - _Requisitos: 1.5, 1.6, 2.1, 2.5, 5.1, 5.5_

  - [x] 6.2 Implementar scores compactos con etiquetas descriptivas e insights contextuales
    - Rediseñar recovery section: número ~48pt (reducido del 72pt actual) + `recoveryLabel` + indicador de color en una línea horizontal
    - Rediseñar activity section: número ~48pt + `activityLabel` + indicador de color en una línea horizontal
    - Reemplazar el breakdown técnico (pesos, porcentajes, normalizedScore) por `MetricInsight.message` en el expandible de detalles
    - Mantener el botón de expandir/colapsar detalles existente
    - Mantener todos los `accessibilityLabel` existentes y agregar nuevos para coach summary, action card e insights
    - _Requisitos: 3.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.2, 6.4_

  - [x] 6.3 Implementar estado de carga con placeholders animados
    - Cuando `isLoading` es true o scores están en `.loading`, mostrar `ProgressView` con placeholder animado en lugar de valores por defecto
    - Coach summary muestra placeholder durante carga
    - Action card muestra placeholder durante carga
    - _Requisitos: 5.3_

- [x] 7. Checkpoint final — Verificar que toda la app compila y la UI funciona correctamente
  - Asegurar que todos los tests pasan, preguntar al usuario si surgen dudas.

## Notas

- Las tareas marcadas con `*` son opcionales y se pueden omitir para un MVP más rápido
- Cada tarea referencia requisitos específicos para trazabilidad
- Los checkpoints aseguran validación incremental
- Los tests de propiedades validan propiedades universales de correctitud
- Los unit tests validan ejemplos específicos y edge cases
- **NO se modifica** `HealthKitManager.swift`, `ScoreBreakdown.swift`, ni la lógica de `refreshHealthData()`
