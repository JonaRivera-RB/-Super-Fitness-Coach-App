# Super Fitness Coach App — visión del proyecto

Documento de referencia para alinear qué es la app, dónde vive la lógica y qué depende de qué. Actualizar cuando cambie el alcance o la arquitectura visible.

---

## Qué hace la app

Aplicación de **entrenamiento y coaching** en iOS que combina:

- **Plan de entrenamiento semanal** generado según preferencias del usuario, con días, ejercicios y progresión.
- **“Mi rutina”**: rutina personalizada por el usuario (editor de ejercicios y alternativas).
- **Ejecución de entrenos** (series, peso, descansos, temporizador de descanso con notificación al terminar).
- **Recuperación / “Recovery”** usando datos de salud (sueño, métricas relacionadas) para el **Home** y recomendaciones.
- **Gamificación y feedback** tras completar sesiones (p. ej. feedback post-entreno).
- **Catálogo de ejercicios offline-first** importado desde fixtures públicos (wger, vía GitHub) a **SwiftData** (`ExerciseCatalogEntry`), con búsqueda local y fallback ES/EN.
- **Estadísticas e historial** de entrenos.
- Flujos opcionales: **onboarding**, **detox** (seguimiento dedicado en el código).

Idioma de UI principalmente **español** (`AppLanguage`), configurable desde perfil.

---

## Plataformas

| Ámbito | Detalle |
|--------|---------|
| **OS principal** | **iOS** (proyecto Xcode nativo Swift). |
| **Dispositivos** | **iPhone y iPad** (`TARGETED_DEVICE_FAMILY = 1,2` en el `.xcodeproj`). |
| **Extensión** | Target **SuperFitnessCoachWidgets** (WidgetKit): widget de ejemplo; Live Activity puede reactivarse en el futuro según decisión de producto. |
| **Apple Watch** | Código preparatorio (`WCSessionManager`, modelos relacionados); no sustituye al flujo principal en teléfono. |

**Deployment target** configurado en el proyecto: **iOS 26.1** (revisar alineación con la versión de Xcode/SDK del equipo).

---

## Módulos principales (carpetas)

Ruta base: `Super Fitness Coach App/`.

| Área | Rol |
|------|-----|
| **`Super_Fitness_Coach_AppApp.swift`** | Punto de entrada; registra el **modelContainer** SwiftData. |
| **`ContentView.swift`** | Shell de la app: onboarding, tabs, servicios compartidos, sheets (entreno, preferencias, feedback, rutina). |
| **`Features/Home/`** | Pantalla principal (recovery, accesos al entreno). |
| **`Features/Workout/`** | Tab “Entreno”: plan generado, inicio de sesiones, acceso a Mi rutina y editor. |
| **`Features/Training/`** | Ejecución (`WorkoutExecutor*`), plan, preferencias de generación, detalle de ejercicio, feedback. |
| **`Features/Routine/`** | Editor de rutina personalizada y pickers de ejercicios. |
| **`Features/Stats/`** | Estadísticas e historial. |
| **`Features/Profile/`** | Perfil, ajustes, catálogo local, permisos. |
| **`Features/Onboarding/`** | Primer uso. |
| **`Features/Detox/`** | Flujo detox (si está activo en UI). |
| **`Core/`** | Servicios transversales: `ExerciseService`, `ExerciseCatalogImporter`, `HealthKitManager`, `NotificationService`, generación de plan, coach, unidades, etc. |
| **`Models/`** | Tipos SwiftData y dominio (`TrainingPlan`, `UserRoutine`, `ExerciseCatalogEntry`, …). |
| **`Repositories/`** | Acceso a datos SwiftData (plan, perfil, rutina, recovery, etc.). |
| **`SuperFitnessCoachWidgets/`** | Extensión de widgets (proyecto separado en el workspace). |

---

## Dependencias críticas

No hay `Package.swift` en la raíz; las dependencias son **frameworks de Apple** y datos embebidos/red:

| Dependencia | Uso |
|-------------|-----|
| **SwiftUI** | UI principal. |
| **SwiftData** | Persistencia local (perfil, planes, rutinas, logs, catálogo de ejercicios). |
| **HealthKit** + **background delivery** | Recovery, métricas; requiere capacidades en entitlements. |
| **UserNotifications** | Recordatorios diarios, **notificación al terminar descanso** en entreno (bloqueo del teléfono). |
| **WidgetKit** | Extensión de widgets. |
| **Red (HTTPS)** | Importación del catálogo desde **fixtures wger en GitHub** (`ExerciseCatalogImporter`); no es runtime “API en cada pantalla”. |
| **UserDefaults** | Sesiones de entreno / rutina (p. ej. IDs de sesión). |

Riesgo operativo: sin permisos de notificaciones, el aviso de fin de descanso no se programa; sin HealthKit autorizado, la parte de recovery queda limitada.

---

## Flujo principal del usuario

1. **Primera apertura**  
   Onboarding → creación/uso de perfil y permisos (salud según flujo).

2. **App principal (tabs)**  
   **Inicio** · **Entreno** · **Estadísticas** · **Perfil**

3. **Inicio**  
   Ve estado de recuperación/recomendaciones y puede ir al entreno.

4. **Entreno**  
   - Ve el **plan semanal** (si existe) y puede **generar/ajustar plan** (preferencias).  
   - Puede abrir **Mi rutina**, editar ejercicios y **iniciar una sesión** desde el plan o desde la rutina.  
   - Al iniciar, se abre el **executor** (series, pesos, descanso, notificación al acabar descanso).

5. **Al completar**  
   Feedback/gamificación según logs; plan o rutina se actualizan en SwiftData.

6. **Estadísticas**  
   Historial y métricas agregadas.

7. **Perfil**  
   Idioma, fitness, **catálogo local de ejercicios** (importación/reintento), otras preferencias.

---

## Cómo mantener este documento

- Tras cambios grandes (nuevo módulo, nueva persistencia, nueva capacidad de sistema), actualizar **módulos** y **dependencias críticas**.
- Si se reactiva Live Activity u otra extensión, documentarlo aquí y en entitlements.
