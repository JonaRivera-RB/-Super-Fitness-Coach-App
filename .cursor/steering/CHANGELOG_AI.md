# Changelog (trabajo asistido por IA)

Registro de **cambios introducidos o documentados con asistencia de IA**: qué, por qué, riesgo, validación y cómo revertir.

**Convención:** añadir entradas **al inicio** (más reciente arriba). Una entrada por “lote” lógico (misma sesión o mismo PR).

---

## [2026-05-06] — Home: perspectiva de sueño (reglas locales + Foundation Models opcional)

| Campo | Detalle |
|-------|---------|
| **Qué cambió** | `SleepOutlookFactsEngine` + `SleepOutlookNarrator` (FoundationModels con fallback), tarjeta en `HomeView`, `generateSleepOutlook` en `HomeViewModel`, strings en `AppLocalizedStrings`, tests `SleepOutlookFactsEngineTests`; scheme Xcode enlaza target de tests en Test Action. |
| **Por qué** | Feature planificada: lectura orientativa de sueño/recuperación on-device sin tocar scores en `HealthKitManager`. |
| **Riesgo** | **Medio-bajo.** Latencia opcional si Apple Intelligence genera texto; guardarraíles pueden forzar fallback a plantillas. |
| **Validación hecha** | `xcodebuild build` + `xcodebuild test -only-testing:…SleepOutlookFactsEngineTests` (éxito). |
| **Rollback plan** | `git revert` o checkout de archivos tocados + revert del `.xcscheme` si no se desea test action. |

---

## [2026-04-23] — Rediseño sleep score: 60/20/10/10, continuidad, techo por horas, confianza suave

| Campo | Detalle |
|-------|---------|
| **Qué cambió** | Nuevo `SleepQualityScoring` (duración no lineal, cap por pocas horas, REM/Deep en banda, ajuste aditivo de confianza); `SleepDetectionResult` + vigilia en `SleepSessionFilter`; `HealthKitManager` y recovery usan el composite; `sleepContinuitySubscore` en Home + fila en `SleepDetailScreen`. |
| **Por qué** | Plan producto: evitar compensación irreal REM/deep y alinear con HealthKit. |
| **Riesgo** | **Medio.** Números de sueño/recovery cambian respecto a la fórmula antigua; pruebas de `ExerciseService` obsoletas sustituidas por smoke (API ya sin `parseExercises`). |
| **Validación hecha** | `xcodebuild build-for-testing` (éxito). `xcodebuild test` falló en simulador (Mach -308) en el entorno; compila tests. |
| **Rollback plan** | `git checkout --` de los archivos listados o `git revert` del commit. |

---

## [2026-04-22] — Steering: análisis comparativo algoritmos de sueño (Oura, Apple, SleepWatch)

| Campo | Detalle |
|-------|---------|
| **Qué cambió** | Nuevo [.cursor/steering/SLEEP_ALGORITHMS_OURA_APPLE_SLEEPWATCH.md](SLEEP_ALGORITHMS_OURA_APPLE_SLEEPWATCH.md): marco público de staging/score de terceros y relación con VitrikFit (HealthKit + reglas locales). |
| **Por qué** | Documentar referencia de producto sin tocar lógica de `HealthKitManager`. |
| **Riesgo** | **Nulo.** Solo documentación en steering. |
| **Validación hecha** | Revisión de contenido frente al plan acordado (sin editar el archivo `.cursor/plans/*.plan.md`). |
| **Rollback plan** | `git checkout --` del steering añadido y de esta entrada en `CHANGELOG_AI.md`. |

---

## [2026-04-15] — Racha (Home/Stats): reset visual a medianoche

| Campo | Detalle |
|-------|---------|
| **Qué cambió** | `GamificationEngine.displayedStreak()` muestra **0** si hoy no se ha entrenado (después de medianoche), sin romper la racha interna para cuando se entrene hoy; Home/Stats/Feedback usan este valor para UI. |
| **Por qué** | Requisito de producto: la racha “se termina” automáticamente a las 00:00 si ese día no entrenas. |
| **Riesgo** | **Bajo.** Solo afecta el valor mostrado; la racha real sigue en `currentStreak` para sumar correctamente cuando entrenes hoy. |
| **Validación hecha** | `xcodebuild -scheme "Super Fitness Coach App" -destination 'platform=iOS Simulator,name=iPhone 17' build` (éxito). |
| **Rollback plan** | `git checkout --` de los archivos tocados o `git revert` del commit. |

---

## [2026-04-15] — Mi rutina (Workout tab): barra semanal, anillos por superficie, semana calendario

