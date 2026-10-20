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

  /// Creates the account, signs into it and gives it [name] as display name.
  /// Throws [SeedlyAuthException].
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  });

  /// Emails a link to choose a new password. Completes the same whether or
  /// not [email] has an account, so nobody can probe who signed up.
  /// Throws [SeedlyAuthException].
  Future<void> sendPasswordReset(String email);

  /// Returns false when the person closes the Google picker.
  /// Throws [SeedlyAuthException].
  Future<bool> signInWithGoogle();

  /// Throws [SeedlyAuthException].
  Future<void> signOut();
}
