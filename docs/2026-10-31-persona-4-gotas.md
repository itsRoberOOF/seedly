# Persona 4: Sistema de gotas — notas técnicas

**Alcance:** obtener gotas (tareas, proyectos y minutos de riego), guardar el total y la fase de la planta
por usuario en Firestore, y las reglas que evitan duplicados y trampas.

## Reglas del juego

| Origen | Gotas | Condiciones |
|---|---|---|
| Minuto de riego | 1 | Solo minutos completos. Máximo 120 por sesión. |
| Tarea completada | 3 | Se restan si se desmarca. Máximo 20 tareas premiadas al día. |
| Proyecto completado | 10 | 3 tareas o más, todas hechas. Una sola vez por proyecto. |

**Fases** (gotas acumuladas): Fase 1 desde 0, Fase 2 con 150, Fase 3 con 500, Fase 4 (máximo) con 1,200.
Crecer es manual (botón "Haz crecer tu planta"); las gotas que sobran se siguen sumando.

Pon estos números como constantes en un solo archivo de `lib/models/` para que nadie los repita.

## Por qué así

No hay Cloud Functions (el proyecto está en el plan gratuito), así que la app escribe las gotas
directamente. La seguridad tiene que estar en `firestore.rules`. Además, `users/{uid}` no acepta campos
nuevos (`validProfile()` usa `hasOnly`), así que las gotas van en colecciones propias.

## Colecciones

**`drops/{source}_{refId}`** — un movimiento por cada cosa que paga gotas.

| Campo | Tipo | Nota |
|---|---|---|
| `ownerId` | string | uid del usuario |
| `source` | string | `task`, `project` o `watering` |
| `refId` | string | id de la tarea, proyecto o sesión |
| `amount` | int | gotas de este movimiento |
| `createdAt` | timestamp | `request.time` |

El id del documento es fijo (`task_abc`, `project_p1`, `watering_s9`): si se intenta crear dos veces, la
segunda escritura choca con la primera, así que nada paga doble.

**`sessions/{sessionId}`** — se crea al iniciar una sesión de riego: `ownerId` y `startedAt`
(= `request.time`). Como la hora la pone el servidor, nadie puede inventar cuándo empezó.

**`progress/{uid}`** — `phase` (1 a 4) y `updatedAt`. Se crea en fase 1.

**Total de gotas:** suma de `amount` de los `drops` del usuario con una consulta de agregación
(`sum`), sin leer cada documento.

## Reglas de seguridad (`firestore.rules`)

Siguiendo el estilo del archivo (`ownsExisting()`, `ownsIncoming()`, `getAfter`):

- **Todas:** el dueño lee; nadie edita un movimiento (`update: if false`); `createdAt == request.time`;
  el id del documento es `source + '_' + refId`.
- **`task`:** `amount == 3`; la tarea existe, es del usuario y tiene `done == true` (con `getAfter`, para
  que funcione en el mismo batch que marca la tarea). Solo se puede borrar si la tarea ya no está hecha
  o ya no existe.
- **`project`:** `amount == 10`; el proyecto es del usuario, `taskCount >= 3` y `doneCount == taskCount`.
  No se puede borrar.
- **`watering`:** `amount` entre 1 y 120, y no mayor que los minutos reales desde `sessions/{refId}.startedAt`
  (`request.time` menos `startedAt`). La sesión es del usuario. No se puede borrar.
- **`progress`:** al crear, `phase == 1`; al actualizar, `phase` sube exactamente 1 y no pasa de 4.
- **`sessions`:** solo se crea (con `startedAt == request.time`); no se edita.

Lo que las reglas **no** pueden revisar, y por eso controla la app:

- El tope de 20 tareas premiadas al día.
- Que haya gotas suficientes antes de crecer (las reglas no pueden sumar).
- Sesiones de riego en paralelo.

## Funciones para los demás

Una interfaz en `lib/repositories/` y su implementación en `lib/data/firebase/`:

- `addTaskDrops(taskId)` / `removeTaskDrops(taskId)` — Persona 1.
- `addProjectDrops(projectId)` — Persona 1.
- `startWateringSession()` → `sessionId`, y `payWateringSession(sessionId, minutes)` — Persona 5.
- `watchPlantState()` → fase, total, meta siguiente y si ya puede crecer — Personas 2 y 3.
- `growPlant()` — Persona 3.

**Entrega primero** la interfaz y un fake en `test/support/` (que guarde todo en memoria), para que las
Personas 1, 2, 3 y 5 avancen mientras armas Firestore y las reglas.

## Pruebas

- Unitarias de las funciones con `fake_cloud_firestore` (como los tests de repositorios existentes).
- Reglas en el emulador de Firestore: que se rechace pagar dos veces, montos inválidos, una tarea sin
  marcar, un proyecto incompleto, más minutos que los reales, saltarse una fase y escribir en datos de
  otro usuario.
- No desplegar las reglas hasta que pasen esas pruebas: `firebase deploy --only firestore:rules`.

## Convenciones del repo

- Solo `lib/data/` (y `lib/main.dart`) importa Firebase; `test/architecture_test.dart` lo revisa.
- Dependencias por constructor; el repositorio se construye en `lib/main.dart` junto a los demás.
