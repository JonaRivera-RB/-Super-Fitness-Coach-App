# Plan de Implementación: Insights de Progreso de Actividad

## Resumen

Corregir los mensajes de insight engañosos en la sección de Actividad, agregar barras de progreso visual para pasos y calorías, e implementar mensajes motivacionales por nivel de avance. Los cambios se limitan a `MetricInsightGenerator.swift`, `HomeView.swift` y el struct `MetricInsight`. Se incluyen tests de propiedades y unitarios para validar la correctitud.

## Tareas

- [x] 1. Modificar el struct MetricInsight y refactorizar MetricInsightGenerator
  - [x] 1.1 Agregar campo opcional `normalizedScore` al struct `MetricInsight`
    - Agregar `let normalizedScore: Double?` al struct en `MetricInsightGenerator.swift`
    - Agregar init con valor default `nil` para backward compatibility
    - Verificar que los insights de recovery (Sleep, HR, HRV) sigan funcionando sin cambios
    - _Requisitos: 6.1_

  - [x] 1.2 Refactorizar `stepsInsight` para usar `normalizedScore` en vez de `ComponentStatus`
    - Reemplazar el `switch component.status` por condicionales sobre `component.normalizedScore`
    - Implementar los 4 rangos: >= 100 ("¡Meta cumplida!"), 70-99 ("ya casi llegas"), 40-69 ("vas bien"), < 40 ("a moverse")
    - Pasar `normalizedScore` al `MetricInsight` retornado
    - _Requisitos: 1.1, 1.2, 1.3, 1.4, 6.1, 6.2_

  - [x] 1.3 Refactorizar `caloriesInsight` para usar `normalizedScore` en vez de `ComponentStatus`
    - Reemplazar el `switch component.status` por condicionales sobre `component.normalizedScore`
    - Implementar los 4 rangos: >= 100 ("Meta de calorías cumplida"), 70-99 ("casi lo logras"), 40-69 ("en progreso"), < 40 ("aún queda camino")
    - Pasar `normalizedScore` al `MetricInsight` retornado
    - _Requisitos: 2.1, 2.2, 2.3, 2.4, 6.1, 6.2_

  - [x] 1.4 Agregar método `motivationalSuffix(for:)` en MetricInsightGenerator
    - Implementar método estático que retorna sufijo motivacional según 5 rangos de `normalizedScore`
    - Rangos: < 25 ("¡Cada paso cuenta!"), 25-49 ("¡Buen arranque!"), 50-74 ("¡Más de la mitad!"), 75-99 ("¡Ya casi!"), >= 100 ("¡Meta cumplida! 🎉")
    - Integrar el sufijo en los mensajes de `stepsInsight` y `caloriesInsight` para rangos intermedios (< 100)
    - _Requisitos: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ]* 1.5 Escribir test de propiedad: Mensaje de pasos mapea correctamente al rango de normalizedScore
    - **Propiedad 1: Mensaje de pasos mapea correctamente al rango de normalizedScore**
    - **Valida: Requisitos 1.1, 1.2, 1.3, 1.4**

  - [ ]* 1.6 Escribir test de propiedad: Mensaje de calorías mapea correctamente al rango de normalizedScore
    - **Propiedad 2: Mensaje de calorías mapea correctamente al rango de normalizedScore**
    - **Valida: Requisitos 2.1, 2.2, 2.3, 2.4**

  - [ ]* 1.7 Escribir test de propiedad: Mensaje motivacional mapea correctamente al rango de normalizedScore
    - **Propiedad 5: Mensaje motivacional mapea correctamente al rango de normalizedScore**
    - **Valida: Requisitos 5.1, 5.2, 5.3, 5.4, 5.5**

  - [ ]* 1.8 Escribir test de propiedad: "Meta cumplida" se reserva exclusivamente para normalizedScore >= 100
    - **Propiedad 6: "Meta cumplida" se reserva exclusivamente para normalizedScore >= 100**
    - **Valida: Requisitos 6.1, 6.2**

  - [ ]* 1.9 Escribir test de propiedad: Generación de insights es determinista
    - **Propiedad 7: Generación de insights es determinista**
    - **Valida: Requisito 6.3**

