# Documento de Requisitos: Insights de Progreso de Actividad

## Introducción

La sección de Actividad del dashboard muestra mensajes de insight engañosos que indican "meta cumplida" cuando el usuario solo ha alcanzado aproximadamente el 70% de su meta real de fitness. Esto ocurre porque `componentStatus` clasifica un `normalizedScore >= 70` como `.good`, y `MetricInsightGenerator` interpreta `.good` como meta cumplida, cuando en realidad 70% no es 100%. Este feature corrige los mensajes de insight, agrega barras de progreso visual para pasos y calorías, e introduce mensajes motivacionales que varían según el nivel de avance hacia la meta.

## Glosario

- **MetricInsightGenerator**: Módulo en `MetricInsightGenerator.swift` que genera mensajes de insight contextuales en español para cada componente de un `ScoreBreakdown`.
- **HealthKitManager**: Módulo en `HealthKitManager.swift` que consulta datos de salud, normaliza métricas y construye los breakdowns de actividad y recuperación.
- **HomeView**: Vista principal del dashboard en `HomeView.swift` que muestra las secciones de recuperación y actividad con sus insights.
- **HomeViewModel**: ViewModel en `HomeViewModel.swift` que coordina la obtención de datos y genera etiquetas descriptivas para el dashboard.
- **ScoreBreakdown**: Modelo en `ScoreBreakdown.swift` que contiene los componentes desglosados de un score, cada uno con su `normalizedScore` y `ComponentStatus`.
- **ComponentStatus**: Enumeración dentro de `ScoreBreakdown` con valores `.warning`, `.normal` y `.good`, determinada por umbrales del `normalizedScore`.
- **FitnessConfig**: Modelo en `FitnessConfig.swift` que almacena las metas personalizadas del usuario (`stepsGoal`, `calorieGoal`, etc.).
- **normalizedScore**: Valor calculado como `actual / goal * 100`, limitado al rango [0, 100], que representa el porcentaje de avance hacia la meta.
- **Barra_de_Progreso**: Componente visual de SwiftUI que muestra el avance proporcional de una métrica hacia su meta configurada.
- **Mensaje_Motivacional**: Texto dinámico que varía según el rango de porcentaje de avance hacia la meta del usuario.

## Requisitos

### Requisito 1: Corregir mensajes de insight de pasos

**Historia de Usuario:** Como usuario, quiero que el mensaje de pasos refleje con precisión si alcancé mi meta, para no recibir felicitaciones falsas cuando aún me falta progreso.

#### Criterios de Aceptación

1. WHEN el `normalizedScore` de pasos es mayor o igual a 100, THE MetricInsightGenerator SHALL mostrar el mensaje "¡Meta cumplida! X pasos hoy ✓" con estado `.good`.
2. WHEN el `normalizedScore` de pasos está entre 70 y 99 (inclusive), THE MetricInsightGenerator SHALL mostrar el mensaje "X de Y pasos — ¡ya casi llegas! 💪" con estado `.good`.
3. WHEN el `normalizedScore` de pasos está entre 40 y 69 (inclusive), THE MetricInsightGenerator SHALL mostrar el mensaje "X de Y pasos — vas bien" con estado `.normal`.
4. WHEN el `normalizedScore` de pasos es menor a 40, THE MetricInsightGenerator SHALL mostrar el mensaje "Llevas X de Y pasos — ¡a moverse! 🚶" con estado `.warning`.

### Requisito 2: Corregir mensajes de insight de calorías

**Historia de Usuario:** Como usuario, quiero que el mensaje de calorías refleje con precisión si alcancé mi meta de calorías activas, para no ver "Meta de calorías cumplida" cuando aún no la he alcanzado.

#### Criterios de Aceptación

1. WHEN el `normalizedScore` de calorías es mayor o igual a 100, THE MetricInsightGenerator SHALL mostrar el mensaje "Meta de calorías cumplida: X kcal ✓" con estado `.good`.
2. WHEN el `normalizedScore` de calorías está entre 70 y 99 (inclusive), THE MetricInsightGenerator SHALL mostrar el mensaje "X de Y kcal activas — ¡casi lo logras! 🔥" con estado `.good`.
3. WHEN el `normalizedScore` de calorías está entre 40 y 69 (inclusive), THE MetricInsightGenerator SHALL mostrar el mensaje "X de Y kcal activas — en progreso" con estado `.normal`.
4. WHEN el `normalizedScore` de calorías es menor a 40, THE MetricInsightGenerator SHALL mostrar el mensaje "X de Y kcal activas — aún queda camino" con estado `.warning`.

