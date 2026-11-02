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

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initializing;
  bool _initialized = false;
  bool _exactAlarmGranted = true;
  void Function(String taskId)? _onTaskReminderTap;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Future<void> initialize({void Function(String taskId)? onTaskReminderTap}) {
    _onTaskReminderTap = onTaskReminderTap;
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    if (!_supported) {
      _initialized = true;
      return;
    }

    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } on Object {
      // tz.local remains the package default if the native lookup fails.
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
        _deliverTaskPayload(response.payload);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _deliverTaskPayload(launch?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  @override
  Future<SeedlyNotificationPermission> requestReminderPermission() async {
    await initialize();
    if (!_supported) return SeedlyNotificationPermission.unavailable;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission() ?? true;
      if (!granted) return SeedlyNotificationPermission.denied;
      _exactAlarmGranted =
          await android?.requestExactAlarmsPermission() ?? true;
      return SeedlyNotificationPermission.granted;
    }

    final granted = defaultTargetPlatform == TargetPlatform.iOS
        ? await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(alert: true, badge: true, sound: true) ??
              false
        : await _plugin
                  .resolvePlatformSpecificImplementation<
                    MacOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(alert: true, badge: true, sound: true) ??
              false;
    return granted
        ? SeedlyNotificationPermission.granted
        : SeedlyNotificationPermission.denied;
  }

  @override
  Future<void> scheduleTaskReminder(SeedlyTask task) async {
    await initialize();
    if (!_supported) return;
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
    await initialize();
    if (_supported) await _plugin.cancel(id: _taskNotificationId(taskId));
  }

  @override
  Future<void> syncTaskReminders(Iterable<SeedlyTask> tasks) async {
    await initialize();
    if (!_supported) return;
    final eligible = <String, SeedlyTask>{
      for (final task in tasks)
        if (SeedlyTaskReminder.at(task, now: DateTime.now()) != null)
          task.id: task,
    };
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final taskId = _taskIdFromPayload(request.payload);
      if (taskId != null && !eligible.containsKey(taskId)) {
        await cancelTaskReminder(taskId);
      }
    }
    for (final task in eligible.values) {
      await cancelTaskReminder(task.id);
      await scheduleTaskReminder(task);
    }
  }

  @override
  Future<void> cancelAllTaskReminders() async {
    await initialize();
    if (!_supported) return;
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      final taskId = _taskIdFromPayload(request.payload);
      if (taskId != null) await cancelTaskReminder(taskId);
    }
  }

  @override
  Future<void> showWateringSessionNotification({
    required String sessionId,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!_supported) return;
    await _plugin.show(
      id: _wateringNotificationId(sessionId),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _wateringChannelId,
          'Sesión de riego',
          channelDescription: 'Avisos de sesiones de riego de Seedly',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
        macOS: DarwinNotificationDetails(presentSound: true),
      ),
      payload: '$_wateringPrefix$sessionId',
    );
  }

  @override
  Future<void> cancelWateringSessionNotification(String sessionId) async {
    await initialize();
    if (_supported) {
      await _plugin.cancel(id: _wateringNotificationId(sessionId));
    }
  }

  void _deliverTaskPayload(String? payload) {
    final taskId = _taskIdFromPayload(payload);
    if (taskId != null) _onTaskReminderTap?.call(taskId);
  }

  static String? _taskIdFromPayload(String? payload) =>
      payload != null && payload.startsWith(_taskPrefix)
      ? payload.substring(_taskPrefix.length)
      : null;

  static int _taskNotificationId(String taskId) =>
      _stableNotificationId('task:$taskId');

  static int _wateringNotificationId(String sessionId) =>
      _stableNotificationId('watering:$sessionId');

  static int _stableNotificationId(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
