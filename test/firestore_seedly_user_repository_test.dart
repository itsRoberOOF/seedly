import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/data/firebase/firestore_seedly_user_repository.dart';
import 'package:seedly/models/seedly_user_profile.dart';

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
}
