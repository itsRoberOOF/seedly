import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Authentication used by Seedly's screens. Screens depend on this interface
/// so tests can swap Firebase for a fake.
abstract interface class SeedlyAuth {
  bool get isSignedIn;

  /// Throws [SeedlyAuthException] with a message ready to show.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Returns false when the person closes the Google picker.
  /// Throws [SeedlyAuthException] with a message ready to show.
  Future<bool> signInWithGoogle();

  /// Throws [SeedlyAuthException] with a message ready to show.
  Future<void> signOut();
}

class SeedlyAuthException implements Exception {
  const SeedlyAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebaseSeedlyAuth implements SeedlyAuth {
  FirebaseSeedlyAuth({
    FirebaseAuth? auth,
    GoogleSignIn? google,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _google = google ?? GoogleSignIn.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;
  final FirebaseFirestore _firestore;
  Future<void>? _googleReady;

  /// Mirrors the account into `users/{uid}`; the password stays in Firebase
  /// Auth. Not awaited so a slow or offline write never blocks signing in,
  /// Firestore retries it once the connection returns.
  void _saveProfile(User? user) {
    if (user == null) return;
    _firestore
        .collection('users')
        .doc(user.uid)
        .set({
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'providers': [for (final info in user.providerData) info.providerId],
          'createdAt': Timestamp.fromDate(
            user.metadata.creationTime ?? DateTime.now(),
          ),
          'lastSignInAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .catchError(
          (Object error) => debugPrint('Seedly profile not saved: $error'),
        );
  }

  @override
  bool get isSignedIn => _auth.currentUser != null;

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
      throw SeedlyAuthException(_firebaseMessage(error.code));
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
      throw const SeedlyAuthException(
        'No se pudo iniciar sesión con Google. Inténtalo de nuevo.',
      );
    } on FirebaseAuthException catch (error) {
      throw SeedlyAuthException(_firebaseMessage(error.code));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw SeedlyAuthException(_firebaseMessage(error.code));
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

  static String _firebaseMessage(String code) => switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Correo o contraseña incorrectos',
    'invalid-email' => 'Ingresa un correo válido',
    'user-disabled' => 'Esta cuenta está deshabilitada',
    'too-many-requests' => 'Demasiados intentos. Espera un momento.',
    'network-request-failed' => 'Sin conexión. Revisa tu internet.',
    'account-exists-with-different-credential' =>
      'Este correo ya usa otro método de acceso',
    'operation-not-allowed' => 'Este método de acceso no está habilitado',
    _ => 'No se pudo iniciar sesión. Inténtalo de nuevo.',
  };
}
