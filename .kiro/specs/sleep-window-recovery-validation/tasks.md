# Plan de Implementación

- [x] 1. Escribir test de exploración de la condición del bug
  - **Property 1: Bug Condition** - Datos de HRV/RHR fuera de la ventana de sueño contaminan el Recovery Score
  - **CRITICAL**: Este test DEBE FALLAR en el código sin corregir — el fallo confirma que el bug existe
  - **NO intentes arreglar el test ni el código cuando falle**
  - **NOTA**: Este test codifica el comportamiento esperado — validará el fix cuando pase después de la implementación
  - **GOAL**: Generar contraejemplos que demuestren que el bug existe
  - **Scoped PBT Approach**: Para este bug determinístico, acotar la propiedad a los casos concretos de fallo: HRV/RHR con timestamps fuera de la ventana de sueño
  - Crear mocks de HealthKit que retornen samples de HRV y RHR con timestamps específicos fuera de la ventana de sueño
  - Condición del bug (de `isBugCondition` en diseño): `input.sleepWindow != nil AND (hrvSample.startDate/endDate NO se superpone con [sleepStart, sleepEnd] OR rhrSample.startDate/endDate NO se superpone con [sleepStart, sleepEnd])`
  - Caso 1: HRV a las 21:30 con sueño de 23:00-07:00 → el sistema NO debería usar este HRV en el Recovery Score
  - Caso 2: RHR a las 15:00 con sueño de 00:30-06:45 → el sistema NO debería usar este RHR en el Recovery Score
  - Caso 3: HRV más reciente a las 09:00 (fuera del sueño), HRV anterior a las 03:15 (dentro del sueño de 23:00-07:00) → el sistema DEBERÍA usar el de las 03:15
  - Caso 4: Múltiples HRV dentro del sueño (01:00, 03:15, 05:30 con sueño de 23:00-07:00) → el sistema DEBERÍA usar el de las 05:30 (más reciente dentro de la ventana)
  - Las aserciones deben verificar que HRV/RHR fuera del sueño se tratan como `nil` (no disponible) y se excluyen del cálculo
  - Ejecutar test en código SIN corregir
  - **RESULTADO ESPERADO**: Test FALLA (esto es correcto — demuestra que el bug existe, el código actual usa datos de vigilia)
  - Documentar contraejemplos encontrados (ej. "HRV de las 21:30 se usa en Recovery Score cuando debería ser excluido")
  - Marcar tarea como completa cuando el test esté escrito, ejecutado, y el fallo documentado
  - Archivo de test: `Tests/PropertyTests/SleepWindowValidationPropertyTests.swift`
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 2.5, 2.8, 2.9, 2.10_

