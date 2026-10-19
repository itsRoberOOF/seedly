import '../models/seedly_errors.dart';

/// Authentication used by Seedly's screens; they never see the provider.
abstract interface class SeedlyAuthRepository {
  bool get isSignedIn;

  /// Null when signed out.
  String? get currentUserId;

  /// Throws [SeedlyAuthException].
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Returns false when the person closes the Google picker.
  /// Throws [SeedlyAuthException].
  Future<bool> signInWithGoogle();

  /// Throws [SeedlyAuthException].
  Future<void> signOut();
}
