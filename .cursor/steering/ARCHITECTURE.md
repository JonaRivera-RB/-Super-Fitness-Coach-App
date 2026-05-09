# Arquitectura (código real)

Este documento describe **lo que el repo hace hoy**, no un diseño ideal. Actualizar cuando cambien flujos centrales.

---

## Patrón usado (real)

- **SwiftUI** como capa de UI.
- **ViewModels con `@Observable` (Observation)** para pantallas con lógica de presentación y orquestación: `HomeViewModel`, `StatsViewModel`, `ProfileViewModel`, `TrainingPlanViewModel`, `TrainingPreferencesViewModel`, `WorkoutExecutorViewModel`, `ExerciseService`, etc.
- **Repositorios** delgados sobre **SwiftData** (`TrainingPlanRepository`, `UserProfileRepository`, `UserRoutineRepository`, …) para leer/escribir modelos persistidos.
- **Servicios** como tipos de referencia (`HealthKitManager`, `NotificationService`, `GamificationEngine`, `DetoxManager`, `ExerciseCatalogImporter` usado vía `ExerciseService`): no hay un contenedor IoC; se **instancian o comparten** desde la raíz de la app.
- No hay capa “Use Cases” explícita; la lógica vive en ViewModels, Core y repositorios según el caso.

---

## Navegación

- **Raíz**: `ContentView` decide entre **ProgressView** (carga), **OnboardingView** o **`TabView`** con cuatro pestañas (`home`, `workout`, `stats`, `profile`).
- **Modales / sheets** (todos anclados desde `ContentView` o desde el tab Entreno):
  - Preferencias de plan → `TrainingPreferencesView`
  - Editor de rutina → `RoutineEditorView`
  - Ejecución de entreno → `WorkoutExecutorView` + `WorkoutExecutorViewModel` empaquetado en un `ExecutorItem` identificable
  - Feedback post-entreno → `FeedbackView`
- **Navegación stack** dentro de features: `NavigationStack` / `NavigationView` donde cada vista lo define (no hay un router global único).
- **Entorno SwiftUI**: `\.appLanguage` inyectado en el `TabView` para hijos.

---

## Manejo de estado

| Mecanismo | Uso típico en el proyecto |
|-----------|---------------------------|
| `@State` en `ContentView` | Servicios de larga vida (`HealthKitManager`, `NotificationService`), flags de onboarding, tab seleccionada, sheets, ViewModels cacheados para no recrearlos en cada render. |
| `@Environment(\.modelContext)` | Acceso a SwiftData desde vistas que guardan o consultan. |
| `@Query` | Listas reactivas al store (p. ej. `WorkoutView`, `RoutineEditorView`, `ProfileView` para catálogo). |
| `@Bindable` | Binding a ViewModels `@Observable` (`ProfileView`, `WorkoutExecutorView`, …). |
| `UserDefaults` | **IDs de sesión de entreno** del plan y de «Mi rutina» (claves tipo `trainingSession|…`, `routineSession|…`); limpieza al completar. |
| `@AppStorage` | Preferencias ligeras (p. ej. idioma `AppLanguage.storageKey`). |
| `Timer` + `Date` deadline | Temporizador de descanso en `WorkoutExecutorViewModel` (sincronización al volver de background vía `scenePhase` en la vista). |

No hay un store global tipo Redux; el estado “de producto” vive en **SwiftData** y en **ViewModels** por pantalla.

---

## Red

- **No** hay cliente REST genérico para la app de entrenamiento día a día.
- **Uso principal de red**: importar el **catálogo de ejercicios** desde URLs estáticas (fixtures wger en GitHub raw) dentro de `ExerciseService.ensureLocalCatalogImportedIfNeeded()` / `ExerciseCatalogImporter`, vía **`URLSession`** (inyectable en `ExerciseService`, por defecto `.shared`).
- Tras importar, las pantallas consumen el catálogo **solo desde SwiftData** (`ExerciseCatalogEntry`).

Fallos de red: reintentos en importación; si el catálogo sigue vacío, errores tipados (`CatalogError.emptyCatalog`, etc.) en búsqueda/listados.

---

## Persistencia

- **SwiftData** es la fuente de verdad local: modelos registrados en `Super_Fitness_Coach_AppApp` (`UserProfile`, `TrainingPlan`, `WorkoutLog`, `UserRoutine`, `ExerciseCatalogEntry`, …).
- **UserDefaults** complementa con identificadores de sesión de entreno para reanudar sin mezclar logs entre arranques/días.
- **UserNotifications**: notificaciones programadas (diarias, fin de descanso); no sustituyen al modelo de datos.

No hay sincronización cloud ni migración Firebase en el flujo actual descrito en código.

---

## Inyección de dependencias

- **Patrón real: “composition root” en `ContentView` + constructores.**
  - `initializeServices()` crea o asigna repositorios y `ExerciseService.shared`, llama `exerciseService.configure(modelContext:)` y dispara import del catálogo en `Task`.
  - `createViewModels()` construye ViewModels pasando explícitamente dependencias (repos, `HealthKitManager`, `NotificationService`, `ExerciseService`, etc.).
- **`ExerciseService.shared`**: singleton configurado con `ModelContext` desde la raíz; varias vistas llaman `ExerciseService.shared` + `configure` en `onAppear` para no depender de un provider inyectado.
- **`WorkoutExecutorViewModel`**: recibe `SetLogger`, `HealthKitManager`, etc.; **`NotificationService` tiene valor por defecto `NotificationService()` en el `init`**, así que si el caller no lo pasa, cada executor usa **una instancia nueva** del servicio de notificaciones (el centro `UNUserNotificationCenter` sigue siendo el del sistema; el objeto wrapper es distinto).
- **Previews**: `modelContainer` local en `#Preview` donde hace falta.

No hay Swinject, ni EnvironmentObject global para servicios (salvo `appLanguage` y `modelContext` del sistema).

---

## Auth / sesión (cómo se maneja en la práctica)

- **No hay login**, OAuth ni tokens de backend en el código actual.
- **“Usuario” de la app**: registro local **`UserProfile`** en SwiftData; el onboarding marca perfil completado vía `UserProfileRepository.fetchCompleted()`.
- **Permisos de sistema** (no son sesión de cuenta):
  - **HealthKit**: autorización y estado en `HealthKitManager` / modelos de estado de autorización.
  - **Notificaciones**: `NotificationService.requestPermission()` al arranque en `ContentView`.
- **Sesión de entreno**: identificador **string** (`sessionId`) asociado al día del plan o al día calendario de la rutina, persistido en **UserDefaults** y enlazado a `SetLogger` / `WorkoutLog`; al completar se limpian claves y se actualiza el plan o la rutina en SwiftData.

Para un futuro Firebase/auth, hoy no hay hook centralizado: habría que definir explícitamente capa de identidad y sincronización.

---

## Cómo validar que este doc sigue siendo cierto

- Buscar `TabView`, `.sheet` y `ExecutorItem` en `ContentView.swift`.
- Buscar `@Observable` y `Repository(context:` en Features/Core.
- Confirmar `modelContainer(for:)` en `Super_Fitness_Coach_AppApp.swift`.
- Revisar `ExerciseService` / `ExerciseCatalogImporter` para URLs y `URLSession`.
