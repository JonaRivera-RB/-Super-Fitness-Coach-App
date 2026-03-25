# Validación de Ventana de Sueño para Recovery Score — Diseño del Bugfix

## Resumen

El bug radica en que `refreshHealthData()` usa `queryQuantity` para obtener HRV y Resting HR de las últimas 24 horas sin validar si el timestamp del sample cae dentro de la sesión de sueño detectada. Esto permite que datos de vigilia (ej. HRV de las 21:30 antes de dormir, o RHR de la tarde) contaminen el Recovery Score, produciendo un indicador que no refleja la recuperación fisiológica real durante el descanso.

La estrategia de corrección consiste en:
1. Modificar `queryQuantity` para que retorne `(value: Double, date: Date)?` en vez de `Double?`
2. Exponer `sessionStart`/`sessionEnd` desde `querySleepPhases`
3. Validar los timestamps de HRV y RHR contra la ventana de sueño ANTES de la normalización
4. Tratar como no disponible cualquier métrica cuyo sample esté fuera del sueño

## Glosario

- **Bug_Condition (C)**: La condición que dispara el bug — cuando el timestamp del sample de HRV o RHR está fuera del rango `[sleepStart, sleepEnd]` de la sesión de sueño detectada, pero el sistema lo usa igualmente para calcular el Recovery Score
- **Property (P)**: El comportamiento deseado — solo usar HRV/RHR cuyos timestamps caigan dentro de la ventana de sueño detectada; ignorar los demás
- **Preservation**: El cálculo del Recovery Score cuando los datos SÍ están dentro del sueño, el Activity Score, los fallbacks sin datos de sueño, y las funciones de normalización deben permanecer sin cambios
- **`queryQuantity`**: Función privada en `HealthKitManager.swift` que consulta HealthKit con `limit: 1` y retorna el sample más reciente. Actualmente retorna `Double?`, debe retornar `(value: Double, startDate: Date, endDate: Date)?`
- **`querySleepPhases`**: Función privada que detecta sesiones de sueño y retorna `(total: Double?, deep: Double?, rem: Double?)`. Debe exponer también `sessionStart` y `sessionEnd`
- **`refreshHealthData(config:)`**: Función principal que orquesta todas las queries y calcula Recovery/Activity scores
- **Ventana de sueño**: El rango temporal `[sessionStart, sessionEnd]` de la sesión de sueño más reciente detectada por `querySleepPhases`

## Detalles del Bug

### Condición del Bug

El bug se manifiesta cuando `queryQuantity` obtiene un sample de HRV o Resting HR cuyo `startDate` está fuera de la ventana de sueño detectada (`sessionStart` → `sessionEnd`), pero el sistema lo usa igualmente para calcular el Recovery Score. Esto ocurre porque `queryQuantity` solo retorna `Double?` (sin timestamp) y `querySleepPhases` no expone los límites temporales de la sesión.

**Especificación Formal:**
```
FUNCTION isBugCondition(input)
  INPUT: input de tipo { hrvSample: (value: Double, startDate: Date, endDate: Date)?,
                         rhrSample: (value: Double, startDate: Date, endDate: Date)?,
                         sleepWindow: (start: Date, end: Date)? }
  OUTPUT: boolean

  IF input.sleepWindow == nil THEN
    RETURN false  // Sin sueño detectado, se usa fallback existente (no es bug)
  END IF

  LET sleepStart = input.sleepWindow.start
  LET sleepEnd = input.sleepWindow.end

  LET hrvOutside = input.hrvSample != nil
                   AND NOT overlaps(input.hrvSample.startDate, input.hrvSample.endDate, sleepStart, sleepEnd)
  LET rhrOutside = input.rhrSample != nil
                   AND NOT overlaps(input.rhrSample.startDate, input.rhrSample.endDate, sleepStart, sleepEnd)

  RETURN hrvOutside OR rhrOutside
END FUNCTION

FUNCTION overlaps(sampleStart, sampleEnd, sleepStart, sleepEnd)
  // Un sample es válido si al menos parte de su intervalo cae dentro del sueño
  RETURN sampleStart < sleepEnd AND sampleEnd > sleepStart
END FUNCTION
```

