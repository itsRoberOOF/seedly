import 'package:seedly/models/seedly_user_profile.dart';
import 'package:seedly/repositories/seedly_user_repository.dart';

/// In-memory [SeedlyUserRepository] so tests never reach Firestore.
class FakeSeedlyUserRepository implements SeedlyUserRepository {
  FakeSeedlyUserRepository({this.error});

  /// Thrown by [saveProfile] when set.
  Exception? error;

  final saved = <SeedlyUserProfile>[];

  @override
  Future<void> saveProfile(SeedlyUserProfile profile) async {
    if (error != null) throw error!;
    saved.add(profile);
  }
}
