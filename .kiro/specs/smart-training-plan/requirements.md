# Documento de Requisitos — Smart Training Plan

## Introducción

Sistema inteligente de generación y ejecución de planes de entrenamiento para la Super Fitness Coach App. El usuario configura sus preferencias de entrenamiento (objetivo, días disponibles, nivel, músculos prioritarios, cardio, duración) y la aplicación genera automáticamente un plan de 4-8 semanas con progresión semanal, ajuste diario basado en recuperación, registro de sets, seguimiento de progreso, gestión de días y gamificación.

## Glosario

- **Training_Plan_Generator**: Motor principal que genera el plan de entrenamiento completo (semanas, días, ejercicios) a partir de las preferencias del usuario.
- **Training_Preferences**: Conjunto de datos de entrada del onboarding: objetivo, días por semana, nivel de experiencia, músculos prioritarios, preferencia de cardio y duración del plan.
- **Weekly_Progression_Engine**: Componente que calcula los multiplicadores de peso y volumen para cada semana del plan según la semana actual dentro del ciclo de 4 semanas.
- **Recovery_Adapter**: Componente que ajusta peso sugerido y número de sets de la sesión diaria según el recoveryScore del usuario.
- **Workout_Executor**: Pantalla y lógica de ejecución de un workout diario, mostrando ejercicios con campos de peso/reps y temporizador de descanso.
- **Set_Logger**: Componente de registro de sets individuales (peso, repeticiones) con persistencia por ejercicio.
- **Progress_Tracker**: Componente que calcula y muestra el estado de progreso (mejorando, estable, declinando) comparando métricas actuales vs anteriores.
- **Day_Manager**: Componente que gestiona las acciones sobre un día del plan: completar, saltar o reprogramar.
- **Gamification_Module**: Extensión del GamificationEngine existente para otorgar puntos y bonificaciones por entrenamientos completados y rachas.
- **Feedback_View**: Vista post-entrenamiento que muestra mejoras de peso, días consecutivos y progreso positivo.
- **MuscleGroup**: Enumeración de grupos musculares disponibles (chest, back, shoulders, biceps, triceps, quads, hamstrings, glutes, calves, core).
- **MusclePriority**: `enum MusclePriority { case primary, case secondary }`. Clasifica los grupos musculares: primary (chest, back, legs) y secondary (shoulders, biceps, triceps, calves, core, etc.).
- **DayStatus**: `enum DayStatus { case pending, case completed, case skipped, case rescheduled }`. Enumeración de estados de un día del plan.
- **PlanStatus**: `enum PlanStatus { case active, case completed, case paused }`. Enumeración de estados del plan de entrenamiento.
- **DayPlan**: Estructura que representa un día dentro del plan semanal, incluyendo grupo(s) muscular(es) asignado(s) y ejercicios.
- **WorkoutLog**: Modelo de persistencia que almacena el registro de un entrenamiento: exerciseId, fecha, sets con peso/reps, y notas opcionales.
- **SetLog**: Registro individual de un set: peso utilizado y repeticiones completadas.
- **ProgressStatus**: Enumeración con tres estados: improving (🔼), stable (➖), declining (🔽).
- **RecoveryScore**: Puntuación de recuperación (0-100) obtenida del HealthKitManager existente.
- **currentWeek**: `currentWeek: Int` — Identificador de la semana actual del plan, utilizado por el Weekly_Progression_Engine para el cálculo de progresión.
- **exerciseId**: Identificador único de un ejercicio, utilizado por el Progress_Tracker para garantizar la comparación entre el mismo ejercicio a lo largo de sesiones.

## Requisitos

### Requisito 1: Captura de Preferencias de Entrenamiento (Onboarding)

**Historia de Usuario:** Como usuario, quiero configurar mis preferencias de entrenamiento, para que la app genere un plan personalizado a mi medida.

#### Criterios de Aceptación

1. THE Training_Preferences SHALL presentar los campos: goal (FitnessGoal), trainingDaysPerWeek (Int, rango 3...6), experienceLevel (FitnessLevel), priorityMuscles ([MuscleGroup], máximo 2), wantsCardio (Bool) y planDurationWeeks (Int, valores 4, 6 u 8).
2. THE Training_Preferences SHALL requerir como mínimo la selección de goal y trainingDaysPerWeek para proceder.
3. WHEN el usuario selecciona más de 2 elementos en priorityMuscles, THE Training_Preferences SHALL impedir la selección adicional y mostrar un mensaje indicando el límite de 2 músculos prioritarios.
4. WHEN el usuario no selecciona ningún valor en priorityMuscles, THE Training_Plan_Generator SHALL aplicar una distribución balanceada de grupos musculares.
5. WHEN el usuario no selecciona un valor en planDurationWeeks, THE Training_Preferences SHALL asignar el valor por defecto de 4 semanas.

