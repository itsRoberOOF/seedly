import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/data/firebase/firestore_seedly_user_repository.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_user_profile.dart';

import 'support/fake_seedly_image_picker.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreSeedlyUserRepository users;

  final profile = SeedlyUserProfile(
    uid: 'ana',
    email: 'ana@seedly.app',
    displayName: 'Ana',
    photoUrl: 'https://seedly.app/ana.png',
    providers: const ['password', 'google.com'],
    createdAt: DateTime(2026, 10, 1, 9, 30),
  );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    users = FirestoreSeedlyUserRepository(firestore: firestore);
  });

  test('writes the profile to users/{uid}', () async {
    await users.saveProfile(profile);

    final data = (await firestore.collection('users').doc('ana').get()).data()!;
    expect(data['email'], 'ana@seedly.app');
    expect(data['displayName'], 'Ana');
    expect(data['photoUrl'], 'https://seedly.app/ana.png');
    expect(data['providers'], ['password', 'google.com']);
    expect(data['createdAt'], Timestamp.fromDate(DateTime(2026, 10, 1, 9, 30)));
    expect(data['lastSignInAt'], isNotNull);
    // validProfile() in firestore.rules rejects any other key, so the uid
    // must stay the document id and never become a field.
    expect(
      data.keys,
      unorderedEquals([
        'email',
        'displayName',
        'photoUrl',
        'providers',
        'createdAt',
        'lastSignInAt',
      ]),
    );
  });

  test('keeps the fields it does not write', () async {
    await firestore.collection('users').doc('ana').set({'language': 'es'});

    await users.saveProfile(profile);

    final data = (await firestore.collection('users').doc('ana').get()).data()!;
    expect(data['language'], 'es');
    expect(data['email'], 'ana@seedly.app');
  });

  group('watchProfile', () {
    test('emits null without a document', () async {
      expect(await users.watchProfile('ana').first, isNull);
    });

    test('emits the profile with username and bio, then later edits', () async {
      await users.saveProfile(profile);
      await users.updateProfile(
        'ana',
        username: const SeedlyField('ana_1'),
        bio: const SeedlyField('Hola'),
      );

      final emitted = users.watchProfile('ana');
      final stored = await emitted.first;
      expect(stored!.username, 'ana_1');
      expect(stored.bio, 'Hola');
      expect(stored.email, 'ana@seedly.app');
      expect(stored.providers, ['password', 'google.com']);

      final next = expectLater(
        emitted,
        emitsThrough(predicate<SeedlyUserProfile?>((p) => p?.bio == 'Otra')),
      );
      await users.updateProfile('ana', bio: const SeedlyField('Otra'));
      await next;
    });
  });

  test('watchProfile emits the photo as bytes', () async {
    await users.saveProfile(profile);
    expect((await users.watchProfile('ana').first)!.photo, isNull);

    await users.updateProfile('ana', photo: SeedlyField(tinyPng));

    expect((await users.watchProfile('ana').first)!.photo, tinyPng);
  });

  group('updateProfile', () {
    Future<Map<String, dynamic>> data() async =>
        (await firestore.collection('users').doc('ana').get()).data()!;

    test('writes only the given fields', () async {
      await users.saveProfile(profile);

      final result = await users.updateProfile(
        'ana',
        username: const SeedlyField('ana_1'),
      );

      expect(result, SeedlyProfileSave.saved);
      expect((await data())['username'], 'ana_1');
      expect((await data()).containsKey('bio'), isFalse);

      await users.updateProfile('ana', bio: const SeedlyField('Hola'));
      expect((await data())['username'], 'ana_1');
      expect((await data())['bio'], 'Hola');
    });

    test('a null value deletes the key', () async {
      await users.saveProfile(profile);
      await users.updateProfile(
        'ana',
        username: const SeedlyField('ana_1'),
        bio: const SeedlyField('Hola'),
      );

      await users.updateProfile('ana', username: const SeedlyField(null));

      expect((await data()).containsKey('username'), isFalse);
      expect((await data())['bio'], 'Hola');
    });

    test('a photo is stored as a Blob and leaves username and bio', () async {
      await users.saveProfile(profile);
      await users.updateProfile(
        'ana',
        username: const SeedlyField('ana_1'),
        bio: const SeedlyField('Hola'),
      );

      await users.updateProfile('ana', photo: SeedlyField(tinyPng));

      final photo = (await data())['photo'];
      expect(photo, isA<Blob>());
      expect((photo as Blob).bytes, tinyPng);
      expect((await data())['username'], 'ana_1');
      expect((await data())['bio'], 'Hola');
    });

    test('a null photo deletes the key', () async {
      await users.saveProfile(profile);
      await users.updateProfile('ana', photo: SeedlyField(tinyPng));

      await users.updateProfile('ana', photo: const SeedlyField(null));

      expect((await data()).containsKey('photo'), isFalse);
    });

    test('without fields it writes nothing, even without a document', () async {
      final result = await users.updateProfile('ana');

      expect(result, SeedlyProfileSave.saved);
      expect(
        (await firestore.collection('users').doc('ana').get()).exists,
        isFalse,
      );
    });

    test('does not change lastSignInAt', () async {
      final ref = firestore.collection('users').doc('ana');
      await ref.set({
        'email': 'ana@seedly.app',
        'lastSignInAt': Timestamp.fromDate(DateTime(2026, 9)),
      });

      await users.updateProfile('ana', bio: const SeedlyField('Hola'));

      expect(
        (await data())['lastSignInAt'],
        Timestamp.fromDate(DateTime(2026, 9)),
      );
    });

    test('fails with saveFailed when the document does not exist', () async {
      await expectLater(
        users.updateProfile('ana', bio: const SeedlyField('Hola')),
        throwsA(
          isA<SeedlyProfileException>().having(
            (e) => e.reason,
            'reason',
            SeedlyProfileError.saveFailed,
          ),
        ),
      );
    });
  });

  test('signing in again keeps the username and bio', () async {
    await users.saveProfile(profile);
    await users.updateProfile(
      'ana',
      username: const SeedlyField('ana_1'),
      bio: const SeedlyField('Hola'),
    );

    await users.saveProfile(profile);

    final data = (await firestore.collection('users').doc('ana').get()).data()!;
    expect(data['username'], 'ana_1');
    expect(data['bio'], 'Hola');
  });

  test('signing in again keeps the photo', () async {
    await users.saveProfile(profile);
    await users.updateProfile('ana', photo: SeedlyField(tinyPng));

    await users.saveProfile(profile);

    final data = (await firestore.collection('users').doc('ana').get()).data()!;
    expect((data['photo'] as Blob).bytes, tinyPng);
  });
}
