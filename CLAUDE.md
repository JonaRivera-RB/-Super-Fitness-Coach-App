# VitrikFit — Fuente de la verdad

App de fitness iOS en SwiftUI + SwiftData. Este archivo describe **cómo está construido el
proyecto y cómo escribir código nuevo en él**.

> **Verificado contra el código el 2026-08-15.** Todo lo que sigue se comprobó ejecutando
> búsquedas sobre el repo, no se heredó de documentación previa.

---

## Cómo no pudrir este archivo

La documentación anterior de este repo se borró entera porque afirmaba cosas falsas: daba por
pendiente un refactor que ya estaba hecho, ignoraba 13 archivos de `Core/` y describía un target
de watchOS que no existe. Se pudrió por dos causas concretas. Evítalas:

1. **No dupliques este archivo.** Había 5 copias byte a byte en `.cursor/steering/` que se
   desincronizaron. Si otra herramienta necesita contexto, apúntala aquí; no copies.
2. **No escribas aquí lo que el código ya dice.** Nada de conteos de líneas, inventarios de
   archivos ni listas de funciones: `find` y `grep` lo regeneran en un segundo y siempre estarán
   más al día que un `.md`. Este archivo es para lo que el código **no puede** decir — por qué
   algo se decidió así, qué invariante no fuerza el compilador, qué se rompe si tocas X.

Regla práctica: si puedes responder la pregunta con un `grep`, no va aquí.

---

## Qué es el producto

Entrenamiento adaptado a tu recuperación real. La app lee HealthKit (HRV, frecuencia cardiaca en
reposo, sueño), calcula un **recovery score** diario y **ajusta el entrenamiento del día** en
consecuencia: si dormiste mal, baja el peso y el volumen.

Alrededor de ese núcleo hay: plan guiado semanal con progresión automática, "Mi rutina"
personalizable como alternativa, gamificación (puntos, niveles, racha, insignias), catálogo de
ejercicios offline y un challenge alcohol-free. Bilingüe ES/EN.

**Local-first**: no hay backend, ni login, ni sincronización. El usuario es un `UserProfile` en
SwiftData más los permisos del sistema. Ver `DECISIONS.md` (D1, D8).

---

## Targets y build

Hay **tres** targets, y solo tres:

| Target | Qué es |
|---|---|
| `Super Fitness Coach App` | La app iOS |
| `SuperFitnessCoachWidgetsExtension` | Extensión WidgetKit |
| `Super Fitness Coach AppTests` | Unit + property tests |

- Bundle: `com.riverland.Super-Fitness-Coach-App` · Swift 5.0 · deployment target iOS 26.1
- Entitlements: HealthKit y HealthKit background delivery. **ActivityKit está deliberadamente
  ausente** (D9).
- El proyecto usa **grupos sincronizados con el sistema de archivos**
  (`PBXFileSystemSynchronizedRootGroup`) sobre `Super Fitness Coach App/`, `Tests/` y
  `SuperFitnessCoachWidgets/`. Consecuencia práctica: **añadir un `.swift` dentro de esas carpetas
  lo mete al build automáticamente**, no hay que tocar el `.xcodeproj`. Y a la inversa: un archivo
  fuera de esas tres rutas no compila aunque exista.

⚠️ La carpeta `Super Fitness Coach Watch App/` **no está en ningún target ni grupo sincronizado**:
es código huérfano que no compila. Ver `PENDIENTES.md` → P1.

---

## Arquitectura

**MVVM + Composition Root + Repository.** Sin capa de casos de uso (D2), sin contenedor de
inyección de dependencias.

### Regla de dependencia (la invariante central)

```
Vista  →  ViewModel  →  Servicio (Core/)  →  Repositorio  →  SwiftData
```

Las flechas van en una sola dirección y **ninguna vista ni ViewModel toca `ModelContext`**. Solo
los repositorios hablan con SwiftData.

Excepciones reales que existen hoy, ambas conocidas y acotadas:
- `RoutineEditorView` usa `modelContext` directamente.
- `WorkoutView` usa `@Query` además del ViewModel inyectado — dos fuentes de verdad, ver
  `PENDIENTES.md` → P2.