### Requisito 2: Cálculo de Frecuencia Muscular

**Historia de Usuario:** Como usuario, quiero que el plan distribuya la frecuencia de cada grupo muscular según mis días disponibles y prioridades, para que los músculos que me importan reciban más atención.

#### Criterios de Aceptación

1. WHEN trainingDaysPerWeek es mayor o igual a 4, THE Training_Plan_Generator SHALL asignar frecuencia 2 a los grupos musculares principales y frecuencia 1 a los secundarios.
2. WHEN trainingDaysPerWeek es menor a 4, THE Training_Plan_Generator SHALL asignar frecuencia 1 a todos los grupos musculares.
3. WHEN el usuario ha seleccionado priorityMuscles, THE Training_Plan_Generator SHALL incrementar en 1 la frecuencia de cada grupo muscular prioritario, sin exceder una frecuencia máxima de 3.
4. THE Training_Plan_Generator SHALL producir un diccionario [MuscleGroup: Int] que represente la frecuencia semanal de cada grupo muscular.
5. THE Training_Plan_Generator SHALL validar que la frecuencia muscular total pueda distribuirse dentro de trainingDaysPerWeek; de lo contrario, THE Training_Plan_Generator SHALL normalizar las frecuencias proporcionalmente.
6. THE Training_Plan_Generator SHALL clasificar chest, back y legs como grupos musculares primary según MusclePriority.

### Requisito 3: Generación del Split Semanal

**Historia de Usuario:** Como usuario, quiero que el plan organice los días de entrenamiento de forma inteligente, para evitar sobrecargar el mismo músculo en días consecutivos.

#### Criterios de Aceptación

1. THE Training_Plan_Generator SHALL generar un arreglo de DayPlan con longitud igual a trainingDaysPerWeek.
2. THE Training_Plan_Generator SHALL asignar un máximo de 2 grupos musculares por día de entrenamiento.
3. THE Training_Plan_Generator SHALL garantizar que un mismo grupo muscular principal no se repita en días consecutivos de entrenamiento.
4. THE Training_Plan_Generator SHALL distribuir la carga de forma equilibrada entre los días disponibles.
5. THE Training_Plan_Generator SHALL asignar días de descanso automáticamente cuando trainingDaysPerWeek sea menor a 7, distribuyéndolos de forma equilibrada a lo largo de la semana.

### Requisito 4: Asignación de Ejercicios

**Historia de Usuario:** Como usuario, quiero que cada día de entrenamiento tenga ejercicios apropiados para los grupos musculares asignados, para tener una rutina completa y efectiva.

#### Criterios de Aceptación

1. THE Training_Plan_Generator SHALL asignar entre 4 y 6 ejercicios por día de entrenamiento.
2. THE Training_Plan_Generator SHALL incluir al menos 1 ejercicio compuesto obligatorio por cada grupo muscular principal del día.
3. THE Training_Plan_Generator SHALL completar los ejercicios restantes del día con ejercicios accesorios del grupo muscular correspondiente.
4. WHEN wantsCardio es true, THE Training_Plan_Generator SHALL incluir al menos un día con ejercicios de tipo cardio en el split semanal.
5. THE Training_Plan_Generator SHALL ordenar los ejercicios colocando los ejercicios compuestos primero, seguidos de los ejercicios accesorios.
6. THE Training_Plan_Generator SHALL asignar valores por defecto de 3 sets y 8–12 repeticiones por ejercicio, a menos que sean modificados por progresión o recuperación.
7. THE Training_Plan_Generator SHALL inicializar el peso sugerido basándose en datos previos de WorkoutLog cuando estén disponibles; de lo contrario, SHALL utilizar un peso base por defecto para cada ejercicio definido mediante valores estáticos predefinidos.

### Requisito 5: Progresión Semanal

**Historia de Usuario:** Como usuario, quiero que el plan incremente la intensidad progresivamente cada semana, para que mi cuerpo se adapte y mejore de forma segura.

#### Criterios de Aceptación

1. THE Weekly_Progression_Engine SHALL aplicar los multiplicadores base (weightMultiplier: 1.0, volumeMultiplier: 1.0) durante la semana 1 de cada ciclo de 4 semanas.
2. THE Weekly_Progression_Engine SHALL aplicar un incremento de peso del 5% (weightMultiplier: 1.05) durante la semana 2 de cada ciclo.
3. THE Weekly_Progression_Engine SHALL establecer volumeMultiplier = 1.1 durante la semana 3 de cada ciclo.
4. THE Weekly_Progression_Engine SHALL aplicar una semana de descarga (deload) con multiplicadores reducidos durante la semana 4 de cada ciclo.
5. WHEN el plan tiene duración de 6 u 8 semanas, THE Weekly_Progression_Engine SHALL repetir el ciclo de 4 semanas para las semanas restantes.
6. THE Weekly_Progression_Engine SHALL mantener un campo currentWeek (Int) que represente la semana actual del plan para el cálculo de progresión.

