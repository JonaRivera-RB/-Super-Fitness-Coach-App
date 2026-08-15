# Decisiones

Por qué el proyecto está construido como está. `CLAUDE.md` describe **cómo**; este archivo
guarda el **por qué** y el coste que se aceptó a cambio.

Estas decisiones ya están tomadas. No hace falta rediscutirlas para trabajar; hace falta
conocerlas para no "arreglar" a ciegas algo que es intencional.

> **Revisadas contra el código el 2026-08-15.** D3 y D10 se corrigieron en esa pasada: describían
> un estado que el código ya había dejado atrás.

**Para modificar una decisión:** edítala aquí con fecha y motivo, y menciona su número en el
commit. Si la revocas, no borres la entrada — márcala revocada. El valor está en el registro.

---

## Vigentes

### D1 — Persistencia local con SwiftData

Todo el estado de dominio vive en SwiftData, registrado en `Super_Fitness_Coach_AppApp`.

**Por qué:** offline-first, una sola stack, integración natural con SwiftUI.
**Coste:** las migraciones de schema hay que cuidarlas a mano y probarlas en dispositivo real con
datos previos. No hay sincronización entre dispositivos.

### D2 — Sin capa de casos de uso

La lógica se reparte entre ViewModels `@Observable`, servicios de `Core/` y repositorios. No hay
capa intermedia de use cases ni contenedor de inyección de dependencias.

**Por qué:** menos archivos y más velocidad para un equipo pequeño.
**Coste:** las reglas de negocio quedan repartidas. Para un cambio transversal hay que conocer
varios sitios a la vez.

### D3 — Cableado en `ContentView`, sesión de entreno en su propio coordinador

`ContentView` es el composition root: construye servicios y ViewModels, y gestiona tabs,
onboarding y estado de sheets. La lógica de la sesión de entreno vive aparte, en
`Core/WorkoutSessionCoordinator.swift`.

**Por qué:** un único sitio donde cablear dependencias, pero sin que el ciclo de vida del entreno
—la parte con más lógica y más frágil— quede atrapado en la capa de presentación.
**Coste:** `ContentView` sigue siendo el archivo que cualquier feature nueva de Training o Workout
tiene que tocar.

> *Corregida el 2026-08-15.* La versión anterior decía que la construcción de los executors vivía
> en `ContentView` y listaba extraerla como trabajo pendiente. Ya estaba hecho.

### D4 — Catálogo de ejercicios: import desde fixtures, no desde la API en vivo

Los ejercicios se importan desde los **fixtures de wger en GitHub raw**
(`raw.githubusercontent.com/wger-project/wger/master/wger/exercises/fixtures`) hacia
`ExerciseCatalogEntry` en SwiftData. La UI nunca depende de `wger.de` en tiempo de uso.
`ExerciseCatalogImporter` conserva la ruta a la API v2, pero la estrategia primaria es fixtures.

**Por qué:** el catálogo no puede caerse porque un servicio de terceros esté caído. Dataset
reproducible y offline real.
**Coste:** si wger cambia el formato hay que reimportar. Las traducciones al español están
incompletas y se compensan con fallback a inglés.

### D5 — Identidad de ejercicio: `id` local + `wgerUuid`

Cada entrada del catálogo tiene un `id: UUID` propio de la app y un `wgerUuid` (único) para
correlacionar con el origen.

**Por qué:** desacoplar el modelo interno del identificador externo, dejando la puerta abierta a
migrar o sincronizar sin reescribir referencias.
**Coste:** rutinas e historial deben referenciar siempre el identificador estable acordado.
Quitar `wgerUuid` rompe el historial del usuario.

### D6 — `ExerciseService.shared` + `configure(modelContext:)`

Un singleton recibe el `ModelContext` desde la raíz; algunas vistas lo reconfiguran en `onAppear`.

**Por qué:** en el primer arranque, instancias separadas del servicio producían un catálogo vacío
y ejercicios sin nombre. El singleton lo resolvió.
**Coste:** es un global, y hay que llamar a `configure` antes de buscar o importar. Convive con la
inyección desde `ContentView`, lo cual es contradictorio — ver `PENDIENTES.md` → P5.

### D7 — Sesión de entreno identificada vía `UserDefaults`

Los `sessionId` del plan semanal y de "Mi rutina" se guardan en `UserDefaults` y se enlazan a
`SetLogger` y `WorkoutLog`. Los gestiona `WorkoutSessionCoordinator`.

**Por qué:** permite reanudar un entreno interrumpido y agrupar las series de una misma sesión sin
servidor.
**Coste:** cambiar el formato de las claves rompe la continuidad de sesiones en curso y puede
duplicar entrenos. Migrar estas claves exige plan.

### D8 — Sin autenticación ni backend

No hay login, ni OAuth, ni tokens. El usuario es un `UserProfile` local más los permisos del
sistema (HealthKit, notificaciones).

**Por qué:** producto local-first. Los datos de salud no salen del dispositivo.
**Coste:** cualquier sincronización multi-dispositivo o función social requiere decisión nueva,
migración de identidad y una revisión de privacidad seria: son datos de salud.

### D9 — Temporizador de descanso por notificación local; ActivityKit desactivado

El aviso de fin de descanso con el teléfono bloqueado usa `UserNotifications`, más haptics en
foreground. **Live Activity / ActivityKit está desactivado**, y el entitlement no está en el
target principal.

**Por qué:** ActivityKit exigía fricción de provisioning y capabilities que no compensaba
mientras el producto se estabilizaba. Esto fue un Plan B explícito, no un olvido.
**Coste:** no hay cuenta atrás en la pantalla de bloqueo. Si el usuario denegó las notificaciones,
no recibe el aviso.

Reactivarlo exige las tres cosas a la vez: entitlement, target de extensión alineado y
actualización de esta entrada.

### D10 — Solo iOS, más extensión de widgets

Hay tres targets: la app iOS, la extensión WidgetKit y los tests.

**Por qué:** alcance incremental. Primero el teléfono.
**Coste:** existe una carpeta `Super Fitness Coach Watch App/` con código de una companion app que
**no está en ningún target**: no compila y no forma parte del producto. `Core/WCSessionManager.swift`
sí compila, pero nadie lo usa. Ver `PENDIENTES.md` → P1.

> *Corregida el 2026-08-15.* La versión anterior describía el Watch como "preparatorio en código",
> lo que sugería trabajo en curso. Es código huérfano; hay que decidir entre adoptarlo o borrarlo.

---

## No cambiar sin acuerdo explícito

Refactors que parecen mejoras evidentes y no lo son en este proyecto:

1. **No** introducir un contenedor IoC ni capas de "arquitectura limpia" (D2).
2. **No** reescribir de golpe la orquestación de `ContentView`. Cambios incrementales; ya se hizo
   así con `WorkoutSessionCoordinator` y funcionó.
3. **No** cambiar SwiftData por Core Data ni por JSON plano sin plan de migración (D1).
4. **No** volver a la API en vivo de wger como fuente principal del catálogo (D4).
5. **No** quitar `wgerUuid` de modelos o logs sin migración (D5).
6. **No** reactivar ActivityKit a medias (D9).
7. **No** añadir login obligatorio ni dependencia de backend (D8).
8. **No** meter literales de texto en las vistas: van en `AppLocalizedStrings`, en los dos idiomas.

Un bugfix acotado a una vista o a un cálculo no necesita tocar nada de esto.
