import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_watering.dart';
import 'package:seedly/services/seedly_watering_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final session = SeedlyWateringSession(
    id: 's1',
    ownerId: 'ana',
    minutes: 25,
    startedAt: DateTime(2026, 11, 2, 10),
    pausedAt: DateTime(2026, 11, 2, 10, 5),
    focusTaskId: 't1',
    focusTitle: 'Estudiar',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guarda y recupera la sesión de su dueño', () async {
    final store = SharedPreferencesSeedlyWateringStore();

    await store.save(session);

    expect(await store.load('ana'), session);
    expect(await store.load('beto'), isNull);
  });

  test('borrar la quita', () async {
    final store = SharedPreferencesSeedlyWateringStore();
    await store.save(session);

    await store.clear('ana');

    expect(await store.load('ana'), isNull);
  });

  test('una copia ilegible no se retoma y se borra', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSeedlyWateringStore.key('ana'): '{roto',
    });
    final store = SharedPreferencesSeedlyWateringStore();

    expect(await store.load('ana'), isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.containsKey(SharedPreferencesSeedlyWateringStore.key('ana')),
      isFalse,
    );
  });

  test('la sesión de otra persona nunca se entrega', () async {
    final store = SharedPreferencesSeedlyWateringStore();
    await store.save(session);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      SharedPreferencesSeedlyWateringStore.key('beto'),
      preferences.getString(SharedPreferencesSeedlyWateringStore.key('ana'))!,
    );

    expect(await store.load('beto'), isNull);
  });
}