### Ejemplos

- **HRV antes de dormir**: El usuario duerme de 23:00 a 07:00. HealthKit tiene un sample de HRV a las 21:30 (vigilia). El sistema actual lo usa para el Recovery Score → score contaminado con datos de vigilia
- **RHR de la tarde**: El usuario duerme de 00:30 a 06:45. HealthKit tiene un sample de RHR a las 15:00 del día anterior. El sistema actual lo usa → score no refleja recuperación nocturna
- **HRV durante el sueño**: El usuario duerme de 23:00 a 07:00. HealthKit tiene un sample de HRV a las 03:15. El sistema actual lo usa correctamente → este caso NO es bug
- **Sin datos de sueño**: No hay sesión de sueño detectada. El sistema usa fallback existente (solo HR/HRV o estimación desde actividad) → este caso NO es bug, es comportamiento esperado
- **HRV con superposición parcial**: El usuario duerme de 23:00 a 07:00. HealthKit tiene un sample de HRV de 22:45 a 23:15 (se superpone parcialmente con el sueño). El sistema DEBERÁ considerarlo válido porque parte del intervalo cae dentro del sueño
- **HRV más reciente fuera, anterior dentro**: El usuario duerme de 23:00 a 07:00. HealthKit tiene un sample de HRV a las 09:00 (más reciente, fuera del sueño) y otro a las 03:15 (anterior, dentro del sueño). El sistema DEBERÁ usar el de las 03:15 (dentro del sueño), no el más reciente
- **Múltiples samples dentro del sueño**: El usuario duerme de 23:00 a 07:00. HealthKit tiene samples de HRV a las 01:00, 03:15 y 05:30 (todos dentro del sueño). El sistema DEBERÁ usar el de las 05:30 (el más reciente dentro de la ventana)

## Comportamiento Esperado

### Requisitos de Preservación

**Comportamientos Sin Cambios:**
- Cuando HRV y RHR tienen timestamps dentro de la ventana de sueño, el Recovery Score se calcula exactamente igual que antes (pesos: sleep=0.45, hr=0.25, hrv=0.30)
- Cuando no hay datos de sueño disponibles, el fallback existente (usar solo HR/HRV, o estimar desde actividad) se mantiene sin cambios
- El Activity Score (steps + calories) no se ve afectado por este fix
- Las funciones `normalizeHRV`, `normalizeRestingHR`, `calculateRecoveryScore`, `buildRecoveryBreakdown` no se modifican
- La redistribución de pesos via `redistributeWeights` sigue funcionando igual cuando se excluyen componentes
- Las queries de baselines (14 días) para RHR y HRV no cambian

**Alcance:**
Todos los inputs que NO involucren HRV/RHR con timestamps fuera de la ventana de sueño deben ser completamente inalterados por este fix. Esto incluye:
- Cálculos cuando HRV/RHR están dentro del sueño
- Activity Score completo
- Fallbacks sin datos de sueño
- Queries de baselines
- Queries acumulativas (steps, calories)

## Causa Raíz Hipotética

Basado en el análisis del código, las causas raíz son:

1. **`queryQuantity` descarta el timestamp**: La función (línea ~700) obtiene `sample.startDate` y lo imprime en un `print("🧪 ...")`, pero solo retorna `sample.quantity.doubleValue(for: unit)` como `Double?`. El timestamp se pierde y no puede ser validado contra la ventana de sueño.

2. **`querySleepPhases` no expone la ventana temporal**: La función calcula `sessionStart` y `sessionEnd` internamente (líneas ~640-641) pero solo retorna `(total: Double?, deep: Double?, rem: Double?)`. Los límites temporales de la sesión no están disponibles para el caller.

3. **`refreshHealthData` no valida timestamps**: La función orquestadora consume `rhr` y `hrvMs` como `Double?` directamente, sin posibilidad de verificar si pertenecen al periodo de sueño. La validación temporal simplemente no existe en el flujo actual.

4. **Diseño original asume correlación temporal**: El código original asume que el sample más reciente de HRV/RHR en las últimas 24 horas es representativo de la recuperación durante el sueño, lo cual no es correcto fisiológicamente.