### Requisito 6: Adaptación Diaria por Recuperación

**Historia de Usuario:** Como usuario, quiero que la app ajuste la intensidad de mi entrenamiento diario según mi nivel de recuperación, para evitar lesiones y optimizar resultados.

#### Criterios de Aceptación

1. WHEN el recoveryScore es mayor o igual a 80, THE Recovery_Adapter SHALL multiplicar el peso sugerido por 1.05.
2. WHEN el recoveryScore está entre 50 y 79 (inclusive), THE Recovery_Adapter SHALL mantener el peso y sets sugeridos sin modificación.
3. WHEN el recoveryScore es menor a 50, THE Recovery_Adapter SHALL multiplicar el peso sugerido por 0.85 y reducir en 1 el número de sets de cada ejercicio.
4. THE Recovery_Adapter SHALL garantizar un mínimo de 1 set por ejercicio después de cualquier ajuste.
5. THE Recovery_Adapter SHALL modificar únicamente el peso sugerido y el número de sets, sin cambiar los ejercicios asignados al día.

### Requisito 7: Ejecución del Entrenamiento

**Historia de Usuario:** Como usuario, quiero ejecutar mi entrenamiento diario con una interfaz clara que me guíe ejercicio por ejercicio, para concentrarme en el entrenamiento sin distracciones.

#### Criterios de Aceptación

1. THE Workout_Executor SHALL mostrar una pantalla por ejercicio con los campos de peso y repeticiones para cada set.
2. THE Workout_Executor SHALL mostrar un indicador de completado (checkmark) por cada set.
3. WHEN el usuario marca un set como completado, THE Workout_Executor SHALL iniciar un temporizador de descanso de 60 segundos.
4. THE Workout_Executor SHALL mostrar el temporizador de descanso como no editable en esta versión (MVP).
5. WHEN todos los sets de un ejercicio están completados, THE Workout_Executor SHALL avanzar automáticamente al siguiente ejercicio.
6. WHEN el usuario navega fuera del ejercicio, THE Workout_Executor SHALL detener el temporizador de descanso activo.

### Requisito 8: Registro de Sets

**Historia de Usuario:** Como usuario, quiero registrar el peso y las repeticiones de cada set individualmente, para tener un historial detallado de mi rendimiento.

#### Criterios de Aceptación

1. THE Set_Logger SHALL persistir cada set de forma individual con los campos: peso utilizado y repeticiones completadas.
2. THE Set_Logger SHALL permitir la edición de peso y repeticiones de un set antes de que el usuario finalice el ejercicio.
3. THE Set_Logger SHALL almacenar el registro completo en un WorkoutLog con los campos: exerciseId, date, sets ([SetLog]) y notes (String opcional).
4. WHEN el usuario ingresa una nota opcional, THE Set_Logger SHALL almacenar la nota asociada al WorkoutLog del ejercicio.

### Requisito 9: Seguimiento de Progreso

**Historia de Usuario:** Como usuario, quiero ver si estoy mejorando, manteniéndome o declinando en mis métricas de entrenamiento, para ajustar mi esfuerzo.

#### Criterios de Aceptación

1. THE Progress_Tracker SHALL calcular las métricas: peso máximo levantado, repeticiones máximas y volumen total (peso × repeticiones × sets) por ejercicio.
2. THE Progress_Tracker SHALL identificar ejercicios mediante un exerciseId único para garantizar que la comparación se realice entre el mismo ejercicio a lo largo de las sesiones.
3. THE Progress_Tracker SHALL comparar las métricas del entrenamiento actual con las del entrenamiento anterior del mismo ejercicio utilizando exerciseId.
4. WHEN las métricas actuales superan a las anteriores, THE Progress_Tracker SHALL retornar el estado improving (🔼).
5. WHEN las métricas actuales son equivalentes a las anteriores (diferencia menor al 5%), THE Progress_Tracker SHALL retornar el estado stable (➖).
6. WHEN las métricas actuales son inferiores a las anteriores, THE Progress_Tracker SHALL retornar el estado declining (🔽).
7. IF no existe un WorkoutLog previo para un ejercicio, THEN THE Progress_Tracker SHALL establecer ProgressStatus como stable por defecto.

### Requisito 10: Gestión de Días

**Historia de Usuario:** Como usuario, quiero poder completar, saltar o reprogramar un día de entrenamiento, para adaptar el plan a mi vida real sin perder el progreso.

