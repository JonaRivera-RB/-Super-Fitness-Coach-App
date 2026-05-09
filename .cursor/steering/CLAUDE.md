# VitrikFit — Guía de arquitectura para Claude

> Generado por auditoría de código real. No asumir; verificar si algo parece desactualizado.

---

## Resumen del proyecto

App de fitness iOS (SwiftUI + SwiftData) con:
- Recovery score diario calculado desde HealthKit (HRV, RHR, sueño)
- Plan guiado semanal con progresión automática + ajuste por recuperación
- "Mi rutina" personalizable (alternativa al plan guiado)
- Gamificación (puntos, niveles, racha, insignias)
- Catálogo de 414 ejercicios (API wger.de + fallback JSON local)
- Apple Watch companion app
- Soporte bilingüe ES/EN

**Targets**: iOS app principal · watchOS app · Tests (Unit + Property)

---

## Arquitectura real

### Patrón: MVVM + Composition Root + Repository

```
App.swift
└── ContentView  ← Composition Root (servicio/VM init + nav state)
    └── TabView
        ├── HomeView            ← ViewModel injected
        ├── WorkoutView         ← VM injected + @Query propio
        ├── StatsView           ← ViewModel injected
        └── ProfileView         ← ViewModel injected
```

**Frameworks clave**:
- `@Observable` (Observation framework, NO `ObservableObject` / Combine)
- `SwiftData` para persistencia (NO CoreData)
- `HealthKit` para métricas de salud
- `WatchConnectivity` para Watch

### Capa de servicios (Core/)

```
Composition Root
├── HealthKitManager        @Observable  — Toda la lógica HealthKit
├── GamificationEngine      @Observable  — Puntos/niveles/racha
├── ExerciseService         @Observable  — Catálogo de ejercicios (API + cache)
├── DetoxManager                         — Challenge alcohol-free
├── NotificationService                  — Notificaciones locales
├── TrainingPlanGenerator   (struct)     — Generación de planes
├── AICoach                 (struct)     — Mensajes del coach (stateless)
├── GymCoach                (struct)     — Micro-coaching en sesión (stateless)
├── RecoveryAdapter         (struct)     — Score → ajuste peso/volumen
├── WeeklyProgressionEngine (struct)     — Multiplicadores semanales
├── SetLogger                            — Logging por sesión
├── DayManager                           — Skip/complete/reschedule días
└── WCSessionManager                     — Watch connectivity
```

### Capa de datos

```
Repositories/  ← Toda la lógica SwiftData va aquí
├── TrainingPlanRepository   — Plan activo, WorkoutLogs, performance
├── UserProfileRepository    — Perfil + preferencias
├── GamificationRepository   — Estado de gamificación
├── DetoxRepository          — Progreso detox
├── RecoverySnapshotRepository — Historial local de recovery score
└── UserRoutineRepository    — Rutina personalizada del usuario
```

**Regla**: Ninguna Vista ni ViewModel accede a `ModelContext` directamente.
Solo los Repositories tocan SwiftData.

---

## Mapa de módulos y responsabilidades

### `Features/Home/`
- **HomeViewModel**: Orquesta refresh de HealthKit → calcula labels de recovery/activity/sueño → genera mensaje AICoach → programa notificación → persiste snapshot. **620 líneas, hace demasiado** (ver deuda técnica).
- **HomeView**: Dashboard principal con scroll. ~1000 líneas pero toda UI, sin lógica de negocio.

### `Features/Training/`
- **TrainingPlanView + VM**: Muestra semana actual, estados de días, acciones (skip/complete/reschedule).
- **TrainingPreferencesView + VM**: Formulario para generar nuevo plan. Llama a `TrainingPlanGenerator`.
- **WorkoutExecutorView + VM**: Sesión activa de entrenamiento. Gestiona timer de descanso, PR detection, logging por serie. El VM recibe `PlannedExercise[]` ya construido — no hace fetch.
- **FeedbackView + VM**: Post-workout. Recibe `[WorkoutLog]` + otorga puntos de gamificación.
- **ExerciseDetailView**: Vista de detalle de ejercicio con GIF + sustitutos. Sin ViewModel propio.

### `Features/Workout/`
- **WorkoutView**: Tab "Entrenamiento". Muestra Plan Guiado o Mi Rutina (Picker si ambos existen). Usa `@Query` SwiftData directo + `TrainingPlanViewModel` inyectado (dos fuentes de verdad — ver deuda técnica).

