import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/modals/seedly_confirm_modal.dart';
import 'package:seedly/theme/seedly_theme.dart';

/// Opens the modal from a button and records what it completed with.
Future<List<bool>> _open(
  WidgetTester tester, {
  Size size = const Size(440, 956),
  String? confirmIcon = 'assets/images/profile_log_out.svg',
  String confirmLabel = 'Salir',
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
              await showSeedlyConfirmModal(
                context,
                illustration: 'assets/images/modal_log_out.svg',
                title: 'Cerrar sesión',
                message: '¿Seguro que quieres cerrar sesión?',
                confirmLabel: confirmLabel,
                confirmIcon: confirmIcon,
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
  testWidgets('shows the illustration, texts and both buttons', (tester) async {
    await _open(tester);

    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text('¿Seguro que quieres cerrar sesión?'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Salir'), findsOneWidget);
    // The blob, the illustration and the button's icon.
    expect(find.byType(SvgPicture), findsNWidgets(3));
    // It is a confirmation, not a menu: no round close button.
    expect(find.byTooltip('Cerrar'), findsNothing);
  });

  testWidgets('follows Figma on a tall phone', (tester) async {
    await _open(tester);

    expect(
      tester.getSize(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is SizedBox &&
                  widget.width == 200 &&
                  widget.height == 200,
            )
            .first,
      ),
      const Size(200, 200),
    );
    final title = tester.widget<Text>(find.text('Cerrar sesión'));
    expect(title.style!.fontSize, 28);
    expect(title.style!.letterSpacing, 2);
    expect(title.textAlign, TextAlign.center);
    final message = tester.widget<Text>(
      find.text('¿Seguro que quieres cerrar sesión?'),
    );
    expect(message.style!.fontSize, 18);
    expect(message.style!.fontWeight, FontWeight.w500);
  });

  testWidgets('the confirm button is Figma\'s red, 48px tall, with its icon', (
    tester,
  ) async {
    await _open(tester);

    final button = find.widgetWithText(FilledButton, 'Salir');
    expect(tester.getSize(button).height, 48);
    final style = tester.widget<FilledButton>(button).style!;
    expect(style.backgroundColor!.resolve({}), SeedlyPalette.danger[600]);
    expect(
      find.descendant(of: button, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
  });

  testWidgets('without a confirm icon the button is text only', (tester) async {
    await _open(tester, confirmIcon: null);

    expect(
      find.descendant(
        of: find.widgetWithText(FilledButton, 'Salir'),
        matching: find.byType(SvgPicture),
      ),
      findsNothing,
    );
  });

  testWidgets('confirming completes with true and closes the modal', (
    tester,
  ) async {
    final results = await _open(tester);

    await tester.tap(find.text('Salir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(results, [true]);
    expect(find.text('¿Seguro que quieres cerrar sesión?'), findsNothing);
  });

  testWidgets('Cancelar completes with false', (tester) async {
    final results = await _open(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(results, [false]);
    expect(find.text('¿Seguro que quieres cerrar sesión?'), findsNothing);
  });

  testWidgets('tapping outside the modal counts as no', (tester) async {
    final results = await _open(tester);

    await tester.tapAt(const Offset(220, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(results, [false]);
  });

  testWidgets('a short phone gets a compact modal with its buttons on screen', (
    tester,
  ) async {
    await _open(tester, size: const Size(360, 640));

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final confirm = tester.getRect(find.widgetWithText(FilledButton, 'Salir'));
    final cancel = tester.getRect(find.text('Cancelar'));
    expect(confirm.bottom, lessThanOrEqualTo(screen.height));
    expect(cancel.bottom, lessThanOrEqualTo(screen.height));
    expect(
      tester.getSize(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is SizedBox &&
                  widget.width == 140 &&
                  widget.height == 140,
            )
            .first,
      ),
      const Size(140, 140),
    );
  });

  testWidgets('a long confirm label is not cut on a 360px phone', (
    tester,
  ) async {
    await (FontLoader('Plus Jakarta Sans')..addFont(
          rootBundle.load(
            'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf',
          ),
        ))
        .load();
    await _open(
      tester,
      size: const Size(360, 640),
      confirmLabel: 'Cerrar sesión',
    );

    final label = find.descendant(
      of: find.widgetWithText(FilledButton, 'Cerrar sesión'),
      matching: find.text('Cerrar sesión'),
    );
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(find.text('Cancelar'), findsOneWidget);
  });
}
