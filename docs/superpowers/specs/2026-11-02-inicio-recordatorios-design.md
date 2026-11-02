# Inicio y recordatorios — diseño

## Intención

Completar la parte de la Persona 2 de Seedly: convertir Inicio en una pantalla
real con las tareas del día y la planta/estado de gotas, y programar
recordatorios locales de tareas que funcionen aunque la app esté cerrada.
La solución debe dejar un contrato claro para que la Persona 1 pueda terminar
proyectos/tareas y la Persona 5 pueda usar el mismo servicio de notificaciones
para riego.

## Estado actual relevante

- `SeedlyHomeScreen` solo muestra una `SeedlyPlant(phase: 1)` fija.
- `SeedlyProjectRepository` solo expone `create`; la implementación de
  Firestore aún no tiene modelos de lectura ni consultas de tareas.
- La documentación de Persona 1 ya define `SeedlyProject`, `SeedlyTask`,
  `watchTasks(projectId)` y la consulta por propietario.
- Persona 4 ya dejó `SeedlyDropsRepository.watchPlantState()` y el widget
  reutilizable `SeedlyPlant`.
- No existe todavía un documento de Persona 5 dentro de `docs/`; se agregará
  un documento de coordinación mínimo sin inventar su lógica de riego.
- El repositorio está limpio sobre `main`; no se tocarán CRUD, edición o
  borrado de Persona 1 ni la lógica de riego de Persona 5.

## Objetivos

1. Consultar las tareas del día filtrando siempre por `ownerId` y por el rango
   de `dueDate` del día local.
2. Registrar el índice compuesto de Firestore para `ownerId` + `dueDate`.
3. Mostrar en Inicio las tareas del día y reutilizar `SeedlyPlant` con el
   estado real de Persona 4 cuando esté disponible.
4. Programar recordatorios a `dueDate + dueMinutes - reminderMinutes`.
5. Reprogramar cambios y cancelar recordatorios de tareas completadas,
   eliminadas o sin recordatorio.
6. Pedir permisos cuando la persona selecciona un recordatorio; guardar la
   tarea aunque el permiso sea rechazado.
7. Inicializar un solo servicio de notificaciones con dos canales: `Recordatorios`
   y `Sesión de riego`.
8. Mantener la plataforma web sin notificaciones locales y permitir fakes en
   pruebas.

## No objetivos

- No implementar el catálogo, edición, borrado ni actualización de tareas de
  Persona 1.
- No implementar sesiones, pagos, límites ni crecimiento de Persona 5.
- No usar Firebase Cloud Messaging ni Cloud Functions.
- No persistir recordatorios en una colección nueva: la fuente de verdad es
  `SeedlyTask` en Firestore.

## Reglas y restricciones

- El acceso a Firebase queda en `lib/data/`; las pantallas reciben servicios y
  repositorios por constructor.
- La consulta de tareas debe filtrar por `ownerId`, porque las reglas de
  Firestore no actúan como filtros.
- Un recordatorio requiere `dueDate`, `dueMinutes` y uno de 10, 30 o 60
  minutos. Si la hora calculada ya pasó, no se programa.
- El id de `SeedlyTask` será el id estable de la notificación. La sincronización
  debe cancelar ids que ya no aparecen o que ya no son elegibles.
- La programación usa zona horaria local y alarmas exactas cuando el permiso
  está disponible. Si el permiso de alarma exacta no está disponible, se evita
  una excepción y se deja la tarea guardada.

## Enfoques considerados

### A. Notificaciones locales detrás de un servicio propio — elegido

Usar `flutter_local_notifications` con `timezone` y `flutter_timezone`, detrás
de `SeedlyNotificationService`. La implementación nativa vivirá en
`lib/data/notifications/`; las pantallas solo conocerán la interfaz. Un
coordinador recibe `watchTasksFrom(today)` y reconcilia las tareas futuras:
programa las elegibles, reprograma las modificadas y cancela las demás.

Ventajas: funciona offline después de guardar la programación, no depende de
backend, identifica cada tarea de forma estable, y Persona 5 puede compartir
inicialización/canales. El proyecto usa Flutter 3.47.7, por lo que la versión
estable actual documentada de la dependencia es compatible.