### `Features/Stats/`
- **StatsViewModel**: Lee de GamificationEngine + TrainingPlanRepository. Construye historial y PRs.
- **StatsView**: Muestra nivel, puntos, racha, badges, historial, PRs. **Sin gráficas** (deuda técnica).

### `Features/Profile/`
- **ProfileView + VM**: Edición de perfil, unidades, estado HealthKit, notificaciones.

### `Features/Routine/`
- **RoutineEditorView**: Editor de Mi Rutina. Sin ViewModel propio (usa `modelContext` directamente — excepción documentada).

### `Features/Detox/`
- **DetoxView + VM**: Challenge alcohol-free. Aislado del resto del sistema.

### `Core/HealthKitManager.swift` (~48.5 KB)
El archivo más grande y crítico. Hace:
1. Autorización HealthKit
2. Fetch de sueño + filtrado por ventana
3. Cálculo de recovery score (HRV, RHR, sueño, baseline 14 días)
4. Cálculo de activity score (steps, calorías activas)
5. Sleep consistency score vs horario configurado
6. Observers para actualización en background
7. Publicación de todos los estados como propiedades `private(set)`

**NO TOCAR sin consultar.** Cada cambio aquí afecta Home, notificaciones y WorkoutExecutor.

### `Core/AppLocalizedStrings.swift` (~45.7 KB)
Todas las cadenas UI como extensiones de `AppLanguage`. Patrón:
```swift
var miClave: String {
    switch self {
    case .spanish: return "..."
    case .english: return "..."
    }
}
```
Agregar strings nuevos siempre aquí, nunca literales en las Vistas.

### `Core/AppSemanticPalette.swift`
Sistema de color dark/light safe. Usar `AppSemanticPalette.systemBlue` en lugar de `Color.blue`.
`HomeView` tiene su propio `Color.homeAccent` (naranja) definido en extensión privada local — correcto para colores de módulo específicos.

---

## Convenciones que ya usa el proyecto

### ViewModels
```swift
@Observable
final class MiViewModel {
    private(set) var estado: String = ""   // NO public var
    
    @ObservationIgnored
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "MiVM")
    
    func onAppear() async { ... }          // async, llamado desde .task {}
    func refresh() async { ... }           // sin showLoading
}
```

### Vistas
```swift
struct MiView: View {
    var viewModel: MiViewModel             // var, no @State (ya es @Observable)
    @Environment(\.appLanguage) private var lang
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        // ...
        .task { await viewModel.onAppear() }
    }
}
```

### Strings localizadas
```swift
// En la vista:
Text(lang.miClave)

// En AppLocalizedStrings.swift:
var miClave: String {
    switch self {
    case .spanish: return "Texto en español"
    case .english: return "Text in English"
    }
}
```

### Colores
```swift
// Sistema (dark/light safe) → AppSemanticPalette
AppSemanticPalette.systemBlue
AppSemanticPalette.muscleTagBackground(colorScheme)

// Solo si es un color de branding del módulo específico:
static let homeAccent = Color(red: 1.0, green: 122/255, blue: 38/255)
```

### Estado de datos HealthKit
```swift
// Siempre usar el enum, nunca asumir que hay valor:
switch viewModel.recoveryScore {
case .loading: ProgressView()
case .unavailable: Text("—")
case .available(let v): Text("\(v)")
}
```

### Logging
```swift
@ObservationIgnored
private let logger = Logger(subsystem: "com.superfitnesscoach", category: "NombreClase")

logger.info("Mensaje informativo")
logger.warning("Advertencia")
logger.error("Error: \(error.localizedDescription)")
```

### Repositories
```swift
// SIEMPRE reciben ModelContext en init, nunca lo guardan como @Environment
final class MiRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }
}

// Se instancian en ContentView y se pasan a los ViewModels
```

---

## Dónde va cada feature nueva

| Tipo de feature | Dónde va |
|---|---|
| Nueva pantalla completa | `Features/{Nombre}/NombreView.swift` + `NombreViewModel.swift` |
| Nuevo servicio de negocio | `Core/NombreService.swift` |
| Nueva utilidad stateless | `Core/NombreUtility.swift` (struct, no class) |
| Nuevo modelo persistido | `Models/NombreModel.swift` + registrar en App.swift + ContentView preview |
| Nuevo acceso a datos | `Repositories/NombreRepository.swift` |
| Nueva cadena UI | Agregar a `Core/AppLocalizedStrings.swift` (ambos idiomas) |
| Nuevo color semántico | Agregar a `Core/AppSemanticPalette.swift` |
| Nueva métrica HealthKit | `Core/HealthKitManager.swift` — consultar primero |

