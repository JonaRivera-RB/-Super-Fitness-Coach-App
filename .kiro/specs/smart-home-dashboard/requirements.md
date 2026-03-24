# Documento de Requisitos — Smart Home Dashboard

## Introducción

El Home Dashboard actual de Super Fitness Coach muestra datos de salud (recovery score, activity score, HR, HRV, sueño) como números crudos sin contexto humano. El usuario ve "72" pero no sabe si eso es bueno o malo, ni qué hacer al respecto. Este feature rediseña el Home para que actúe como un coach real: en 2 segundos el usuario debe entender su estado y saber qué acción tomar (descansar, entrenar fuerte, ir moderado, dormir más, etc.). Se transforma la presentación de datos técnicos en guía personalizada y accionable.

## Glosario

- **Dashboard**: La pantalla principal (Home) de la app que muestra el resumen diario del usuario
- **Recovery_Score**: Puntuación 0-100 calculada a partir de sueño, frecuencia cardíaca en reposo y HRV que indica el nivel de recuperación del cuerpo
- **Activity_Score**: Puntuación 0-100 calculada a partir de pasos y calorías activas que indica el nivel de actividad del día
- **Status_Indicator**: Indicador visual (rojo/amarillo/verde) que representa el estado general del usuario
- **Coach_Summary**: Resumen ejecutivo generado por el sistema que explica en lenguaje natural el estado del usuario y la acción recomendada
- **Metric_Insight**: Explicación contextual de una métrica individual que indica si el valor es bueno, normal o bajo para el usuario específico
- **Action_Card**: Componente visual que muestra la acción principal recomendada para el día
- **ScoreBreakdown**: Modelo existente que contiene los componentes desglosados de un score con rawValue, normalizedScore, weight, status y description
- **Personal_Baseline**: Promedio de 14 días de una métrica (HR, HRV) calculado automáticamente por HealthKitManager para comparar contra el valor actual del usuario
- **AICoach**: Módulo que genera mensajes y recomendaciones contextuales basados en los datos de salud del usuario
- **ComponentStatus**: Estado de un componente del score: warning (< 40), normal (40-69), good (≥ 70)

## Requisitos

### Requisito 1: Resumen Ejecutivo del Coach

**User Story:** Como usuario, quiero ver un resumen claro y breve al abrir la app, para saber en 2 segundos si hoy debo descansar, entrenar fuerte o ir moderado.

#### Criterios de Aceptación

1. WHEN el Dashboard se carga con datos disponibles, THE Coach_Summary SHALL mostrar un mensaje en lenguaje natural que incluya el estado general del usuario (descansar / moderado / entrenar fuerte) basado en el Recovery_Score
2. WHEN el Recovery_Score es menor a 40, THE Coach_Summary SHALL recomendar descanso y explicar brevemente por qué (ej: "dormiste poco", "tu cuerpo está fatigado")
3. WHEN el Recovery_Score está entre 40 y 69, THE Coach_Summary SHALL recomendar actividad moderada e indicar qué métricas están limitando la recuperación
4. WHEN el Recovery_Score es 70 o mayor, THE Coach_Summary SHALL indicar que el usuario está listo para entrenar fuerte
5. THE Coach_Summary SHALL posicionarse como el primer elemento visible del Dashboard, antes de los scores numéricos
6. THE Coach_Summary SHALL incluir un emoji o icono visual que refuerce el mensaje (🔴 descanso, 🟡 moderado, 🟢 a tope)
7. WHEN el Activity_Score es mayor a 70 y el Recovery_Score es menor a 40, THE Coach_Summary SHALL reconocer el esfuerzo reciente y enfatizar la necesidad de recuperación

### Requisito 2: Tarjeta de Acción Principal

**User Story:** Como usuario, quiero ver una acción clara y destacada que me diga exactamente qué hacer hoy, para no tener que interpretar números.

#### Criterios de Aceptación

1. THE Action_Card SHALL mostrar la acción recomendada del día en texto grande y claro (ej: "Hoy: Descanso activo", "Hoy: Entrenamiento de fuerza", "Hoy: Cardio ligero")
2. WHEN el Recovery_Score es menor a 40, THE Action_Card SHALL recomendar descanso o actividad muy ligera independientemente del tipo de entrenamiento programado
3. WHEN el Recovery_Score está entre 40 y 69, THE Action_Card SHALL adaptar la intensidad del entrenamiento programado a un nivel moderado
4. WHEN el Recovery_Score es 70 o mayor, THE Action_Card SHALL mostrar el entrenamiento programado del día a intensidad completa
5. THE Action_Card SHALL incluir un indicador visual de intensidad (baja/media/alta) con color correspondiente

