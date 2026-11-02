# Persona 1: Proyectos y tareas — notas técnicas

**Alcance:** catálogo de proyectos, completar el repositorio de proyectos y tareas, pantallas de editar
proyecto y tarea, y avisar al sistema de gotas (Persona 4) cuando se completa una tarea o un proyecto.

## Lo que ya existe

- `firestore.rules`: colecciones raíz `projects` y `tasks`, con sus validaciones. Léelas antes de escribir
  cualquier campo; un campo que no esté en `validProject()` / `validTask()` hace fallar la escritura.
- `lib/models/seedly_project.dart`: solo modelos de **creación** (`NewSeedlyProject`, `NewSeedlyTask`).
- `lib/repositories/seedly_project_repository.dart`: la interfaz solo tiene `create`.
- `lib/data/firebase/firestore_seedly_project_repository.dart`: crea el proyecto y sus tareas en un batch.
- `lib/screens/seedly_create_project_view.dart` y `seedly_create_task_view.dart` (esta última ya recibe
  `initial`, útil para editar).

## Lo que falta

### 1. Modelos de lectura

Agregar `SeedlyProject` y `SeedlyTask` en `lib/models/seedly_project.dart`, con su `id` y los mismos
campos que Firestore (`taskCount`, `doneCount`, `order`, `dueDate`, `dueMinutes`, `reminderMinutes`…).
Sin imports de Firebase: los `Timestamp` se convierten a `DateTime` dentro de `lib/data/`.

Publícalos pronto: la Persona 2 (inicio y recordatorios) y la Persona 4 (gotas) dependen de `SeedlyTask`.

### 2. Repositorio

Ampliar `SeedlyProjectRepository` y su implementación de Firestore:

- `watchProjects()` → `Stream<List<SeedlyProject>>`: la lista del catálogo, que se actualiza sola.
- `watchProject(id)` y `watchTasks(projectId)` (ordenadas por `order`).
- `update(...)` de proyecto y de tarea, `delete(...)` de ambos.
- `setTaskDone(taskId, done)`.

Reglas que hay que respetar:

- **Toda consulta filtra por `ownerId`**; las reglas no son filtros y Firestore rechaza la consulta si falta.
- **Contadores:** `taskCount` y `doneCount` del proyecto se actualizan en el **mismo batch** que la tarea
  (agregar, borrar, marcar o desmarcar). Las reglas exigen `doneCount <= taskCount`.
- **Borrar un proyecto** borra también sus tareas en el mismo batch.
- `createdAt` y `projectId` no cambian al editar (las reglas lo verifican).
- Errores: mapear a `SeedlyProjectError` en `lib/models/seedly_errors.dart`; agrega los motivos nuevos
  ahí (el texto en español vive solo en ese archivo).

### 3. Catálogo

- Estado **cargando** mientras llega el primer valor del stream.
- Estado **sin conexión**: Firestore guarda caché local, así que se muestra lo último que tenga. Si no hay
  nada en caché, mostrar un estado vacío con aviso de conexión.
- Estado **sin proyectos**.
- El avance sale de `doneCount / taskCount`; no hace falta leer las tareas.

### 4. Editar proyecto y tarea

Reutilizar las vistas de creación en modo edición (precargar valores, cambiar el título y el botón).
Borrar con confirmación.

### 5. Gotas (coordinar con la Persona 4)

Ver `2026-10-31-persona-4-gotas.md`. En resumen:

- Al **marcar** una tarea: `addTaskDrops(taskId)`. Al **desmarcarla**: `removeTaskDrops(taskId)`.
- Si con esa tarea el proyecto queda completo (`doneCount == taskCount` y `taskCount >= 3`):
  `addProjectDrops(projectId)`.
- Si el sistema de gotas aún no está listo, usa el fake que entregue la Persona 4.

## Convenciones del repo

- Solo `lib/data/` (y `lib/main.dart`) importa Firebase; `test/architecture_test.dart` lo revisa.
- Los repositorios llegan a las pantallas por constructor, sin paquetes de inyección.
- Para tests de pantallas, ampliar `test/support/fake_seedly_project_repository.dart`; para el repositorio,
  `fake_cloud_firestore` como en `test/firestore_seedly_project_repository_test.dart`.
