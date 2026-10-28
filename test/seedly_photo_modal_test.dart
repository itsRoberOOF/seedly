import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/modals/seedly_photo_modal.dart';
import 'package:seedly/services/seedly_image_picker.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_modal.dart';

import 'support/fake_seedly_image_picker.dart';

Future<List<Object?>> _open(
  WidgetTester tester,
  FakeSeedlyImagePicker picker, {
  bool hasPhoto = false,
}) async {
  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: SeedlyTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showSeedlyPhotoModal(
                context,
                picker: picker,
                hasPhoto: hasPhoto,
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  tearDown(hideSeedlyAlert);

  testWidgets('without a photo it only offers to choose one', (tester) async {
    await _open(tester, FakeSeedlyImagePicker());

    expect(find.text('Foto de perfil'), findsOneWidget);
    expect(find.text('Elegir imagen'), findsOneWidget);
    expect(find.text('Quitar foto'), findsNothing);
  });

  testWidgets('with a photo it also offers to remove it', (tester) async {
    await _open(tester, FakeSeedlyImagePicker(), hasPhoto: true);

    expect(find.text('Elegir imagen'), findsOneWidget);
    expect(find.text('Quitar foto'), findsOneWidget);
    expect(find.text('Volver a mostrar tus iniciales'), findsOneWidget);
  });

  testWidgets('choosing completes with the picked bytes', (tester) async {
    final picker = FakeSeedlyImagePicker(photo: tinyPng);
    final results = await _open(tester, picker);

    await tester.tap(find.text('Elegir imagen'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(find.byType(SeedlyModal), findsNothing);
    final choice = results.single! as SeedlyPhotoPicked;
    expect(choice.photo, tinyPng);
  });

  testWidgets('closing the system picker keeps the modal open', (tester) async {
    final results = await _open(tester, FakeSeedlyImagePicker());

    await tester.tap(find.text('Elegir imagen'));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyModal), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('a picker error alerts and keeps the modal open', (tester) async {
    final results = await _open(
      tester,
      FakeSeedlyImagePicker(
        error: const SeedlyImagePickerException('La imagen es muy grande.'),
      ),
    );

    await tester.tap(find.text('Elegir imagen'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar la imagen'), findsOneWidget);
    expect(find.text('La imagen es muy grande.'), findsOneWidget);
    expect(find.byType(SeedlyModal), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('removing completes with SeedlyPhotoRemoved', (tester) async {
    final results = await _open(
      tester,
      FakeSeedlyImagePicker(),
      hasPhoto: true,
    );

    await tester.tap(find.text('Quitar foto'));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyModal), findsNothing);
    expect(results.single, isA<SeedlyPhotoRemoved>());
  });

  testWidgets('the close button completes with null', (tester) async {
    final results = await _open(tester, FakeSeedlyImagePicker());

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyModal), findsNothing);
    expect(results, [null]);
  });
}