### Reglas de navegación
- Tabs nuevos → registrar en `ContentView.Tab` enum + añadir case en `TabView`
- Sheets → el estado (`@State private var showingX`) vive en `ContentView` si es cross-tab, o en la Vista hija si es local
- Las sheets que involucran `WorkoutExecutorViewModel` siempre van en `ContentView` (necesita el orquestador de sesión)

---

## Deuda técnica (ordenada por impacto en seguridad al agregar features)

### 🔴 Alta — Arreglar antes de agregar features en las áreas afectadas

**1. ContentView como Composition Root sobrecargado (~480 líneas)**
- Hace: service init + VM creation + sheet management + business logic de sesión
- Riesgo: cualquier feature nueva de Training o Workout tiene que tocar ContentView
- Acción: extraer `WorkoutSessionCoordinator` que gestione el flujo workout → executor → feedback → complete

**2. Lógica de sesión en ContentView**
- `buildWorkoutExecutorViewModel`, `buildRoutineExecutorViewModel`, `loadOrCreateSessionId`, `clearSessionId`, `markRoutineDayCompleted` son lógica de negocio en la capa de presentación
- Acción: mover a `WorkoutSessionCoordinator` (servicio, no VM)

**3. `populateRecoveryContextLinesES` / `populateRecoveryContextLinesEN` duplicadas**
- Dos funciones de ~140 líneas cada una que son casi idénticas
- Riesgo: cualquier cambio en la lógica de sueño requiere editarlas en paralelo
- Acción: unificar en una función parametrizada por `AppLanguage`

**4. WorkoutView con dos fuentes de verdad**
- Usa `@Query` (SwiftData) para `activePlans` + `TrainingPlanViewModel` inyectado
- Pueden desincronizarse tras operaciones asíncronas
- Acción: eliminar el `@Query` directo; que `TrainingPlanViewModel` sea la única fuente

### 🟡 Media — Afectan calidad pero no bloquean features nuevas

**5. HomeViewModel con demasiadas responsabilidades (~620 líneas)**
- Mezcla: data refresh + text formatting + business logic + side effects (notificación, snapshot)
- Acción: extraer `SleepContextFormatter` (las líneas ES/EN de sueño) + mover `scheduleDailyNotification` a un servicio separado

**6. HealthKitManager monolítico (48.5 KB)**
- Todo el pipeline de HealthKit en un archivo
- Riesgo bajo de tocar (está bien testeado conceptualmente), pero difícil de mantener
- Acción futura: separar en `SleepPipeline`, `CardioMetricsManager`, `RecoveryScorer`

**7. `ExerciseService.shared` singleton innecesario**
- Tiene `static let shared = ExerciseService()` pero también se inyecta desde ContentView
- Riesgo de dos instancias con caches separadas
- Acción: eliminar `static let shared`

**8. `StatusIndicator.label` hardcodeado en inglés**
- `HomeViewModel.StatusIndicator.label` devuelve "Fatigued"/"Medium"/"Optimal" (inglés fijo)
- Acción: usar `AppLanguage` para localizarlo

### 🟢 Baja — No bloquean nada, mejoras de pulido

**9. Instrucciones de ejercicios en inglés**
- `PlannedExercise.instructions: [String]` viene de la API en inglés
- No hay capa de traducción
- Acción: display en inglés con nota, o llamar a endpoint de traducción de wger

**10. StatsView sin gráficas**
- `StatsViewModel` tiene `recentHistory` y `prRecords` completos
- La pantalla muestra listas pero no charts
- Acción: Swift Charts — necesita diseño previo (¿qué métricas priorizar?)

**11. Pantalla post-workout casi vacía**
- `FeedbackView` recibe `[WorkoutLog]` con toda la data de la sesión
- Solo muestra puntos otorgados
- Acción: enriquecer con resumen de sets, PRs detectados, comparativa vs sesión anterior

**12. Sistema de color inconsistente**
- `HomeView` usa `Color.homeAccent` (naranja custom)
- `WorkoutExecutorView` usa `AppSemanticPalette`
- Algunos módulos usan `Color.teal` / `Color.blue` directos (no dark-safe)
- Acción: auditar todas las vistas y migrar a `AppSemanticPalette`

---

## Plan de acción priorizado

