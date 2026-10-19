import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/seedly_user_profile.dart';
import '../../repositories/seedly_user_repository.dart';

/// Mirrors each account into `users/{uid}`. The password stays in the auth
/// provider. `lastSignInAt` is a server timestamp because `firestore.rules`
/// requires it.
class FirestoreSeedlyUserRepository implements SeedlyUserRepository {
  FirestoreSeedlyUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> saveProfile(SeedlyUserProfile profile) {
    return _firestore.collection('users').doc(profile.uid).set({
      'email': profile.email,
      'displayName': profile.displayName,
      'photoUrl': profile.photoUrl,
      'providers': profile.providers,
      'createdAt': Timestamp.fromDate(profile.createdAt),
      'lastSignInAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
