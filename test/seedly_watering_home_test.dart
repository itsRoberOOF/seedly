import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_watering.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_button.dart';
import 'package:seedly/widgets/seedly_menu.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_notification_service.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';
import 'support/fake_seedly_watering_store.dart';
import 'support/keep_plant_still.dart';
import 'support/sign_out.dart';

void main() {
  keepPlantStill();
  tearDown(hideSeedlyAlert);

  late FakeSeedlyNotificationService notifications;
  late FakeSeedlyWateringStore store;

  setUp(() {
    notifications = FakeSeedlyNotificationService();
    store = FakeSeedlyWateringStore();
  });

  Future<void> pumpHome(WidgetTester tester, {bool withDrops = true}) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyHomeScreen(
          auth: FakeSeedlyAuthRepository(isSignedIn: true),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
          drops: withDrops ? FakeSeedlyDropsRepository() : null,
          notifications: notifications,
          wateringStore: store,
        ),
      ),
    );
    await tester.pump();
  }

  /// Desmonta Home, y con él el controlador de riego y su timer.
  Future<void> close(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Finder tab(String label) =>
      find.descendant(of: find.byType(SeedlyMenu), matching: find.text(label));

  Future<void> openRiego(WidgetTester tester) async {
    await tester.tap(tab('Riego'));
    await tester.pump();
  }

  /// Una sesión guardada que empezó hace cinco minutos.
  SeedlyWateringSession running() => SeedlyWateringSession(
    id: 's1',
    ownerId: 'ana',
    minutes: 25,
    startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );

  testWidgets('la pestaña Riego abre "Empezar riego"', (tester) async {
    await pumpHome(tester);

    await openRiego(tester);

    expect(find.text('Sesión de Riego'), findsOneWidget);
    await close(tester);
  });

  testWidgets('"Regar por 25 minutos" de Inicio lleva a Riego', (tester) async {
    await pumpHome(tester);

    final water = find.widgetWithText(SeedlyButton, 'Regar por 25 minutos');
    await tester.ensureVisible(water);
    await tester.tap(water);
    await tester.pump();

    expect(find.text('Sesión de Riego'), findsOneWidget);
    await close(tester);
  });

  testWidgets('la flecha atrás de una sesión pregunta antes de terminar', (
    tester,
  ) async {
    store.saved['ana'] = running();
    await pumpHome(tester);
    await openRiego(tester);
    expect(find.text('Regando tu Seedly'), findsOneWidget);

    // La flecha ya no vuelve a Inicio: abre el modal de terminar sesión.
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('¿Terminar riego?'), findsOneWidget);

    // Cancelar cierra el modal y la sesión sigue en curso.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Terminar riego?'), findsNothing);
    expect(find.text('Regando tu Seedly'), findsOneWidget);
    await close(tester);
  });

  testWidgets('tocar un aviso de riego abre Riego', (tester) async {
    await pumpHome(tester);

    notifications.onWateringSessionTap!('s1');
    await tester.pump();

    expect(find.text('Sesión de Riego'), findsOneWidget);
    await close(tester);
  });

  testWidgets('retoma la sesión guardada en el teléfono', (tester) async {
    store.saved['ana'] = running();
    await pumpHome(tester);

    await openRiego(tester);

    expect(find.text('Regando tu Seedly'), findsOneWidget);
    expect(notifications.wateringNotices['s1'], isNotNull);
    await close(tester);
  });

  testWidgets('la sesión sigue al cambiar de pestaña', (tester) async {
    await pumpHome(tester);
    await openRiego(tester);
    final start = find.widgetWithText(SeedlyButton, 'Comenzar sesión');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    expect(find.text('Regando tu Seedly'), findsOneWidget);

    await tester.tap(tab('Inicio'));
    await tester.pump();
    await openRiego(tester);

    expect(find.text('Regando tu Seedly'), findsOneWidget);
    await close(tester);
  });

  testWidgets('cerrar sesión quita los avisos de riego y guarda la sesión', (
    tester,
  ) async {
    store.saved['ana'] = running();
    await pumpHome(tester);
    expect(notifications.wateringNotices['s1'], isNotNull);

    await tester.tap(tab('Mi perfil'));
    await tester.pump();
    await tapSignOut(tester);
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    expect(notifications.wateringNotices, isEmpty);
    expect(notifications.wateringEnds, isEmpty);
    expect(store.saved['ana'], isNotNull);
  });

  testWidgets('sin el sistema de gotas no hay pantalla de riego', (
    tester,
  ) async {
    await pumpHome(tester, withDrops: false);

    await openRiego(tester);

    expect(find.text('Sesión de Riego'), findsNothing);
    await close(tester);
  });
}
