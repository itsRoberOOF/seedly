import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_header.dart';

Widget _host(Widget child) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(body: Center(child: child)),
);

/// A screen with a button that opens a floating alert.
Widget _launcher({String message = 'Correo o contraseña incorrectos'}) =>
    MaterialApp(
      theme: SeedlyTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showSeedlyAlert(
                context,
                style: SeedlyAlertStyle.danger,
                title: 'No se pudo iniciar sesión',
                message: message,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

/// Laid out like the create-project form: the header, when [showHeader] is
/// on, sits at the top with a button below it that opens a floating alert.
Widget _form({required ValueNotifier<bool> showHeader, VoidCallback? onBack}) =>
    MaterialApp(
      theme: SeedlyTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: ValueListenableBuilder(
            valueListenable: showHeader,
            builder: (context, show, _) => Column(
              children: [
                if (show)
                  SeedlyHeader(
                    title: 'Nuevo proyecto',
                    onBack: onBack ?? () {},
                  ),
                const SizedBox(height: 200),
                TextButton(
                  onPressed: () => showSeedlyAlert(
                    context,
                    style: SeedlyAlertStyle.danger,
                    title: 'Campos incompletos',
                    message: 'Escribe un nombre',
                  ),
                  child: const Text('abrir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  tearDown(hideSeedlyAlert);

  testWidgets('each style tints the title and icon with its Figma accent', (
    tester,
  ) async {
    final accents = {
      SeedlyAlertStyle.notification: SeedlyPalette.neutral[850],
      SeedlyAlertStyle.success: SeedlyPalette.success[600],
      SeedlyAlertStyle.info: SeedlyPalette.info[600],
      SeedlyAlertStyle.warning: SeedlyPalette.warning[600],
      SeedlyAlertStyle.danger: SeedlyPalette.danger[600],
    };
    for (final MapEntry(key: style, value: accent) in accents.entries) {
      await tester.pumpWidget(
        _host(SeedlyAlert(style: style, title: 'Title', message: 'Message')),
      );
      expect(tester.widget<Text>(find.text('Title')).style?.color, accent);
      expect(
        tester.widget<Text>(find.text('Message')).style?.color,
        SeedlyPalette.textSecondaryDark,
      );
      final icon = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
      expect(icon.colorFilter, ColorFilter.mode(accent!, BlendMode.srcIn));
    }
  });

  testWidgets('danger uses the warning icon, others the info icon', (
    tester,
  ) async {
    String iconAsset() =>
        ((tester.widget<SvgPicture>(find.byType(SvgPicture).first).bytesLoader)
                as SvgAssetLoader)
            .assetName;

    await tester.pumpWidget(
      _host(
        const SeedlyAlert(
          style: SeedlyAlertStyle.danger,
          title: 'Error',
          message: 'Descripción',
        ),
      ),
    );
    expect(iconAsset(), 'assets/images/input_warning_circle.svg');

    await tester.pumpWidget(
      _host(
        const SeedlyAlert(
          style: SeedlyAlertStyle.info,
          title: 'Info',
          message: 'Descripción',
        ),
      ),
    );
    expect(iconAsset(), 'assets/images/alert_info.svg');
  });

  testWidgets('close button and actions appear only when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SeedlyAlert(title: 'Title', message: 'Message')),
    );
    expect(find.byTooltip('Cerrar'), findsNothing);
    expect(find.byType(TextButton), findsNothing);

    var closed = 0;
    final pressed = <String>[];
    await tester.pumpWidget(
      _host(
        SeedlyAlert(
          title: 'Recordatorio de tarea',
          message: 'Es un buen momento para continuar',
          onClose: () => closed++,
          secondaryAction: SeedlyAlertAction(
            label: 'Posponer 5 min',
            onPressed: () => pressed.add('secondary'),
          ),
          primaryAction: SeedlyAlertAction(
            label: 'Abrir Seedly',
            onPressed: () => pressed.add('primary'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.tap(find.text('Posponer 5 min'));
    await tester.tap(find.text('Abrir Seedly'));
    expect(closed, 1);
    expect(pressed, ['secondary', 'primary']);
    expect(
      tester.getRect(find.text('Posponer 5 min')).right,
      lessThan(tester.getRect(find.text('Abrir Seedly')).left),
    );
  });

  testWidgets('close icon sits 16px from the top-right edges like Figma', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 400,
          child: SeedlyAlert(
            title: 'Error',
            message: 'Descripción',
            onClose: () {},
          ),
        ),
      ),
    );
    final alert = tester.getRect(find.byType(SeedlyAlert));
    final icon = tester.getRect(
      find.descendant(
        of: find.byTooltip('Cerrar'),
        matching: find.byType(SvgPicture),
      ),
    );
    expect(icon.size, const Size(24, 24));
    expect(alert.right - icon.right, 16);
    expect(icon.top - alert.top, 18);
  });

  testWidgets('floating alert closes itself after five seconds', (
    tester,
  ) async {
    await tester.pumpWidget(_launcher());
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo iniciar sesión'), findsOneWidget);
    expect(
      tester.getRect(find.byType(SeedlyAlert)).top,
      lessThan(tester.getRect(find.text('abrir')).top),
    );

    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(SeedlyAlert), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyAlert), findsNothing);
  });

  testWidgets('the X closes the floating alert early', (tester) async {
    await tester.pumpWidget(_launcher());
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyAlert), findsNothing);
  });

  testWidgets('a new alert replaces the visible one', (tester) async {
    await tester.pumpWidget(_launcher());
    await tester.tap(find.text('abrir'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyAlert), findsOneWidget);
  });

  group('header back arrow', () {
    Rect alert(WidgetTester tester) => tester.getRect(find.byType(SeedlyAlert));
    Rect arrow(WidgetTester tester) => tester.getRect(find.byTooltip('Volver'));

    testWidgets('without a header the alert keeps its spot at the top', (
      tester,
    ) async {
      await tester.pumpWidget(_form(showHeader: ValueNotifier(false)));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(alert(tester).top, 12);
    });

    testWidgets('the alert opens below the arrow, which stays tappable', (
      tester,
    ) async {
      var backs = 0;
      await tester.pumpWidget(
        _form(showHeader: ValueNotifier(true), onBack: () => backs++),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(alert(tester).top, greaterThan(arrow(tester).bottom));

      await tester.tap(find.byTooltip('Volver'));
      expect(backs, 1);
    });

    testWidgets('a header that opens under a visible alert pushes it down', (
      tester,
    ) async {
      final showHeader = ValueNotifier(false);
      await tester.pumpWidget(_form(showHeader: showHeader));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(alert(tester).top, 12);

      showHeader.value = true;
      await tester.pumpAndSettle();
      expect(alert(tester).top, greaterThan(arrow(tester).bottom));
    });

    testWidgets('a header on a screen underneath does not move the alert', (
      tester,
    ) async {
      await tester.pumpWidget(_form(showHeader: ValueNotifier(true)));
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () => showSeedlyAlert(
                        context,
                        title: 'Recordatorio',
                        message: 'Es un buen momento para continuar',
                      ),
                      child: const Text('encima'),
                    ),
                  ),
                ),
              ),
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.text('encima'));
      await tester.pumpAndSettle();
      expect(alert(tester).top, 12);
    });
  });
}
