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

  /// Mirrors the account into `users/{uid}`; the password stays in Firebase
  /// Auth. Not awaited so a slow or offline write never blocks signing in,
  /// Firestore retries it once the connection returns.
  void _saveProfile(User? user) {
    if (user == null) return;
    _users
        .saveProfile(
          SeedlyUserProfile(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            photoUrl: user.photoURL,
            providers: [for (final info in user.providerData) info.providerId],
            createdAt: user.metadata.creationTime ?? DateTime.now(),
          ),
        )
        .catchError(
          (Object error) => debugPrint('Seedly profile not saved: $error'),
        );
  }

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

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
      if (error.code == GoogleSignInExceptionCode.canceled) return false;
      throw const SeedlyAuthException(SeedlyAuthError.googleFailed);
    } on FirebaseAuthException catch (error) {
      throw SeedlyAuthException(_signInError(error.code));
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
}
