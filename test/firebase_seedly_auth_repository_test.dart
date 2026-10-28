import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:seedly/data/firebase/firebase_seedly_auth_repository.dart';
import 'package:seedly/models/seedly_errors.dart';

import 'support/fake_seedly_user_repository.dart';

Matcher _failsWith(SeedlyAuthError reason) => throwsA(
  isA<SeedlyAuthException>().having((error) => error.reason, 'reason', reason),
);

/// A [MockUser] whose Auth profile update can be made to fail, with no name
/// until one is stored (unlike the account MockFirebaseAuth creates itself).
// ignore: must_be_immutable
class _FlakyUser extends MockUser {
  _FlakyUser({required super.uid, this.failsUpdate = true})
    : super(email: '$uid@seedly.app');

  final bool failsUpdate;

  @override
  Future<void> updateDisplayName(String? value) {
    if (failsUpdate) {
      throw FirebaseAuthException(code: 'network-request-failed');
    }
    return super.updateDisplayName(value);
  }
}

class _Credential extends Fake implements UserCredential {
  _Credential(this.user);

  @override
  final User? user;
}

/// Signs up and in as whichever [User] is queued in [next].
class _ScriptedAuth extends Fake implements FirebaseAuth {
  User? next;
  User? _current;

  @override
  User? get currentUser => _current;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async => _Credential(_current = next);

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => _Credential(_current = next);

  @override
  Future<void> signOut() async => _current = null;
}

class _FakeGoogle extends Fake implements GoogleSignIn {
  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  late FakeSeedlyUserRepository users;
  late MockFirebaseAuth auth;
  late FirebaseSeedlyAuthRepository repository;

