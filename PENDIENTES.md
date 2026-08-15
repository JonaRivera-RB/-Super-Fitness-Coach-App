# Pendientes

Deuda técnica y trabajo a medio terminar. Todo lo listado aquí se **verificó contra el código el
2026-08-15** con la referencia exacta.

Al cerrar un punto: borra su entrada. Este archivo solo contiene lo que sigue abierto.

> El documento anterior daba por pendientes cosas que ya estaban hechas, y eso le costó la
> credibilidad entera. Si vas a añadir un punto, cita archivo y línea; si no puedes citarlos, va
> en `BUGS.md` como sospecha, no aquí como deuda.

---

## Alta — resolver antes de tocar el área afectada

### P1 · Watch App huérfano

`Super Fitness Coach Watch App/` contiene 5 archivos Swift (app entry, `WatchMainView`,
`WatchWorkoutView`, `WatchSessionManager`, `WatchModels`) que **no pertenecen a ningún target ni
grupo sincronizado del `.xcodeproj`**. No compilan. En paralelo, `Core/WCSessionManager.swift` sí
entra al build pero **no lo referencia nadie**: es código muerto dentro del target.

Verificado: los targets nativos son solo `Super Fitness Coach App`,
`Super Fitness Coach AppTests` y `SuperFitnessCoachWidgetsExtension`; los grupos sincronizados
apuntan solo a `Super Fitness Coach App`, `Tests` y `SuperFitnessCoachWidgets`.

**Es una decisión de producto, no una tarea técnica.** Dos caminos:
- **Adoptarlo** — crear el target watchOS, meter la carpeta, cablear `WCSessionManager` en la app.
- **Borrarlo** — eliminar la carpeta y `WCSessionManager.swift`, y quitar el Watch de D10.

Lo que no sirve es dejarlo: aparenta que existe una companion app que no existe.

### P2 · `WorkoutView` con dos fuentes de verdad

`Features/Workout/WorkoutView.swift:29` y `:37` declaran `@Query` de SwiftData, al mismo tiempo
que la vista recibe `TrainingPlanViewModel` inyectado. Las dos fuentes pueden desincronizarse
después de operaciones asíncronas, y además viola la regla de dependencia de `CLAUDE.md`
(ninguna vista toca SwiftData).

**Acción:** eliminar ambos `@Query` y exponer desde el ViewModel lo que la vista necesita
(`hasPlan`, `hasRoutine`).

---

## Media — no bloquean, pero se pagan cada vez que se pasa por ahí

### P3 · `populateRecoveryContextLines` sigue duplicada

`Features/Home/HomeViewModel.swift:647` ya despacha por idioma correctamente, pero
`populateRecoveryContextLinesES` (`:654`) y `populateRecoveryContextLinesEN` (`:801`) son dos
bloques casi idénticos de ~147 líneas cada uno. Cualquier cambio en la lógica de sueño hay que
hacerlo dos veces, en paralelo, sin que nada avise si se olvida uno.

**Acción:** una sola función parametrizada que construya las líneas y saque los textos de
`AppLocalizedStrings`.

### P4 · `HomeViewModel` hace demasiado

Mezcla refresh de datos, formateo de texto, lógica de negocio y efectos secundarios (programar
notificación, persistir snapshot). Es, con diferencia, el ViewModel más grande.

**Acción:** extraer el formateo de sueño a un `SleepContextFormatter` en `Core/` (con tests, que
un ViewModel no puede tener fácilmente) y sacar la programación de la notificación a un servicio.
Se resuelve junto con P3, es el mismo código.

### P5 · `ExerciseService.shared` convive con inyección

`Core/ExerciseService.swift:15` declara `static let shared`, pero el servicio **también** se
inyecta desde `ContentView`. Coexisten dos vías de acceso, con riesgo de dos instancias y dos
caches.

Ojo: el singleton existe por una razón real (D6 — resolvió el catálogo vacío en primer arranque).
No lo borres sin más; hay que elegir **una** de las dos vías y migrar todos los usos.

### P6 · `StatusIndicator.label` hardcodeado en inglés

`Features/Home/HomeViewModel.swift:137` devuelve `"Fatigued"` / `"Medium"` / `"Optimal"` fijos, y
`:623` devuelve `"Optimal recovery"`. En una app bilingüe, un usuario en español ve inglés.

**Acción:** mover a `AppLocalizedStrings` y resolver con `AppLanguage`.

### P7 · Sistema de color a medias

`DesignTokens` (actual) y `AppSemanticPalette` (anterior) conviven, y quedan usos de `Color.blue`
y `Color.teal` directos que no son dark-safe.

**Acción:** auditar vistas y migrar a `DesignTokens`. Es incremental — cada vista que toques,
migra esa vista.

---

## Baja — pulido

### P8 · `StatsView` sin gráficas

`StatsViewModel` ya expone `recentHistory` y `prRecords` completos, pero la pantalla los muestra
como listas. Swift Charts **ya está en el proyecto** y en uso en
`Features/Workout/WorkoutView.swift:12`, así que no hay que introducir dependencias: es UI.

Necesita decidir antes qué métricas priorizar.

### P9 · Pantalla post-workout pobre

`FeedbackView` recibe los `[WorkoutLog]` completos de la sesión y solo muestra los puntos
otorgados. Con esos datos ya se podría enseñar resumen de series, PRs detectados y comparativa
con la sesión anterior.

### P10 · Instrucciones de ejercicios en inglés

`PlannedExercise.instructions` viene del catálogo en inglés, sin capa de traducción (consecuencia
aceptada de D4). Decidir entre traducir en cliente o preprocesar el dataset.

---

## Specs a medio terminar

En `.kiro/specs/`. Estado real de sus `tasks.md`:

| Spec | Estado | Qué falta |
|---|---|---|
| `smart-fitness-coach` | **8/12** | Refactor de las funciones estáticas de scoring de `HealthKitManager` · actualizar `WorkoutEngine` para `FitnessLevel` · actualizar firma de `AICoach` · actualizar ViewModels |
| `smart-home-dashboard` | **6/7** | Mejorar `AICoach` con reglas contextuales y mensajes en español — marcada *en progreso* |
| `activity-progress-insights` | **5/6** | Tests unitarios de boundaries y edge cases |
| `sleep-window-goal` | **sin empezar** | Tiene `requirements.md` y `design.md` pero **nunca se le escribió `tasks.md`** |

Completas, no requieren acción: `smart-training-plan` (14/14), `body-metrics-onboarding` (9/9),
`sleep-window-recovery-validation` (4/4).

⚠️ La tarea pendiente de `smart-fitness-coach` toca `HealthKitManager`, que es la zona más frágil
del proyecto (ver `CLAUDE.md` → Zonas frágiles). No es un refactor mecánico.

---

## Higiene del repo

- `build/` y `.derivedData/` existen en el árbol de trabajo. Están ignorados por git, pero ocupan
  espacio y ensucian las búsquedas — conviene filtrarlos al hacer `grep`/`find`.
- `tmp_wger_fixtures/` fue eliminado del repo; el import ya apunta a GitHub raw (D4).
- El repo es **público** y no tiene `README.md`.
- Ninguna rama está protegida, incluida `main`.
