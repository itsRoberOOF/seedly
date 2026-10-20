import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/repositories/seedly_auth_repository.dart';

/// In-memory [SeedlyAuthRepository] so widget tests never reach Firebase.
class FakeSeedlyAuthRepository implements SeedlyAuthRepository {
  FakeSeedlyAuthRepository({
    this.isSignedIn = false,
    this.error,
    this.googleResult = true,
    this.uid = 'ana',
  });

  @override
  bool isSignedIn;

  /// The id [currentUserId] reports while signed in.
  final String uid;

  @override
  String? get currentUserId => isSignedIn ? uid : null;

  /// Thrown by the sign-in and sign-up methods when set.
  SeedlyAuthException? error;

  /// What [signInWithGoogle] returns; false mimics closing the picker.
  final bool googleResult;

  final emailAttempts = <({String email, String password})>[];
  final signUpAttempts = <({String name, String email, String password})>[];
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

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    signUpAttempts.add((name: name, email: email, password: password));
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
