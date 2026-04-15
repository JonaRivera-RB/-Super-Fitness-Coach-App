# Bugs conocidos

Registro de **bugs activos** reproducibles: síntomas, dónde mirar y qué ya se probó.  
Actualizar al **cerrar** un bug (mover a “Resueltos” con fecha y PR/commit si aplica).

**Última pasada por el repo:** búsqueda de `TODO` / `FIXME` / `HACK` en `Super Fitness Coach App/**/*.swift` — **sin coincidencias** que indiquen bug pendiente explícito en código.

---

## Bugs activos

| ID | Síntomas | Módulos sospechosos | Qué ya se intentó | Estado |
|----|----------|---------------------|-------------------|--------|
| — | *Ninguno registrado aquí todavía.* | — | — | — |

**Cómo añadir una fila:** asignar `KB-001`, `KB-002`, …; describir el síntoma en pasos; listar archivos o carpetas; anotar fixes o diagnósticos fallidos para no repetir trabajo.

---

## Candidatos a verificar (no confirmados como bug)

Cosas que pueden parecer fallos pero **no están validadas** como registro en esta tabla:

| Tema | Por qué sospechar | Cómo confirmar |
|------|---------------------|----------------|
| **Companion Apple Watch** | Existe `WCSessionManager` y modelos `Watch*`; no hay target watch documentado como producto terminado en `PROJECT_OVERVIEW.md`. | Probar flujo con reloj emparejado; revisar si la app watch está en el mismo workspace. |
| **Deployment target iOS** | El `.xcodeproj` declara `IPHONEOS_DEPLOYMENT_TARGET = 26.1` (valor inusual). | Confirmar en Xcode que coincide con el SDK deseado; corregir si fue un typo. |
| **Notificación de descanso** | Si el usuario denegó notificaciones, no sonará el aviso al terminar el descanso con el teléfono bloqueado. | Revisar ajustes del sistema; flujo de `NotificationService.requestPermission()`. |

Cuando uno de estos pase a **reproducible y no intencional**, moverlo a la tabla **Bugs activos** con ID `KB-xxx`.

---

## Resueltos recientemente (referencia; no reabrir sin nueva repro)

Estos problemas **ya se abordaron** en el código según el historial del proyecto; sirven para evitar duplicar informes.

| Tema | Qué pasaba | Enfoque aplicado (resumen) |
|------|------------|----------------------------|
| Mi rutina — barra / anillos / semana (Workout tab) | Barra de resumen al 100% con rutina vacía; anillos del plan visibles al elegir superficie Mi rutina; criterio de «esta semana» distinto entre anillo y píldoras. | `CHANGELOG_AI` [2026-04-15]; días configurados en barra; `workoutSurface` en `WorkoutInsightsCalculator`; helper único de semana; subtítulo en gráfica de volumen en superficie rutina. |
| Finalización del entreno | La rutina se marcaba terminada con series pendientes (saltar último ejercicio o completar en orden incorrecto). | Lógica global de “todas las series completadas” en `WorkoutExecutorViewModel` (`advanceToNextExercise`, etc.). |
| Catálogo vacío / nombres “Ejercicio” | Primera ejecución sin datos o instancias distintas de `ExerciseService`. | `ExerciseService.shared`, `configure(modelContext:)`, import desde fixtures; `nameEs` vacío para fallback EN en import. |
| “Mi rutina” mostraba catálogo viejo | Vistas con `ExerciseService()` nuevo sin contexto. | Uso de `ExerciseService.shared` + `configure` en `onAppear`. |
| Picker de rutina cerraba al agregar | UX de añadir varios ejercicios. | Sheet sin `dismiss` inmediato, feedback y anti-duplicados en `RoutineEditorView`. |
| Conversión lb/kg confusa | Redondeos que parecían adivinación. | `UnitConverter` + texto explícito en UI (`AppLocalizedStrings`, `WorkoutExecutorView`). |
| Live Activity / provisioning | Error de perfil sin entitlement ActivityKit; opción no visible en Xcode según cuenta. | **Plan B:** notificación local al fin de descanso; Live Activity desactivada en código/entitlements hasta decisión explícita (`DECISIONS.md`). |

Si algo de esta lista **vuelve a ocurrir** en una build actual, añadir de nuevo en **Bugs activos** con pasos y versión.

---

## Notas para el agente

- Antes de marcar algo como bug, reproducir en dispositivo/simulador y anotar **versión de iOS** y **rama**.
- Priorizar sospechosos listados en `MODULE_MAP.md` → “Puntos frágiles” y `DECISIONS.md` → tradeoffs.
- No borrar filas de **Resueltos** sin motivo; añadir nueva fila en **Activos** si la regresión existe.
