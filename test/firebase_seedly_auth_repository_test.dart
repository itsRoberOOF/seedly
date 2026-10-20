import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:seedly/data/firebase/firebase_seedly_auth_repository.dart';
import 'package:seedly/models/seedly_errors.dart';

import 'support/fake_seedly_user_repository.dart';

Matcher _failsWith(SeedlyAuthError reason) => throwsA(
  isA<SeedlyAuthException>().having((error) => error.reason, 'reason', reason),
);

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
}
