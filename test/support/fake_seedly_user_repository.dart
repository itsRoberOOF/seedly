import 'dart:async';
import 'dart:typed_data';

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
  late final _changes = StreamController<SeedlyUserProfile?>.broadcast(
    sync: true,
  );

  /// Thrown by [updateProfile] when set.
  SeedlyProfileException? updateError;

  /// What [updateProfile] returns.
  SeedlyProfileSave updateResult = SeedlyProfileSave.saved;

  /// Every [updateProfile] call, with the fields it was given (null: not
  /// given, so left alone).
  final updates =
      <
        ({
          SeedlyField<String>? displayName,
          SeedlyField<String>? username,
          SeedlyField<String>? bio,
          SeedlyField<Uint8List>? photo,
        })
      >[];

  /// Holds [updateProfile] after it records the call, until it completes;
  /// an [updateError] then throws once released.
  Future<void>? updateGate;

  /// How many times [watchProfile] was subscribed to.
  int watchCalls = 0;

  /// The next this-many [watchProfile] streams fail at once, without
  /// reporting [stored].
  int failingWatches = 0;

  /// Fails the open [watchProfile] streams.
  void emitError([Object error = 'permission-denied']) =>
      _changes.addError(error);

  /// Pushes [profile] to the open [watchProfile] streams.
  void emit(SeedlyUserProfile? profile) {
    stored = profile;
    _changes.add(profile);
  }

  @override
  Stream<SeedlyUserProfile?> watchProfile(String uid) {
    watchCalls++;
    final fails = failingWatches > 0;
    if (fails) failingWatches--;
    StreamSubscription<SeedlyUserProfile?>? changes;
    late final StreamController<SeedlyUserProfile?> controller;
    controller = StreamController<SeedlyUserProfile?>(
      sync: true,
      onListen: () {
        if (fails) {
          controller.addError(StateError('watch failed'));
          return;
        }
        controller.add(stored);
        changes = _changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      // No future returned: a failing listener that cancels on error would
      // wait for it, and a fake clock never gets there.
      onCancel: () {
        changes?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<SeedlyProfileSave> updateProfile(
    String uid, {
    SeedlyField<String>? displayName,
    SeedlyField<String>? username,
    SeedlyField<String>? bio,
    SeedlyField<Uint8List>? photo,
  }) async {
    if (updateError != null && updateGate == null) throw updateError!;
    updates.add((
      displayName: displayName,
      username: username,
      bio: bio,
      photo: photo,
    ));
    await updateGate;
    if (updateError != null) throw updateError!;
    return updateResult;
  }
}
