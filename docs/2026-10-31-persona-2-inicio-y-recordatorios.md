# Persona 2: Inicio y recordatorios — notas técnicas

**Alcance:** pantalla de inicio (con la consulta de las tareas del día) y notificaciones nativas de
recordatorio de tareas.

## 1. Tareas del día

Inicio muestra las tareas de hoy de todos los proyectos. La consulta va en el repositorio de proyectos
(`lib/data/firebase/firestore_seedly_project_repository.dart`), usando el modelo `SeedlyTask` que publica
la Persona 1:

- `watchTasksOn(DateTime day)` → `Stream<List<SeedlyTask>>`.
- Filtra por `ownerId` (obligatorio por las reglas) y por `dueDate` dentro del día.
- **Índice compuesto:** `ownerId` + `dueDate` en la colección `tasks`. Hoy no hay ninguno
  (`firebase firestore:indexes --project seedly-54ac7` sale vacío). Al correr la consulta, Firestore da en
  el error el enlace para crearlo; luego guárdalo en `firestore.indexes.json` y regístralo en
  `firebase.json` para que quede en el repo.

Inicio también muestra la planta y las gotas: eso sale de `watchPlantState()` de la Persona 4. Mientras no
esté, usa su fake.

## 2. Recordatorios de tareas

**Dónde se crean en la app:** al agregar una tarea en *Nueva tarea* (`seedly_create_task_view.dart`,
campo *Recordatorio*), en las tareas de *Crear proyecto*, y al editar una tarea (pantalla de la Persona 1).
Se guardan en la tarea como `dueDate` + `dueMinutes` (hora límite, minutos desde medianoche) +
`reminderMinutes` (10, 30 o 60). Un recordatorio siempre tiene día y hora.

**Qué debe pasar:**

- Suena a la hora `dueDate + dueMinutes − reminderMinutes`, aunque la app esté cerrada.
- Se **reprograma** al editar la tarea, y se **cancela** al borrarla, completarla o quitarle el recordatorio.
- Al iniciar sesión (o en otro teléfono) se programan los de todas las tareas futuras; al cerrar sesión se
  cancelan todos.
- Si la hora ya pasó al guardarla, no se programa.
- Al tocarla abre la tarea.
- Usar el id de la tarea para identificar su notificación facilita reprogramar y cancelar.

**Permisos (Android):**

- Android 13+: pedir el permiso de notificaciones (`POST_NOTIFICATIONS`) la primera vez que el usuario
  pone un recordatorio, no al abrir la app. Si lo niega, la tarea se guarda igual y se le avisa.
- Android 12+: para que suenen a la hora exacta hace falta el permiso de alarmas exactas.
- Al reiniciar el teléfono, las notificaciones programadas se pierden si no se vuelven a programar.

**Web:** no hay notificaciones locales; ahí se omiten.

## 3. Coordinar con la Persona 5

La Persona 5 también usa notificaciones (el contador de la sesión de riego). Acuerden un solo servicio de
notificaciones que se inicialice una vez y tenga dos canales: **Recordatorios** y **Sesión de riego**.
Como el resto de servicios, va detrás de una interfaz (como `lib/services/seedly_image_picker.dart`) para
poder usar un fake en los tests.

## Convenciones del repo

- Solo `lib/data/` (y `lib/main.dart`) importa Firebase; `test/architecture_test.dart` lo revisa.
- Dependencias por constructor; fakes en `test/support/`.
