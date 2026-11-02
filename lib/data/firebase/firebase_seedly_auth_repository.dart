import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/seedly_errors.dart';
import '../../models/seedly_user_profile.dart';
import '../../repositories/seedly_auth_repository.dart';
import '../../repositories/seedly_user_repository.dart';

class FirebaseSeedlyAuthRepository implements SeedlyAuthRepository {
  FirebaseSeedlyAuthRepository({
    required this._users,
    FirebaseAuth? auth,
    GoogleSignIn? google,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _google = google ?? GoogleSignIn.instance;

  final SeedlyUserRepository _users;
  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  Future<void>? _googleReady;

  /// The name typed at sign-up when Auth could not store it. Until the next
  /// sign-in [currentUser] shows it, like the profile saved in the database.
  ({String uid, String name})? _signUpName;

  static SeedlyUserProfile _profileOf(User user, {String? displayName}) =>
      SeedlyUserProfile(
        uid: user.uid,
        email: user.email,
        displayName: displayName ?? user.displayName,
        photoUrl: user.photoURL,
        providers: [for (final info in user.providerData) info.providerId],
        createdAt: user.metadata.creationTime ?? DateTime.now(),
      );

  /// Mirrors the account through the user repository. Not awaited so a slow
  /// or offline write never blocks signing in.
  void _saveProfile(User? user, {String? displayName}) {
    if (user == null) return;
    final profile = _profileOf(user, displayName: displayName);
    Future.sync(() => _users.saveProfile(profile)).catchError(
      (Object error) => debugPrint('Seedly profile not saved: $error'),
    );
  }

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  SeedlyUserProfile? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    final fallback = _signUpName;
    return _profileOf(
      user,
      displayName:
          user.displayName ??
          (fallback?.uid == user.uid ? fallback?.name : null),
    );
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _saveProfile(result.user);
    } on FirebaseAuthException catch (error) {
      throw SeedlyAuthException(_signInError(error.code));
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final User? user;
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = result.user;
    } on FirebaseAuthException catch (error) {
      throw SeedlyAuthException(_signUpError(error.code));
    }
    // The account already exists and is signed in, so a failed name update
    // must not report the sign-up as failed; the profile still has the name.
    try {
      await user?.updateDisplayName(name);
    } on FirebaseAuthException catch (error) {
      debugPrint('Seedly display name not saved: $error');
      if (user != null) _signUpName = (uid: user.uid, name: name);
    }
    _saveProfile(user, displayName: name);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const SeedlyProfileException(SeedlyProfileError.sessionExpired);
    }
    try {
      await user.updateDisplayName(name);
      _signUpName = null;
    } on FirebaseAuthException catch (error) {
      throw SeedlyProfileException(
        error.code == 'requires-recent-login' ||
                error.code == 'user-token-expired' ||
                error.code == 'user-not-found'
            ? SeedlyProfileError.sessionExpired
            : SeedlyProfileError.saveFailed,
      );
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      // Projects without email enumeration protection still report this.
      if (error.code == 'user-not-found') return;
      throw SeedlyAuthException(_resetError(error.code));
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    try {
      await (_googleReady ??= _google.initialize());
      final account = await _google.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      _saveProfile(result.user);
      return true;
    } on GoogleSignInException catch (error) {
      debugPrint(
        'Seedly Google sign-in failed: ${error.code.name} '
        '(${error.description})',
      );
      // Google also reports "[16] Account reauth failed." as `canceled` when
      // the account is picked but cannot be verified (typically this build's
      // signing key is not registered in Firebase). Only a picker closed on
      // purpose ("Cancelled by user.") is silent.
      final reauthFailed =
          error.description?.toLowerCase().contains('reauth') ?? false;
      if (error.code == GoogleSignInExceptionCode.canceled && !reauthFailed) {
        return false;
      }
      throw SeedlyAuthException(switch (error.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError ||
        GoogleSignInExceptionCode.canceled => SeedlyAuthError.googleConfig,
        _ => SeedlyAuthError.googleFailed,
      });
    } on FirebaseAuthException catch (error) {
      debugPrint('Seedly Google sign-in rejected: ${error.code}');
      throw SeedlyAuthException(_signInError(error.code));
    } on Exception catch (error) {
      // Anything unexpected must reach the user instead of ending the tap in
      // silence.
      debugPrint('Seedly Google sign-in crashed: $error');
      throw const SeedlyAuthException(SeedlyAuthError.googleFailed);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw SeedlyAuthException(
        error.code == 'network-request-failed'
            ? SeedlyAuthError.network
            : SeedlyAuthError.signOutFailed,
      );
    }
    _signUpName = null;
    // Forget the Google account too so the next Google sign-in shows the
    // account picker. The Firebase session is already closed, so a failure
    // here must not undo the sign-out.
    try {
      await (_googleReady ??= _google.initialize());
      await _google.signOut();
    } on Exception catch (error) {
      debugPrint('Seedly Google sign-out skipped: $error');
    }
  }

  static SeedlyAuthError _signInError(String code) => switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => SeedlyAuthError.invalidCredentials,
    'invalid-email' => SeedlyAuthError.invalidEmail,
    'user-disabled' => SeedlyAuthError.userDisabled,
    'too-many-requests' => SeedlyAuthError.tooManyRequests,
    'network-request-failed' => SeedlyAuthError.network,
    'account-exists-with-different-credential' =>
      SeedlyAuthError.accountExistsWithDifferentCredential,
    'operation-not-allowed' => SeedlyAuthError.methodNotAllowed,
    _ => SeedlyAuthError.signInFailed,
  };

  static SeedlyAuthError _signUpError(String code) => switch (code) {
    'email-already-in-use' => SeedlyAuthError.emailInUse,
    'weak-password' => SeedlyAuthError.weakPassword,
    'invalid-email' => SeedlyAuthError.invalidEmail,
    'too-many-requests' => SeedlyAuthError.tooManyRequests,
    'network-request-failed' => SeedlyAuthError.network,
    'operation-not-allowed' => SeedlyAuthError.methodNotAllowed,
    _ => SeedlyAuthError.signUpFailed,
  };

  static SeedlyAuthError _resetError(String code) => switch (code) {
    'invalid-email' => SeedlyAuthError.invalidEmail,
    'too-many-requests' => SeedlyAuthError.tooManyRequests,
    'network-request-failed' => SeedlyAuthError.network,
    _ => SeedlyAuthError.resetFailed,
  };
}
