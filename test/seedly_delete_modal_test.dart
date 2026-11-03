import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/modals/seedly_confirm_modal.dart';
import 'package:seedly/modals/seedly_delete_modal.dart';
import 'package:seedly/theme/seedly_theme.dart';

const _message =
    '¿Estás seguro de eliminar este proyecto? Es una acción permanente y '
    'todas sus tareas e información se perderán.';

/// Opens the delete modal from a button and records what it completed with.
Future<List<bool>> _open(
  WidgetTester tester, {
  Size size = const Size(440, 956),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final results = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: SeedlyTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showSeedlyDeleteModal(
                context,
                title: 'Eliminar proyecto',
                message: _message,
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return results;
}

void main() {
  testWidgets('is the shared red confirmation modal', (tester) async {
    await _open(tester);

    // Not a copy of it: the very same content, so both always agree.
    expect(find.byType(SeedlyConfirmContent), findsOneWidget);
    final content = tester.widget<SeedlyConfirmContent>(
      find.byType(SeedlyConfirmContent),
    );
    expect(content.illustration, 'assets/images/modal_trash.svg');
    expect(content.confirmIcon, 'assets/images/icon_trash.svg');
    expect(content.confirmLabel, 'Eliminar');
    expect(content.cancelLabel, 'Cancelar');
  });

  testWidgets('says what is about to be lost, with Figma\'s type', (
    tester,
  ) async {
    await _open(tester);

    final title = tester.widget<Text>(find.text('Eliminar proyecto'));
    expect(title.style!.fontSize, 28);
    expect(title.style!.letterSpacing, 2);
    expect(find.text(_message), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    // The blob, the trash and the button's trash.
    expect(find.byType(SvgPicture), findsNWidgets(3));
    expect(find.byTooltip('Cerrar'), findsNothing);
  });

  testWidgets('Eliminar completes with true and closes it', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text('Eliminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(results, [true]);
    expect(find.text('Eliminar proyecto'), findsNothing);
  });

  testWidgets('Cancelar completes with false', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(results, [false]);
  });

  testWidgets('tapping outside it counts as no', (tester) async {
    final results = await _open(tester);

    await tester.tapAt(const Offset(220, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(results, [false]);
  });

  testWidgets('on a short phone both buttons are on screen without scrolling', (
    tester,
  ) async {
    // The test font is far wider than the app's, which would wrap the message
    // into many more lines than a phone shows.
    await (FontLoader('Plus Jakarta Sans')..addFont(
          rootBundle.load(
            'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf',
          ),
        ))
        .load();
    await _open(tester, size: const Size(360, 640));

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      tester.getRect(find.widgetWithText(FilledButton, 'Eliminar')).bottom,
      lessThanOrEqualTo(screen.height),
    );
    expect(
      tester.getRect(find.text('Cancelar')).bottom,
      lessThanOrEqualTo(screen.height),
    );
  });
}
