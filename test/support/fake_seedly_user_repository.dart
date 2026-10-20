import 'package:seedly/models/seedly_user_profile.dart';
import 'package:seedly/repositories/seedly_user_repository.dart';

/// In-memory [SeedlyUserRepository] so tests never reach Firestore.
class FakeSeedlyUserRepository implements SeedlyUserRepository {
  FakeSeedlyUserRepository({this.error});

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
}
