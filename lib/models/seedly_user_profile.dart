/// The account details mirrored into the database on each sign-in. The
/// password never leaves the auth provider.
class SeedlyUserProfile {
  const SeedlyUserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.providers = const [],
    required this.createdAt,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  /// Sign-in methods linked to the account, such as `password` or
  /// `google.com`.
  final List<String> providers;
  final DateTime createdAt;
}
