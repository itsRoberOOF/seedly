import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_drops.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_progress_view.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_menu.dart';
import 'package:seedly/widgets/seedly_plant.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';
import 'support/keep_plant_still.dart';

Widget _progress(FakeSeedlyDropsRepository drops, {VoidCallback? onWater}) =>
    MaterialApp(
      theme: SeedlyTheme.light,
      home: SeedlyProgressView(drops: drops, onWater: onWater),
    );

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _SlowDrops extends FakeSeedlyDropsRepository {
  _SlowDrops() : super(phase: 2, startingDrops: 500);

  final release = Completer<void>();
  int growCalls = 0;

  @override
  Future<void> growPlant() async {
    growCalls++;
    await release.future;
    await super.growPlant();
  }
}

class _HangingDrops extends FakeSeedlyDropsRepository {
  _HangingDrops() : super(startingDrops: 18);

  final pending = StreamController<SeedlyPlantState>();
  bool respond = false;

  @override
  Stream<SeedlyPlantState> watchPlantState() =>
      respond ? super.watchPlantState() : pending.stream;
}

void main() {
  keepPlantStill();
  tearDown(hideSeedlyAlert);

  testWidgets('shows the current phase and remaining drops', (tester) async {
    final drops = FakeSeedlyDropsRepository(phase: 2, startingDrops: 300);
    await tester.pumpWidget(_progress(drops));
    await tester.pump();

    expect(find.text('Mi progreso'), findsOneWidget);
    expect(find.text('300 / 500'), findsOneWidget);
    expect(
      find.text('Te faltan 200 gotas para la siguiente fase'),
      findsOneWidget,
    );
    expect(tester.widget<SeedlyPlant>(find.byType(SeedlyPlant)).phase, 2);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.6);
  });

  testWidgets('grows once and shows the new phase and its real next goal', (
    tester,
  ) async {
    final drops = _SlowDrops();
    await tester.pumpWidget(_progress(drops));
    await tester.pump();

    expect(find.text('500 / 500'), findsOneWidget);
    expect(find.text('Haz crecer tu planta'), findsOneWidget);
    await tester.tap(find.text('Haz crecer tu planta'));
    await tester.tap(find.text('Haz crecer tu planta'));
    await tester.pump();
    expect(drops.growCalls, 1);
    expect(find.text('Haciendo crecer tu planta…'), findsOneWidget);

    drops.release.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('¡Tu planta creció!'), findsOneWidget);
    expect(find.text('1,200'), findsOneWidget);
    expect(find.text('Tu próxima meta'), findsOneWidget);
    expect(tester.widget<SeedlyPlant>(find.byType(SeedlyPlant)).phase, 3);
  });

  testWidgets('at the last phase shows accumulated drops without grow', (
    tester,
  ) async {
    _phoneSize(tester);
    final drops = FakeSeedlyDropsRepository(phase: 4, startingDrops: 1240);
    var waterCalls = 0;
    await tester.pumpWidget(_progress(drops, onWater: () => waterCalls++));
    await tester.pump();

    expect(find.text('¡Nivel máximo!'), findsOneWidget);
    expect(find.text('1,240'), findsOneWidget);
    expect(find.text('Gotas acumuladas'), findsOneWidget);
    expect(find.text('Haz crecer tu planta'), findsNothing);
    expect(tester.widget<SeedlyPlant>(find.byType(SeedlyPlant)).phase, 4);
    await tester.tap(find.text('Seguir regando'));
    expect(waterCalls, 1);
  });

  testWidgets('growth into phase four has a confirmation, then maximum', (
    tester,
  ) async {
    final drops = FakeSeedlyDropsRepository(phase: 3, startingDrops: 1200);
    await tester.pumpWidget(_progress(drops));
    await tester.pump();
    await tester.tap(find.text('Haz crecer tu planta'));
    await tester.pump();
    await tester.pump();
    expect(find.text('¡Tu planta creció!'), findsOneWidget);
    expect(find.text('Gotas acumuladas'), findsOneWidget);
    expect(find.text('Tu próxima meta'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_progress(drops));
    await tester.pump();
    expect(find.text('¡Nivel máximo!'), findsOneWidget);
  });

  testWidgets('a read error can be retried without inventing zero drops', (
    tester,
  ) async {
    final drops = FakeSeedlyDropsRepository(startingDrops: 300)
      ..error = const SeedlyDropsException(SeedlyDropsError.saveFailed);
    await tester.pumpWidget(_progress(drops));
    await tester.pump();
    expect(find.text('No se pudo cargar tu progreso.'), findsOneWidget);
    expect(find.text('0 / 150'), findsNothing);

    drops.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('300 / 150'), findsOneWidget);
  });

  testWidgets('a stalled initial read offers retry after twelve seconds', (
    tester,
  ) async {
    final drops = _HangingDrops();
    addTearDown(drops.pending.close);
    await tester.pumpWidget(_progress(drops));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 12));
    expect(find.text('No se pudo cargar tu progreso.'), findsOneWidget);
    expect(find.text('0 / 150'), findsNothing);

    drops.respond = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('18 / 150'), findsOneWidget);
  });

  testWidgets('a failed growth keeps the ready phase and explains the error', (
    tester,
  ) async {
    final drops = FakeSeedlyDropsRepository(startingDrops: 150);
    await tester.pumpWidget(_progress(drops));
    await tester.pump();
    drops.error = const SeedlyDropsException(SeedlyDropsError.saveFailed);

    await tester.tap(find.text('Haz crecer tu planta'));
    await tester.pump();
    expect(find.text('Haz crecer tu planta'), findsOneWidget);
    expect(tester.widget<SeedlyPlant>(find.byType(SeedlyPlant)).phase, 1);
    expect(find.text('No se pudo hacer crecer tu planta'), findsOneWidget);
  });

  testWidgets('the maximum screen scrolls on a small phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final drops = FakeSeedlyDropsRepository(phase: 4, startingDrops: 1240);
    await tester.pumpWidget(_progress(drops));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Seguir regando'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inicio opens Mi progreso when the plant is tapped', (
    tester,
  ) async {
    final drops = FakeSeedlyDropsRepository(startingDrops: 18);
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyHomeScreen(
          auth: FakeSeedlyAuthRepository(isSignedIn: true),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
          drops: drops,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(SeedlyPlant));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyProgressView), findsOneWidget);
    expect(find.text('18 / 150'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyProgressView), findsNothing);
    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
  });

  testWidgets('watering CTA fits a narrow phone and opens the Riego tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final drops = FakeSeedlyDropsRepository(startingDrops: 18);
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyHomeScreen(
          auth: FakeSeedlyAuthRepository(isSignedIn: true),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
          drops: drops,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(SeedlyPlant));
    await tester.pumpAndSettle();

    final label = find.text('Sigue regando y lo lograrás');
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);

    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyProgressView), findsNothing);
    expect(
      tester.widget<SeedlyMenu>(find.byType(SeedlyMenu)).active,
      SeedlyMenuTab.riego,
    );
  });
}
