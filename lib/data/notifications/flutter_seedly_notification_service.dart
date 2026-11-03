import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../models/seedly_project.dart';
import '../../services/seedly_notification_service.dart';
import '../../services/seedly_task_reminders.dart';

/// Native local-notification adapter. Web and unsupported desktop targets are
/// intentionally no-op so the Firebase web development flow stays usable.
class FlutterSeedlyNotificationService implements SeedlyNotificationService {
  FlutterSeedlyNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _taskPrefix = 'task:';
  static const _wateringPrefix = 'watering:';
  static const _taskChannelId = 'seedly_reminders';
  static const _wateringChannelId = 'seedly_watering';
  static const _wateringChannelName = 'Sesión de riego';
  static const _wateringChannelDescription =
      'Avisos de sesiones de riego de Seedly';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initializing;
  bool _initialized = false;
  bool _timezoneReady = false;
  bool _notificationsGranted = false;
  bool _exactAlarmGranted = false;
  void Function(String taskId)? _onTaskReminderTap;
  String? _pendingTaskId;
  void Function(String sessionId)? _onWateringSessionTap;
  String? _pendingWateringSessionId;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<void> initialize({
    void Function(String taskId)? onTaskReminderTap,
    void Function(String sessionId)? onWateringSessionTap,
  }) {
    _onTaskReminderTap = onTaskReminderTap;
    _onWateringSessionTap = onWateringSessionTap;
    if (_initialized) {
      _deliverPending();
      return Future<void>.value();
    }
    return _ensureInitialized();
  }

  /// Para las llamadas internas del servicio: a diferencia de [initialize],
  /// no toca los handlers de toque. Antes cada llamada interna los dejaba en
  /// null y tocar un recordatorio no abría nada.
  Future<void> _ensureInitialized() =>
      _initialized ? Future<void>.value() : _initializing ??= _initialize();

