import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/seedly_errors.dart';
import '../../models/seedly_user_profile.dart';
import '../../repositories/seedly_user_repository.dart';

/// Mirrors each account into `users/{uid}`. The password stays in the auth
/// provider. `lastSignInAt` is a server timestamp because `firestore.rules`
/// requires it on sign-in; edits leave it as it was.
class FirestoreSeedlyUserRepository implements SeedlyUserRepository {
  FirestoreSeedlyUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// How long to wait for the server before trusting the offline queue.
  static const _serverWait = Duration(seconds: 8);

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Future<void> saveProfile(SeedlyUserProfile profile) {
    return _doc(profile.uid).set({
      'email': profile.email,
      'displayName': profile.displayName,
      'photoUrl': profile.photoUrl,
      'providers': profile.providers,
      'createdAt': Timestamp.fromDate(profile.createdAt),
      'lastSignInAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<SeedlyUserProfile?> watchProfile(String uid) {
    return _doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return SeedlyUserProfile(
        uid: uid,
        email: data['email'] as String?,
        displayName: data['displayName'] as String?,
        photoUrl: data['photoUrl'] as String?,
        username: data['username'] as String?,
        bio: data['bio'] as String?,
        photo: (data['photo'] as Blob?)?.bytes,
        providers: [
          for (final provider in data['providers'] as List? ?? const [])
            provider as String,
        ],
        // A just-written server timestamp is still null in the local copy.
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
  }

  @override
  Future<SeedlyProfileSave> updateProfile(
    String uid, {
    SeedlyField<String>? displayName,
    SeedlyField<String>? username,
    SeedlyField<String>? bio,
    SeedlyField<Uint8List>? photo,
  }) async {
    final changes = <String, Object?>{
      // Kept (as null when cleared) since the rules read it on every write.
      if (displayName != null) 'displayName': displayName.value,
      if (username != null) 'username': _valueOrDelete(username.value),
      if (bio != null) 'bio': _valueOrDelete(bio.value),
      // Avatar-sized, so it fits in the document; Storage needs Blaze.
      if (photo != null)
        'photo': _valueOrDelete(
          photo.value == null ? null : Blob(photo.value!),
        ),
    };
    if (changes.isEmpty) return SeedlyProfileSave.saved;
    // Offline, the write is already in the local cache and syncs later, but
    // the future only completes once the server answers.
    try {
      await _doc(uid).update(changes).timeout(_serverWait);
      return SeedlyProfileSave.saved;
    } on TimeoutException {
      return SeedlyProfileSave.pendingSync;
    } on FirebaseException catch (error) {
      // Without a profile document the rules read an update as a create they
      // refuse, so a missing document arrives as permission-denied: the
      // account has to sign in again for its profile to be written.
      final missing =
          error.code == 'permission-denied' || error.code == 'not-found';
      throw SeedlyProfileException(
        missing
            ? SeedlyProfileError.sessionExpired
            : SeedlyProfileError.saveFailed,
      );
    }
  }

  static Object _valueOrDelete(Object? value) => value ?? FieldValue.delete();
}
