# Documento de Requisitos: Smart Fitness Coach

## Introducción

Este documento define los requisitos para la refactorización completa del sistema de puntuación de fitness y la integración con HealthKit en la app "Tu Coach Inteligente". El sistema actual tiene 11 problemas críticos: valores hardcodeados en los objetivos (8h sueño, 10k pasos, 500 kcal), cálculo incorrecto de frecuencia cardíaca en reposo, mezcla de métricas de recuperación y actividad en un solo score, flujo de autorización de HealthKit roto, defaults falsos que enmascaran ausencia de datos, falta de perfil de fitness del usuario, ausencia de HRV, scoring de sueño incompleto, manejo incorrecto de datos vacíos, score no explicable, y código muerto en la verificación de autorización. La refactorización busca crear un sistema de scoring competitivo y serio, comparable a Whoop/Oura, con scores separados de recuperación y actividad, soporte de HRV, metas personalizadas, y transparencia total en el cálculo.

## Glosario

- **HealthKit_Manager**: El módulo responsable de leer datos de salud de Apple HealthKit, gestionar autorización, y calcular scores de recuperación y actividad
- **UserProfile**: El modelo de datos persistido con SwiftData que almacena nombre, meta de fitness, métricas corporales, y metas personalizadas del usuario
- **FitnessConfig**: La estructura dentro de UserProfile que contiene las metas personalizadas del usuario: sleepGoalHours, stepsGoal, calorieGoal, baselineRestingHR, y fitnessLevel
- **Recovery_Score**: Un valor numérico de 0 a 100 calculado a partir de calidad de sueño, frecuencia cardíaca en reposo, y variabilidad de frecuencia cardíaca (HRV), representando la recuperación física del usuario
- **Activity_Score**: Un valor numérico de 0 a 100 calculado a partir de pasos y calorías activas, representando el nivel de actividad física del día
- **HRV**: Heart Rate Variability (Variabilidad de Frecuencia Cardíaca), medida en milisegundos mediante HKQuantityType heartRateVariabilitySDNN de HealthKit
- **Sleep_Quality_Score**: Un sub-score de 0 a 100 que pondera la duración total del sueño y la distribución de fases (deep, REM, core) en lugar de usar solo duración
- **Score_Breakdown**: Una estructura que contiene el valor de cada componente individual del score junto con su contribución al score final, permitiendo explicar al usuario qué subió o bajó su puntuación
- **HealthData_Status**: Un enum que distingue entre dato real obtenido de HealthKit (.available), dato no disponible (.unavailable), y dato pendiente de carga (.loading), eliminando el uso de valores por defecto que enmascaran ausencia de datos
- **Authorization_Status**: Un enum que representa el estado real de autorización de HealthKit: .notDetermined, .authorized, .denied, .unavailable
- **Workout_Engine**: El módulo responsable de generar planes semanales y ajustar entrenamientos diarios basándose en Recovery_Score y Activity_Score
- **Dashboard**: La pantalla principal que muestra Recovery_Score, Activity_Score, indicadores de estado, y desglose de componentes

## Requisitos

### Requisito 1: Perfil de Fitness del Usuario (FitnessConfig)

**User Story:** Como usuario, quiero configurar mis metas personales de fitness (horas de sueño, pasos, calorías, frecuencia cardíaca base), para que el sistema de scoring se adapte a mi nivel y objetivos individuales.

#### Criterios de Aceptación

1. THE UserProfile SHALL contener una estructura FitnessConfig con las propiedades: sleepGoalHours (Double), stepsGoal (Double), calorieGoal (Double), baselineRestingHR (Double), y fitnessLevel (enum: beginner, intermediate, advanced).
2. WHEN el usuario no ha configurado FitnessConfig, THE App SHALL asignar valores iniciales basados en estándares de salud generales: sleepGoalHours = 8.0, stepsGoal = 10000, calorieGoal = 500, baselineRestingHR = 70, fitnessLevel = .beginner.
3. WHEN el usuario edita su FitnessConfig desde la pantalla de Profile, THE App SHALL persistir los cambios en SwiftData y recalcular inmediatamente Recovery_Score y Activity_Score con las nuevas metas.
4. THE App SHALL validar que sleepGoalHours esté entre 4.0 y 12.0, stepsGoal entre 1000 y 50000, calorieGoal entre 100 y 2000, y baselineRestingHR entre 35 y 120.
5. WHEN el usuario cambia su fitnessLevel, THE Workout_Engine SHALL ajustar la intensidad del plan semanal de acuerdo al nuevo nivel.

