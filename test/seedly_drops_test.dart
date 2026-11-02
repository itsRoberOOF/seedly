import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_drops.dart';

void main() {
  test('a new plant aims at phase 2', () {
    const state = SeedlyPlantState(phase: 1, totalDrops: 0);
    expect(state.nextGoal, 150);
    expect(state.canGrow, isFalse);
  });

  test('can grow once the next goal is reached', () {
    expect(const SeedlyPlantState(phase: 1, totalDrops: 150).canGrow, isTrue);
    expect(const SeedlyPlantState(phase: 2, totalDrops: 499).canGrow, isFalse);
    expect(const SeedlyPlantState(phase: 3, totalDrops: 1200).canGrow, isTrue);
  });

  test('the last phase has no goal and keeps counting drops', () {
    const state = SeedlyPlantState(phase: 4, totalDrops: 5000);
    expect(state.nextGoal, isNull);
    expect(state.canGrow, isFalse);
  });

  test('growing is manual: extra drops do not skip phases', () {
    // 600 drops reach phase 3's goal, but a phase 1 plant only grows to 2.
    expect(const SeedlyPlantState(phase: 1, totalDrops: 600).nextGoal, 150);
  });
}
