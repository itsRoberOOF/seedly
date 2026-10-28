/// The account details mirrored into the database on each sign-in, plus what
/// the person edits in Mi perfil. The password never leaves the auth provider.
class SeedlyUserProfile {
  const SeedlyUserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.username,
    this.bio,
    this.providers = const [],
    required this.createdAt,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  /// The handle shown after "@", lowercase and already validated.
  final String? username;
  final String? bio;

  /// Sign-in methods linked to the account, such as `password` or
  /// `google.com`.
  final List<String> providers;
  final DateTime createdAt;
}

/// A profile field being changed: [value] null clears it. A null
/// [SeedlyField] leaves the field alone.
final class SeedlyField<T> {
  const SeedlyField(this.value);

  final T? value;
}

/// How far an edit got, as for projects: offline it waits in the local
/// queue and syncs later.
enum SeedlyProfileSave { saved, pendingSync }