No añadas excepciones nuevas sin registrarlas ahí.

### Composition Root

`ContentView` es donde se cablea todo. Construye los servicios y los ViewModels, los guarda en
`@State` opcionales, y expone `servicesReady` para no renderizar hasta que estén listos. También
gestiona los tabs, el onboarding y el estado de las sheets.

La lógica de la **sesión de entreno** ya **no** vive aquí: está en
`Core/WorkoutSessionCoordinator.swift`, que construye los executors, resuelve los `sessionId` y
marca días completados. Si necesitas tocar el flujo entreno → executor → feedback, ese es el
archivo.

### Capas

- **`Core/`** — servicios de negocio. Los `@Observable` con estado (`HealthKitManager`,
  `GamificationEngine`, `ExerciseService`, `ExerciseImageLoader`, `DetoxManager`,
  `WorkoutSessionCoordinator`) y los `struct` sin estado (generadores, scorers, adapters,
  formatters).
- **`Models/`** — 11 `@Model` de SwiftData más enums y value types de apoyo.
- **`Repositories/`** — único punto de acceso a SwiftData. Reciben `ModelContext` en el `init`,
  nunca lo leen del entorno.
- **`Features/<Nombre>/`** — una carpeta por pantalla, con su `View` y su `ViewModel`.

### Schema SwiftData

Registrado en `Super_Fitness_Coach_AppApp.swift`. Añadir o quitar una propiedad de cualquiera de
estos modelos **requiere pensar en migración y probar en dispositivo real con datos previos**:

`UserProfile` · `TrainingPlan` · `TrainingWeek` · `TrainingDayPlan` · `WorkoutLog` ·
`UserRoutine` · `UserRoutineDay` · `GamificationState` · `RecoverySnapshot` · `DetoxProgress` ·
`ExerciseCatalogEntry`

Un modelo nuevo hay que registrarlo en el `.modelContainer` o no persiste.

---

## Convenciones

### ViewModels

```swift
@Observable
final class MiViewModel {
    private(set) var estado: String = ""      // el estado se expone solo-lectura

    @ObservationIgnored
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "MiVM")

    func onAppear() async { ... }
}
```

`@Observable` del framework Observation. **No** `ObservableObject`, **no** Combine.
`@ObservationIgnored` en todo lo que no sea estado observable (loggers, dependencias) para no
disparar invalidaciones de vista inútiles.

### Vistas

```swift
struct MiView: View {
    var viewModel: MiViewModel                 // var, no @State: el VM ya es @Observable
    @Environment(\.appLanguage) private var lang
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // ...
        .task { await viewModel.onAppear() }
    }
}
```

El ViewModel se recibe como `var`, no como `@State`. Envolverlo en `@State` en la vista hija crea
una segunda instancia.

### Textos

Todas las cadenas de UI van en `Core/AppLocalizedStrings.swift`, como propiedades de
`AppLanguage`, siempre en **los dos idiomas**:

```swift
var miClave: String {
    switch self {
    case .spanish: return "Texto en español"
    case .english: return "Text in English"
    }
}
```

En la vista: `Text(lang.miClave)`. Nunca literales sueltos en las vistas.

### Color

Dos sistemas conviven y hay que saber cuál usar:

- **`DesignTokens`** — el sistema actual, introducido con el rediseño de Home. Es al que se está
  migrando.
- **`AppSemanticPalette`** — el anterior, seguro en dark/light. Sigue en uso en varias pantallas.

Para código nuevo usa `DesignTokens`. Nunca `Color.blue` / `Color.teal` directos: no son
dark-safe. Un color de branding propio de un módulo puede vivir en una extensión privada de ese
archivo (como `Color.homeAccent` en Home); eso es correcto, no deuda.

### Datos de HealthKit

Nunca asumas que hay valor. El estado es un enum de tres casos y hay que cubrir los tres:

```swift
switch viewModel.recoveryScore {
case .loading:            ProgressView()
case .unavailable:        Text("—")
case .available(let v):   Text("\(v)")
}
```

