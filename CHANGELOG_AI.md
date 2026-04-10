# Changelog (trabajo asistido por IA)

Registro de **cambios introducidos o documentados con asistencia de IA**: qué, por qué, riesgo, validación y cómo revertir.

**Convención:** añadir entradas **al inicio** (más reciente arriba). Una entrada por “lote” lógico (misma sesión o mismo PR).

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