#### Criterios de Aceptación

1. THE Day_Manager SHALL ofrecer las acciones: Completar, Saltar y Reprogramar para cada día del plan.
2. WHEN el usuario selecciona Saltar, THE Day_Manager SHALL marcar el día con estado skipped (DayStatus) sin eliminar el día del plan ni modificar los días restantes.
3. WHEN el usuario selecciona Reprogramar, THE Day_Manager SHALL marcar el día con estado rescheduled (DayStatus) y mover el entrenamiento del día al siguiente día disponible en el plan.
4. THE Day_Manager SHALL considerar un día como "disponible" cuando no tiene sesión de entrenamiento asignada y su DayStatus es pending.
5. IF no existe un día disponible para reprogramar, THEN THE Day_Manager SHALL informar al usuario que no hay días disponibles y mantener el día en su posición original.
6. THE Day_Manager SHALL limitar la reprogramación de un entrenamiento a una vez por día.
7. WHEN el usuario completa un día, THE Day_Manager SHALL marcar el día con estado completed (DayStatus).
8. THE Day_Manager SHALL inicializar cada día del plan con estado pending (DayStatus).
9. THE Day_Manager SHALL preservar el número total de sesiones de entrenamiento por semana al reprogramar un día.
10. IF el usuario salta 3 días consecutivos, THEN el sistema SHALL disparar un mensaje de re-engagement.

### Requisito 11: Gamificación

**Historia de Usuario:** Como usuario, quiero recibir puntos y bonificaciones por completar entrenamientos y mantener rachas, para sentirme motivado a seguir el plan.

#### Criterios de Aceptación

1. WHEN el usuario completa un entrenamiento del plan, THE Gamification_Module SHALL otorgar 100 puntos al usuario.
2. WHEN el usuario acumula una racha de 3 o más días consecutivos de entrenamiento completado, THE Gamification_Module SHALL otorgar una bonificación adicional de puntos.
3. THE Gamification_Module SHALL integrar los puntos otorgados con el GamificationEngine existente de la aplicación.

### Requisito 12: Feedback Post-Entrenamiento

**Historia de Usuario:** Como usuario, quiero ver un resumen positivo al terminar mi entrenamiento, para sentirme motivado y consciente de mi progreso.

#### Criterios de Aceptación

1. WHEN el usuario completa un entrenamiento, THE Feedback_View SHALL mostrar las mejoras de peso respecto al entrenamiento anterior del mismo ejercicio.
2. WHEN el usuario completa un entrenamiento, THE Feedback_View SHALL mostrar el número de días consecutivos de entrenamiento.
3. WHEN el Progress_Tracker indica estado improving para al menos un ejercicio, THE Feedback_View SHALL destacar el progreso positivo con un indicador visual (🔼).
4. IF no existen datos de entrenamientos anteriores para comparar, THEN THE Feedback_View SHALL mostrar un mensaje de bienvenida al primer entrenamiento sin métricas de comparación.

### Requisito 13: Persistencia de Datos

**Historia de Usuario:** Como usuario, quiero que mi plan, registros y progreso se guarden de forma persistente, para no perder información al cerrar la app.

#### Criterios de Aceptación

1. THE Training_Plan_Generator SHALL persistir el plan generado utilizando SwiftData, incluyendo las entidades: UserProfile (existente), Plan (nuevo, con campo planStatus: PlanStatus), DayPlan (extendido), Exercise (existente) y WorkoutLog (nuevo).
2. THE Set_Logger SHALL persistir cada WorkoutLog de forma inmediata al guardar un set individual.
3. WHEN la aplicación se cierra y se reabre, THE Training_Plan_Generator SHALL restaurar el plan activo (PlanStatus.active) y el progreso del usuario desde SwiftData.
4. IF ocurre un error de persistencia, THEN THE Training_Plan_Generator SHALL registrar el error en el logger y mostrar un mensaje al usuario indicando que los datos no se pudieron guardar.

### Requisito 14: Visualización Diaria del Plan

**Historia de Usuario:** Como usuario, quiero ver mi rutina del día de forma clara, para saber qué entrenamiento me toca y prepararme.

#### Criterios de Aceptación

1. THE Workout_Executor SHALL mostrar la vista diaria del plan dentro de la sección Workout existente de la aplicación.
2. THE Workout_Executor SHALL mostrar los grupos musculares del día, la lista de ejercicios con sets y reps sugeridos, y el peso sugerido ajustado por progresión semanal y recuperación.
3. WHEN el día actual es un día de descanso en el plan, THE Workout_Executor SHALL mostrar un indicador de día de descanso sin ejercicios.
4. WHEN el usuario tiene un plan activo, THE Workout_Executor SHALL mostrar el progreso general del plan (semana actual / total de semanas).