- [x] 2. Escribir tests de preservación basados en propiedades (ANTES de implementar el fix)
  - **Property 2: Preservation** - Comportamiento inalterado para datos dentro del sueño y otros cálculos
  - **IMPORTANTE**: Seguir la metodología observation-first
  - Observar: con HRV/RHR dentro de la ventana de sueño, el Recovery Score se calcula con pesos sleep=0.45, hr=0.25, hrv=0.30 en código sin corregir
  - Observar: el Activity Score (steps + calories) se calcula independientemente del sueño en código sin corregir
  - Observar: sin datos de sueño, el fallback existente (solo HR/HRV, o estimar desde actividad) funciona en código sin corregir
  - Observar: `normalizeHRV` y `normalizeRestingHR` producen los mismos valores para los mismos inputs
  - Escribir property-based test: para todo input donde `isBugCondition` retorna false (HRV/RHR dentro del sueño, o sin datos de sueño), el resultado del cálculo es idéntico al comportamiento observado
  - Escribir property-based test: para todo input de steps/calories, el Activity Score es idéntico antes y después
  - Escribir property-based test: `redistributeWeights` produce pesos que suman 1.0 para cualquier combinación de componentes disponibles
  - Verificar que los tests PASAN en código SIN corregir
  - **RESULTADO ESPERADO**: Tests PASAN (esto confirma el comportamiento base a preservar)
  - Marcar tarea como completa cuando los tests estén escritos, ejecutados, y pasando en código sin corregir
  - Archivo de test: `Tests/PropertyTests/SleepWindowValidationPropertyTests.swift`
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 3. Fix para validación de ventana de sueño en Recovery Score

  - [x] 3.1 Crear nueva función `queryQuantityInSleepWindow`
    - Nueva función privada que consulta HealthKit con `HKObjectQueryNoLimit` (no `limit: 1`)
    - Ordenar por `startDate` descendente
    - Filtrar samples cuyo intervalo (`startDate`→`endDate`) se superpone con la ventana de sueño (`sleepStart`→`sleepEnd`)
    - Superposición: `sampleStart < sleepEnd AND sampleEnd > sleepStart`
    - Retornar el más reciente que se superpone: `(value: Double, startDate: Date, endDate: Date)?`
    - Si ningún sample se superpone, retornar `nil`
    - La función `queryQuantity` original se mantiene sin cambios para callers que no necesitan validación (weight, height)
    - Archivo: `Super Fitness Coach App/Core/HealthKitManager.swift`
    - _Requirements: 2.7, 2.8, 2.9, 2.10_

  - [x] 3.2 Exponer `sessionStart`/`sessionEnd` desde `querySleepPhases`
    - Cambiar tipo de retorno de `(total: Double?, deep: Double?, rem: Double?)` a `(total: Double?, deep: Double?, rem: Double?, sessionStart: Date?, sessionEnd: Date?)`
    - Retornar `sessionStart` y `sessionEnd` de la sesión más reciente detectada
    - Retornar `nil` para ambos cuando no hay sesión de sueño
    - Archivo: `Super Fitness Coach App/Core/HealthKitManager.swift`, función `querySleepPhases` (~línea 580)
    - _Bug_Condition: querySleepPhases calcula sessionStart/sessionEnd pero no los expone al caller_
    - _Expected_Behavior: querySleepPhases retorna sessionStart/sessionEnd para validación temporal_
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [x] 3.3 Agregar validación de ventana de sueño en `refreshHealthData`
    - Extraer `sessionStart`/`sessionEnd` del resultado de `querySleepPhases`
    - Si hay ventana de sueño disponible, usar `queryQuantityInSleepWindow` para obtener HRV y RHR (el más reciente dentro de la ventana)
    - Si no hay ventana de sueño (`sessionStart`/`sessionEnd` son `nil`), mantener fallback existente con `queryQuantity` (sin validación)
    - Si `queryQuantityInSleepWindow` retorna `nil` (ningún sample dentro del sueño), tratar como no disponible y redistribuir pesos
    - Archivo: `Super Fitness Coach App/Core/HealthKitManager.swift`, función `refreshHealthData(config:)` (~línea 130)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.8, 2.9, 2.10_

  - [x] 3.4 Agregar logging de validación
    - Registrar via `logger.info` la ventana de sueño detectada (`sleepStart` → `sleepEnd`)
    - Registrar los timestamps de los samples de HRV y RHR
    - Registrar si cada sample fue aceptado o rechazado (dentro/fuera de la ventana de sueño)
    - Archivo: `Super Fitness Coach App/Core/HealthKitManager.swift`, dentro de `refreshHealthData(config:)`
    - _Requirements: 2.6_

  - [x] 3.5 Verificar que el test de exploración de la condición del bug ahora pasa
    - **Property 1: Expected Behavior** - Datos de HRV/RHR fuera de la ventana de sueño se excluyen
    - **IMPORTANTE**: Re-ejecutar el MISMO test de la tarea 1 — NO escribir un test nuevo
    - El test de la tarea 1 codifica el comportamiento esperado
    - Cuando este test pasa, confirma que el comportamiento esperado se satisface
    - Ejecutar test de exploración de la condición del bug de la tarea 1
    - **RESULTADO ESPERADO**: Test PASA (confirma que el bug está corregido)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.8, 2.9, 2.10_

  - [x] 3.6 Verificar que los tests de preservación siguen pasando
    - **Property 2: Preservation** - Comportamiento inalterado para datos dentro del sueño y otros cálculos
    - **IMPORTANTE**: Re-ejecutar los MISMOS tests de la tarea 2 — NO escribir tests nuevos
    - Ejecutar tests de preservación de la tarea 2
    - **RESULTADO ESPERADO**: Tests PASAN (confirma que no hay regresiones)
    - Confirmar que todos los tests siguen pasando después del fix (sin regresiones)

- [x] 4. Checkpoint - Verificar que todos los tests pasan
  - Compilar el proyecto y verificar que no hay errores de compilación
  - Ejecutar todos los tests unitarios existentes en `Tests/UnitTests/HealthKitManagerTests.swift`
  - Ejecutar todos los property-based tests en `Tests/PropertyTests/SleepWindowValidationPropertyTests.swift`
  - Verificar que los tests de exploración (Property 1) PASAN después del fix
  - Verificar que los tests de preservación (Property 2) PASAN después del fix
  - Si hay preguntas o fallos inesperados, consultar al usuario
