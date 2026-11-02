import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/screens/seedly_create_task_view.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_input_tags.dart';

void main() {
  testWidgets(
    'selecting a reminder requests permission but keeps it on denial',
    (tester) async {
      var permissionRequests = 0;
      final saved = <NewSeedlyTask>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlyTheme.light,
          home: Scaffold(
            body: SeedlyCreateTaskView(
              projectName: 'Huerto',
              projectIcon: 'assets/images/icon_project.svg',
              initial: NewSeedlyTask(
                'Sembrar',
                dueDate: DateTime(2026, 11, 2),
                dueMinutes: 9 * 60,
              ),
              onClose: () {},
              onSave: saved.add,
              onReminderSelected: () async {
                permissionRequests++;
                return false;
              },
            ),
          ),
        ),
      );

      final tag = find.text('30 min antes').last;
      await tester.ensureVisible(tag);
      await tester.tap(tag);
      await tester.pumpAndSettle();

      final reminder = tester.widget<SeedlyInputTags>(
        find.widgetWithText(SeedlyInputTags, 'Recordatorio'),
      );
      expect(permissionRequests, 1);
      expect(reminder.value, '30 min antes');
      expect(find.text('Notificaciones desactivadas'), findsOneWidget);
      expect(saved, isEmpty);
    },
  );

  testWidgets('turning an existing reminder off does not request permission', (
    tester,
  ) async {
    var permissionRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: Scaffold(
          body: SeedlyCreateTaskView(
            projectName: 'Huerto',
            projectIcon: 'assets/images/icon_project.svg',
            initial: NewSeedlyTask(
              'Sembrar',
              dueDate: DateTime(2026, 11, 2),
              dueMinutes: 9 * 60,
              reminderMinutes: 30,
            ),
            onClose: () {},
            onSave: (_) {},
            onReminderSelected: () async {
              permissionRequests++;
              return true;
            },
          ),
        ),
      ),
    );

    final tag = find.text('30 min antes').last;
    await tester.ensureVisible(tag);
    await tester.tap(tag);
    await tester.pumpAndSettle();

    expect(permissionRequests, 0);
  });
}
