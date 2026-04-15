# Decisiones arquitectónicas (registro)

Registro de decisiones **ya tomadas** en el código y en el producto. Sirve para alinear humanos y agentes y evitar “mejoras” no consensuadas.

Actualizar este archivo cuando se **revoque** explícitamente una decisión (con fecha y motivo).

---

## Decisiones vigentes

### D1 — Persistencia local con SwiftData

- **Decisión:** El estado de dominio (perfil, plan, rutina, logs, catálogo importado) vive en **SwiftData** registrado en `Super_Fitness_Coach_AppApp`.
- **Por qué:** Offline-first, una sola stack en el app target, integración natural con SwiftUI (`@Query`, `modelContext`).
- **Tradeoff:** Migraciones y modelos grandes requieren cuidado; no hay backend de sincronización en el flujo actual.

### D2 — Sin capa “Use Cases” explícita

- **Decisión:** La lógica se reparte entre **ViewModels `@Observable`**, **Core** y **Repositories** según el caso.
- **Por qué:** Menos archivos y velocidad de iteración en un equipo pequeño.
- **Tradeoff:** Reglas de negocio pueden quedar repartidas; hay que conocer `WorkoutExecutorViewModel`, generadores y repos para cambios amplios.

### D3 — Orquestación central en `ContentView`

- **Decisión:** Tabs, onboarding, sheets del entreno (preferencias, rutina, executor, feedback) y **construcción de `WorkoutExecutorViewModel`** viven en **`ContentView`**.
- **Por qué:** Un solo sitio donde cablear dependencias y ciclo de vida del entreno.
- **Tradeoff:** `ContentView` tiende a crecer; el acoplamiento entre features pasa por aquí.

### D4 — Catálogo de ejercicios: import fijo + consumo local

- **Decisión:** Los ejercicios se importan desde **fixtures wger en GitHub (raw)** a **`ExerciseCatalogEntry`** en SwiftData; la UI **no** depende de la API pública wger en tiempo de uso.
- **Por qué:** Estabilidad (menos caídas de red/API), dataset reproducible, offline.
- **Tradeoff:** Hay que volver a importar o actualizar fixtures si wger cambia; traducciones ES incompletas se compensan con fallback EN en código.

### D5 — Identidad de ejercicio: UUID local + `wgerUuid`

- **Decisión:** Cada fila del catálogo tiene `id: UUID` generado por la app y **`wgerUuid`** para correlación futura (p. ej. sync).
- **Por qué:** Desacoplar modelo interno del ID externo y permitir migraciones.
- **Tradeoff:** Toda referencia en rutinas/logs debe seguir usando el identificador estable acordado (p. ej. `wgerUuid` en logs).

### D6 — `ExerciseService.shared` + `configure(modelContext:)`

- **Decisión:** Un singleton **`ExerciseService.shared`** recibe el **`ModelContext`** desde la raíz y varias vistas lo reconfiguran en `onAppear` si hace falta.
- **Por qué:** Evitar múltiples instancias con catálogo vacío en primer arranque.
- **Tradeoff:** Patrón global; hay que llamar `configure` antes de búsquedas/import.

### D7 — Sesión de entreno: `UserDefaults` + `sessionId` en lógica de logs

- **Decisión:** Identificadores de sesión para plan semanal y «Mi rutina» se guardan en **UserDefaults** (claves acordadas) y se enlazan a **`SetLogger`** / **`WorkoutLog`**.
- **Por qué:** Reanudar entreno y agrupar series sin un servidor.
- **Tradeoff:** Cambiar formato de claves o semana actual puede romper continuidad o duplicar sesiones.

### D8 — Sin autenticación remota en el flujo actual

- **Decisión:** No hay login OAuth ni tokens; el “usuario” es **`UserProfile`** local + permisos de sistema (HealthKit, notificaciones).
- **Por qué:** Producto local-first sin backend obligatorio.
- **Tradeoff:** Cualquier sync multi-dispositivo requerirá decisión explícita nueva (Firebase, etc.) y migración de identidad.

### D9 — Temporizador de descanso: notificación local (Plan B)

- **Decisión:** El aviso al terminar el descanso con el teléfono bloqueado usa **`UserNotifications`** (y haptics en foreground). **Live Activity / ActivityKit** está **desactivada** en el código actual (Plan B documentado en conversación; sin entitlement en el target principal).
- **Por qué:** Evitar fricción de provisioning/capabilities mientras se estabiliza el producto.
- **Tradeoff:** No hay countdown en pantalla de bloqueo vía ActivityKit hasta reactivarlo de forma coordinada.

### D10 — iOS primero; extensión de widgets separada

- **Decisión:** App principal iPhone/iPad; target **`SuperFitnessCoachWidgets`** para WidgetKit (widget placeholder); Watch solo preparatorio en código (`WCSessionManager`).
- **Por qué:** Alcance incremental.
- **Tradeoff:** La extensión no sustituye funcionalidad crítica del entreno en el teléfono.

---

## Qué no debe cambiar el agente (sin acuerdo explícito)

Reglas para PRs y refactors automáticos:

1. **No** introducir un contenedor IoC global (Swinject, etc.) ni “arquitectura limpia” de capas nuevas sin decisión registrada aquí y en `ARCHITECTURE.md`.
2. **No** mover la orquestación masiva de `ContentView` a “otro patrón” en un solo PR grande sin plan y revisión; cambios incrementales preferidos.
3. **No** reemplazar SwiftData por Core Data / solo JSON sin decisión y plan de migración.
4. **No** volver a llamar la **API live wger** como fuente principal del catálogo sin actualizar `DECISIONS.md` y el flujo de import.
5. **No** eliminar **`wgerUuid`** de modelos o logs sin migración y búsqueda de referencias en rutinas e historial.
6. **No** reactivar **ActivityKit** en código y proyecto sin: entitlement, target de extensión alineado, y actualización de esta lista.
7. **No** añadir **login obligatorio** o dependencia de backend para el flujo actual sin producto/ADR.

Si el cambio es **bugfix local** (una vista, un cálculo), no hace falta tocar decisiones globales; sí documentar en el PR qué se tocó.

---

## Tradeoffs históricos (resumen)

| Tema | Elección hecha | Coste aceptado |
|------|----------------|----------------|
| Datos de ejercicios | Fixtures GitHub + SwiftData | Mantener import y posibles cambios upstream |
| i18n de ejercicios | ES prioridad, EN fallback | Algunos textos en inglés en UI |
| Navegación | `ContentView` + sheets | Fichero central pesado |
| Descanso bloqueado | Notificación local | Sin UI de countdown en lock screen (hasta Live Activity) |
| Complejidad `RoutineEditorView` | Un archivo grande | Refactor costoso; cambios quirúrgicos preferidos |

---

## Relación con otros documentos

- **`PROJECT_OVERVIEW.md`** — qué es el producto y plataformas.
- **`ARCHITECTURE.md`** — cómo está cableado el código hoy.
- **`MODULE_MAP.md`** — carpetas, dependencias y puntos frágiles.

---

## Cómo proponer un cambio de decisión

1. Añadir sección “Propuesta” o editar una decisión con **fecha** y **motivo**.
2. Actualizar `ARCHITECTURE.md` / `MODULE_MAP.md` si el impacto es transversal.
3. En PR, mencionar explícitamente qué número de decisión se modifica o reemplaza.