### B. Firebase Cloud Messaging

Requiere tokens, un servidor o Cloud Functions y sincronización remota. No es
necesario para un recordatorio local y añade infraestructura que el proyecto
quiere evitar.

### C. Invocar el plugin directamente desde cada pantalla

Reduce archivos al principio, pero duplica permisos, zona horaria,
cancelaciones e inicialización. También impediría usar un fake limpio en los
tests y dejaría a Persona 5 acoplada a la dependencia.

## Diseño elegido

### Modelo y repositorio

Agregar el modelo de lectura sin imports de Firebase:

```dart
class SeedlyTask {
  const SeedlyTask({
    required this.id,
    required this.projectId,
    required this.title,
    required this.done,
    required this.order,
    this.dueDate,
    this.dueMinutes,
    this.reminderMinutes,
  });
}
```

El repositorio expondrá las consultas que Persona 2 necesita:

- `watchTasksOn(DateTime day)` para el listado de Inicio.
- `watchTasksFrom(DateTime day)` para reprogramar todos los recordatorios
  futuros al iniciar sesión o abrir Inicio.

Ambas consultas filtran `ownerId` y convierten `Timestamp` a `DateTime` en la
capa Firebase. La consulta por día usa inicio inclusivo y fin exclusivo; la
consulta futura usa `dueDate >= inicioDelDía`. La Persona 1 podrá ampliar la
misma interfaz con sus operaciones de edición sin cambiar este contrato.

### Servicio compartido de notificaciones

La interfaz quedará detrás de `lib/services/seedly_notification_service.dart`
e incluirá, como mínimo:

- `initialize({void Function(String taskId)? onTaskReminderTap})`, idempotente.
- `requestReminderPermission()` para permiso de notificaciones y permiso de
  alarmas exactas cuando aplique.
- `scheduleTaskReminder(SeedlyTask task)`.
- `cancelTaskReminder(String taskId)`.
- `cancelAllTaskReminders()` al cerrar sesión.
- `showWateringSessionNotification(...)` y su cancelación para Persona 5.

La implementación usará `flutter_local_notifications` 22.3.3, el canal
Android `seedly_reminders`/`Recordatorios` y un canal separado
`seedly_watering`/`Sesión de riego`. La fecha se calculará como `TZDateTime`
local y se usará `zonedSchedule` con `AndroidScheduleMode.exactAllowWhileIdle`
solo cuando el permiso de alarma exacta esté concedido. Se añadirá el receptor
de reinicio requerido para que el plugin pueda reprogramar alarmas después de
reiniciar Android. La implementación web será no-op.

### Coordinación de tareas

Un coordinador pequeño, testeable con un fake, mantendrá el conjunto de ids
programados. Cada emisión de `watchTasksFrom` produce una reconciliación:

1. ignorar tareas hechas, sin fecha/hora, sin recordatorio o cuyo instante ya
   pasó;
2. cancelar ids que desaparecieron o dejaron de ser elegibles;
3. cancelar y volver a programar una tarea cuyo instante cambió;
4. programar las tareas nuevas y mantener las que no cambiaron.

La selección de un chip de recordatorio invocará el servicio de permisos desde
la pantalla de tarea. Si la persona rechaza el permiso, se conserva la tarea y
se muestra un aviso; el coordinador no debe borrar datos de Firestore.

### Inicio y autenticación

`SeedlyHomeScreen` recibirá opcionalmente `SeedlyDropsRepository` y el servicio
de notificaciones, conservando valores no-op para que los tests existentes no
necesiten Firebase. Inicio combinará:

- `StreamBuilder` de `watchTasksOn(SeedlyDates.day(DateTime.now()))`;
- `StreamBuilder` de `watchPlantState()` cuando se inyecte Persona 4;
- `SeedlyPlant(phase: state.phase)` y el total de gotas;
- tarjetas `SeedlyCheckboxCard` para cada tarea del día.

El callback de toque de una notificación conservará el `taskId` y quedará
expuesto para que Persona 1 conecte su futura pantalla de edición. No se
fabricará una pantalla de edición dentro de este trabajo.

Al cerrar sesión, después de confirmar el cierre exitoso, se cancelarán todos
los recordatorios locales para no mezclar cuentas.

### Android, iOS y web