### Requisito 3: Insights Contextuales por Métrica

**User Story:** Como usuario, quiero entender qué significa cada métrica de salud para mí personalmente, para saber si mis números son buenos o malos.

#### Criterios de Aceptación

1. WHEN el Dashboard muestra el ScoreBreakdown de Recovery, THE Metric_Insight SHALL mostrar cada componente (sueño, HR, HRV) con una explicación en lenguaje natural de si el valor es bueno, normal o bajo para el usuario
2. WHEN el valor de sueño es menor al 70% de la meta configurada, THE Metric_Insight SHALL mostrar un mensaje indicando que el usuario necesita dormir más y cuántas horas le faltaron
3. WHEN la frecuencia cardíaca en reposo está por encima del Personal_Baseline, THE Metric_Insight SHALL explicar que el cuerpo muestra señales de fatiga o estrés
4. WHEN el HRV está por debajo del Personal_Baseline, THE Metric_Insight SHALL explicar que la variabilidad cardíaca indica menor recuperación
5. WHEN el HRV está por encima del Personal_Baseline, THE Metric_Insight SHALL indicar que el sistema nervioso está bien recuperado
6. WHEN el valor de pasos es menor al 50% de la meta, THE Metric_Insight SHALL sugerir incrementar la actividad con un mensaje motivacional
7. THE Metric_Insight SHALL usar el ComponentStatus (warning/normal/good) existente para determinar el tono del mensaje

### Requisito 4: Mejora del AICoach con Reglas Contextuales

**User Story:** Como usuario, quiero que las recomendaciones del coach sean específicas a mi situación actual, no mensajes genéricos que aplican a cualquier persona.

#### Criterios de Aceptación

1. THE AICoach SHALL generar mensajes que referencien las métricas específicas que están afectando el score del usuario (ej: "tu HRV está bajo" en vez de solo "descansa")
2. WHEN el sueño total es menor a 6 horas y el Recovery_Score es menor a 50, THE AICoach SHALL mencionar específicamente la falta de sueño como factor principal
3. WHEN la frecuencia cardíaca en reposo supera el Personal_Baseline en más de 10%, THE AICoach SHALL mencionar el estrés cardiovascular como factor
4. WHEN el usuario tiene un streak de 3 o más días, THE AICoach SHALL combinar el reconocimiento del streak con la recomendación basada en datos actuales
5. THE AICoach SHALL recibir el ScoreBreakdown completo como entrada para generar mensajes contextuales en lugar de solo los scores numéricos
6. THE AICoach SHALL generar mensajes en español

### Requisito 5: Jerarquía Visual del Dashboard

**User Story:** Como usuario, quiero que la información más importante esté arriba y sea fácil de leer, para no tener que buscar lo que necesito.

#### Criterios de Aceptación

1. THE Dashboard SHALL organizar el contenido en el siguiente orden: Coach_Summary, Action_Card, Recovery con Metric_Insights, Activity con Metric_Insights, puntos y detox
2. THE Dashboard SHALL mostrar el Recovery_Score y Activity_Score con tamaño reducido respecto al diseño actual, priorizando el Coach_Summary como elemento principal
3. WHEN los datos de salud están cargando, THE Dashboard SHALL mostrar un estado de carga con placeholder animado en lugar de valores por defecto
4. THE Dashboard SHALL usar colores consistentes para los tres estados: rojo para descanso/warning, amarillo/naranja para moderado/normal, verde para óptimo/good
5. THE Dashboard SHALL mantener accesibilidad con labels descriptivos en todos los elementos interactivos y de información

### Requisito 6: Explicación del Score

**User Story:** Como usuario, quiero entender qué significa mi score de recuperación y actividad, para que los números tengan sentido.

#### Criterios de Aceptación

1. WHEN el usuario ve el Recovery_Score, THE Dashboard SHALL mostrar una etiqueta descriptiva junto al número (ej: "72 — Buena recuperación", "35 — Necesitas descanso")
2. WHEN el usuario ve el Activity_Score, THE Dashboard SHALL mostrar una etiqueta descriptiva junto al número (ej: "85 — Muy activo", "20 — Día tranquilo")
3. THE Dashboard SHALL definir rangos claros para las etiquetas: 0-39 (Bajo/Necesitas descanso), 40-69 (Moderado/En progreso), 70-100 (Alto/Óptimo)
4. WHEN el usuario expande los detalles del score, THE Dashboard SHALL mostrar los Metric_Insights contextuales en lugar del breakdown técnico actual con pesos y porcentajes
