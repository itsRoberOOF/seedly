import 'package:flutter_test/flutter_test.dart';

/// Home opens on Inicio, whose plant sways forever, so pumpAndSettle would
/// never settle. Turns on reduce motion, as a person could, for every test of
/// the calling file; the plant then stands still.
void keepPlantStill() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue(),
  );
}
