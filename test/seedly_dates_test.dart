import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/utils/seedly_dates.dart';

void main() {
  group('due', () {
    final today = DateTime(2026, 11, 2, 15, 30);

    test('says Hoy and Mañana, with the time when there is one', () {
      expect(
        SeedlyDates.due(DateTime(2026, 11, 2), 10 * 60, today),
        'Hoy • 10:00 AM',
      );
      expect(
        SeedlyDates.due(DateTime(2026, 11, 3), 14 * 60 + 5, today),
        'Mañana • 2:05 PM',
      );
      expect(SeedlyDates.due(DateTime(2026, 11, 2), null, today), 'Hoy');
      expect(SeedlyDates.due(DateTime(2026, 11, 3), null, today), 'Mañana');
    });

    test('names any other day', () {
      expect(
        SeedlyDates.due(DateTime(2026, 11, 12), 9 * 60, today),
        '12 nov 2026 • 9:00 AM',
      );
      expect(SeedlyDates.due(DateTime(2026, 12, 1), null, today), '1 dic 2026');
    });

    test('ignores the hour of the dates it is given', () {
      expect(
        SeedlyDates.due(DateTime(2026, 11, 2, 23, 59), null, today),
        'Hoy',
      );
      expect(
        SeedlyDates.due(DateTime(2026, 11, 3, 0, 1), null, today),
        'Mañana',
      );
    });

    test('tomorrow rolls over the end of the month and the year', () {
      expect(
        SeedlyDates.due(DateTime(2026, 12, 1), null, DateTime(2026, 11, 30)),
        'Mañana',
      );
      expect(
        SeedlyDates.due(DateTime(2027), null, DateTime(2026, 12, 31)),
        'Mañana',
      );
    });
  });
}
