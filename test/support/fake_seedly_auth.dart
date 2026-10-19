import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/services/seedly_auth.dart';

/// In-memory [SeedlyAuth] so widget tests never reach Firebase.
class FakeSeedlyAuth implements SeedlyAuth {
  FakeSeedlyAuth({
    this.isSignedIn = false,
    this.error,
    this.googleResult = true,
  });

  @override
  bool isSignedIn;

  /// Thrown by both sign-in methods when set.
  SeedlyAuthException? error;

  /// What [signInWithGoogle] returns; false mimics closing the picker.
  final bool googleResult;

  final emailAttempts = <({String email, String password})>[];
  int googleAttempts = 0;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emailAttempts.add((email: email, password: password));
    if (error != null) throw error!;
    isSignedIn = true;
  }

  int signOutCalls = 0;

  /// Thrown by [signOut] when set.
  SeedlyAuthException? signOutError;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
    isSignedIn = false;
  }

  @override
  Future<bool> signInWithGoogle() async {
    googleAttempts++;
    if (error != null) throw error!;
    isSignedIn = googleResult;
    return googleResult;
  }
}