Este es el error más fácil de cometer en esta app: HealthKit puede no tener datos (usuario sin
Watch, permisos denegados, primer arranque) y la UI tiene que sostenerlo sin romperse.

### Logging

```swift
private let logger = Logger(subsystem: "com.superfitnesscoach", category: "NombreClase")
```

`subsystem` siempre ese; `category` el nombre de la clase.

---

## Dónde va cada cosa

| Necesito… | Va en… |
|---|---|
| Pantalla nueva | `Features/<Nombre>/<Nombre>View.swift` + `<Nombre>ViewModel.swift` |
| Servicio de negocio con estado | `Core/<Nombre>Service.swift`, `@Observable final class` |
| Cálculo sin estado | `Core/<Nombre>.swift`, `struct` con funciones puras |
| Acceso a datos | `Repositories/<Nombre>Repository.swift` |
| Modelo persistido | `Models/` + registrar en `Super_Fitness_Coach_AppApp.swift` |
| Cadena de UI | `Core/AppLocalizedStrings.swift`, ES y EN |
| Tab nuevo | Enum `Tab` de `ContentView` + case en el `TabView` |
| Sheet del flujo de entreno | `ContentView` (necesita el coordinator) |
| Sheet local de una pantalla | La propia vista |

Las funciones puras de `Core/` son el sitio preferente para lógica nueva: son las únicas
trivialmente testeables sin HealthKit ni SwiftData.

---

## Zonas frágiles

No son intocables, pero exigen leer antes y validar después.

| Zona | Por qué |
|---|---|
| `Core/HealthKitManager.swift` | El archivo más grande y central. Autorización, fetch de sueño, recovery score, activity score, consistencia de sueño, observers en background. Alimenta Home, notificaciones y el ajuste del entreno: un cambio en las queries se propaga a todo |
| `Repositories/TrainingPlanRepository.swift` | Avance de semana y actualización de rendimiento. Un error aquí corrompe el plan del usuario de forma persistente |
| `Core/TrainingPlanGenerator.swift` | Afecta a todos los planes generados |
| `Core/RecoveryAdapter.swift` | Los multiplicadores están calibrados contra datos reales; cambiarlos a ojo desajusta el producto entero |
| `Core/WorkoutSessionCoordinator.swift` + sheets de entreno | La orquestación executor → complete → feedback tiene workarounds de SwiftData |
| Cualquier `@Model` | Migración de schema |

---

## Tests

`Tests/UnitTests/` y `Tests/PropertyTests/`. Cubren sobre todo `Core/`: sueño, recuperación,
progreso, detox, catálogo y el motor de outlook de sueño.

- **Todo lo nuevo en `Core/` lleva test unitario.** Es la regla que sostiene la calidad aquí,
  porque los ViewModels no están testeados.
- Los ViewModels no tienen tests y no es crítico *mientras solo orquesten*. Si un ViewModel
  acumula lógica de negocio, esa lógica debe bajar a `Core/` y testearse ahí.

---

## Specs de producto

`.kiro/specs/` contiene 7 features especificadas (`requirements.md` + `design.md` + `tasks.md`).
**Revisa si existe spec antes de implementar una feature.** El estado de las que quedaron a medias
está en `PENDIENTES.md`.

---

## Los otros documentos

Este archivo dice **cómo está construido**. Los demás no lo repiten:

- **`DECISIONS.md`** — por qué está construido así. Decisiones vigentes con su tradeoff, y la
  lista de lo que no se cambia sin acuerdo explícito.
- **`PENDIENTES.md`** — deuda técnica verificada y specs a medio terminar.
- **`BUGS.md`** — bugs reproducibles y sospechas sin confirmar.
- **`ALGORITMOS_SUENO.md`** — material de referencia, no instrucciones. Cómo puntúan el sueño
  Oura, Apple y SleepWatch, y en qué se diferencia el composite de VitrikFit
  (`Core/SleepQualityScoring.swift`). Léelo antes de tocar el scoring de sueño: los pesos y las
  bandas de fase están calibrados, no son arbitrarios.