## Propiedades de Correctitud

Property 1: Bug Condition - Datos de HRV/RHR fuera de la ventana de sueño se excluyen

_Para cualquier_ input donde la condición del bug se cumple (isBugCondition retorna true), es decir, donde el timestamp del sample de HRV o RHR está fuera de la ventana de sueño detectada, la función corregida `refreshHealthData` DEBERÁ tratar esa métrica como no disponible (`nil`) y excluirla del cálculo del Recovery Score, redistribuyendo los pesos entre los componentes restantes.

**Valida: Requisitos 2.1, 2.2, 2.3, 2.4, 2.5, 2.8, 2.9, 2.10**

Property 2: Preservation - Comportamiento inalterado para datos dentro del sueño y otros cálculos

_Para cualquier_ input donde la condición del bug NO se cumple (isBugCondition retorna false), es decir, donde los timestamps de HRV/RHR están dentro de la ventana de sueño, o no hay datos de sueño, o se trata del Activity Score, la función corregida DEBERÁ producir exactamente el mismo resultado que la función original, preservando todos los pesos, normalizaciones, fallbacks y cálculos existentes.

**Valida: Requisitos 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

## Implementación del Fix

### Cambios Requeridos

Asumiendo que nuestro análisis de causa raíz es correcto:

**Archivo**: `Super Fitness Coach App/Core/HealthKitManager.swift`

**Cambios Específicos**:

1. **Crear nueva función `queryQuantityInSleepWindow`**: Nueva función que consulta HealthKit con `HKObjectQueryNoLimit` (en vez de `limit: 1`), ordenado por `startDate` descendente, y filtra los samples para retornar el más reciente cuyo intervalo (`startDate`→`endDate`) se superpone con la ventana de sueño (`sleepStart`→`sleepEnd`). Retorna `(value: Double, startDate: Date, endDate: Date)?`. Si ningún sample se superpone con el sueño, retorna `nil`. La función `queryQuantity` original se mantiene sin cambios para los callers que no necesitan validación de ventana de sueño (weight, height, steps, calories).

2. **Exponer ventana de sueño en `querySleepPhases`**: Cambiar el tipo de retorno para incluir `sessionStart` y `sessionEnd`. El nuevo tipo sería `(total: Double?, deep: Double?, rem: Double?, sessionStart: Date?, sessionEnd: Date?)`. Los valores de `sessionStart`/`sessionEnd` serán `nil` cuando no hay sesión de sueño.

3. **Agregar validación temporal en `refreshHealthData(config:)`**: Después de obtener los resultados de `querySleepPhases` y ANTES de la normalización:
   - Extraer `sessionStart`/`sessionEnd` del resultado de `querySleepPhases`
   - Si hay ventana de sueño disponible, usar `queryQuantityInSleepWindow` para obtener HRV y RHR dentro del sueño (el más reciente que se superpone con la ventana)
   - Si no hay ventana de sueño, mantener el comportamiento actual con `queryQuantity` (fallback)
   - Si `queryQuantityInSleepWindow` retorna `nil` (ningún sample dentro del sueño), tratar como no disponible y redistribuir pesos
   - Registrar en logs la decisión de validación

4. **Agregar logging de validación**: Registrar via `logger.info` la ventana de sueño detectada, los timestamps de HRV/RHR encontrados, y si cada uno fue aceptado o rechazado.

## Estrategia de Testing

### Enfoque de Validación

La estrategia de testing sigue un enfoque de dos fases: primero, generar contraejemplos que demuestren el bug en el código sin corregir, luego verificar que el fix funciona correctamente y preserva el comportamiento existente.

### Exploración de la Condición del Bug

**Objetivo**: Generar contraejemplos que demuestren el bug ANTES de implementar el fix. Confirmar o refutar el análisis de causa raíz. Si refutamos, necesitaremos re-hipotizar.

**Plan de Test**: Crear mocks de HealthKit que retornen samples de HRV/RHR con timestamps específicos (dentro y fuera de la ventana de sueño). Ejecutar estos tests en el código SIN corregir para observar que el sistema usa datos de vigilia.

