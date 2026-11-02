import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Taps Cerrar sesión in Mi perfil and confirms the red modal that opens.
///
/// The modal's button shares the label, so each is found by its kind: the
/// profile's is an outline button, the modal's a filled one.
Future<void> tapSignOut(WidgetTester tester) async {
  final button = find.widgetWithText(OutlinedButton, 'Cerrar sesión');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  final confirm = find.widgetWithText(FilledButton, 'Cerrar sesión');
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
  await tester.pump();
}
