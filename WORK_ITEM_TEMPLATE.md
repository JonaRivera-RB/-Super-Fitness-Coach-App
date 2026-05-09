# Plantilla: feature o bug

**Uso:** copiar el bloque de abajo **por cada** feature o bug (ticket, issue o tarea). Puede ir en el PR, en el cuerpo del issue, o en un comentario antes de tocar código.

**Referencias:** `MODULE_MAP.md` (módulos), `DECISIONS.md` (límites), `KNOWN_BUGS.md` (activos), `ARCHITECTURE.md` (cableado real).

---

## Respuesta previa a implementar (5 puntos — obligatoria en el agente)

Responder **justo antes** de escribir código (regla `.cursor/rules/agent-change-discipline.mdc`):

| Punto | Contenido |
|-------|-----------|
| **Qué entendí** | Alcance y petición |
| **Qué archivos tocaré** | Lista de rutas |
| **Qué podría romper** | Riesgos / regresiones |
| **Cómo lo pruebo** | Pasos o `xcodebuild` / tests |
| **Cómo hago rollback** | Git o revert manual |

Encaja con el brief largo: §0 (entendido) ↔ 1–2; archivos ↔ 6; riesgos ↔ 4; pruebas ↔ 7; rollback explícito aquí y en plan de entrega.

---

## Copiar desde aquí

### 1. Contexto

- Usuario / escenario:
- Pantalla o flujo:
- Versión o rama (si aplica):

### 2. Problema real

- Qué falla o qué falta (hechos observables, no soluciones):
- Pasos para reproducir (si es bug):

### 3. Módulos afectados

- Features / carpetas (p. ej. `Features/Training`, `Core/`):
- Datos (SwiftData / `UserDefaults` / red):

### 4. Riesgos

- Regresiones probables:
- Permisos, migraciones, o sincronización con catálogo / logs:

### 5. Plan por pasos

1.
2.
3.
*(Mantener cambios acotados; si el plan supera 3–5 archivos, justificar.)*

### 6. Archivos a tocar

- Lista prevista (rutas concretas):
- Archivos que **no** se deben tocar salvo necesidad:

### 7. Cómo validar

- Pasos manuales o casos límite:
- Comando de build/test (si aplica):

### 8. Qué no debe romperse

- Flujos o invariantes a preservar (p. ej. “completar entreno solo si todas las series”, “catálogo solo desde SwiftData”):

---

## Hasta aquí (fin del bloque copiable)