### Fase 1 — Refactorizar para agregar features sin riesgo

**Hacer primero, antes de cualquier feature nueva de Training:**

1. Extraer `WorkoutSessionCoordinator` desde ContentView
   - Mueve: `buildWorkoutExecutorViewModel`, `buildRoutineExecutorViewModel`, `loadOrCreateSessionId`, `clearSessionId`, `markRoutineDayCompleted`, `applyPerformanceUpdates`
   - ContentView lo crea e inyecta igual que los otros servicios
   - Resultado: ContentView ~480 → ~280 líneas; lógica testeable

2. Unificar `populateRecoveryContextLinesES/EN` en HomeViewModel
   - Una sola función `populateRecoveryContextLines(config:language:)`
   - Elimina ~140 líneas duplicadas

3. Eliminar `@Query` de WorkoutView
   - Usar solo `TrainingPlanViewModel` como fuente de verdad
   - Pasar `hasPlan` / `hasRoutine` desde el VM

### Fase 2 — Features que se pueden agregar YA sin tocar arquitectura

Estos son seguros de implementar sobre la arquitectura actual:

- **Gráficas en Stats**: Agregar Swift Charts en `StatsView`. El VM ya tiene los datos. Solo UI.
- **Post-workout enriquecido**: Mejorar `FeedbackView` con los `WorkoutLog` que ya recibe.
- **Nuevas insignias**: Agregar cases a `BadgeMilestone` + lógica en `GamificationEngine.isMilestoneReached`.
- **Nuevo ejercicio sustituto**: El catálogo y `alternateExerciseIds` ya lo soportan.
- **Notificaciones adicionales**: Extender `NotificationService` sin tocar otras capas.
- **Mejoras de UI en Perfil**: `ProfileView` está limpio y aislado.

### Fase 3 — Requieren diseño antes de implementar

Estos NO se deben tocar sin diseño previo:

- **Home scroll refactor**: Dividir en secciones independientes requiere definir si HomeViewModel se divide también o solo la vista.
- **Traducción de instrucciones**: Definir si es client-side (Translate API) o se pre-procesan los datos del catálogo.
- **Semana 2+ del plan con gráfica de progreso**: Requiere decidir cómo visualizar la progressión sin sobrecargar TrainingPlanViewModel.
- **Social / compartir**: Requiere decisiones de privacidad sobre datos de salud.
- **Nueva métrica HealthKit** (ej. VO2max): Tocar HealthKitManager siempre requiere revisión completa del pipeline de scoring.

---

## ⛔ No tocar sin consultar primero

| Archivo / área | Por qué |
|---|---|
| `Core/HealthKitManager.swift` | Afecta todo el scoring; cambio en queries puede romper datos de sueño/HRV |
| `Repositories/TrainingPlanRepository.swift` | Lógica de avance de semana, performance updates; errores aquí corrompen el plan |
| `ContentView.swift` — flujo de sheets de workout | La orquestación executor → complete → feedback es frágil y tiene workarounds de SwiftData |
| Schema SwiftData (`@Model` classes) | Requiere migration si se añaden/eliminan propiedades; probar en dispositivo real |
| `Core/TrainingPlanGenerator.swift` | Cambios aquí afectan todos los planes generados; requiere tests |
| `Core/RecoveryAdapter.swift` | Calibrado contra datos reales; modificar los multiplicadores requiere validación |

---

## Entorno de testing

```
Tests/
├── UnitTests/
│   ├── DayManagerTests.swift
│   ├── DetoxManagerTests.swift
│   ├── ExerciseServiceTests.swift
│   ├── HealthKitManagerTests.swift
│   ├── ProgressTrackerTests.swift
│   ├── RecoveryAdapterTests.swift
│   ├── RoutineSessionStoreTests.swift
│   └── SleepHistoryAggregatorTests.swift
└── PropertyTests/
    └── SleepWindowValidationPropertyTests.swift
```

Todo código nuevo en `Core/` debe tener tests unitarios.
Los ViewModels no tienen tests actualmente (no crítico si el VM solo orquesta).

---

## Specs en `.kiro/`

El directorio `.kiro/specs/` contiene especificaciones de features:
- `activity-progress-insights/`
- `body-metrics-onboarding/`
- `sleep-window-goal/`
- `sleep-window-recovery-validation/`
- `smart-fitness-coach/`
- `smart-home-dashboard/`
- `smart-training-plan/`

Antes de implementar una feature, revisar si hay spec en este directorio.
