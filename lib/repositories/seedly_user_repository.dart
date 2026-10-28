import 'dart:typed_data';

import '../models/seedly_errors.dart';
import '../models/seedly_user_profile.dart';

/// Where account profiles are mirrored and edited.
abstract interface class SeedlyUserRepository {
  /// Mirrors the account details at sign-in. Never writes the fields the
  /// person edits (username, bio), so signing in can't erase them.
  /// May fail; callers don't wait for it and only log the error.
  Future<void> saveProfile(SeedlyUserProfile profile);

  /// The stored profile of [uid], again whenever it changes; null while there
  /// is none. Served from the local cache when offline. Errors end the stream.
  Stream<SeedlyUserProfile?> watchProfile(String uid);

  /// Changes only the given fields of [uid]'s stored profile.
  /// Throws [SeedlyProfileException].
  Future<SeedlyProfileSave> updateProfile(
    String uid, {
    SeedlyField<String>? username,
    SeedlyField<String>? bio,
    SeedlyField<Uint8List>? photo,
  });
}