  setUp(() {
    users = FakeSeedlyUserRepository();
    auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'ana', email: 'ana@seedly.app'),
    );
    repository = FirebaseSeedlyAuthRepository(users: users, auth: auth);
  });

  Future<void> signIn() =>
      repository.signInWithEmail(email: 'ana@seedly.app', password: 'secreto');

  test('email sign-in signs in and mirrors the profile', () async {
    expect(repository.isSignedIn, isFalse);
    expect(repository.currentUserId, isNull);

    await signIn();

    expect(repository.isSignedIn, isTrue);
    expect(repository.currentUserId, 'ana');
    expect(users.saved, hasLength(1));
    expect(users.saved.single.uid, 'ana');
    expect(users.saved.single.email, 'ana@seedly.app');
  });

  const signInErrors = {
    'invalid-credential': SeedlyAuthError.invalidCredentials,
    'wrong-password': SeedlyAuthError.invalidCredentials,
    'user-not-found': SeedlyAuthError.invalidCredentials,
    'invalid-email': SeedlyAuthError.invalidEmail,
    'user-disabled': SeedlyAuthError.userDisabled,
    'too-many-requests': SeedlyAuthError.tooManyRequests,
    'network-request-failed': SeedlyAuthError.network,
    'account-exists-with-different-credential':
        SeedlyAuthError.accountExistsWithDifferentCredential,
    'operation-not-allowed': SeedlyAuthError.methodNotAllowed,
    'something-new': SeedlyAuthError.signInFailed,
  };
  for (final entry in signInErrors.entries) {
    test('email sign-in maps ${entry.key} to ${entry.value.name}', () async {
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: entry.key));

      await expectLater(signIn(), _failsWith(entry.value));
      expect(repository.isSignedIn, isFalse);
      expect(users.saved, isEmpty);
    });
  }

  Future<void> signUp() => repository.signUpWithEmail(
    name: 'Ana',
    email: 'nueva@seedly.app',
    password: 'secreto123',
  );

  test('email sign-up creates the account under the given name', () async {
    await signUp();

    expect(repository.isSignedIn, isTrue);
    expect(auth.currentUser!.email, 'nueva@seedly.app');
    expect(auth.currentUser!.displayName, 'Ana');
    final profile = users.saved.single;
    expect(profile.uid, repository.currentUserId);
    expect(profile.email, 'nueva@seedly.app');
    expect(profile.displayName, 'Ana');
    expect(profile.providers, ['password']);
  });

  const signUpErrors = {
    'email-already-in-use': SeedlyAuthError.emailInUse,
    'weak-password': SeedlyAuthError.weakPassword,
    'invalid-email': SeedlyAuthError.invalidEmail,
    'too-many-requests': SeedlyAuthError.tooManyRequests,
    'network-request-failed': SeedlyAuthError.network,
    'operation-not-allowed': SeedlyAuthError.methodNotAllowed,
    'something-new': SeedlyAuthError.signUpFailed,
  };
  for (final entry in signUpErrors.entries) {
    test('email sign-up maps ${entry.key} to ${entry.value.name}', () async {
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: entry.key));

      await expectLater(signUp(), _failsWith(entry.value));
      expect(repository.isSignedIn, isFalse);
      expect(users.saved, isEmpty);
    });
  }

  test('a password reset email is sent', () async {
    await expectLater(
      repository.sendPasswordReset('ana@seedly.app'),
      completes,
    );
  });

  test(
    'an email without an account looks sent, to hide who signed up',
    () async {
      whenCalling(Invocation.method(#sendPasswordResetEmail, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));

      await expectLater(
        repository.sendPasswordReset('nadie@seedly.app'),
        completes,
      );
    },
  );

  const resetErrors = {
    'invalid-email': SeedlyAuthError.invalidEmail,
    'too-many-requests': SeedlyAuthError.tooManyRequests,
    'network-request-failed': SeedlyAuthError.network,
    'something-new': SeedlyAuthError.resetFailed,
  };
  for (final entry in resetErrors.entries) {
    test('password reset maps ${entry.key} to ${entry.value.name}', () async {
      whenCalling(Invocation.method(#sendPasswordResetEmail, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: entry.key));

      await expectLater(
        repository.sendPasswordReset('ana@seedly.app'),
        _failsWith(entry.value),
      );
    });
  }

  test('signOut without a connection maps to network', () async {
    whenCalling(Invocation.method(#signOut, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

    await expectLater(
      repository.signOut(),
      _failsWith(SeedlyAuthError.network),
    );
  });

  test('signOut failing for another reason maps to signOutFailed', () async {
    whenCalling(Invocation.method(#signOut, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'something-new'));

    await expectLater(
      repository.signOut(),
      _failsWith(SeedlyAuthError.signOutFailed),
    );
  });

  test('a failing profile save does not fail the sign-in', () async {
    final logged = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message);
    addTearDown(() => debugPrint = original);
    users.error = Exception('offline');

    await signIn();
    await pumpEventQueue();

    expect(repository.isSignedIn, isTrue);
    expect(logged, ['Seedly profile not saved: Exception: offline']);
  });

  test('a hanging profile save does not block the sign-in', () async {
    users.pending = Completer<void>().future;

    await signIn();

    expect(repository.isSignedIn, isTrue);
  });

  test('a synchronously throwing save does not fail the sign-in', () async {
    final logged = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message);
    addTearDown(() => debugPrint = original);
    users
      ..error = Exception('broken')
      ..throwSynchronously = true;

    await signIn();
    await pumpEventQueue();

    expect(repository.isSignedIn, isTrue);
    expect(logged, ['Seedly profile not saved: Exception: broken']);
  });

  test('currentUser is null without a session', () {
    expect(repository.currentUser, isNull);
  });

  test('currentUser reports the signed-in account', () async {
    auth = MockFirebaseAuth(
      mockUser: MockUser(
        uid: 'ana',
        email: 'ana@seedly.app',
        displayName: 'Ana',
      ),
      signedIn: true,
    );
    repository = FirebaseSeedlyAuthRepository(users: users, auth: auth);

    final user = repository.currentUser;

    expect(user, isNotNull);
    expect(user!.uid, 'ana');
    expect(user.email, 'ana@seedly.app');
    expect(user.displayName, 'Ana');
  });

  group('the sign-up name when Auth cannot store it', () {
    late _ScriptedAuth scripted;

    setUp(() {
      scripted = _ScriptedAuth();
      repository = FirebaseSeedlyAuthRepository(
        users: users,
        auth: scripted,
        google: _FakeGoogle(),
      );
    });

    Future<void> signUpAs(User user, {String name = 'Ana'}) {
      scripted.next = user;
      return repository.signUpWithEmail(
        name: name,
        email: 'nueva@seedly.app',
        password: 'secreto123',
      );
    }

    test('currentUser falls back to the name typed at sign-up', () async {
      final logged = <String?>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logged.add(message);
      addTearDown(() => debugPrint = original);

      await signUpAs(_FlakyUser(uid: 'ana'));

      expect(scripted.currentUser!.displayName, isNull);
      expect(repository.currentUser?.displayName, 'Ana');
      expect(logged, hasLength(1));
      expect(logged.single, startsWith('Seedly display name not saved'));
    });

    test('the saved profile still carries the name', () async {
      await signUpAs(_FlakyUser(uid: 'ana'));
      await pumpEventQueue();

      expect(users.saved.single.displayName, 'Ana');
    });

    test('a stored Auth name is read from Auth', () async {
      await signUpAs(_FlakyUser(uid: 'ana', failsUpdate: false));

      expect(scripted.currentUser!.displayName, 'Ana');
      expect(repository.currentUser?.displayName, 'Ana');

      // Proof it is not the fallback: Auth changes and currentUser follows.
      await scripted.currentUser!.updateDisplayName('Ana María');
      expect(repository.currentUser?.displayName, 'Ana María');
    });

    test('an Auth name wins over the fallback', () async {
      final user = _FlakyUser(uid: 'ana');
      await signUpAs(user);
      expect(repository.currentUser?.displayName, 'Ana');

      user.displayName = 'Otra';

      expect(repository.currentUser?.displayName, 'Otra');
    });

    test('a different uid does not inherit the fallback', () async {
      await signUpAs(_FlakyUser(uid: 'ana'));
      await repository.signOut();
      scripted.next = _FlakyUser(uid: 'beto');
      await signIn();

      expect(repository.currentUser?.uid, 'beto');
      expect(repository.currentUser?.displayName, isNull);
    });

    test('signOut clears the fallback even for the same uid', () async {
      await signUpAs(_FlakyUser(uid: 'ana'));
      await repository.signOut();
      scripted.next = _FlakyUser(uid: 'ana');
      await signIn();

      expect(repository.currentUser?.displayName, isNull);
    });
  });
}
