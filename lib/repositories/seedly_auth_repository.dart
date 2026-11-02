import '../models/seedly_errors.dart';
import '../models/seedly_user_profile.dart';

/// Authentication used by Seedly's screens; they never see the provider.
abstract interface class SeedlyAuthRepository {
  bool get isSignedIn;

  /// Null when signed out.
  String? get currentUserId;

  /// The signed-in account's details, null when signed out.
  SeedlyUserProfile? get currentUser;

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

  /// Changes the signed-in account's display name, which every sign-in
  /// copies into the stored profile. Throws [SeedlyProfileException].
  Future<void> updateDisplayName(String name);

  /// Throws [SeedlyAuthException].
  Future<void> signOut();
}