### Requisito 2: Separación de Recovery Score y Activity Score

**User Story:** Como usuario, quiero ver mi recuperación y mi actividad como scores independientes, para entender claramente si estoy descansado y cuánto me he movido hoy.

#### Criterios de Aceptación

1. THE HealthKit_Manager SHALL calcular Recovery_Score usando la fórmula: recoveryScore = (sleepQualityScore × 0.45) + (restingHRScore × 0.25) + (hrvScore × 0.30), donde cada componente está normalizado a una escala de 0 a 100.
2. THE HealthKit_Manager SHALL calcular Activity_Score usando la fórmula: activityScore = (stepsScore × 0.50) + (caloriesScore × 0.50), donde cada componente está normalizado a una escala de 0 a 100.
3. THE Dashboard SHALL mostrar Recovery_Score y Activity_Score como dos valores numéricos separados y visualmente diferenciados.
4. WHEN el Recovery_Score se calcula, THE HealthKit_Manager SHALL usar las metas del FitnessConfig del usuario (sleepGoalHours, baselineRestingHR) en lugar de valores hardcodeados para la normalización.
5. WHEN el Activity_Score se calcula, THE HealthKit_Manager SHALL usar las metas del FitnessConfig del usuario (stepsGoal, calorieGoal) en lugar de valores hardcodeados para la normalización.
6. THE HealthKit_Manager SHALL exponer una función estática pura calculateRecoveryScore(sleepQualityScore:restingHRScore:hrvScore:) que retorne un Int entre 0 y 100.
7. THE HealthKit_Manager SHALL exponer una función estática pura calculateActivityScore(stepsScore:caloriesScore:) que retorne un Int entre 0 y 100.

### Requisito 3: Soporte de HRV (Heart Rate Variability)

**User Story:** Como usuario, quiero que mi variabilidad de frecuencia cardíaca se incluya en el cálculo de recuperación, para tener una medición de recuperación precisa y comparable a dispositivos como Whoop y Oura.

#### Criterios de Aceptación

1. THE HealthKit_Manager SHALL solicitar autorización de lectura para HKQuantityType(.heartRateVariabilitySDNN) además de los tipos existentes.
2. WHEN datos de HRV están disponibles en HealthKit, THE HealthKit_Manager SHALL consultar la muestra más reciente de heartRateVariabilitySDNN de las últimas 24 horas.
3. THE HealthKit_Manager SHALL normalizar el valor de HRV a una escala de 0 a 100, donde un HRV de 20ms o menor mapea a 0 y un HRV de 100ms o mayor mapea a 100, usando interpolación lineal.
4. IF datos de HRV no están disponibles, THEN THE HealthKit_Manager SHALL marcar el componente HRV como HealthData_Status.unavailable y calcular Recovery_Score redistribuyendo los pesos: sleepQualityScore × 0.60 + restingHRScore × 0.40.
5. THE Score_Breakdown SHALL incluir el valor de HRV en milisegundos y su score normalizado cuando el dato esté disponible.

### Requisito 4: Cálculo Correcto de Frecuencia Cardíaca en Reposo

**User Story:** Como usuario, quiero que mi frecuencia cardíaca en reposo se evalúe contra mi baseline personal, para que el score refleje mi condición real y no una escala arbitraria.

#### Criterios de Aceptación

1. THE HealthKit_Manager SHALL calcular restingHRScore usando un enfoque basado en porcentaje: `percentageChange = (actualRestingHR - baselineRestingHR) / baselineRestingHR`, luego `restingHRScore = clamp(0, 100, 100 - (percentageChange × 100 × factor))`, donde `factor = 2.5` y `baselineRestingHR` proviene del FitnessConfig del usuario.
2. WHEN actualRestingHR es igual a baselineRestingHR, THE HealthKit_Manager SHALL asignar un restingHRScore de 100.
3. WHEN actualRestingHR es igual o mayor que baselineRestingHR × 1.40 (40% sobre baseline), THE HealthKit_Manager SHALL asignar un restingHRScore de 0.
4. WHEN actualRestingHR es menor que baselineRestingHR (mejor recuperación), THE HealthKit_Manager SHALL asignar un restingHRScore mayor a 100 clampeado a 100.
5. THE HealthKit_Manager SHALL exponer una función estática pura normalizeRestingHR(actual:baseline:) que retorne un Double entre 0 y 100.