- [x] 2. Checkpoint — Verificar que los insights refactorizados funcionan correctamente
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Agregar barras de progreso visual en HomeView
  - [x] 3.1 Crear componente `activityProgressBar` y `progressBarColor` en HomeView
    - Implementar función `activityProgressBar(progress:normalizedScore:accessibilityLabel:)` usando `GeometryReader` y `Capsule`
    - Implementar función `progressBarColor(for:)` con 3 rangos: >= 100 verde, 40-99 azul, < 40 naranja
    - La fracción de progreso debe estar clamped a [0.0, 1.0]
    - _Requisitos: 3.2, 3.3, 3.4, 3.5, 4.2, 4.3, 4.4, 4.5_

  - [x] 3.2 Modificar `insightRow` para mostrar barra de progreso cuando hay `normalizedScore`
    - Agregar parámetro opcional `normalizedScore: Double?` a `insightRow`
    - Mostrar `activityProgressBar` debajo del mensaje cuando `normalizedScore` no es nil
    - Incluir etiqueta de accesibilidad "Progreso de [métrica]: X por ciento"
    - _Requisitos: 3.1, 3.6, 4.1, 4.6_

  - [x] 3.3 Integrar barras en `insightsBreakdownView` para insights de actividad
    - Pasar `insight.normalizedScore` al llamar `insightRow` dentro de la sección de actividad
    - Verificar que los insights de recovery NO muestran barra (normalizedScore es nil)
    - _Requisitos: 3.1, 4.1_

  - [ ]* 3.4 Escribir test de propiedad: Fracción de barra de progreso está limitada a [0, 1]
    - **Propiedad 3: Fracción de barra de progreso está limitada a [0, 1]**
    - **Valida: Requisitos 3.2, 4.2**

  - [ ]* 3.5 Escribir test de propiedad: Color de barra de progreso mapea correctamente al rango de normalizedScore
    - **Propiedad 4: Color de barra de progreso mapea correctamente al rango de normalizedScore**
    - **Valida: Requisitos 3.3, 3.4, 3.5, 4.3, 4.4, 4.5**

- [x] 4. Checkpoint — Verificar barras de progreso y accesibilidad
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Escribir tests unitarios de boundaries y edge cases
  - [ ]* 5.1 Escribir tests unitarios para stepsInsight en boundaries
    - Tests para normalizedScore = 39, 40, 69, 70, 99, 100
    - Test para rawValue = 0 con goal = 10000
    - _Requisitos: 1.1, 1.2, 1.3, 1.4, 6.2_

  - [ ]* 5.2 Escribir tests unitarios para caloriesInsight en boundaries
    - Tests para normalizedScore = 39, 40, 69, 70, 99, 100
    - Test para rawValue = 0 con goal = 500
    - _Requisitos: 2.1, 2.2, 2.3, 2.4, 6.2_

  - [ ]* 5.3 Escribir tests unitarios para motivationalSuffix en boundaries
    - Tests para normalizedScore = 0, 24, 25, 49, 50, 74, 75, 99, 100
    - _Requisitos: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ]* 5.4 Escribir tests unitarios para progressBarColor en boundaries
    - Tests para normalizedScore = 39, 40, 99, 100
    - _Requisitos: 3.3, 3.4, 3.5, 4.3, 4.4, 4.5_

- [x] 6. Checkpoint final — Verificar que todos los tests pasan
  - Ensure all tests pass, ask the user if questions arise.

## Notas

- Las tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido
- Cada tarea referencia requisitos específicos para trazabilidad
- Los tests de propiedades usan el patrón `SeededRNG` ya establecido en `SleepWindowValidationPropertyTests.swift`
- Los checkpoints aseguran validación incremental
- Los insights de recovery (Sleep, HR, HRV) no se modifican — solo se cambian pasos y calorías
