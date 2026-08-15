# Bugs

Bugs **reproducibles**. Un bug entra aquí cuando alguien lo reprodujo; si solo se sospecha, va a
"Sospechas" más abajo.

Al cerrar uno: muévelo a "Resueltos" con la fecha y el commit. No lo borres — el historial de qué
falló y cómo se arregló es lo que evita repetir el diagnóstico dentro de seis meses.

> Última pasada: **2026-08-15**. Búsqueda de `TODO` / `FIXME` / `HACK` en todo el código Swift:
> **cero coincidencias**. No hay bugs marcados en el código.

---

## Activos

Ninguno registrado.

**Plantilla para añadir uno:**

```markdown
### KB-001 · Título corto

**Síntoma:** qué ve el usuario, en pasos.
**Repro:** iOS X.Y · dispositivo o simulador · rama · con/sin datos de HealthKit.
**Dónde mirar:** archivo:línea o módulo.
**Ya se intentó:** diagnósticos y fixes descartados, para no repetirlos.
```

El campo *ya se intentó* es el que más tiempo ahorra. Anótalo aunque el intento fallara —
sobre todo si falló.

---

## Sospechas sin confirmar

No son bugs todavía. Son cosas que huelen mal y nadie ha reproducido.

### S1 · Deployment target iOS 26.1

El `.xcodeproj` declara `IPHONEOS_DEPLOYMENT_TARGET = 26.1`. Es un valor inusualmente alto y
restringe mucho el parque de dispositivos compatibles.

**Cómo confirmar:** revisar en Xcode si coincide con el SDK y con el mínimo que se quiere
soportar. Si fue un typo, corregirlo antes de publicar; después de publicar es mucho más caro.

### S2 · Aviso de descanso si se denegaron notificaciones

Por D9 el aviso de fin de descanso con el teléfono bloqueado depende de `UserNotifications`. Si
el usuario denegó el permiso, no suena nada y no hay fallback: no hay Live Activity que lo
sustituya.

**Cómo confirmar:** denegar notificaciones, iniciar un entreno, bloquear el teléfono y esperar a
que termine un descanso.
**Nota:** puede que el comportamiento sea correcto pero la app no avise al usuario de que se está
perdiendo la función. Eso sería un bug de UX, no de lógica.

### S3 · Estados vacíos de HealthKit

`recoveryScore`, `activityScore` y demás son enums con caso `.unavailable`. La convención está
documentada, pero no se ha auditado que **todas** las vistas cubran ese caso sin degradarse.

**Cómo confirmar:** ejecutar con permisos de HealthKit denegados, o en un simulador sin datos, y
recorrer Home, Stats y el detalle de recuperación.
**Por qué importa:** es el escenario del primer arranque de cualquier usuario sin Apple Watch.

---

## Resueltos

Referencia histórica. No reabrir sin una repro nueva.

| Qué pasaba | Cómo se resolvió |
|---|---|
| El entreno se marcaba terminado con series pendientes (al saltar el último ejercicio o completarlos en otro orden) | Lógica global de "todas las series completadas" en `WorkoutExecutorViewModel` |
| Catálogo vacío o ejercicios llamados "Ejercicio" en el primer arranque | Causa: instancias separadas de `ExerciseService` sin contexto. Se resolvió con `ExerciseService.shared` + `configure(modelContext:)` e import desde fixtures (D6) |
| "Mi rutina" mostraba un catálogo desactualizado | Mismo origen: vistas creando su propio `ExerciseService()`. Unificado en el singleton |
| El picker de rutina se cerraba al añadir un ejercicio | Sheet sin `dismiss` inmediato, más feedback y anti-duplicados en `RoutineEditorView` |
| Conversión lb/kg con redondeos confusos | `UnitConverter` y texto explícito en la UI |
| Live Activity fallaba por provisioning sin entitlement de ActivityKit | Plan B: notificación local. ActivityKit desactivado a propósito (D9) |
