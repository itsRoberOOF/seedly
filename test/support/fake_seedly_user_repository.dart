import 'dart:async';

import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_user_profile.dart';
import 'package:seedly/repositories/seedly_user_repository.dart';

/// In-memory [SeedlyUserRepository] so tests never reach Firestore.
class FakeSeedlyUserRepository implements SeedlyUserRepository {
  FakeSeedlyUserRepository({this.error, this.stored});

  /// Thrown by [saveProfile] when set.
  Exception? error;

  /// Makes [saveProfile] throw [error] before it returns a future, like a
  /// non-`async` implementation would.
  bool throwSynchronously = false;

  /// Returned by [saveProfile] when set, so a test can leave a save hanging.
  Future<void>? pending;

  final saved = <SeedlyUserProfile>[];

  @override
  Future<void> saveProfile(SeedlyUserProfile profile) {
    if (throwSynchronously && error != null) throw error!;
    return pending ?? _record(profile);
  }

  Future<void> _record(SeedlyUserProfile profile) async {
    if (error != null) throw error!;
    saved.add(profile);
  }

  /// The profile [watchProfile] reports; set it to push a new value.
  SeedlyUserProfile? stored;
  late final _changes = StreamController<SeedlyUserProfile?>.broadcast();

  /// Thrown by [updateProfile] when set.
  SeedlyProfileException? updateError;

  /// What [updateProfile] returns.
  SeedlyProfileSave updateResult = SeedlyProfileSave.saved;

  /// Every [updateProfile] call, with the fields it was given (null: not
  /// given, so left alone).
  final updates =
      <({SeedlyField<String>? username, SeedlyField<String>? bio})>[];

  /// Pushes [profile] to the open [watchProfile] streams.
  void emit(SeedlyUserProfile? profile) {
    stored = profile;
    _changes.add(profile);
  }

  @override
  Stream<SeedlyUserProfile?> watchProfile(String uid) async* {
    yield stored;
    yield* _changes.stream;
  }

  @override
  Future<SeedlyProfileSave> updateProfile(
    String uid, {
    SeedlyField<String>? username,
    SeedlyField<String>? bio,
  }) async {
    if (updateError != null) throw updateError!;
    updates.add((username: username, bio: bio));
    return updateResult;
  }
}
