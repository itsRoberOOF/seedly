import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/screens/seedly_create_project_view.dart';
import 'package:seedly/screens/seedly_create_task_view.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/services/seedly_projects.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_avatar.dart';
import 'package:seedly/widgets/seedly_checkbox.dart';
import 'package:seedly/widgets/seedly_input.dart';
import 'package:seedly/widgets/seedly_input_button.dart';
import 'package:seedly/widgets/seedly_input_tags.dart';
import 'package:seedly/widgets/seedly_menu.dart';
import 'package:seedly/widgets/seedly_modal.dart';
import 'package:seedly/widgets/seedly_segmented_control.dart';
import 'package:seedly/widgets/seedly_task_field.dart';

import 'package:seedly/services/seedly_image_picker.dart';

import 'support/fake_seedly_auth.dart';
import 'support/fake_seedly_image_picker.dart';
import 'support/fake_seedly_projects.dart';

/// Monday 12 October 2026.
final _today = DateTime(2026, 10, 12);

/// A 390x844 phone, where the modals fit like on a real device.
void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens the form from the + button and the add modal, like a person would.
Future<FakeSeedlyProjects> _openFromHome(
  WidgetTester tester,
  String option, {
  FakeSeedlyProjects? projects,
}) async {
  _usePhone(tester);
  final fake = projects ?? FakeSeedlyProjects();
  await tester.pumpWidget(
    MaterialApp(
      theme: SeedlyTheme.light,
      home: SeedlyHomeScreen(
        auth: FakeSeedlyAuth(isSignedIn: true),
        projects: fake,
      ),
    ),
  );
  await tester.tap(find.bySemanticsLabel('Agregar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
  return fake;
}

/// The form alone, with today pinned for the date flows.
Future<(FakeSeedlyProjects, List<NewSeedlyProject>)> _openView(
  WidgetTester tester, {
  SeedlyProjectKind kind = SeedlyProjectKind.full,
  FakeSeedlyImagePicker? picker,
}) async {
  _usePhone(tester);
  final projects = FakeSeedlyProjects();
  final created = <NewSeedlyProject>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: SeedlyTheme.light,
      home: Scaffold(
        body: SeedlyCreateProjectView(
          projects: projects,
          initialKind: kind,
          today: _today,
          imagePicker: picker ?? FakeSeedlyImagePicker(),
          onClose: () {},
          onCreated: (project, _) => created.add(project),
        ),
      ),
    ),
  );
  return (projects, created);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The big title field of "Nueva tarea".
final _taskTitle = find.descendant(
  of: find.byType(SeedlyCreateTaskView),
  matching: find.byType(TextFormField),
);

/// Adds a Completo task through "Nueva tarea", optionally with a quick date.
Future<void> _createTask(
  WidgetTester tester,
  String title, {
  String? tag,
}) async {
  await _tapVisible(tester, find.text('Añadir tarea'));
  await tester.enterText(_taskTitle, title);
  if (tag != null) await _tapVisible(tester, find.text(tag));
  await _tapVisible(tester, find.text('Crear tarea'));
}

Future<void> _pickDate(WidgetTester tester, int field, String day) async {
  await _tapVisible(tester, find.byType(SeedlyInputButton).at(field));
  await tester.tap(find.bySemanticsLabel(day));
  await tester.pump();
  await tester.tap(find.text('Confirmar'));
  await tester.pumpAndSettle();
}

SeedlyProjectKind _variant(WidgetTester tester) => tester
    .widget<SeedlySegmentedControl<SeedlyProjectKind>>(
      find.byType(SeedlySegmentedControl<SeedlyProjectKind>),
    )
    .selected;

void main() {
  tearDown(hideSeedlyAlert);

  group('opening', () {
    testWidgets('"Proyecto completo" opens the Completo variant', (
      tester,
    ) async {
      await _openFromHome(tester, 'Proyecto completo');
      expect(find.text('Nuevo proyecto'), findsOneWidget);
      expect(_variant(tester), SeedlyProjectKind.full);
      expect(find.text('Descripción'), findsOneWidget);
      expect(find.text('INICIO'), findsOneWidget);
      // The menu stays visible, as in Figma.
      expect(find.byType(SeedlyMenu), findsOneWidget);
    });

    testWidgets('"Proyecto Express" opens the Express variant', (tester) async {
      await _openFromHome(tester, 'Proyecto Express');
      expect(_variant(tester), SeedlyProjectKind.express);
      // The same task list as Completo, with at least one task required.
      expect(find.text('Tareas *'), findsOneWidget);
      expect(find.text('Añadir tarea'), findsOneWidget);
      expect(find.text('Descripción'), findsNothing);
    });
  });

  group('closing', () {
    testWidgets('the back arrow closes the form', (tester) async {
      await _openFromHome(tester, 'Proyecto completo');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedlyCreateProjectView), findsNothing);
    });

    testWidgets('the system back button closes the form first', (tester) async {
      await _openFromHome(tester, 'Proyecto completo');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SeedlyCreateProjectView), findsNothing);
      expect(find.byType(SeedlyHomeScreen), findsOneWidget);
    });

    testWidgets('choosing a menu tab closes the form and opens the tab', (
      tester,
    ) async {
      await _openFromHome(tester, 'Proyecto completo');
      await tester.tap(find.text('Mi perfil'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedlyCreateProjectView), findsNothing);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });
  });

  group('variants', () {
    testWidgets('switching keeps what was typed', (tester) async {
      await _openView(tester);
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await tester.tap(find.text('Express'));
      await tester.pumpAndSettle();
      expect(_variant(tester), SeedlyProjectKind.express);
      expect(find.text('Huerto'), findsOneWidget);

      await _tapVisible(tester, find.text('Mostrar más opciones'));
      expect(_variant(tester), SeedlyProjectKind.full);
      await _tapVisible(tester, find.text('Mostrar menos opciones'));
      expect(_variant(tester), SeedlyProjectKind.express);
    });
  });

  group('validation', () {
    testWidgets('a full project only requires its name', (tester) async {
      final (projects, _) = await _openView(tester);
      await tester.tap(find.text('Crear proyecto'));
      await tester.pumpAndSettle();
      final alert = tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));
      expect(alert.title, 'Campos incompletos');
      expect(alert.message, 'Ingresa el nombre del proyecto');
      expect(projects.created, isEmpty);
    });

    testWidgets('an express project also needs at least one task', (
      tester,
    ) async {
      final (projects, _) = await _openView(
        tester,
        kind: SeedlyProjectKind.express,
      );
      await tester.tap(find.text('Crear proyecto'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SeedlyAlert>(find.byType(SeedlyAlert)).message,
        'Ingresa el nombre del proyecto\nAñade al menos una tarea',
      );
      expect(projects.created, isEmpty);
    });

    testWidgets('any filled row satisfies the express task requirement', (
      tester,
    ) async {
      final (projects, _) = await _openView(
        tester,
        kind: SeedlyProjectKind.express,
      );
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await _tapVisible(tester, find.text('Añadir tarea'));
      // The first row stays empty; the second one counts.
      await tester.enterText(find.byType(SeedlyTaskField).at(1), 'Regar');
      await _tapVisible(tester, find.text('Crear proyecto'));
      expect(projects.created.single.tasks, const [NewSeedlyTask('Regar')]);
    });
  });

  group('dates', () {
    testWidgets('the end date cannot be before the start', (tester) async {
      await _openView(tester);
      await _pickDate(tester, 0, '15 oct 2026');
      expect(find.text('15 oct 2026'), findsOneWidget);

      await _tapVisible(tester, find.byType(SeedlyInputButton).at(1));
      // Days before the start can't be tapped in the end date's calendar.
      await tester.tap(find.bySemanticsLabel('14 oct 2026'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.bySemanticsLabel('20 oct 2026'));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.text('20 oct 2026'), findsOneWidget);
    });

    testWidgets('moving the start past the end clears the end', (tester) async {
      await _openView(tester);
      await _pickDate(tester, 0, '13 oct 2026');
      await _pickDate(tester, 1, '16 oct 2026');
      await _pickDate(tester, 0, '22 oct 2026');
      expect(find.text('22 oct 2026'), findsOneWidget);
      expect(find.text('16 oct 2026'), findsNothing);
    });

    testWidgets('quick dates pick today, tomorrow and the weekends', (
      tester,
    ) async {
      await _openView(tester);
      for (final (tag, expected) in [
        ('Hoy', '12 oct 2026'),
        ('Mañana', '13 oct 2026'),
        ('Esta semana', '17 oct 2026'),
        ('Próxima semana', '19 oct 2026'),
      ]) {
        await _tapVisible(tester, find.byType(SeedlyInputButton).at(0));
        await tester.ensureVisible(find.text(tag));
        await tester.tap(find.text(tag));
        await tester.pump();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget, reason: tag);
      }
    });

    testWidgets('cancelling the date modal keeps the field empty', (
      tester,
    ) async {
      await _openView(tester);
      await _tapVisible(tester, find.byType(SeedlyInputButton).at(0));
      await tester.tap(find.bySemanticsLabel('15 oct 2026'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedlyModal), findsNothing);
      expect(find.text('Añadir fecha'), findsNWidgets(2));
    });
  });

  group('icon', () {
    testWidgets('the edit button picks the avatar icon', (tester) async {
      await _openView(tester);
      expect(
        tester.widget<SeedlyAvatar>(find.byType(SeedlyAvatar)).icon,
        SeedlyProjectIcon.planta.asset,
      );
      await _tapVisible(tester, find.byTooltip('Cambiar imagen'));
      expect(find.text('Seleccionar imagen'), findsOneWidget);
      await tester.tap(find.text('Ideas'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SeedlyAvatar>(find.byType(SeedlyAvatar)).icon,
        SeedlyProjectIcon.ideas.asset,
      );
    });

    testWidgets('a gallery photo fills the avatar and is saved', (
      tester,
    ) async {
      final picker = FakeSeedlyImagePicker(photo: tinyPng);
      final (projects, _) = await _openView(tester, picker: picker);
      await _tapVisible(tester, find.byTooltip('Cambiar imagen'));
      await tester.tap(find.text('Elegir imagen'));
      await tester.pumpAndSettle();

      expect(picker.calls, 1);
      expect(find.text('Seleccionar imagen'), findsNothing);
      expect(
        tester.widget<SeedlyAvatar>(find.byType(SeedlyAvatar)).photo,
        tinyPng,
      );
      expect(find.bySemanticsLabel('Imagen del proyecto'), findsOneWidget);

      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await _tapVisible(tester, find.text('Crear proyecto'));
      expect(projects.created.single.photo, tinyPng);
    });

    testWidgets('choosing an icon afterwards replaces the photo', (
      tester,
    ) async {
      final (projects, _) = await _openView(
        tester,
        picker: FakeSeedlyImagePicker(photo: tinyPng),
      );
      await _tapVisible(tester, find.byTooltip('Cambiar imagen'));
      await tester.tap(find.text('Elegir imagen'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byTooltip('Cambiar imagen'));
      await tester.tap(find.text('Ideas'));
      await tester.pumpAndSettle();

      final avatar = tester.widget<SeedlyAvatar>(find.byType(SeedlyAvatar));
      expect(avatar.photo, isNull);
      expect(avatar.icon, SeedlyProjectIcon.ideas.asset);
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await _tapVisible(tester, find.text('Crear proyecto'));
      expect(projects.created.single.photo, isNull);
      expect(projects.created.single.icon, SeedlyProjectIcon.ideas);
    });

    testWidgets('closing the gallery keeps the modal open', (tester) async {
      final picker = FakeSeedlyImagePicker();
      await _openView(tester, picker: picker);
      await _tapVisible(tester, find.byTooltip('Cambiar imagen'));
      await tester.tap(find.text('Elegir imagen'));
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(find.text('Seleccionar imagen'), findsOneWidget);
      expect(
        tester.widget<SeedlyAvatar>(find.byType(SeedlyAvatar)).photo,
        isNull,
      );
    });

    testWidgets('a gallery error shows an alert over the modal', (
      tester,
    ) async {
      await _openView(
        tester,
        picker: FakeSeedlyImagePicker(
          error: const SeedlyImagePickerException('Sin permiso.'),
        ),
      );
      await _tapVisible(tester, find.byTooltip('Cambiar imagen'));
      await tester.tap(find.text('Elegir imagen'));
      await tester.pumpAndSettle();
      final alert = tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));
      expect(alert.style, SeedlyAlertStyle.danger);
      expect(alert.message, 'Sin permiso.');
      expect(find.text('Seleccionar imagen'), findsOneWidget);
    });

    testWidgets('the catalogue scrolls and builds rows lazily', (tester) async {
      await _openView(tester);
      await _tapVisible(tester, find.byTooltip('Cambiar imagen'));
      expect(find.byType(ListView), findsOneWidget);
      // The last icons aren't built until scrolled to.
      final last = SeedlyProjectIcon.choices.last;
      expect(find.text(last.label), findsNothing);
      await tester.scrollUntilVisible(
        find.text(last.label),
        300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text(last.label));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SeedlyAvatar>(find.byType(SeedlyAvatar)).icon,
        last.asset,
      );
    });
  });

  group('tasks', () {
    testWidgets('the checkbox marks a task done and keeps it on switching', (
      tester,
    ) async {
      final (projects, _) = await _openView(
        tester,
        kind: SeedlyProjectKind.express,
      );
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      final field = find.byType(SeedlyTaskField).first;
      // Placeholder until there's something to check.
      expect(
        tester.widget<SeedlyCheckbox>(find.byType(SeedlyCheckbox)).placeholder,
        isTrue,
      );
      await tester.enterText(field, 'Sembrar');
      await tester.pump();
      expect(
        tester.widget<SeedlyCheckbox>(find.byType(SeedlyCheckbox)).placeholder,
        isFalse,
      );

      await tester.tap(find.bySemanticsLabel('Tarea hecha'));
      await tester.pump();
      expect(tester.widget<SeedlyTaskField>(field).done, isTrue);
      // Completo shows the same task as a checked card.
      await tester.tap(find.text('Completo'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SeedlyCheckboxCard>(find.byType(SeedlyCheckboxCard))
            .value,
        isTrue,
      );
      await tester.tap(find.text('Express'));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.text('Crear proyecto'));
      expect(projects.created.single.tasks, const [
        NewSeedlyTask('Sembrar', done: true),
      ]);
    });

    testWidgets('express rows can be added and removed', (tester) async {
      await _openView(tester, kind: SeedlyProjectKind.express);
      expect(find.byType(SeedlyTaskField), findsOneWidget);
      expect(find.byTooltip('Quitar tarea'), findsNothing);

      await _tapVisible(tester, find.text('Añadir tarea'));
      await _tapVisible(tester, find.text('Añadir tarea'));
      expect(find.byType(SeedlyTaskField), findsNWidgets(3));
      await tester.enterText(find.byType(SeedlyTaskField).at(0), 'Uno');
      await tester.enterText(find.byType(SeedlyTaskField).at(2), 'Tres');

      await _tapVisible(tester, find.byTooltip('Quitar tarea').at(1));
      expect(find.byType(SeedlyTaskField), findsNWidgets(2));
      // The other rows keep their text.
      expect(find.text('Uno'), findsOneWidget);
      expect(find.text('Tres'), findsOneWidget);
    });

    testWidgets('switching to Completo drops empty express rows', (
      tester,
    ) async {
      await _openView(tester, kind: SeedlyProjectKind.express);
      await _tapVisible(tester, find.text('Añadir tarea'));
      await tester.enterText(find.byType(SeedlyTaskField).at(1), 'Regar');
      await tester.tap(find.text('Completo'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedlyCheckboxCard), findsOneWidget);
      expect(find.text('Regar'), findsOneWidget);
      // And Express always offers a row to type in.
      await _tapVisible(tester, find.byTooltip('Más opciones'));
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Express'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedlyTaskField), findsOneWidget);
    });
  });

  group('new task', () {
    testWidgets('"Añadir tarea" opens it with the project fixed', (
      tester,
    ) async {
      await _openView(tester);
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await _tapVisible(tester, find.text('Añadir tarea'));

      expect(find.byType(SeedlyCreateTaskView), findsOneWidget);
      expect(find.text('Nueva tarea'), findsOneWidget);
      expect(find.bySemanticsLabel('Proyecto: Huerto'), findsOneWidget);
      expect(find.text('Escribe tu tarea...'), findsOneWidget);
    });

    testWidgets('the empty task card also opens it', (tester) async {
      await _openView(tester);
      await _tapVisible(tester, find.text('¿Cuál es la tarea?'));
      expect(find.byType(SeedlyCreateTaskView), findsOneWidget);
    });

    testWidgets('a task needs a title', (tester) async {
      await _openView(tester);
      await _tapVisible(tester, find.text('Añadir tarea'));
      await _tapVisible(tester, find.text('Crear tarea'));
      final alert = tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));
      expect(alert.title, 'Campos incompletos');
      expect(alert.message, 'Escribe la tarea');
      expect(find.byType(SeedlyCreateTaskView), findsOneWidget);
    });

    testWidgets('back returns to the project with everything typed', (
      tester,
    ) async {
      await _openView(tester);
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await _tapVisible(tester, find.text('Añadir tarea'));
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(SeedlyCreateTaskView), findsNothing);
      expect(find.text('Huerto'), findsOneWidget);
      expect(find.byType(SeedlyCheckboxCard), findsNothing);
    });

    testWidgets('the system back button closes it before the project', (
      tester,
    ) async {
      await _openFromHome(tester, 'Proyecto completo');
      await _tapVisible(tester, find.text('Añadir tarea'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SeedlyCreateTaskView), findsNothing);
      expect(find.byType(SeedlyCreateProjectView), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SeedlyCreateProjectView), findsNothing);
    });

    testWidgets('time waits for a date and reminders wait for a time', (
      tester,
    ) async {
      await _openView(tester);
      await _tapVisible(tester, find.text('Añadir tarea'));
      await _tapVisible(tester, find.text('Mostrar más opciones'));

      SeedlyInputButton hour() =>
          tester.widget<SeedlyInputButton>(find.byType(SeedlyInputButton));
      SeedlyInputTags reminder() => tester.widget<SeedlyInputTags>(
        find.widgetWithText(SeedlyInputTags, 'Recordatorio'),
      );
      expect(hour().enabled, isFalse);
      expect(reminder().enabled, isFalse);

      await _tapVisible(tester, find.text('Mañana'));
      expect(hour().enabled, isTrue);
      expect(reminder().enabled, isFalse);

      await _tapVisible(tester, find.byType(SeedlyInputButton));
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(hour().value, '9:00 AM');
      expect(reminder().enabled, isTrue);

      await _tapVisible(tester, find.text('30 min antes'));
      expect(reminder().value, '30 min antes');

      // Clearing the day clears what depends on it.
      await _tapVisible(tester, find.text('Mañana'));
      expect(hour().value, isNull);
      expect(reminder().value, isNull);
    });

    testWidgets('the time wheels set the deadline', (tester) async {
      await _openView(tester);
      await _tapVisible(tester, find.text('Añadir tarea'));
      await _tapVisible(tester, find.text('Mostrar más opciones'));
      await _tapVisible(tester, find.text('Hoy'));
      await _tapVisible(tester, find.byType(SeedlyInputButton));
      expect(find.text('Seleccionar hora'), findsOneWidget);

      // One row down on hours (9 → 10) and on AM/PM (AM → PM).
      final wheels = find.byType(ListWheelScrollView);
      await tester.drag(wheels.at(0), const Offset(0, -62));
      await tester.pumpAndSettle();
      await tester.drag(wheels.at(2), const Offset(0, -62));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SeedlyInputButton>(find.byType(SeedlyInputButton)).value,
        '10:00 PM',
      );
    });

    testWidgets('a created task shows as a card with its deadline', (
      tester,
    ) async {
      final (projects, _) = await _openView(tester);
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await _tapVisible(tester, find.text('Añadir tarea'));
      await tester.enterText(_taskTitle, ' Sembrar ');
      await _tapVisible(tester, find.text('Mañana'));
      await _tapVisible(tester, find.text('Mostrar más opciones'));
      await _tapVisible(tester, find.byType(SeedlyInputButton));
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('1 hora antes'));
      await _tapVisible(tester, find.text('Crear tarea'));

      expect(find.byType(SeedlyCreateTaskView), findsNothing);
      final card = tester.widget<SeedlyCheckboxCard>(
        find.byType(SeedlyCheckboxCard),
      );
      expect(card.label, 'Sembrar');
      expect(card.time, '13 oct 2026 · 9:00 AM');

      await _tapVisible(tester, find.text('Crear proyecto'));
      expect(projects.created.single.tasks, [
        NewSeedlyTask(
          'Sembrar',
          dueDate: DateTime(2026, 10, 13),
          dueMinutes: 9 * 60,
          reminderMinutes: 60,
        ),
      ]);
    });

    testWidgets('a task can be edited and removed from its menu', (
      tester,
    ) async {
      await _openView(tester);
      await _createTask(tester, 'Sembrar', tag: 'Hoy');
      await _createTask(tester, 'Regar');

      await _tapVisible(tester, find.byTooltip('Más opciones').first);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar tarea'), findsOneWidget);
      expect(find.text('Sembrar'), findsOneWidget);
      expect(
        tester.widget<SeedlyInputTags>(find.byType(SeedlyInputTags)).value,
        '12 oct 2026',
      );
      await tester.enterText(_taskTitle, 'Sembrar tomates');
      await _tapVisible(tester, find.text('Guardar tarea'));
      expect(find.text('Sembrar tomates'), findsOneWidget);

      await _tapVisible(tester, find.byTooltip('Más opciones').last);
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      expect(find.text('Regar'), findsNothing);
      expect(find.byType(SeedlyCheckboxCard), findsOneWidget);
    });

    testWidgets('editing keeps the task done', (tester) async {
      final (projects, _) = await _openView(tester);
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await _createTask(tester, 'Sembrar');
      await _tapVisible(tester, find.text('Sembrar'));
      expect(
        tester
            .widget<SeedlyCheckboxCard>(find.byType(SeedlyCheckboxCard))
            .value,
        isTrue,
      );
      await _tapVisible(tester, find.byTooltip('Más opciones'));
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Guardar tarea'));
      await _tapVisible(tester, find.text('Crear proyecto'));
      expect(projects.created.single.tasks.single.done, isTrue);
    });
  });

  group('saving', () {
    testWidgets('a full project saves everything it shows', (tester) async {
      final (projects, created) = await _openView(tester);
      await tester.enterText(find.byType(SeedlyInput).at(0), '  Huerto  ');
      await tester.enterText(find.byType(SeedlyInput).at(1), 'Tomates');
      await _tapVisible(tester, find.byTooltip('Cambiar imagen'));
      await tester.tap(find.text('Hogar'));
      await tester.pumpAndSettle();
      await _pickDate(tester, 0, '13 oct 2026');
      await _pickDate(tester, 1, '30 oct 2026');
      await _createTask(tester, 'Sembrar');
      await _createTask(tester, ' Regar ');
      // The first task is already done.
      await _tapVisible(tester, find.text('Sembrar'));

      await _tapVisible(tester, find.text('Crear proyecto'));

      final project = projects.created.single;
      expect(project.name, 'Huerto');
      expect(project.kind, SeedlyProjectKind.full);
      expect(project.description, 'Tomates');
      expect(project.icon, SeedlyProjectIcon.hogar);
      expect(project.startDate, DateTime(2026, 10, 13));
      expect(project.endDate, DateTime(2026, 10, 30));
      // Titles trimmed and each keeps its state.
      expect(project.tasks, const [
        NewSeedlyTask('Sembrar', done: true),
        NewSeedlyTask('Regar'),
      ]);
      expect(created, [project]);
    });

    testWidgets('an express project saves its tasks but not Completo extras', (
      tester,
    ) async {
      final (projects, _) = await _openView(tester);
      await tester.enterText(find.byType(SeedlyInput).at(0), 'Huerto');
      await tester.enterText(find.byType(SeedlyInput).at(1), 'No se guarda');
      await _pickDate(tester, 0, '13 oct 2026');
      await _createTask(tester, 'Sembrar', tag: 'Hoy');
      await tester.tap(find.text('Express'));
      await tester.pumpAndSettle();
      // Express shows Completo's tasks as rows and keeps their details.
      expect(find.byType(SeedlyTaskField), findsOneWidget);
      await _tapVisible(tester, find.text('Añadir tarea'));
      await tester.enterText(find.byType(SeedlyTaskField).at(1), 'Cosechar');
      await _pickDate(tester, 0, '25 oct 2026');

      await _tapVisible(tester, find.text('Crear proyecto'));

      final project = projects.created.single;
      expect(project.kind, SeedlyProjectKind.express);
      expect(project.description, isNull);
      expect(project.startDate, isNull);
      expect(project.endDate, DateTime(2026, 10, 25));
      expect(project.tasks, [
        NewSeedlyTask('Sembrar', dueDate: DateTime(2026, 10, 12)),
        const NewSeedlyTask('Cosechar'),
      ]);
    });

    testWidgets('a saved project closes the form with a success alert', (
      tester,
    ) async {
      final projects = await _openFromHome(tester, 'Proyecto Express');
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await tester.enterText(find.byType(SeedlyTaskField).first, 'Sembrar');
      await _tapVisible(tester, find.text('Crear proyecto'));

      expect(projects.created, hasLength(1));
      expect(find.byType(SeedlyCreateProjectView), findsNothing);
      final alert = tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));
      expect(alert.style, SeedlyAlertStyle.success);
      expect(alert.title, 'Proyecto creado');
      expect(alert.message, '«Huerto» ya está en tus proyectos.');
    });

    testWidgets('offline saves say they will sync later', (tester) async {
      await _openFromHome(
        tester,
        'Proyecto Express',
        projects: FakeSeedlyProjects(save: SeedlyProjectSave.pendingSync),
      );
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await tester.enterText(find.byType(SeedlyTaskField).first, 'Sembrar');
      await _tapVisible(tester, find.text('Crear proyecto'));
      expect(
        tester.widget<SeedlyAlert>(find.byType(SeedlyAlert)).message,
        '«Huerto» se guardará cuando vuelva la conexión.',
      );
    });

    testWidgets('a failed save keeps the form open with the error', (
      tester,
    ) async {
      await _openFromHome(
        tester,
        'Proyecto Express',
        projects: FakeSeedlyProjects(
          error: const SeedlyProjectsException('Sin conexión.'),
        ),
      );
      await tester.enterText(find.byType(SeedlyInput).first, 'Huerto');
      await tester.enterText(find.byType(SeedlyTaskField).first, 'Sembrar');
      await _tapVisible(tester, find.text('Crear proyecto'));

      final alert = tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));
      expect(alert.style, SeedlyAlertStyle.danger);
      expect(alert.title, 'No se pudo crear el proyecto');
      expect(find.byType(SeedlyCreateProjectView), findsOneWidget);
      expect(find.text('Huerto'), findsOneWidget);
    });
  });
}
