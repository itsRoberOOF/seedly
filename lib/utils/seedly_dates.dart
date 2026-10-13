/// Spanish date names for Seedly, without pulling in a localisation package.
abstract final class SeedlyDates {
  static const months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  /// Calendar header, Sunday first as in Figma's Date Picker.
  static const weekdays = ['DO', 'LU', 'MA', 'MI', 'JU', 'VI', 'SA'];

  /// "Abril 2026".
  static String monthYear(DateTime date) =>
      '${months[date.month - 1]} ${date.year}';

  /// "12 abr 2026".
  static String short(DateTime date) =>
      '${date.day} ${months[date.month - 1].substring(0, 3).toLowerCase()} '
      '${date.year}';

  /// "9:00 AM" for [minutes] after midnight.
  static String time(int minutes) {
    final hour = minutes ~/ 60;
    final minute = (minutes % 60).toString().padLeft(2, '0');
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute ${hour < 12 ? 'AM' : 'PM'}';
  }

  /// "10 min antes" / "1 hora antes" for a reminder offset.
  static String reminder(int minutes) => minutes % 60 == 0
      ? '${minutes ~/ 60} ${minutes == 60 ? 'hora' : 'horas'} antes'
      : '$minutes min antes';

  /// The quick-date tags offered with a calendar. "Esta semana" is this
  /// week's Saturday, the last column of the Sunday-first grid.
  static List<(String, DateTime)> quickDates(DateTime today) {
    final day0 = day(today);
    return [
      ('Hoy', day0),
      ('Mañana', day0.add(const Duration(days: 1))),
      ('Esta semana', day0.add(Duration(days: 6 - day0.weekday % 7))),
      ('Próxima semana', day0.add(const Duration(days: 7))),
    ];
  }

  /// The date with its time dropped.
  static DateTime day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
