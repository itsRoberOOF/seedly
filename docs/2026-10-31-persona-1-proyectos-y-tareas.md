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

## Integración con Inicio y recordatorios (Persona 2)

Esta sección se agrega al final para que la implementación de proyectos y
tareas pueda continuar encima del contrato ya usado por Inicio, sin duplicar
la lógica de notificaciones ni renombrar campos.

### Contrato de lectura que ya consume Inicio

`lib/models/seedly_project.dart` ahora publica el modelo Firebase-free
`SeedlyTask`. Su id estable y estos campos deben conservarse:

- `id`: id del documento de `tasks`; identifica también la notificación.
- `projectId`, `title`, `done` y `order`.
- `dueDate`: día de calendario local, guardado como `Timestamp` en Firestore.
- `dueMinutes`: minutos locales desde medianoche.
- `reminderMinutes`: solo `10`, `30` o `60`, o `null`.

`FirestoreSeedlyProjectRepository` ya expone
`watchTasksOn(DateTime day)` para Inicio y `watchTasksFrom(DateTime day)` para
reconciliar recordatorios futuros. Las dos consultas filtran por el
`ownerId` de la sesión; no eliminen ese filtro porque las reglas de Firestore
no funcionan como filtros. `watchTasksOn` usa inicio inclusivo y fin exclusivo
del día siguiente.

### Eventos que debe preservar la Persona 1

Al crear o editar, mantengan el mismo id de documento cuando la operación sea
una edición y escriban los tres campos de fecha/hora con los nombres exactos.
El coordinador observa el stream completo y automáticamente:

- programa una tarea futura elegible;
- reemplaza su aviso si cambian `dueDate`, `dueMinutes` o `reminderMinutes`;
- cancela el aviso si la tarea se elimina, se marca `done == true` o pierde el
  recordatorio.

El payload de cada aviso es `task:<taskId>`. `SeedlyHomeScreen` expone
`onNotificationTaskTap` para que la futura pantalla de edición abra la tarea;
esta rama no crea ni implementa esa pantalla. Las tarjetas de Inicio son
display-only hasta que la Persona 1 termine `setTaskDone(taskId, done)`.

No llamen directamente a `flutter_local_notifications` desde repositorios o
pantallas de Persona 1. La fuente de verdad sigue siendo el documento de la
tarea; basta con que cada escritura emita el estado completo y el coordinador
de `SeedlyNotificationService` hará la sincronización.

## Lo que Inicio ya adelantó del catálogo

Para la sección «Proyectos» de Inicio (`lib/screens/seedly_inicio_view.dart`) se agregó la parte mínima de
lectura de proyectos, con la forma que describe este documento. Amplíenla en lugar de duplicarla:

- `SeedlyProject` en `lib/models/seedly_project.dart`: `id`, `name`, `kind`, `icon`, `description`,
  `startDate`, `endDate`, `taskCount` y `doneCount`, con `remaining`, `isComplete` y `progress`. Falta la
  foto (`photo`), que Inicio no usa.
- `SeedlyProjectRepository.watchProjects()` y su versión de Firestore: filtra por `ownerId` y ordena en
  Dart por `createdAt` (más nuevo primero, sin `orderBy` para no pedir otro índice compuesto).
- `FakeSeedlyProjectRepository.projects` para tests. Sus tres streams se reproducen a cada oyente, como
  Firestore, para que una pantalla pueda volver a escucharlos al cambiar de pestaña.

Inicio muestra los proyectos sin terminar (`!isComplete`), con su avance, y las tarjetas de tarea llaman a
`onNotificationTaskTap`, el mismo gancho del editor de tareas. No son tocables mientras ese gancho no exista.

## Decisiones de diseño (Figma "Proyectos y Tareas")

- **Una tarea no cambia de proyecto.** "Editar - Tarea" en Figma muestra el campo
  *Proyecto* con flecha, como si se pudiera mover la tarea a otro proyecto. No se permite:
  `firestore.rules` exige `projectId == resource.data.projectId` al actualizar una tarea, y los
  contadores `taskCount` / `doneCount` de cada proyecto dependen de ello. En la app el campo se
  muestra **solo de lectura**. Si algún día se quiere mover tareas, hay que cambiar las reglas y
  ajustar los contadores de los dos proyectos en el mismo batch.
- Los datos de las capturas de Figma ("Proyecto UI/UX", 50 %…) son ejemplos; de ahí se copia la
  estructura y el estilo, no el contenido.

## Crear tarea desde el menú +

La opción **+ → Crear tarea** abre `SeedlyAddTaskView` (`lib/screens/seedly_add_task_view.dart`): la pantalla
"Nueva tarea" con el campo *Proyecto \** elegible. Al tocarlo se abre "Modal proyectos"
(`lib/modals/seedly_project_modal.dart`: buscador y la lista de proyectos con su avance). Guardar sin proyecto
se rechaza; con él llama a `SeedlyProjectRepository.addTask`. `SeedlyCreateTaskView` sigue sirviendo a las
tareas de un proyecto que se está creando o editando, donde el proyecto es fijo: solo se activa la elección
con `onPickProject`. El tag amarillo de entrega se compartió en `lib/widgets/seedly_deadline_tag.dart`.