### Requisito 5: Calidad de Sueño Ponderada

**User Story:** Como usuario, quiero que mi score de sueño considere la calidad de las fases (deep, REM, core) y no solo la duración total, para tener una evaluación más precisa de mi descanso.

#### Criterios de Aceptación

1. THE HealthKit_Manager SHALL calcular Sleep_Quality_Score como: sleepQualityScore = (durationScore × 0.50) + (deepScore × 0.25) + (remScore × 0.25).
2. THE HealthKit_Manager SHALL calcular durationScore normalizando las horas totales de sueño contra sleepGoalHours del FitnessConfig del usuario: `durationScore = clamp(0, 100, sleepHours / userSleepGoal × 100)`.
3. THE HealthKit_Manager SHALL calcular deepScore usando el porcentaje de sueño profundo respecto al total: `deepPercentage = deepHours / totalSleepHours`, `deepScore = clamp(0, 100, deepPercentage / expectedDeepPercentage × 100)`, donde `expectedDeepPercentage = 0.175` (17.5%, punto medio del rango 15-20%).
4. THE HealthKit_Manager SHALL calcular remScore usando el porcentaje de sueño REM respecto al total: `remPercentage = remHours / totalSleepHours`, `remScore = clamp(0, 100, remPercentage / expectedREMPercentage × 100)`, donde `expectedREMPercentage = 0.225` (22.5%, punto medio del rango 20-25%).
5. IF los datos de fases de sueño (deep, REM) no están disponibles pero la duración total sí lo está, THEN THE HealthKit_Manager SHALL calcular Sleep_Quality_Score usando solo durationScore con peso 1.0.
6. THE HealthKit_Manager SHALL exponer una función estática pura calculateSleepQualityScore(totalHours:deepHours:remHours:sleepGoal:) que retorne un Double entre 0 y 100.
7. FOR ALL combinaciones válidas de horas de sueño, calcular el Sleep_Quality_Score y luego recalcularlo con los mismos inputs SHALL producir el mismo resultado (propiedad de idempotencia).

### Requisito 6: Flujo de Autorización Real de HealthKit

**User Story:** Como usuario, quiero que la app verifique correctamente si tiene permisos de HealthKit, para que no muestre datos falsos cuando no tiene acceso real a mis datos de salud.

#### Criterios de Aceptación

1. THE HealthKit_Manager SHALL representar el estado de autorización usando Authorization_Status con los valores: .notDetermined, .authorized, .denied, .unavailable.
2. WHEN la App se inicia, THE HealthKit_Manager SHALL verificar el estado de autorización intentando una query de prueba a HealthKit en lugar de asumir isAuthorized = true.
3. WHEN la query de prueba retorna datos o un conjunto vacío sin error, THE HealthKit_Manager SHALL establecer Authorization_Status como .authorized.
4. WHEN la query de prueba falla con un error de autorización, THE HealthKit_Manager SHALL establecer Authorization_Status como .denied.
5. WHEN HKHealthStore.isHealthDataAvailable() retorna false, THE HealthKit_Manager SHALL establecer Authorization_Status como .unavailable.
6. THE HealthKit_Manager SHALL eliminar el método checkExistingAuthorization() actual que establece isAuthorized = true incondicionalmente.
7. WHILE Authorization_Status es .denied o .unavailable, THE Dashboard SHALL mostrar un indicador visual informando al usuario que los datos de salud no están disponibles y que los scores se basan en datos limitados.

### Requisito 7: Manejo Correcto de Datos Ausentes

**User Story:** Como usuario, quiero saber si los valores que veo son datos reales de mis sensores o valores por defecto, para confiar en la información que la app me muestra.

#### Criterios de Aceptación

1. THE HealthKit_Manager SHALL representar cada métrica de salud usando HealthData_Status con los valores: .available(Double) para datos reales, .unavailable para datos no obtenidos, y .loading para datos en proceso de carga.
2. WHEN una query de HealthKit retorna nil, THE HealthKit_Manager SHALL asignar HealthData_Status.unavailable a esa métrica en lugar de usar un valor numérico por defecto (0 para sueño, 70 para HR, etc.).
3. WHEN una métrica tiene estado .unavailable, THE Dashboard SHALL mostrar un indicador visual (por ejemplo, "--" o "Sin datos") en lugar de un número que el usuario podría confundir con un dato real.
4. WHEN se calcula Recovery_Score o Activity_Score, THE HealthKit_Manager SHALL excluir los componentes con estado .unavailable y redistribuir los pesos proporcionalmente entre los componentes disponibles.
5. IF todos los componentes de un score tienen estado .unavailable, THEN THE HealthKit_Manager SHALL retornar el score como HealthData_Status.unavailable en lugar de un valor numérico por defecto.
6. THE HealthKit_Manager SHALL exponer una función estática pura redistributeWeights(availableComponents:originalWeights:) que retorne los pesos ajustados sumando 1.0.

