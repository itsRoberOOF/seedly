import '../models/seedly_user_profile.dart';

/// Where account profiles are mirrored.
abstract interface class SeedlyUserRepository {
  /// May fail; callers don't wait for it and only log the error.
  Future<void> saveProfile(SeedlyUserProfile profile);
}