- Android: declarar `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` y
  `SCHEDULE_EXACT_ALARM`, además de los receivers de notificaciones
  programadas; solicitar permisos en tiempo de ejecución.
- iOS: solicitar permiso de alertas, sonido y badge al seleccionar el primer
  recordatorio; la programación usa UserNotifications mediante el plugin.
- Web: no pedir permisos ni intentar programar notificaciones locales.

## Coordinación documental

Al final de `docs/2026-10-31-persona-1-proyectos-y-tareas.md` se añadirá una
sección de integración que explique cómo los recordatorios consumen
`SeedlyTask`, qué campos no deben renombrarse y qué eventos de edición/borrado/
completado deben dejar que el coordinador observe.

Como no existe `docs/2026-10-31-persona-5-riego.md`, se creará ese documento
con una nota de coordinación mínima: Persona 5 debe reutilizar el mismo
`SeedlyNotificationService`, el mismo `initialize()` idempotente y el canal
`Sesión de riego`, sin crear otro plugin ni llamar directamente a
`flutter_local_notifications`.

## Verificación de aceptación

- Tests unitarios del cálculo de instante, elegibilidad y reconciliación.
- Tests del fake de notificaciones para programar, reprogramar, cancelar y
  cancelar todo al cerrar sesión.
- Tests del repositorio que comprueben filtros, rango diario y conversión de
  datos.
- Tests de Inicio para tareas, planta y estado vacío/cargando.
- `flutter analyze` sin errores y `flutter test` completo sin fallos.
- Revisión manual de `pubspec.yaml`, manifiesto Android, documentación de las
  Personas 1 y 5 e índice de Firestore.

## Decisiones que quedan al implementador

- El diseño visual exacto de las tarjetas y estados de carga/vacío puede seguir
  el tema y widgets actuales del repo.
- El id numérico de la notificación se derivará de un hash estable del id de
  tarea, con colisión manejada de forma determinista; no se usará el id de
  Firestore directamente como entero.
- Los mensajes de alerta seguirán el español ya usado en los widgets del repo.

## Resoluciones del builder check

- **Propietario y ciclo de vida:** `SeedlyAuthRepository.currentUserId` es la
  fuente de `ownerId`; las consultas y el coordinador se crean al entrar a
  `SeedlyHomeScreen` y se cancelan al destruir la pantalla o cerrar sesión.
  La app no permite cambiar de cuenta sin cerrar la anterior.
- **Fecha y zona horaria:** `dueDate` es un día de calendario y `dueMinutes`
  son minutos locales desde medianoche. La consulta usa el día local; la
  programación usa la zona horaria actual del dispositivo y conserva la hora
  local durante cambios normales de horario de verano.
- **Permisos:** si se rechaza el permiso de notificaciones, la tarea se guarda
  y se avisa; no se programa. Si falta permiso de alarma exacta, se intenta
  una programación inexacta mientras el dispositivo esté inactivo y se avisa
  que la precisión exacta depende del permiso.
- **Reinicio:** la reconciliación consulta las notificaciones pendientes del
  plugin, usa el payload `task:<id>` para reconocerlas y elimina las que ya no
  corresponden a tareas elegibles. Después programa las nuevas o modificadas;
  no se usa `cancelAll()` porque también podría borrar el canal de riego.
- **Checkbox de Inicio:** las tarjetas son display-only en este trabajo. La
  Persona 1 conectará su operación `setTaskDone(taskId, done)` cuando termine
  el repositorio; el coordinador ya reaccionará a ese cambio para cancelar.
- **Selección del recordatorio:** la selección vive en `SeedlyCreateTaskView`.
  Recibirá un callback opcional inyectado desde Inicio para pedir permiso; la
  tarea se conserva aun cuando el callback reporte rechazo.
- **Toque de notificación:** el servicio entrega un `taskId` pendiente o
  inmediato mediante callback. No se crea una pantalla de edición paralela;
  Persona 1 conectará ese callback a su pantalla reutilizada.
- **Persona 5:** el contrato compartido tendrá operaciones con `sessionId`,
  título, cuerpo y, cuando corresponda, fecha de entrega. Persona 5 usará el
  canal `Sesión de riego` y no accederá al plugin directamente.