### Requisito 8: Score Explicable (Score Breakdown)

**User Story:** Como usuario, quiero entender qué factores subieron o bajaron mi score de recuperación y actividad, para saber qué mejorar en mi rutina diaria.

#### Criterios de Aceptación

1. THE HealthKit_Manager SHALL generar un Score_Breakdown para cada score calculado, conteniendo: el nombre del componente, el valor raw de la métrica, el score normalizado (0-100), el peso aplicado, y la contribución final al score total.
2. THE Dashboard SHALL mostrar el Score_Breakdown de Recovery_Score con los componentes: Sleep Quality (horas + fases), Resting HR (bpm), y HRV (ms) cuando estén disponibles.
3. THE Dashboard SHALL mostrar el Score_Breakdown de Activity_Score con los componentes: Steps (conteo) y Active Calories (kcal).
4. WHEN un componente del score tiene un valor normalizado menor a 40, THE Dashboard SHALL resaltar ese componente como área de mejora con un indicador visual (por ejemplo, color rojo o ícono de advertencia).
5. THE Score_Breakdown SHALL incluir un texto descriptivo corto para cada componente (por ejemplo, "Dormiste 6.2h de tu meta de 8h", "Tu HR en reposo fue 62 bpm, 8 bpm sobre tu baseline").

### Requisito 9: Integración de Scores con Workout Engine

**User Story:** Como usuario, quiero que mis entrenamientos se ajusten basándose en mi recuperación real (no en un score genérico mezclado), para entrenar de forma segura y efectiva.

#### Criterios de Aceptación

1. WHEN el Workout_Engine evalúa el ajuste diario, THE Workout_Engine SHALL usar Recovery_Score (no el score combinado anterior) para determinar la acción de ajuste.
2. WHEN Recovery_Score es menor a 40 y el entrenamiento programado es de fuerza, THE Workout_Engine SHALL reemplazar el entrenamiento con "Light Cardio" o "Rest".
3. WHEN Recovery_Score está entre 40 y 69 y el entrenamiento programado es de fuerza, THE Workout_Engine SHALL reducir los sets de cada ejercicio en uno.
4. WHEN Recovery_Score es 70 o mayor, THE Workout_Engine SHALL presentar el entrenamiento programado a intensidad completa.
5. THE AI_Coach SHALL usar tanto Recovery_Score como Activity_Score para generar mensajes de recomendación contextuales (por ejemplo, "Tu recuperación es baja pero ayer caminaste mucho, hoy descansa 💤").

### Requisito 10: Normalización Basada en Metas del Usuario

**User Story:** Como usuario, quiero que mis scores se calculen contra mis propias metas y no contra valores genéricos, para que el sistema refleje mi progreso personal.

#### Criterios de Aceptación

1. THE HealthKit_Manager SHALL normalizar stepsScore usando la fórmula: stepsScore = clamp(0, 100, actualSteps / stepsGoal × 100), donde stepsGoal proviene del FitnessConfig del usuario.
2. THE HealthKit_Manager SHALL normalizar caloriesScore usando la fórmula: caloriesScore = clamp(0, 100, actualCalories / calorieGoal × 100), donde calorieGoal proviene del FitnessConfig del usuario.
3. THE HealthKit_Manager SHALL normalizar durationScore usando la fórmula: durationScore = clamp(0, 100, actualSleepHours / sleepGoalHours × 100), donde sleepGoalHours proviene del FitnessConfig del usuario.
4. THE HealthKit_Manager SHALL exponer funciones estáticas puras para cada normalización: normalizeSteps(actual:goal:), normalizeCalories(actual:goal:), normalizeSleepDuration(actual:goal:), cada una retornando un Double entre 0 y 100.
5. FOR ALL valores positivos de meta y valor actual, las funciones de normalización SHALL retornar un valor entre 0.0 y 100.0 inclusive (propiedad de rango acotado).
6. FOR ALL valores de meta positivos, normalizar un valor actual igual a la meta SHALL retornar exactamente 100.0 (propiedad de identidad en la meta).

