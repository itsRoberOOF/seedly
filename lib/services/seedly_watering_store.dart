import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/seedly_watering.dart';

/// Guarda en este teléfono la sesión en curso, para que sobreviva a que se
/// cierre la app. Firestore no puede: un documento de `sessions` solo tiene
/// su dueño y su inicio, y nunca cambia.
abstract interface class SeedlyWateringStore {
  /// La sesión en curso de [ownerId], o null.
  Future<SeedlyWateringSession?> load(String ownerId);

  /// Reemplaza la sesión guardada del dueño.
  Future<void> save(SeedlyWateringSession session);

  Future<void> clear(String ownerId);
}

/// Una preferencia por cuenta, para que la sesión de una persona nunca
/// aparezca para otra que entre en el mismo teléfono.
class SharedPreferencesSeedlyWateringStore implements SeedlyWateringStore {
  SharedPreferencesSeedlyWateringStore({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static String key(String ownerId) => 'seedly.watering.$ownerId';

  @override
  Future<SeedlyWateringSession?> load(String ownerId) async {
    final preferences = await _preferences();
    final saved = preferences.getString(key(ownerId));
    if (saved == null) return null;
    try {
      final json = jsonDecode(saved);
      if (json is! Map<String, Object?>) throw const FormatException();
      final session = SeedlyWateringSession.fromJson(json);
      return session.ownerId == ownerId ? session : null;
    } on FormatException {
      // Ilegible, por ejemplo de una versión anterior: no hay nada que
      // retomar.
      await preferences.remove(key(ownerId));
      return null;
    }
  }

  @override
  Future<void> save(SeedlyWateringSession session) async {
    final preferences = await _preferences();
    await preferences.setString(
      key(session.ownerId),
      jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clear(String ownerId) async {
    final preferences = await _preferences();
    await preferences.remove(key(ownerId));
  }
}