  Future<void> _initialize() async {
    if (!_supported) {
      _initialized = true;
      return;
    }

    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
      _timezoneReady = true;
    } on Object {
      // Fail closed instead of accidentally scheduling in the package's UTC
      // default when the device timezone cannot be identified.
      _timezoneReady = false;
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _deliverPayload(response.payload);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _deliverPayload(launch?.notificationResponse?.payload);
    }
    await _refreshNotificationPermissionState();
    await _refreshExactAlarmState();
    _initialized = true;
    _deliverPending();
  }

  @override
  Future<SeedlyNotificationPermission> requestReminderPermission() async {
    await _ensureInitialized();
    if (!_supported) return SeedlyNotificationPermission.unavailable;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      bool granted;
      try {
        granted = await android?.requestNotificationsPermission() ?? true;
      } on Object {
        _notificationsGranted = false;
        try {
          await _cancelAllTaskNotificationRequests();
        } on Object {
          // Permission errors must not prevent the task form from saving.
        }
        return SeedlyNotificationPermission.denied;
      }
      _notificationsGranted = granted;
      if (!granted) {
        try {
          await _cancelAllTaskNotificationRequests();
        } on Object {
          // Permission errors must not prevent the task form from saving.
        }
        return SeedlyNotificationPermission.denied;
      }
      try {
        await android?.requestExactAlarmsPermission();
      } on Object {
        // Inexact alarms remain a valid fallback when exact alarms are denied.
      }
      await _refreshExactAlarmState();
      return SeedlyNotificationPermission.granted;
    }
    bool granted;
    try {
      granted = defaultTargetPlatform == TargetPlatform.iOS
          ? await _plugin
                    .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin
                    >()
                    ?.requestPermissions(
                      alert: true,
                      badge: true,
                      sound: true,
                    ) ??
                false
          : await _plugin
                    .resolvePlatformSpecificImplementation<
                      MacOSFlutterLocalNotificationsPlugin
                    >()
                    ?.requestPermissions(
                      alert: true,
                      badge: true,
                      sound: true,
                    ) ??
                false;
    } on Object {
      granted = false;
    }
    _notificationsGranted = granted;
    if (!granted) {
      try {
        await _cancelAllTaskNotificationRequests();
      } on Object {
        // Permission errors must not prevent the task form from saving.
      }
    }
    return granted
        ? SeedlyNotificationPermission.granted
        : SeedlyNotificationPermission.denied;
  }

  @override
  Future<SeedlyNotificationPermission> requestWateringPermission() async {
    await _ensureInitialized();
    if (!_supported) return SeedlyNotificationPermission.unavailable;
    // iOS y macOS piden todo junto de todos modos.
    if (defaultTargetPlatform != TargetPlatform.android) {
      return requestReminderPermission();
    }
    bool granted;
    try {
      granted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    } on Object {
      granted = false;
    }
    _notificationsGranted = granted;
    return granted
        ? SeedlyNotificationPermission.granted
        : SeedlyNotificationPermission.denied;
  }

  @override
  Future<void> scheduleTaskReminder(SeedlyTask task) async {
    await _ensureInitialized();
    if (!_supported || !_timezoneReady) return;
    if (!await _refreshNotificationPermissionState()) {
      await cancelTaskReminder(task.id);
      return;
    }
    await _refreshExactAlarmState();
    final reminder = SeedlyTaskReminder.at(task, now: DateTime.now());
    if (reminder == null) {
      await cancelTaskReminder(task.id);
      return;
    }
    await _plugin.zonedSchedule(
      id: _taskNotificationId(task.id),
      title: 'Recordatorio de tarea',
      body: task.title,
      scheduledDate: tz.TZDateTime(
        tz.local,
        reminder.year,
        reminder.month,
        reminder.day,
        reminder.hour,
        reminder.minute,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _taskChannelId,
          'Recordatorios',
          channelDescription: 'Recordatorios de tareas de Seedly',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
        macOS: DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: _exactAlarmGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$_taskPrefix${task.id}',
    );
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    await _ensureInitialized();
    if (_supported) await _plugin.cancel(id: _taskNotificationId(taskId));
  }

  @override
  Future<void> syncTaskReminders(Iterable<SeedlyTask> tasks) async {
    await _ensureInitialized();
    if (!_supported) return;
    if (!await _refreshNotificationPermissionState()) {
      await _cancelAllTaskNotificationRequests();
      return;
    }
    if (!_timezoneReady) {
      await _cancelAllTaskNotificationRequests();
      return;
    }
    await _refreshExactAlarmState();
    final eligible = <String, SeedlyTask>{
      for (final task in tasks)
        if (SeedlyTaskReminder.at(task, now: DateTime.now()) != null)
          task.id: task,
    };
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final taskId = _taskIdFromPayload(request.payload);
      if (taskId != null && !eligible.containsKey(taskId)) {
        await _plugin.cancel(id: _taskNotificationId(taskId));
      }
    }
    for (final task in eligible.values) {
      await _plugin.cancel(id: _taskNotificationId(task.id));
      await scheduleTaskReminder(task);
    }
  }

  @override
  Future<void> cancelAllTaskReminders() async {
    await _ensureInitialized();
    if (!_supported) return;
    await _cancelAllTaskNotificationRequests();
  }

  Future<void> _cancelAllTaskNotificationRequests() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final taskId = _taskIdFromPayload(request.payload);
      if (taskId != null) {
        await _plugin.cancel(id: _taskNotificationId(taskId));
      }
    }
  }

  @override
  Future<void> showWateringSessionNotification({
    required String sessionId,
    required String title,
    required String body,
    DateTime? endsAt,
  }) async {
    await _ensureInitialized();
    if (!_supported) return;
    final left = endsAt?.difference(DateTime.now()).inMilliseconds;
    await _plugin.show(
      id: _wateringNotificationId(sessionId),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _wateringChannelId,
          _wateringChannelName,
          channelDescription: _wateringChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          // Fijo mientras dura la sesión, y silencioso: se actualiza en
          // cada pausa y cada reanudación.
          ongoing: true,
          autoCancel: false,
          silent: true,
          onlyAlertOnce: true,
          timeoutAfter: left == null ? null : math.max(left, 1),
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
        macOS: const DarwinNotificationDetails(presentSound: false),
      ),
      payload: '$_wateringPrefix$sessionId',
    );
  }

  @override
  Future<void> cancelWateringSessionNotification(String sessionId) async {
    await _ensureInitialized();
    if (_supported) {
      await _plugin.cancel(id: _wateringNotificationId(sessionId));
    }
  }

  @override
  Future<void> scheduleWateringSessionEnd({
    required String sessionId,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    if (!_supported || !_timezoneReady) return;
    await _refreshExactAlarmState();
    await _plugin.zonedSchedule(
      id: _wateringEndNotificationId(sessionId),
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _wateringChannelId,
          _wateringChannelName,
          channelDescription: _wateringChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
        macOS: DarwinNotificationDetails(presentSound: true),
      ),
      // Sin alarmas exactas Android puede entregarlo unos minutos tarde; con
      // la app abierta, la sesión igual termina a tiempo.
      androidScheduleMode: _exactAlarmGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$_wateringPrefix$sessionId',
    );
  }

  @override
  Future<void> cancelWateringSessionEnd(String sessionId) async {
    await _ensureInitialized();
    if (_supported) {
      await _plugin.cancel(id: _wateringEndNotificationId(sessionId));
    }
  }

  void _deliverPayload(String? payload) {
    if (_taskIdFromPayload(payload) case final taskId?) {
      if (_onTaskReminderTap case final callback?) {
        callback(taskId);
      } else {
        _pendingTaskId = taskId;
      }
    } else if (_sessionIdFromPayload(payload) case final sessionId?) {
      if (_onWateringSessionTap case final callback?) {
        callback(sessionId);
      } else {
        _pendingWateringSessionId = sessionId;
      }
    }
  }

  void _deliverPending() {
    final taskId = _pendingTaskId;
    final onTask = _onTaskReminderTap;
    if (taskId != null && onTask != null) {
      _pendingTaskId = null;
      onTask(taskId);
    }
    final sessionId = _pendingWateringSessionId;
    final onWatering = _onWateringSessionTap;
    if (sessionId != null && onWatering != null) {
      _pendingWateringSessionId = null;
      onWatering(sessionId);
    }
  }

  Future<bool> _refreshNotificationPermissionState() async {
    if (!_supported) return false;
    try {
      final enabled = switch (defaultTargetPlatform) {
        TargetPlatform.android =>
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled(),
        TargetPlatform.iOS =>
          (await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.checkPermissions())
              ?.isEnabled,
        TargetPlatform.macOS =>
          (await _plugin
                  .resolvePlatformSpecificImplementation<
                    MacOSFlutterLocalNotificationsPlugin
                  >()
                  ?.checkPermissions())
              ?.isEnabled,
        _ => false,
      };
      _notificationsGranted = enabled == true;
    } on Object {
      _notificationsGranted = false;
    }
    return _notificationsGranted;
  }

  Future<void> _refreshExactAlarmState() async {
    if (!_supported || defaultTargetPlatform != TargetPlatform.android) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      _exactAlarmGranted =
          await android?.canScheduleExactNotifications() ?? false;
    } on Object {
      _exactAlarmGranted = false;
    }
  }

  static String? _taskIdFromPayload(String? payload) =>
      payload != null && payload.startsWith(_taskPrefix)
      ? payload.substring(_taskPrefix.length)
      : null;

  static int _taskNotificationId(String taskId) =>
      _stableNotificationId('task:$taskId');

  static String? _sessionIdFromPayload(String? payload) =>
      payload != null && payload.startsWith(_wateringPrefix)
      ? payload.substring(_wateringPrefix.length)
      : null;

  static int _wateringNotificationId(String sessionId) =>
      _stableNotificationId('watering:$sessionId');

  /// Id propio, para cancelar por separado el aviso de "sesión terminada" y
  /// el fijo; los dos llevan el mismo payload `watering:`.
  static int _wateringEndNotificationId(String sessionId) =>
      _stableNotificationId('watering-end:$sessionId');

  static int _stableNotificationId(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
