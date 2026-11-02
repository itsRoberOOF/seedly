import '../models/seedly_project.dart';

/// Pure reminder policy shared by the coordinator and its tests.
abstract final class SeedlyTaskReminder {
  /// Returns the local reminder instant, or null when [task] is not eligible.
  static DateTime? at(SeedlyTask task, {required DateTime now}) {
    final date = task.dueDate;
    final dueMinutes = task.dueMinutes;
    final reminderMinutes = task.reminderMinutes;
    if (task.done ||
        date == null ||
        dueMinutes == null ||
        reminderMinutes == null ||
        !seedlyReminderOptions.contains(reminderMinutes)) {
      return null;
    }

    final due = DateTime(
      date.year,
      date.month,
      date.day,
      dueMinutes ~/ Duration.minutesPerHour,
      dueMinutes % Duration.minutesPerHour,
    );
    final reminder = due.subtract(Duration(minutes: reminderMinutes));
    return reminder.isAfter(now) ? reminder : null;
  }
}
