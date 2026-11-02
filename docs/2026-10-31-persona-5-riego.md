# Persona 5: Riego — coordinación de notificaciones

Este documento define únicamente la dependencia de notificaciones para que la
implementación de riego use el mismo servicio que los recordatorios de tareas.
No implementa sesiones, pagos, cronómetros ni lógica de gotas de Persona 5.

## Servicio compartido

La aplicación usa `flutter_local_notifications: ^22.3.3`, con `timezone`
`^0.11.0` y `flutter_timezone` `^5.1.1`. La instancia real es
`FlutterSeedlyNotificationService` en
`lib/data/notifications/flutter_seedly_notification_service.dart`; el
contrato que debe consumir Persona 5 es
`lib/services/seedly_notification_service.dart`.

`main()` crea e inicializa una sola instancia. `initialize()` es idempotente,
por lo que Persona 5 no debe crear otro plugin, registrar otro callback ni
volver a configurar canales. En tests se puede inyectar
`FakeSeedlyNotificationService`.

## API para una sesión de riego

Cuando Persona 5 necesite mostrar un aviso, debe llamar:

```dart
await notifications.showWateringSessionNotification(
  sessionId: sessionId,
  title: 'Sesión de riego',
  body: 'Tu sesión de riego está activa.',
);
```

Para retirarlo, use el mismo id:

```dart
await notifications.cancelWateringSessionNotification(sessionId);
```

`sessionId` es la identidad estable del aviso y se conserva en el payload
`watering:<sessionId>`. El canal Android es `seedly_watering` y su nombre
visible es **Sesión de riego**; es distinto del canal `seedly_reminders` de
**Recordatorios**.

`cancelAllTaskReminders()` solo cancela avisos cuyos payloads comienzan con
`task:` y se usa al cerrar sesión. Persona 5 no debe llamar ese método para
limpiar un aviso de riego ni llamar `cancelAll()` directamente. El servicio
comparte la inicialización, permisos y zona horaria, pero mantiene separados
los ids y canales para no cruzar cuentas o tipos de aviso.

En web el servicio es no-op. En Android/iOS la solicitud de permisos se
centraliza en el servicio; Persona 5 debe reutilizar esa instancia y no
importar `flutter_local_notifications` directamente.
