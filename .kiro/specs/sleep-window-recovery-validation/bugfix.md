# Documento de Requisitos del Bugfix

## Introducción

El Recovery Score se calcula usando valores de HRV (`heartRateVariabilitySDNN`) y Resting HR (`restingHeartRate`) que pueden provenir de cualquier momento de las últimas 24 horas, sin validar si fueron registrados durante el periodo de sueño detectado. Esto contamina el score de recuperación porque mezcla estados fisiológicos distintos (reposo nocturno vs vigilia diurna), produciendo un indicador que no refleja la recuperación real del usuario durante el descanso.

El método `queryQuantity` actualmente retorna solo `Double?` (el valor de la métrica) sin incluir el timestamp del sample, lo que hace imposible validar si el dato pertenece al periodo de sueño. Mientras tanto, `querySleepPhases` ya detecta correctamente el rango de sueño (`sessionStart` → `sessionEnd`), pero esta información no se utiliza para filtrar los datos de HRV y RHR.

## Análisis del Bug

### Comportamiento Actual (Defecto)

1.1 CUANDO `queryQuantity` obtiene un valor de HRV cuyo timestamp está fuera del rango de sueño detectado (ej. 21:30, antes de dormir) ENTONCES el sistema lo usa igualmente para calcular el Recovery Score

1.2 CUANDO `queryQuantity` obtiene un valor de Resting HR cuyo timestamp está fuera del rango de sueño detectado (ej. durante la tarde del día anterior) ENTONCES el sistema lo usa igualmente para calcular el Recovery Score

1.3 CUANDO `queryQuantity` retorna un valor de HRV o RHR ENTONCES el sistema solo retorna `Double?` sin el `startDate` del sample, haciendo imposible la validación temporal

1.4 CUANDO el Recovery Score se calcula con datos de HRV/RHR fuera del sueño ENTONCES el score no representa la recuperación fisiológica real durante el descanso

### Comportamiento Esperado (Correcto)

2.1 CUANDO se obtiene un valor de HRV cuyo timestamp está dentro del rango de sueño detectado (`sleepStart` → `sleepEnd`) ENTONCES el sistema DEBERÁ usarlo para calcular el Recovery Score

2.2 CUANDO se obtiene un valor de HRV cuyo timestamp está fuera del rango de sueño detectado ENTONCES el sistema DEBERÁ ignorarlo y tratar HRV como no disponible para el cálculo

2.3 CUANDO se obtiene un valor de Resting HR cuyo timestamp está dentro del rango de sueño detectado (`sleepStart` → `sleepEnd`) ENTONCES el sistema DEBERÁ usarlo para calcular el Recovery Score

2.4 CUANDO se obtiene un valor de Resting HR cuyo timestamp está fuera del rango de sueño detectado ENTONCES el sistema DEBERÁ ignorarlo y tratar RHR como no disponible para el cálculo

2.5 CUANDO HRV o RHR no tienen datos válidos dentro del periodo de sueño ENTONCES el sistema DEBERÁ redistribuir los pesos usando la lógica existente de `redistributeWeights` (excluyendo el componente sin datos)

2.6 CUANDO se realiza la validación de HRV y RHR contra el periodo de sueño ENTONCES el sistema DEBERÁ registrar en logs: la ventana de sueño (`sleepStart` → `sleepEnd`), los timestamps de los samples de HRV/RHR, y si cada uno está dentro o fuera del periodo de sueño

2.7 CUANDO `queryQuantity` retorna un valor ENTONCES el sistema DEBERÁ retornar tanto el valor (`Double`) como el `startDate` y `endDate` del sample para permitir la validación temporal y la detección de superposición parcial

2.8 CUANDO un sample de HRV o RHR tiene un rango temporal (`startDate` → `endDate`) que se superpone parcialmente con el periodo de sueño ENTONCES el sistema DEBERÁ considerarlo válido si al menos una parte del intervalo del sample cae dentro del rango de sueño (`sleepStart` → `sleepEnd`)

2.9 CUANDO el sample más reciente de HRV o RHR está fuera de la ventana de sueño, pero existe un sample anterior dentro de la ventana ENTONCES el sistema DEBERÁ usar el sample dentro del sueño (no el más reciente)

2.10 CUANDO existen múltiples samples de HRV o RHR dentro de la ventana de sueño ENTONCES el sistema DEBERÁ usar el más reciente de los que están dentro de la ventana

### Comportamiento Sin Cambios (Prevención de Regresión)

3.1 CUANDO HRV tiene un timestamp dentro del rango de sueño ENTONCES el sistema DEBERÁ CONTINUAR calculando el Recovery Score usando HRV con su peso original (0.30)

3.2 CUANDO Resting HR tiene un timestamp dentro del rango de sueño ENTONCES el sistema DEBERÁ CONTINUAR calculando el Recovery Score usando RHR con su peso original (0.25)

3.3 CUANDO no hay datos de sueño disponibles ENTONCES el sistema DEBERÁ CONTINUAR con el fallback existente (usar solo HR/HRV, o estimar desde actividad)

3.4 CUANDO se calcula el Activity Score ENTONCES el sistema DEBERÁ CONTINUAR calculándolo sin cambios (steps y calories no requieren validación de ventana de sueño)

3.5 CUANDO todos los componentes (sleep, HR, HRV) están disponibles y dentro del sueño ENTONCES el sistema DEBERÁ CONTINUAR usando los pesos originales: sleep=0.45, hr=0.25, hrv=0.30

3.6 CUANDO se normalizan los valores de HRV y RHR ENTONCES el sistema DEBERÁ CONTINUAR usando las funciones `normalizeHRV` y `normalizeRestingHR` sin modificaciones

3.7 CUANDO se construye el breakdown de recuperación ENTONCES el sistema DEBERÁ CONTINUAR usando `buildRecoveryBreakdown` con la misma estructura de `ScoreBreakdown`