| Campo | Detalle |
|-------|---------|
| **Qué cambió** | Nuevo `WorkoutSurface.swift`; `WorkoutInsightsCalculator.compute` recibe `workoutSurface` — en superficie **Mi rutina** solo el anillo de consistencia de rutina (sin mezclar plan/hoy/volumen del plan); barra de cabecera de rutina usa **días configurados** (ejercicios o descanso explícito) / 7; píldoras «Esta semana» y anillo usan `isDate(..., .weekOfYear)` vía `isDateInSameCalendarWeekAsReference`; subtítulo ES/EN bajo la gráfica de volumen en superficie rutina; `refreshInsights` al cambiar el segmented control; `AppLocalizedStrings.workoutVolumeTrendRoutineSubtitle`. |
| **Por qué** | Evitar barra llena sin ejercicios, métricas del plan mezcladas al editar Mi rutina, y divergencia año/semana entre anillo y píldoras. |
| **Riesgo** | **Bajo–medio.** Cambia significado de la barra y qué anillos se muestran al conmutar Plan/Rutina; la gráfica de volumen sigue siendo global (solo copy aclaratorio). |
| **Validación hecha** | `xcodebuild -scheme "Super Fitness Coach App" -destination 'platform=iOS Simulator,name=iPhone 17' build` (éxito). |
| **Rollback plan** | `git checkout --` de los archivos tocados o `git revert` del commit. |

---

## [2026-04-09] — Documentación de proyecto + regla de agente

| Campo | Detalle |
|-------|---------|
| **Qué cambió** | Nuevos archivos: `PROJECT_OVERVIEW.md`, `ARCHITECTURE.md`, `MODULE_MAP.md`, `DECISIONS.md`, `KNOWN_BUGS.md`, `CHANGELOG_AI.md`; regla `.cursor/rules/agent-change-discipline.mdc`. |
| **Por qué** | Fuente de verdad para humanos y agentes: alcance, arquitectura real, mapa de features, decisiones, bugs conocidos y disciplina de cambios. |
| **Riesgo** | **Bajo.** Solo markdown y regla Cursor; no afecta compilación ni runtime. |
| **Validación hecha** | Revisión de consistencia con `ContentView`, `ExerciseService`, `WorkoutExecutorViewModel`, `project.pbxproj` y entitlements donde aplica; búsqueda `TODO`/`FIXME` para `KNOWN_BUGS.md`. `xcodebuild` no re-ejecutado en CI como parte de esta tarea. |
| **Rollback plan** | Borrar o revertir por git los archivos listados; quitar `.cursor/rules/agent-change-discipline.mdc` si no se desea la regla. |

---

## [Iteración previa en rama `feature/fix-home-recovery`] — Entreno, catálogo local, notificaciones (resumen)

*Esta entrada resume trabajo de código ya presente en el árbol; ajustar fechas/commits si se fusiona a otra rama.*

| Campo | Detalle |
|-------|---------|
| **Qué cambió** | Entre otros: catálogo wger vía fixtures GitHub → SwiftData (`ExerciseCatalogImporter`, `ExerciseCatalogEntry`, `ExerciseService.shared`); limpieza de APIs viejos; flujo Mi rutina con picker sin cerrar al agregar y anti-duplicados; lógica de fin de entreno global en `WorkoutExecutorViewModel`; notificaciones al terminar descanso (`NotificationService`) con texto más informativo; conversión lb/kg y UI (`UnitConverter`, `WorkoutExecutorView`); detalle de ejercicio con media (`ExerciseDetailView`, `SafariView`); **Live Activity / ActivityKit desactivada** en código y entitlements; extensión de widgets mantenida compilable sin Live Activity. |
| **Por qué** | Offline-first, UX de rutina, corrección de bugs de completado, feedback con teléfono bloqueado sin depender de provisioning ActivityKit. |
| **Riesgo** | **Medio.** Toca flujo de entreno, persistencia del catálogo y permisos; regresiones posibles en series completadas o import. |
| **Validación hecha** | Pruebas manuales descritas en conversación; `xcodebuild` en entorno sandbox pudo fallar por permisos/DerivedData (no tomar como señal de build roto en máquina local). |
| **Rollback plan** | `git revert` del rango de commits de la feature o restaurar archivos desde `main`/tag; reactivar ActivityKit solo con decisión explícita (`DECISIONS.md`). |

---

## Plantilla (copiar para la próxima entrada)

```markdown
## [YYYY-MM-DD] — Título corto

| Campo | Detalle |
|-------|---------|
| **Qué cambió** | Archivos o comportamiento afectados (rutas). |
| **Por qué** | Objetivo de producto o bug. |
| **Riesgo** | Bajo / medio / alto + breve motivo. |
| **Validación hecha** | Tests, build, pasos manuales, “no ejecutado”. |
| **Rollback plan** | `git revert`, borrar archivo, feature flag, o pasos concretos. |
```

---

## Notas

- Si un cambio **modifica decisiones** (`DECISIONS.md`), cruzar enlace en la entrada.
- Si introduce un bug conocido, añadir fila en `KNOWN_BUGS.md` y referenciar aquí el ID `KB-xxx`.
