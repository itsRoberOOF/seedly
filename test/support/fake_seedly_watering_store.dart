import 'package:seedly/models/seedly_watering.dart';
import 'package:seedly/services/seedly_watering_store.dart';

/// [SeedlyWateringStore] en memoria, para que los tests nunca toquen la
/// plataforma.
class FakeSeedlyWateringStore implements SeedlyWateringStore {
  FakeSeedlyWateringStore([Map<String, SeedlyWateringSession>? saved])
    : saved = saved ?? {};

  /// Sesiones por dueño.
  final Map<String, SeedlyWateringSession> saved;

  /// Si está presente, todos los métodos lo lanzan.
  Object? error;

  @override
  Future<SeedlyWateringSession?> load(String ownerId) async {
    _check();
    return saved[ownerId];
  }

  @override
  Future<void> save(SeedlyWateringSession session) async {
    _check();
    saved[session.ownerId] = session;
  }

  @override
  Future<void> clear(String ownerId) async {
    _check();
    saved.remove(ownerId);
  }

  void _check() {
    if (error case final error?) throw error;
  }
}