### Requisito 3: Barra de progreso visual para pasos

**Historia de Usuario:** Como usuario, quiero ver una barra de progreso visual para mis pasos, para entender de un vistazo cuánto me falta para alcanzar mi meta diaria.

#### Criterios de Aceptación

1. WHEN la sección de detalles de actividad está expandida, THE HomeView SHALL mostrar una Barra_de_Progreso para la métrica de pasos.
2. THE Barra_de_Progreso de pasos SHALL representar visualmente la fracción `actual / meta` del usuario, limitada al rango [0.0, 1.0].
3. WHEN el `normalizedScore` de pasos es mayor o igual a 100, THE Barra_de_Progreso SHALL mostrarse completamente llena con color verde.
4. WHEN el `normalizedScore` de pasos está entre 40 y 99, THE Barra_de_Progreso SHALL mostrarse parcialmente llena con color azul.
5. WHEN el `normalizedScore` de pasos es menor a 40, THE Barra_de_Progreso SHALL mostrarse parcialmente llena con color naranja.
6. THE Barra_de_Progreso de pasos SHALL incluir una etiqueta de accesibilidad que indique "Progreso de pasos: X por ciento".

### Requisito 4: Barra de progreso visual para calorías

**Historia de Usuario:** Como usuario, quiero ver una barra de progreso visual para mis calorías activas, para entender de un vistazo cuánto me falta para alcanzar mi meta diaria de calorías.

#### Criterios de Aceptación

1. WHEN la sección de detalles de actividad está expandida, THE HomeView SHALL mostrar una Barra_de_Progreso para la métrica de calorías activas.
2. THE Barra_de_Progreso de calorías SHALL representar visualmente la fracción `actual / meta` del usuario, limitada al rango [0.0, 1.0].
3. WHEN el `normalizedScore` de calorías es mayor o igual a 100, THE Barra_de_Progreso SHALL mostrarse completamente llena con color verde.
4. WHEN el `normalizedScore` de calorías está entre 40 y 99, THE Barra_de_Progreso SHALL mostrarse parcialmente llena con color azul.
5. WHEN el `normalizedScore` de calorías es menor a 40, THE Barra_de_Progreso SHALL mostrarse parcialmente llena con color naranja.
6. THE Barra_de_Progreso de calorías SHALL incluir una etiqueta de accesibilidad que indique "Progreso de calorías: X por ciento".

### Requisito 5: Mensajes motivacionales según nivel de avance

**Historia de Usuario:** Como usuario, quiero ver mensajes motivacionales que cambien según mi nivel de avance hacia la meta, para sentirme incentivado a seguir progresando.

#### Criterios de Aceptación

1. WHEN el `normalizedScore` de una métrica de actividad (pasos o calorías) es menor a 25, THE MetricInsightGenerator SHALL incluir un tono motivacional de inicio (ej. "¡Cada paso cuenta!").
2. WHEN el `normalizedScore` de una métrica de actividad está entre 25 y 49, THE MetricInsightGenerator SHALL incluir un tono motivacional de progreso temprano (ej. "¡Buen arranque!").
3. WHEN el `normalizedScore` de una métrica de actividad está entre 50 y 74, THE MetricInsightGenerator SHALL incluir un tono motivacional de mitad de camino (ej. "¡Más de la mitad!").
4. WHEN el `normalizedScore` de una métrica de actividad está entre 75 y 99, THE MetricInsightGenerator SHALL incluir un tono motivacional de casi logrado (ej. "¡Ya casi!").
5. WHEN el `normalizedScore` de una métrica de actividad es mayor o igual a 100, THE MetricInsightGenerator SHALL incluir un tono de celebración (ej. "¡Meta cumplida! 🎉").

### Requisito 6: Consistencia entre normalizedScore y mensajes

**Historia de Usuario:** Como usuario, quiero que los mensajes de insight sean consistentes con el porcentaje real de avance hacia mi meta, para confiar en la información que me muestra la app.

#### Criterios de Aceptación

1. THE MetricInsightGenerator SHALL determinar el mensaje de insight basándose en el `normalizedScore` del componente y no únicamente en el `ComponentStatus`.
2. THE MetricInsightGenerator SHALL reservar mensajes de "meta cumplida" exclusivamente para cuando el `normalizedScore` sea mayor o igual a 100.
3. FOR ALL valores válidos de `normalizedScore` en el rango [0, 100], parsear el mensaje generado y luego regenerarlo con los mismos parámetros SHALL producir un mensaje idéntico (propiedad de ida y vuelta).