**Casos de Test**:
1. **HRV antes de dormir**: Simular HRV a las 21:30 con sueño de 23:00-07:00 (fallará en código sin corregir — usará el dato)
2. **RHR de la tarde**: Simular RHR a las 15:00 con sueño de 00:30-06:45 (fallará en código sin corregir — usará el dato)
3. **HRV durante el sueño**: Simular HRV a las 03:15 con sueño de 23:00-07:00 (pasará — comportamiento correcto)
4. **Sin sesión de sueño**: Simular sin datos de sueño con HRV/RHR disponibles (pasará — fallback existente)

**Contraejemplos Esperados**:
- El Recovery Score incluye HRV/RHR de vigilia cuando debería excluirlos
- Causa probable: `queryQuantity` descarta el timestamp, haciendo imposible la validación

### Verificación del Fix

**Objetivo**: Verificar que para todos los inputs donde la condición del bug se cumple, la función corregida produce el comportamiento esperado.

**Pseudocódigo:**
```
PARA TODO input DONDE isBugCondition(input) HACER
  result := refreshHealthData_fixed(input)
  ASSERT metricaFueraDelSueño NO está incluida en el cálculo del Recovery Score
  ASSERT pesos redistribuidos correctamente entre componentes restantes
FIN PARA
```

### Verificación de Preservación

**Objetivo**: Verificar que para todos los inputs donde la condición del bug NO se cumple, la función corregida produce el mismo resultado que la función original.

**Pseudocódigo:**
```
PARA TODO input DONDE NO isBugCondition(input) HACER
  ASSERT refreshHealthData_original(input) = refreshHealthData_fixed(input)
FIN PARA
```

**Enfoque de Testing**: Se recomienda property-based testing para la verificación de preservación porque:
- Genera muchos casos de test automáticamente a través del dominio de inputs
- Detecta edge cases que los unit tests manuales podrían omitir
- Provee garantías fuertes de que el comportamiento no cambia para inputs no afectados por el bug

**Plan de Test**: Observar el comportamiento en código SIN corregir primero para clicks de mouse y otras interacciones, luego escribir property-based tests capturando ese comportamiento.

**Casos de Test**:
1. **Preservación de Recovery Score con datos válidos**: Observar que con HRV/RHR dentro del sueño, el score es idéntico antes y después del fix
2. **Preservación de Activity Score**: Observar que steps/calories producen el mismo Activity Score
3. **Preservación de fallbacks**: Observar que sin datos de sueño, el fallback produce el mismo resultado
4. **Preservación de normalización**: Observar que `normalizeHRV` y `normalizeRestingHR` producen los mismos valores

### Unit Tests

- Verificar que `queryQuantity` retorna `(value, date)` en vez de solo `Double`
- Verificar que HRV fuera de la ventana de sueño se trata como `nil`
- Verificar que RHR fuera de la ventana de sueño se trata como `nil`
- Verificar que HRV/RHR dentro de la ventana de sueño se usan normalmente
- Verificar redistribución de pesos cuando se excluyen componentes
- Verificar edge case: timestamp exactamente en el límite de la ventana
- Verificar edge case: sample con superposición parcial (startDate antes del sueño, endDate dentro del sueño) se considera válido
- Verificar edge case: sample completamente antes del sueño (endDate < sleepStart) se rechaza
- Verificar edge case: sample más reciente fuera del sueño, sample anterior dentro del sueño → se usa el anterior
- Verificar edge case: múltiples samples dentro del sueño → se usa el más reciente dentro de la ventana

### Property-Based Tests

- Generar timestamps aleatorios y ventanas de sueño aleatorias, verificar que solo se incluyen datos dentro de la ventana
- Generar configuraciones aleatorias de componentes disponibles, verificar que `redistributeWeights` produce pesos que suman 1.0
- Generar inputs completos (sleep + HR + HRV todos dentro del sueño), verificar que el Recovery Score es idéntico al cálculo original

### Integration Tests

- Test de flujo completo: query de sueño → validación de timestamps → cálculo de Recovery Score con datos filtrados
- Test de transición: datos de HRV pasan de fuera a dentro del sueño entre refreshes
- Test de logging: verificar que los logs de validación se emiten correctamente con la información esperada
