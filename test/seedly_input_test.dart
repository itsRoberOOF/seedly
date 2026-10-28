import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_input.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(body: Center(child: child)),
);

SeedlyInput _input({
  String? initialValue,
  bool readOnly = false,
  TextEditingController? controller,
}) => SeedlyInput(
  label: 'Nombre',
  hint: 'Tu nombre',
  readOnly: readOnly,
  initialValue: initialValue,
  controller: controller,
);

InputDecoration _decoration(WidgetTester tester) =>
    tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;

void main() {
  testWidgets('a read-only field follows a new initialValue on rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_input(readOnly: true, initialValue: 'Ana')));
    expect(find.text('Ana'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(_input(readOnly: true, initialValue: 'Ana Nueva')),
    );

    expect(find.text('Ana Nueva'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('an editable field keeps what the user typed on rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_input(initialValue: 'Ana')));
    await tester.enterText(find.byType(EditableText), 'Escrito');
    await tester.pump();

    await tester.pumpWidget(_wrap(_input(initialValue: 'Ana')));

    expect(find.text('Escrito'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('an editable field ignores a new initialValue after typing', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_input(initialValue: 'Ana')));
    await tester.enterText(find.byType(EditableText), 'Escrito');
    await tester.pump();

    await tester.pumpWidget(_wrap(_input(initialValue: 'Otra')));

    expect(find.text('Escrito'), findsOneWidget);
  });

  testWidgets('a read-only field has no green border when focused', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_input(readOnly: true, initialValue: 'Ana')));
    await tester.tap(find.byType(EditableText));
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    final decoration = _decoration(tester);
    expect(decoration.focusedBorder, same(decoration.enabledBorder));
  });

  testWidgets('an editable field keeps the green border when focused', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_input(initialValue: 'Ana')));
    await tester.tap(find.byType(EditableText));
    await tester.pump();

    final decoration = _decoration(tester);
    expect(decoration.focusedBorder, isNot(same(decoration.enabledBorder)));
    final focused = decoration.focusedBorder! as OutlineInputBorder;
    expect(focused.borderSide.width, 1.5);
    expect(focused.borderSide.color, SeedlyPalette.primary[500]);
  });

  testWidgets('a read-only field with its own controller is not reset', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Ana');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(_input(readOnly: true, controller: controller)),
    );

    controller.text = 'Cambiado';
    await tester.pumpWidget(
      _wrap(_input(readOnly: true, controller: controller)),
    );

    expect(find.text('Cambiado'), findsOneWidget);
    expect(controller.text, 'Cambiado');
  });

  testWidgets('a read-only field still ignores typed text', (tester) async {
    await tester.pumpWidget(_wrap(_input(readOnly: true, initialValue: 'Ana')));

    await tester.enterText(find.byType(EditableText), 'Otro');
    await tester.pump();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Otro'), findsNothing);
  });
}
